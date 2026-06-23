import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/security/unlocked_vault_session.dart';
import '../../../infrastructure/drive/drive_backup_service.dart';
import '../../../infrastructure/security/app_unlock_mode.dart';
import '../../../infrastructure/storage/backup_task_progress.dart';
import '../../../infrastructure/storage/restore_precheck.dart';
import '../../../infrastructure/storage/vault_archive_io.dart';
import '../../../infrastructure/storage/vault_repository.dart';
import '../../../infrastructure/storage/vault_transfer_service.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/presentation/display_format.dart';
import '../../../shared/providers/tag_providers.dart';
import '../../editor/providers/editor_providers.dart';
import '../../home/providers/home_providers.dart';
import '../../session/providers/session_providers.dart';
import '../../session/session_messages.dart';
import '../../session/state/unlock_result.dart';
import '../portable_import_result_messages.dart';
import '../providers/settings_providers.dart';
import '../settings_messages.dart';
import '../unlock_mode_change.dart';
import 'settings_actions.dart';

final settingsFlowControllerProvider = Provider<SettingsFlowController>((
  Ref ref,
) {
  return SettingsFlowController(ref);
});

enum SettingsFlowFeedbackTone { info, success, error }

class SettingsFlowFeedback {
  const SettingsFlowFeedback(
    this.message, {
    this.tone = SettingsFlowFeedbackTone.info,
  });

  final String message;
  final SettingsFlowFeedbackTone tone;
}

class SettingsRepairVaultResult {
  const SettingsRepairVaultResult({
    required this.report,
    required this.feedback,
  });

  final VaultRepairReport report;
  final SettingsFlowFeedback feedback;
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

  SettingsActions get _actions => _ref.read(settingsActionsProvider);

  Future<SettingsFlowFeedback?> importDocuments(AppLocalizations l10n) async {
    final PortableImportResult? result = await _actions.importDocuments(l10n);
    if (result == null) {
      return null;
    }
    if (result.importedEntries == 0) {
      return SettingsFlowFeedback(result.messageWhenNoEntriesImported(l10n));
    }
    _refreshCaches();
    return SettingsFlowFeedback(result.formatSuccessMessage(l10n));
  }

  Future<SettingsFlowFeedback?> exportMarkdown(AppLocalizations l10n) async {
    final String? exportPath = await _actions.exportMarkdown(l10n);
    if (exportPath == null) {
      return null;
    }
    return SettingsFlowFeedback(
      l10n.settingsImportExportExportSuccess(
        DisplayFormat.formatSavedFileNameForDisplay(exportPath),
      ),
    );
  }

  Future<String> createRecoveryKey(AppLocalizations l10n) async {
    final RecoverySetupResult result = await _actions.setupRecoveryKey();
    _ref
        .read(appSessionProvider.notifier)
        .activateSession(
          result.session,
          message: sessionRecoverySetupSuccessMessage(l10n),
        );
    _ref.invalidate(recoveryMetadataProvider);
    _refreshCaches();
    return result.recoveryKey;
  }

  Future<BackupPersistResult> createLocalBackup({
    BackupTaskProgressListener? onProgress,
  }) {
    return _actions.saveBackupToAppLocal(onProgress: onProgress);
  }

  Future<BackupPersistResult> exportLocalBackup({
    required AppLocalizations l10n,
    BackupTaskProgressListener? onProgress,
  }) {
    return _actions.saveBackupToExternalDirectory(
      l10n: l10n,
      onProgress: onProgress,
    );
  }

  Future<BackupPersistResult> uploadDriveBackup({
    BackupTaskProgressListener? onProgress,
  }) {
    return _actions.uploadBackupToDrive(onProgress: onProgress);
  }

  Future<PreparedRestoreRequest?> prepareAppLocalRestore({
    required Future<LocalBackupFile?> Function(List<LocalBackupFile> backups)
    pickBackup,
  }) async {
    final List<LocalBackupFile> backups = await _actions.listAppLocalBackups();
    final LocalBackupFile? backup = await pickBackup(backups);
    if (backup == null) {
      return null;
    }
    return prepareRestoreFile(File(backup.path));
  }

