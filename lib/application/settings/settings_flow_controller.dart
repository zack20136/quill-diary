import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/application/restore/restore_backup_flow.dart';
import 'package:quill_diary/application/restore/restore_prepared_context.dart';
import 'package:quill_diary/application/session/state/app_session_state.dart';
import 'package:quill_diary/infrastructure/drive/drive_backup_service.dart';
import 'package:quill_diary/infrastructure/security/app_unlock_mode.dart';
import 'package:quill_diary/infrastructure/storage/backup_status_store.dart';
import 'package:quill_diary/infrastructure/storage/vault_archive_io.dart';
import 'package:quill_diary/infrastructure/storage/backup_task_progress.dart';
import 'package:quill_diary/infrastructure/storage/restore_precheck.dart';
import 'package:quill_diary/infrastructure/storage/storage_providers.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';
import 'package:quill_diary/infrastructure/storage/vault_transfer_models.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/application/editor/editor_entry_providers.dart';
import 'package:quill_diary/application/home/home_entry_query_providers.dart';
import 'package:quill_diary/shared/presentation/display_format.dart';
import 'package:quill_diary/application/tag/tag_providers.dart';
import 'package:quill_diary/application/session/providers/session_providers.dart';
import 'package:quill_diary/application/session/session_messages.dart';
import 'package:quill_diary/application/settings/portable_import_result_presenter.dart';
import 'package:quill_diary/application/settings/settings_providers.dart';
import 'package:quill_diary/application/settings/settings_text.dart';
import 'package:quill_diary/application/settings/unlock_mode_change_flow.dart';

final settingsFlowControllerProvider = Provider<SettingsFlowController>((
  Ref ref,
) {
  return SettingsFlowController(ref);
});

enum SettingsFlowFeedbackTone { info, success, warning, error }

class SettingsFlowFeedback {
  const SettingsFlowFeedback(
    this.message, {
    this.tone = SettingsFlowFeedbackTone.info,
  });

  final String message;
  final SettingsFlowFeedbackTone tone;
}

class SettingsRecoveryKeyResult {
  const SettingsRecoveryKeyResult({
    required this.recoveryKey,
    required this.feedback,
  });

  final String recoveryKey;
  final SettingsFlowFeedback feedback;
}

class SettingsRepairVaultResult {
  const SettingsRepairVaultResult({
    required this.report,
    required this.feedback,
  });

  final VaultRepairReport report;
  final SettingsFlowFeedback feedback;
}

enum SettingsRestorePrimaryAction { retryVerification, openSettingsRecovery }

enum SettingsRestoreNavigationTarget { home, settings }

class SettingsRestorePrompt {
  const SettingsRestorePrompt({
    required this.title,
    required this.body,
    required this.nextStepHint,
    required this.primaryAction,
    required this.primaryActionLabel,
    required this.secondaryHint,
    this.isError = false,
  });

  final String title;
  final String body;
  final String nextStepHint;
  final SettingsRestorePrimaryAction primaryAction;
  final String primaryActionLabel;
  final String secondaryHint;
  final bool isError;
}

class SettingsRestoreResult {
  const SettingsRestoreResult({
    this.feedback,
    this.navigationTarget,
    this.prompt,
  });

  final SettingsFlowFeedback? feedback;
  final SettingsRestoreNavigationTarget? navigationTarget;
  final SettingsRestorePrompt? prompt;
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

  Future<void> dispose() async {
    final File? tempFile = tempFileToDelete;
    if (tempFile == null || !tempFile.existsSync()) {
      return;
    }
    await tempFile.delete();
  }
}

class SettingsFlowController {
  const SettingsFlowController(this._ref);

  final Ref _ref;

