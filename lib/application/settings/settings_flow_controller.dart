import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_diary/application/diary/diary_entry_providers.dart';
import 'package:quill_diary/application/errors/user_facing_error.dart';
import 'package:quill_diary/application/people/people_providers.dart';
import 'package:quill_diary/application/restore/restore_backup_flow.dart';
import 'package:quill_diary/application/session/session_messages.dart';
import 'package:quill_diary/application/session/session_providers.dart';
import 'package:quill_diary/application/session/session_state.dart';
import 'package:quill_diary/application/settings/drive_upload_coordinator.dart';
import 'package:quill_diary/application/settings/portable_import_result_presenter.dart';
import 'package:quill_diary/application/settings/settings_providers.dart';
import 'package:quill_diary/application/settings/settings_text.dart';
import 'package:quill_diary/application/settings/unlock_mode_change_flow.dart';
import 'package:quill_diary/application/tag/tag_providers.dart';
import 'package:quill_diary/application/transfer/portable_transfer_service.dart';
import 'package:quill_diary/application/transfer/transfer_feedback.dart';
import 'package:quill_diary/application/transfer/vault_backup_providers.dart';
import 'package:quill_diary/application/vault/vault_providers.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/domain/vault_maintenance_models.dart';
import 'package:quill_diary/domain/vault_salvage_draft.dart';
import 'package:quill_diary/infrastructure/drive/drive_backup_service.dart';
import 'package:quill_diary/infrastructure/security/app_unlock_mode.dart';
import 'package:quill_diary/infrastructure/security/device_key_manager.dart';
import 'package:quill_diary/infrastructure/security/unlock_mode_change_service.dart';
import 'package:quill_diary/infrastructure/storage/backup_status_store.dart';
import 'package:quill_diary/infrastructure/storage/backup_task_progress.dart';
import 'package:quill_diary/infrastructure/storage/portable/portable_export_io.dart';
import 'package:quill_diary/infrastructure/storage/restore_precheck.dart';
import 'package:quill_diary/infrastructure/storage/shared/portable_import_result.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';
import 'package:quill_diary/infrastructure/storage/vault_transfer_models.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/presentation/display_format.dart';

final settingsFlowControllerProvider = Provider<SettingsFlowController>((
  Ref ref,
) {
  return SettingsFlowController(ref);
});

/// 修復前備份未通過驗證時拋出，呼叫端不得繼續修復。
class VaultRepairBackupException implements Exception {
  const VaultRepairBackupException(this.result);

  final BackupPersistResult result;

  @override
  String toString() =>
      'VaultRepairBackupException(${result.status.name}: ${result.message})';
}

enum SettingsFlowFeedbackTone { info, success, warning, error }

class SettingsFlowFeedback {
  const SettingsFlowFeedback(
    this.message, {
    this.tone = SettingsFlowFeedbackTone.info,
  });

  final String message;
  final SettingsFlowFeedbackTone tone;
}

class PreparedRestoreRequest {
  const PreparedRestoreRequest({
    required this.backupFile,
    required this.precheck,
    this.driveBackupName,
    this.tempFileToDelete,
  });

  final File backupFile;
  final RestorePrecheck precheck;
  final String? driveBackupName;
  final File? tempFileToDelete;

  Future<void> dispose() => _deleteRestoreTemporaryFile(tempFileToDelete);
}

Future<void> _deleteRestoreTemporaryFile(File? file) async {
  if (file == null) return;
  try {
    await file.delete();
  } on FileSystemException {
    // 清理失敗不能使已完成的還原變成失敗。
  }
}

class SettingsFlowController {
  const SettingsFlowController(this._ref);

  final Ref _ref;

  Future<SettingsFlowFeedback?> importDocuments(
    AppLocalizations l10n, {
    required ConfirmPortableImportPreview confirmPreview,
  }) async {
    final PortableImportResult? result = await _ref
        .read(appSessionProvider.notifier)
        .runSensitiveTask((UnlockedVaultSession session) {
          return _ref
              .read(portableTransferServiceProvider)
              .importDocumentsWithPicker(
                session,
                l10n: l10n,
                confirmPreview: confirmPreview,
              );
        });
    if (result == null) {
      return null;
    }
    if (result.importedEntries == 0) {
      return SettingsFlowFeedback(result.messageWhenNoEntriesImported(l10n));
    }
    _refreshCaches();
    return SettingsFlowFeedback(
      result.formatSuccessMessage(l10n),
      tone: SettingsFlowFeedbackTone.success,
    );
  }