  Future<PreparedRestoreRequest?> prepareExternalRestore(
    AppLocalizations l10n,
  ) async {
    final PickedBackupFile? backup = await _actions.pickLocalBackupFile(l10n);
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
    final List<DriveBackupFile> backups = await _actions.listDriveBackups();
    final DriveBackupFile? backup = await pickBackup(backups);
    if (backup == null) {
      return null;
    }
    final File tempBackup = await _actions.downloadDriveBackupToTempFile(
      backup,
      onProgress: onProgress,
    );
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
    return _actions.listDriveBackups();
  }

  Future<File> downloadDriveBackupToTempFile(
    DriveBackupFile backup, {
    BackupTaskProgressListener? onProgress,
  }) {
    return _actions.downloadDriveBackupToTempFile(
      backup,
      onProgress: onProgress,
    );
  }

  Future<PreparedRestoreRequest> prepareRestoreFile(
    File backupFile, {
    String? driveBackupName,
    File? tempFileToDelete,
  }) async {
    final RestorePrecheck precheck = await _actions.precheckRestore(backupFile);
    return PreparedRestoreRequest(
      backupFile: backupFile,
      precheck: precheck,
      driveBackupName: driveBackupName,
      tempFileToDelete: tempFileToDelete,
    );
  }

  Future<SettingsFlowFeedback> linkGoogleDrive(AppLocalizations l10n) async {
    final DriveConnectionState connectionState = await _actions
        .linkGoogleDrive();
    await _refreshDriveConnection();
    return SettingsFlowFeedback(
      settingsDriveLinkSuccess(l10n, connectionState.accountLabel(l10n)),
      tone: SettingsFlowFeedbackTone.success,
    );
  }

  Future<SettingsFlowFeedback> switchGoogleDrive(AppLocalizations l10n) async {
    final DriveConnectionState connectionState = await _actions
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
    await _actions.disconnectGoogleDrive();
    await _refreshDriveConnection();
    return SettingsFlowFeedback(
      l10n.settingsDriveBackupDisconnectSuccess,
      tone: SettingsFlowFeedbackTone.success,
    );
  }

  Future<SettingsRepairVaultResult> repairVault(AppLocalizations l10n) async {
    final VaultRepairReport report = await _actions.repairVault();
    _ref.read(entryIndexRevisionProvider.notifier).bump();
    _ref.invalidate(recoveryMetadataProvider);
    _ref.invalidate(tagAccentArgbMapProvider);
    return SettingsRepairVaultResult(
      report: report,
      feedback: SettingsFlowFeedback(
        _repairVaultSuccessMessage(l10n, report),
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
    return '$base ${l10n.settingsRepairVaultSuccessChanges(
      report.relocatedEntries,
      report.removedDuplicateEntries,
      report.removedOrphanAssets,
      report.skippedCorruptEntries,
    )}';
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
    return SettingsFlowFeedback(unlockModeChangeMessage(l10n, outcome.kind));
  }

  Future<String> rotateRecoveryKey(AppLocalizations l10n) async {
    return _ref.read(appSessionProvider.notifier).runSensitiveTask((
      UnlockedVaultSession session,
    ) async {
      final RecoverySetupResult result = await _actions.rotateRecoveryKey(
        session,
      );
      _ref
          .read(appSessionProvider.notifier)
          .activateSession(
            result.session,
            message: sessionRecoveryKeyRotatedMessage(l10n),
          );
      _ref.invalidate(recoveryMetadataProvider);
      _refreshCaches();
      return result.recoveryKey;
    });
  }

  Future<void> _refreshDriveConnection() async {
    _actions.invalidateDriveConnection();
    await _actions.warmDriveConnection();
  }

  void _refreshCaches({String? editedEntryId}) {
    _ref
      ..invalidate(homeEntriesProvider)
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
}