  Future<SettingsFlowFeedback?> importDocuments(AppLocalizations l10n) async {
    final PortableImportResult? result = await _ref
        .read(appSessionProvider.notifier)
        .runSensitiveTask((UnlockedVaultSession session) {
          return _ref
              .read(portableTransferServiceProvider)
              .importDocumentsWithPicker(session, l10n: l10n);
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

  Future<SettingsFlowFeedback?> exportMarkdown(AppLocalizations l10n) async {
    final String? exportPath = await _ref
        .read(appSessionProvider.notifier)
        .runSensitiveTask((UnlockedVaultSession session) {
          return _ref
              .read(portableTransferServiceProvider)
              .exportMarkdownToDirectory(session, l10n);
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

  Future<SettingsRecoveryKeyResult> createRecoveryKey(
    AppLocalizations l10n,
  ) async {
    final RecoverySetupResult result = await _ref
        .read(vaultRecoveryServiceProvider)
        .setupRecoveryKey();
    _ref
        .read(appSessionProvider.notifier)
        .activateSession(
          result.session,
          message: sessionRecoverySetupSuccessMessage(l10n),
        );
    _ref.invalidate(recoveryMetadataProvider);
    _refreshCaches();
    return SettingsRecoveryKeyResult(
      recoveryKey: result.recoveryKey,
      feedback: SettingsFlowFeedback(
        sessionRecoverySetupSuccessMessage(l10n),
        tone: SettingsFlowFeedbackTone.success,
      ),
    );
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

  Future<BackupPersistResult> uploadDriveBackup({
    BackupTaskProgressListener? onProgress,
  }) {
    return _ref
        .read(vaultBackupServiceProvider)
        .uploadBackupToDrive(onProgress: onProgress);
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
    return prepareRestoreFile(File(backup.path));
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
    return prepareRestoreFile(
      backup.file,
      tempFileToDelete: backup.shouldDeleteAfterUse ? backup.file : null,
    );
  }

  Future<PreparedRestoreRequest?> prepareDriveRestore({
    required Future<DriveBackupFile?> Function(List<DriveBackupFile> backups)
    pickBackup,
    BackupTaskProgressListener? onProgress,
  }) async {
    final List<DriveBackupFile> backups = await _ref
        .read(vaultBackupServiceProvider)
        .listDriveBackups();
    final DriveBackupFile? backup = await pickBackup(backups);
    if (backup == null) {
      return null;
    }
    final File tempBackup = await _ref
        .read(vaultRestoreServiceProvider)
        .downloadDriveBackupToTempFile(backup, onProgress: onProgress);
    try {
      return await prepareRestoreFile(
        tempBackup,
        driveBackupName: backup.name,
        tempFileToDelete: tempBackup,
      );
    } on Object {
      if (tempBackup.existsSync()) {
        await tempBackup.delete();
      }
      rethrow;
    }
  }

  Future<List<DriveBackupFile>> listDriveBackups() {
    return _ref.read(vaultBackupServiceProvider).listDriveBackups();
  }

  Future<File> downloadDriveBackupToTempFile(
    DriveBackupFile backup, {
    BackupTaskProgressListener? onProgress,
  }) {
    return _ref
        .read(vaultRestoreServiceProvider)
        .downloadDriveBackupToTempFile(backup, onProgress: onProgress);
  }

  Future<PreparedRestoreRequest> prepareRestoreFile(
    File backupFile, {
    String? driveBackupName,
    File? tempFileToDelete,
  }) async {
    final RestorePrecheck precheck = await _ref
        .read(vaultRestoreServiceProvider)
        .precheckRestore(backupFile);
    return PreparedRestoreRequest(
      backupFile: backupFile,
      precheck: precheck,
      driveBackupName: driveBackupName,
      tempFileToDelete: tempFileToDelete,
    );
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

  Future<SettingsRepairVaultResult> repairVault(AppLocalizations l10n) async {
    final VaultRepairReport report = await _ref
        .read(appSessionProvider.notifier)
        .runSensitiveTask((UnlockedVaultSession session) {
          return _ref
              .read(vaultRepairServiceProvider)
              .repairVaultWithReport(session);
        });
    _ref.read(entryIndexRevisionProvider.notifier).bump();
    _ref.invalidate(recoveryMetadataProvider);
    _ref.invalidate(tagAccentArgbMapProvider);
    return SettingsRepairVaultResult(
      report: report,
      feedback: SettingsFlowFeedback(
        _repairVaultSuccessMessage(l10n, report),
        tone: SettingsFlowFeedbackTone.success,
      ),
    );
  }

  String _repairVaultSuccessMessage(
    AppLocalizations l10n,
    VaultRepairReport report,
  ) {
    final String base = l10n.settingsRepairVaultSuccess(
      report.entryCount,
      DisplayFormat.formatDurationMs(l10n, report.duration.inMilliseconds),
    );
    final bool hasChanges =
        report.relocatedEntries > 0 ||
        report.removedDuplicateEntries > 0 ||
        report.removedOrphanAssets > 0 ||
        report.skippedCorruptEntries > 0;
    if (!hasChanges) {
      return base;
    }
    return '$base ${l10n.settingsRepairVaultSuccessChanges(report.relocatedEntries, report.removedDuplicateEntries, report.removedOrphanAssets, report.skippedCorruptEntries)}';
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

  Future<SettingsRecoveryKeyResult> rotateRecoveryKey(
    AppLocalizations l10n,
  ) async {
    return _ref.read(appSessionProvider.notifier).runSensitiveTask((
      UnlockedVaultSession session,
    ) async {
      final RecoverySetupResult result = await _ref
          .read(vaultRecoveryServiceProvider)
          .rotateRecoveryKey(session);
      _ref
          .read(appSessionProvider.notifier)
          .activateSession(
            result.session,
            message: sessionRecoveryKeyRotatedMessage(l10n),
          );
      _ref.invalidate(recoveryMetadataProvider);
      _refreshCaches();
      return SettingsRecoveryKeyResult(
        recoveryKey: result.recoveryKey,
        feedback: SettingsFlowFeedback(
          sessionRecoveryKeyRotatedMessage(l10n),
          tone: SettingsFlowFeedbackTone.success,
        ),
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
      sessionRecoveryUnlockSuccessMessage(l10n),
      tone: SettingsFlowFeedbackTone.success,
    );
  }

  Future<void> verifyRestoreRecoveryKey(
    File backupFile,
    String recoveryKey,
  ) async {
    await RestoreBackupFlow(
      _ref,
    ).verifyBackupRecoveryKey(backupFile, recoveryKey);
  }

  Future<SettingsRestoreResult> restorePreparedRequest({
    required AppLocalizations l10n,
    required PreparedRestoreRequest request,
    String? backupRecoveryKey,
    bool recoveryKeyAlreadyVerified = false,
    BackupTaskProgressListener? onProgress,
  }) async {
    try {
      final RestoreBackupFlow flow = RestoreBackupFlow(_ref);
      await flow.ensureRestoreAllowed(l10n);
      final String? trimmedKey = backupRecoveryKey?.trim();
      if (!recoveryKeyAlreadyVerified &&
          trimmedKey != null &&
          trimmedKey.isNotEmpty) {
        await flow.verifyBackupRecoveryKey(request.backupFile, trimmedKey);
      }
      final RestorePreparedContext prepared = RestorePreparedContext(
        precheck: request.precheck,
        backupRecoveryKey: trimmedKey,
      );
      final AppSessionState sessionState = await flow
          .executeRestoreAndFinishSession(
            backupFile: request.backupFile,
            prepared: prepared,
            onProgress: onProgress,
          );
      return _buildRestoreResult(
        l10n: l10n,
        sessionState: sessionState,
        prepared: prepared,
        driveBackupName: request.driveBackupName,
      );
    } finally {
      await request.dispose();
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
    switch (result.status) {
      case BackupPersistStatus.success:
        switch (action) {
          case BackupStatusAction.localBackup:
            await store.recordLocalBackupSuccess();
            break;
          case BackupStatusAction.externalExport:
            await store.recordExternalExportSuccess();
            break;
          case BackupStatusAction.driveUpload:
            await store.recordDriveUploadSuccess(
              accountLabel: driveAccountLabel,
            );
            break;
        }
        _ref.invalidate(backupStatusProvider);
        break;
      case BackupPersistStatus.inspectFailed:
        final String message = result.message.trim().isNotEmpty
            ? result.message.trim()
            : l10n.settingsLocalBackupBackupInspectFailed('');
        await store.recordFailure(action: action, message: message);
        _ref.invalidate(backupStatusProvider);
        break;
      case BackupPersistStatus.cancelled:
        break;
    }
    return _backupPersistFeedback(
      l10n: l10n,
      result: result,
      onSuccess: onSuccess,
      inspectFailedMessage: inspectFailedMessage,
    );
  }

  Future<void> _refreshDriveConnection() async {
    _ref.invalidate(settingsDriveConnectionProvider);
    await _ref.read(settingsDriveConnectionProvider.future);
  }

  void _refreshCaches({String? editedEntryId}) {
    _ref
      ..invalidate(homeEntryIndexListProvider)
      ..invalidate(homePinnedEntryIdsProvider)
      ..invalidate(calendarMonthEntryDatesProvider)
      ..invalidate(calendarMonthEntriesProvider)
      ..invalidate(calendarEntriesProvider)
      ..invalidate(allEntryIndexRecordsProvider)
      ..invalidate(tagCatalogProvider)
      ..invalidate(trustedDeviceAccessProvider);
    _ref.read(entryIndexRevisionProvider.notifier).bump();
    final String? id = editedEntryId?.trim();
    if (id != null && id.isNotEmpty) {
      _ref.invalidate(entryProvider(id));
    }
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
          formatInspectFailed(result.message),
          tone: SettingsFlowFeedbackTone.error,
        );
      case BackupPersistStatus.cancelled:
        return null;
    }
  }

  SettingsRestoreResult _buildRestoreResult({
    required AppLocalizations l10n,
    required AppSessionState sessionState,
    required RestorePreparedContext prepared,
    String? driveBackupName,
  }) {
    final String? trimmedKey = prepared.backupRecoveryKey?.trim();
    final bool unlockFailedAfterKey =
        trimmedKey != null &&
        trimmedKey.isNotEmpty &&
        sessionState.status != AppLockStatus.unlocked;

    if (sessionState.status == AppLockStatus.unlocked) {
      return SettingsRestoreResult(
        feedback: SettingsFlowFeedback(
          driveAwarePostRestoreSnackBarMessage(
            l10n: l10n,
            status: sessionState.status,
            driveBackupName: driveBackupName,
          ),
          tone: SettingsFlowFeedbackTone.success,
        ),
        navigationTarget: SettingsRestoreNavigationTarget.home,
      );
    }

    if (unlockFailedAfterKey ||
        sessionState.status == AppLockStatus.locked ||
        sessionState.status == AppLockStatus.recoveryRequired) {
      return SettingsRestoreResult(
        prompt: _buildRestorePrompt(
          l10n: l10n,
          sessionState: sessionState,
          unlockFailedAfterRecoveryKey: unlockFailedAfterKey,
        ),
      );
    }

    return SettingsRestoreResult(
      feedback: SettingsFlowFeedback(
        driveAwarePostRestoreSnackBarMessage(
          l10n: l10n,
          status: sessionState.status,
          driveBackupName: driveBackupName,
        ),
        tone: sessionState.status == AppLockStatus.fatalError
            ? SettingsFlowFeedbackTone.error
            : SettingsFlowFeedbackTone.success,
      ),
      navigationTarget: SettingsRestoreNavigationTarget.home,
    );
  }

  SettingsRestorePrompt _buildRestorePrompt({
    required AppLocalizations l10n,
    required AppSessionState sessionState,
    required bool unlockFailedAfterRecoveryKey,
  }) {
    if (unlockFailedAfterRecoveryKey) {
      return SettingsRestorePrompt(
        title: l10n.postRestoreOutcomeUnlockFailedTitle,
        body: sessionState.message?.trim().isNotEmpty == true
            ? sessionState.message!.trim()
            : l10n.vaultTransferRestoreUnlockFailed,
        nextStepHint: l10n.postRestoreOutcomeNextStepRecovery,
        primaryAction: SettingsRestorePrimaryAction.openSettingsRecovery,
        primaryActionLabel: l10n.postRestoreOutcomePrimaryEnterRecoveryKey,
        secondaryHint: l10n.postRestoreOutcomeSecondaryHint,
        isError: true,
      );
    }

    return switch (sessionState.status) {
      AppLockStatus.locked => SettingsRestorePrompt(
        title: l10n.postRestoreOutcomeTitle,
        body: snackbarMessageForPostRestore(l10n, sessionState.status),
        nextStepHint: l10n.postRestoreOutcomeNextStepLocked,
        primaryAction: SettingsRestorePrimaryAction.retryVerification,
        primaryActionLabel: l10n.postRestoreOutcomePrimaryRetryVerification,
        secondaryHint: l10n.postRestoreOutcomeSecondaryHint,
      ),
      AppLockStatus.recoveryRequired => SettingsRestorePrompt(
        title: l10n.postRestoreOutcomeTitle,
        body: snackbarMessageForPostRestore(l10n, sessionState.status),
        nextStepHint: l10n.postRestoreOutcomeNextStepRecovery,
        primaryAction: SettingsRestorePrimaryAction.openSettingsRecovery,
        primaryActionLabel: l10n.postRestoreOutcomePrimaryEnterRecoveryKey,
        secondaryHint: l10n.postRestoreOutcomeSecondaryHint,
      ),
      _ => SettingsRestorePrompt(
        title: l10n.postRestoreOutcomeTitle,
        body: snackbarMessageForPostRestore(l10n, sessionState.status),
        nextStepHint: sessionState.message?.trim().isNotEmpty == true
            ? sessionState.message!.trim()
            : l10n.sessionRestoreStartupFailedMessage,
        primaryAction: SettingsRestorePrimaryAction.openSettingsRecovery,
        primaryActionLabel: l10n.postRestoreOutcomePrimaryEnterRecoveryKey,
        secondaryHint: l10n.postRestoreOutcomeSecondaryHint,
        isError: sessionState.status == AppLockStatus.fatalError,
      ),
    };
  }
}