  Future<MarkdownExportEstimate> estimateMarkdownExport() {
    return _ref.read(portableTransferServiceProvider).estimateMarkdownExport();
  }

  Future<SettingsFlowFeedback?> exportMarkdown(
    AppLocalizations l10n, {
    required Set<EntryId> entryIds,
    MarkdownExportOptions options = const MarkdownExportOptions(),
  }) async {
    final String? exportPath = await _ref
        .read(appSessionProvider.notifier)
        .runSensitiveTask((UnlockedVaultSession session) {
          return _ref
              .read(portableTransferServiceProvider)
              .exportMarkdownToDirectory(
                session,
                l10n,
                entryIds: entryIds,
                options: options,
              );
        });
    if (exportPath == null) {
      return null;
    }
    return SettingsFlowFeedback(
      l10n.settingsImportExportExportSuccess(
        DisplayFormat.formatSavedFileNameForDisplay(exportPath),
      ),
      tone: SettingsFlowFeedbackTone.success,
    );
  }

  Future<String> createRecoveryKey() async {
    final RecoverySetupResult result = await _ref
        .read(vaultRepositoryProvider)
        .setupRecoveryKey();
    _ref.read(appSessionProvider.notifier).activateSession(result.session);
    _ref.invalidate(recoveryMetadataProvider);
    _refreshCaches();
    return result.recoveryKey;
  }

  Future<BackupPersistResult> createLocalBackup({
    BackupTaskProgressListener? onProgress,
  }) {
    return _ref
        .read(vaultBackupServiceProvider)
        .saveBackupToAppLocal(onProgress: onProgress);
  }

  Future<BackupPersistResult> exportLocalBackup({
    required AppLocalizations l10n,
    BackupTaskProgressListener? onProgress,
  }) {
    return _ref
        .read(vaultBackupServiceProvider)
        .saveBackupToExternalDirectory(l10n: l10n, onProgress: onProgress);
  }

  Future<PreparedRestoreRequest?> prepareAppLocalRestore({
    required Future<LocalBackupFile?> Function(List<LocalBackupFile> backups)
    pickBackup,
  }) async {
    final List<LocalBackupFile> backups = await _ref
        .read(vaultBackupServiceProvider)
        .listAppLocalBackups();
    final LocalBackupFile? backup = await pickBackup(backups);
    if (backup == null) {
      return null;
    }
    return _prepareRestoreFile(File(backup.path));
  }

  Future<PreparedRestoreRequest?> prepareExternalRestore(
    AppLocalizations l10n,
  ) async {
    final PickedBackupFile? backup = await _ref
        .read(vaultRestoreServiceProvider)
        .pickLocalBackupFile(l10n);
    if (backup == null) {
      return null;
    }
    return _prepareRestoreFile(
      backup.file,
      tempFileToDelete: backup.shouldDeleteAfterUse ? backup.file : null,
    );
  }

  Future<PreparedRestoreRequest> prepareDriveRestore(
    DriveBackupFile backup, {
    BackupTaskProgressListener? onProgress,
  }) async {
    final File tempBackup = await _ref
        .read(vaultRestoreServiceProvider)
        .downloadDriveBackupToTempFile(backup, onProgress: onProgress);
    return _prepareRestoreFile(
      tempBackup,
      driveBackupName: backup.name,
      tempFileToDelete: tempBackup,
    );
  }

  Future<List<DriveBackupFile>> listDriveBackups() {
    return _ref.read(vaultBackupServiceProvider).listDriveBackups();
  }

  Future<PreparedRestoreRequest> _prepareRestoreFile(
    File backupFile, {
    String? driveBackupName,
    File? tempFileToDelete,
  }) async {
    final staged =
        tempFileToDelete ??
        await _ref
            .read(vaultBackupServiceProvider)
            .copyBackupForRestore(backupFile);
    try {
      final RestorePrecheck precheck = await _ref
          .read(vaultRestoreServiceProvider)
          .precheckRestore(staged);
      return PreparedRestoreRequest(
        backupFile: staged,
        precheck: precheck,
        driveBackupName: driveBackupName,
        tempFileToDelete: staged,
      );
    } on Object {
      await _deleteRestoreTemporaryFile(staged);
      rethrow;
    }
  }

  Future<SettingsFlowFeedback> linkGoogleDrive(AppLocalizations l10n) async {
    final DriveConnectionState connectionState = await _ref
        .read(vaultBackupServiceProvider)
        .linkGoogleDrive();
    await _refreshDriveConnection();
    return SettingsFlowFeedback(
      settingsDriveLinkSuccess(l10n, connectionState.accountLabel(l10n)),
      tone: SettingsFlowFeedbackTone.success,
    );
  }

  Future<SettingsFlowFeedback> switchGoogleDrive(AppLocalizations l10n) async {
    final DriveConnectionState connectionState = await _ref
        .read(vaultBackupServiceProvider)
        .switchGoogleDrive();
    await _refreshDriveConnection();
    return SettingsFlowFeedback(
      settingsDriveSwitchAccountSuccess(
        l10n,
        connectionState.accountLabel(l10n),
      ),
      tone: SettingsFlowFeedbackTone.success,
    );
  }

  Future<SettingsFlowFeedback> disconnectGoogleDrive(
    AppLocalizations l10n,
  ) async {
    await _ref.read(vaultBackupServiceProvider).disconnectGoogleDrive();
    await _refreshDriveConnection();
    return SettingsFlowFeedback(
      l10n.settingsDriveBackupDisconnectSuccess,
      tone: SettingsFlowFeedbackTone.success,
    );
  }

  Future<VaultInspectReport> inspectVault({
    VaultRepairProgressCallback? onProgress,
  }) async {
    final VaultInspectReport report = await _ref
        .read(appSessionProvider.notifier)
        .runSensitiveTask((UnlockedVaultSession session) {
          return _ref
              .read(vaultRepositoryProvider)
              .inspectVaultWithReport(session, onProgress: onProgress);
        });
    _refreshVaultMaintenanceCaches();
    return report;
  }

  Future<VaultRepairReport> repairVaultAfterVerifiedBackup({
    VaultMaintenanceFlowProgressCallback? onProgress,
  }) async {
    onProgress?.call(VaultMaintenanceFlowPhase.creatingBackup);
    final BackupPersistResult backupResult = await _ref
        .read(vaultBackupServiceProvider)
        .saveBackupBeforeRepair();
    if (backupResult.status != BackupPersistStatus.success) {
      throw VaultRepairBackupException(backupResult);
    }
    final String backupFileName = DisplayFormat.formatSavedFileNameForDisplay(
      backupResult.savedPath ?? '',
    );
    final VaultRepairReport report = await _ref
        .read(appSessionProvider.notifier)
        .runSensitiveTask((UnlockedVaultSession session) {
          return _ref
              .read(vaultRepositoryProvider)
              .repairVaultWithReport(
                session,
                backupFileName: backupFileName,
                onProgress: (VaultRepairPhase phase) {
                  onProgress?.call(switch (phase) {
                    VaultRepairPhase.scanningEntries =>
                      VaultMaintenanceFlowPhase.repairingEntries,
                    VaultRepairPhase.checkingAttachments =>
                      VaultMaintenanceFlowPhase.repairingAttachments,
                    VaultRepairPhase.rebuildingIndex ||
                    VaultRepairPhase.rebuildingPeopleAnalytics ||
                    VaultRepairPhase.cleaning =>
                      VaultMaintenanceFlowPhase.updatingSearch,
                  });
                },
              );
        });
    try {
      await _ref
          .read(driveUploadCoordinatorProvider.notifier)
          .cleanupAbandonedUploadFiles();
    } on Exception {
      // 本機修復已完成，原生暫存留待下次修復清理。
    }
    await _ref.read(backupStatusStoreProvider).recordLocalBackupSuccess();
    _ref.invalidate(backupStatusProvider);
    _refreshVaultMaintenanceCaches();
    return report.copyWith(backupFileName: backupFileName);
  }

  Future<VaultSalvageDraft?> prepareSalvageDraft(
    List<VaultFinding> findings,
  ) async {
    return _ref.read(appSessionProvider.notifier).runSensitiveTask((
      UnlockedVaultSession session,
    ) async {
      final VaultSalvageDraft? draft = await _ref
          .read(vaultRepositoryProvider)
          .tryCreateSalvageDraft(session, findings: findings);
      if (draft == null) return null;
      await _ref
          .read(editorDraftStoreProvider)
          .write(
            VaultSalvageDraft.draftKeyForToken(draft.token),
            draft.record,
            session,
          );
      return draft;
    });
  }

  Future<bool> canSalvageFindings(List<VaultFinding> findings) async {
    return _ref.read(appSessionProvider.notifier).runSensitiveTask((
      UnlockedVaultSession session,
    ) {
      return _ref
          .read(vaultRepositoryProvider)
          .canSalvageFindings(session, findings);
    });
  }

  /// 永久刪除無法安全開啟的異常項對應檔案，並更新最近摘要。
  Future<int> permanentlyDeleteAbnormalFindings(
    List<VaultFinding> findings,
  ) async {
    final int deleted = await _ref
        .read(appSessionProvider.notifier)
        .runSensitiveTask((UnlockedVaultSession session) {
          return _ref
              .read(vaultRepositoryProvider)
              .permanentlyDeleteAbnormalFindings(session, findings: findings);
        });
    _refreshVaultMaintenanceCaches();
    return deleted;
  }

  void _refreshVaultMaintenanceCaches() {
    _refreshCaches();
    _ref
      ..invalidate(recoveryMetadataProvider)
      ..invalidate(tagAccentArgbMapProvider)
      ..invalidate(vaultRepairSummaryProvider)
      ..invalidate(vaultInspectSummaryProvider)
      ..invalidate(peopleCatalogProvider);
  }

  Future<void> retryTrustedUnlock() async {
    final UnlockOutcome outcome = await _ref
        .read(appSessionProvider.notifier)
        .unlock();
    if (outcome == UnlockOutcome.success) {
      _refreshCaches();
    }
  }

  Future<SettingsFlowFeedback?> applyUnlockMode(
    AppLocalizations l10n,
    AppUnlockMode mode,
  ) async {
    final UnlockModeChangeOutcome outcome = await applyUnlockModeChange(
      ref: _ref,
      mode: mode,
    );
    if (outcome is! UnlockModeChangeMessage) {
      _ref.invalidate(trustedDeviceAccessProvider);
      return null;
    }
    _ref.invalidate(trustedDeviceAccessProvider);
    return SettingsFlowFeedback(
      unlockModeChangeMessage(l10n, outcome.kind),
      tone: switch (outcome.kind) {
        UnlockModeChangeMessageKind.changeCancelled =>
          SettingsFlowFeedbackTone.info,
        UnlockModeChangeMessageKind.requiresUnlockedSession ||
        UnlockModeChangeMessageKind.requiresDeviceLock ||
        UnlockModeChangeMessageKind.requiresBiometricEnrollment =>
          SettingsFlowFeedbackTone.warning,
        UnlockModeChangeMessageKind.authFailed =>
          SettingsFlowFeedbackTone.error,
      },
    );
  }

  Future<PreparedRecoveryKeyRotation> prepareRecoveryKeyRotation() => _ref
      .read(appSessionProvider.notifier)
      .runSensitiveTask(
        _ref.read(vaultRepositoryProvider).prepareRecoveryKeyRotation,
      );

  Future<SettingsFlowFeedback> rotateRecoveryKey(
    AppLocalizations l10n,
    PreparedRecoveryKeyRotation prepared,
  ) async {
    return _ref.read(appSessionProvider.notifier).runSensitiveTask((
      UnlockedVaultSession session,
    ) async {
      final RecoverySetupResult result;
      try {
        result = await _ref
            .read(vaultRepositoryProvider)
            .rotateRecoveryKey(session, prepared);
      } on DeviceKeyUserCancelledException {
        return SettingsFlowFeedback(l10n.settingsRecoveryKeyUpdateCancelled);
      } on DeviceKeyException catch (error) {
        return SettingsFlowFeedback(
          friendlySessionErrorMessage(l10n, error),
          tone: SettingsFlowFeedbackTone.error,
        );
      }
      _ref
          .read(appSessionProvider.notifier)
          .activateSession(
            result.session,
            message: l10n.sessionRecoveryKeyRotatedMessage,
          );
      _ref.invalidate(recoveryMetadataProvider);
      _ref.invalidate(backupStatusProvider);
      _refreshCaches();
      return SettingsFlowFeedback(
        l10n.sessionRecoveryKeyRotatedMessage,
        tone: SettingsFlowFeedbackTone.success,
      );
    });
  }

  Future<void> deleteAppLocalBackup(LocalBackupFile backup) {
    return _ref.read(vaultBackupServiceProvider).deleteAppLocalBackup(backup);
  }

  Future<void> deleteDriveBackup(DriveBackupFile backup) {
    return _ref.read(vaultBackupServiceProvider).deleteDriveBackup(backup);
  }

  Future<void> cancelRecoveryUnlock() {
    return _ref.read(appSessionProvider.notifier).lock();
  }

  Future<SettingsFlowFeedback?> unlockWithRecovery(
    AppLocalizations l10n,
    String recoveryKey,
  ) async {
    await _ref
        .read(appSessionProvider.notifier)
        .unlockWithRecovery(recoveryKey);
    _refreshCaches();
    return SettingsFlowFeedback(
      l10n.sessionRecoveryUnlockSuccessMessage,
      tone: SettingsFlowFeedbackTone.success,
    );
  }

  Future<VerifiedBackupKey> verifyRestoreRecoveryKey(
    File backupFile,
    String recoveryKey,
  ) => RestoreBackupFlow(_ref).verifyBackupRecoveryKey(backupFile, recoveryKey);

  Future<void> restorePreparedRequest({
    required PreparedRestoreRequest request,
    VerifiedBackupKey? verifiedKey,
    BackupTaskProgressListener? onProgress,
  }) async {
    try {
      final RestoreBackupFlow flow = RestoreBackupFlow(_ref);
      await flow.ensureRestoreAllowed();
      final RestorePreparedContext prepared = RestorePreparedContext(
        precheck: request.precheck,
        verifiedKey: verifiedKey,
      );
      return await flow.executeRestoreAndFinishSession(
        backupFile: request.backupFile,
        prepared: prepared,
        onProgress: onProgress,
      );
    } finally {
      _ref.invalidate(trustedDeviceAccessProvider);
    }
  }

  Future<SettingsFlowFeedback?> recordBackupPersistResult({
    required AppLocalizations l10n,
    required BackupPersistResult result,
    required BackupStatusAction action,
    required String Function(String savedPath) onSuccess,
    String Function(String message)? inspectFailedMessage,
    String? driveAccountLabel,
  }) async {
    final BackupStatusStore store = _ref.read(backupStatusStoreProvider);
    final feedback = _backupPersistFeedback(
      l10n: l10n,
      result: result,
      onSuccess: onSuccess,
      inspectFailedMessage: inspectFailedMessage,
    );
    switch (result.status) {
      case BackupPersistStatus.success:
        try {
          await (switch (action) {
            BackupStatusAction.localBackup => store.recordLocalBackupSuccess(
              identity: result.identity,
              purpose: result.purpose,
            ),
            BackupStatusAction.externalExport =>
              store.recordExternalExportSuccess(
                identity: result.identity,
                purpose: result.purpose,
              ),
            BackupStatusAction.driveUpload => store.recordDriveUploadSuccess(
              identity: result.identity,
              purpose: result.purpose,
              accountLabel: driveAccountLabel,
            ),
          });
        } on Exception {
          return SettingsFlowFeedback(
            [
              if (feedback != null) feedback.message,
              l10n.settingsBackupStatusUpdateFailedAfterDelivery,
            ].join('\n'),
            tone: SettingsFlowFeedbackTone.warning,
          );
        } finally {
          _ref.invalidate(backupStatusProvider);
        }
        break;
      case BackupPersistStatus.inspectFailed:
        final String detail = localizedBackupInspectDetail(
          l10n,
          result.message.trim(),
        );
        final String message = detail.isNotEmpty
            ? detail
            : l10n.settingsLocalBackupBackupInspectFailed('');
        await store.recordFailure(action: action, message: message);
        _ref.invalidate(backupStatusProvider);
        break;
      case BackupPersistStatus.cancelled:
        break;
    }
    return feedback;
  }

  Future<void> _refreshDriveConnection() async {
    _ref.invalidate(settingsDriveConnectionProvider);
    await _ref.read(settingsDriveConnectionProvider.future);
    // 連回帳戶後立刻重試 CANCEL_CLEANUP_PENDING 對帳。
    await _ref.read(driveUploadCoordinatorProvider.notifier).refresh();
  }

  void _refreshCaches() {
    _ref.read(diaryRevisionProvider.notifier).bump();
    _ref.invalidate(trustedDeviceAccessProvider);
  }

  SettingsFlowFeedback? _backupPersistFeedback({
    required AppLocalizations l10n,
    required BackupPersistResult result,
    required String Function(String savedPath) onSuccess,
    String Function(String message)? inspectFailedMessage,
  }) {
    switch (result.status) {
      case BackupPersistStatus.success:
        final String? savedPath = result.savedPath;
        if (savedPath == null) {
          return null;
        }
        return SettingsFlowFeedback(
          onSuccess(DisplayFormat.formatSavedFileNameForDisplay(savedPath)),
          tone: SettingsFlowFeedbackTone.success,
        );
      case BackupPersistStatus.inspectFailed:
        final String Function(String message) formatInspectFailed =
            inspectFailedMessage ??
            (String message) =>
                l10n.settingsLocalBackupBackupInspectFailed(message);
        return SettingsFlowFeedback(
          formatInspectFailed(
            localizedBackupInspectDetail(l10n, result.message),
          ),
          tone: SettingsFlowFeedbackTone.error,
        );
      case BackupPersistStatus.cancelled:
        return null;
    }
  }
}
