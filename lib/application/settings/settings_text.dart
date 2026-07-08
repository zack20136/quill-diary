import 'package:quill_diary/application/session/session_messages.dart';
import 'package:quill_diary/application/session/session_timeout_policy.dart';
import 'package:quill_diary/application/session/state/app_session_state.dart';
import 'package:quill_diary/infrastructure/security/app_unlock_mode.dart';
import 'package:quill_diary/infrastructure/security/unlock_mode_change_service.dart';
import 'package:quill_diary/infrastructure/storage/backup_task_progress.dart';
import 'package:quill_diary/infrastructure/storage/shared/portable_import_result.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/presentation/display_format.dart';

import 'settings_health_level.dart';
import 'vault_transfer_capabilities.dart';

String settingsRecoveryKeyHintLine(AppLocalizations l10n, String hint) =>
    l10n.settingsRecoveryKeyHintLine(hint);

String settingsBackupTaskProgressLabel(
  AppLocalizations l10n,
  BackupTaskProgress progress,
) {
  final String base = switch (progress.phase) {
    BackupTaskPhase.creatingBackup => l10n.settingsBackupPhaseCreating,
    BackupTaskPhase.copyingBackup => l10n.settingsBackupPhaseCopying,
    BackupTaskPhase.uploadingDrive => l10n.settingsBackupPhaseUploadingDrive,
    BackupTaskPhase.downloadingDrive =>
      l10n.settingsBackupPhaseDownloadingDrive,
    BackupTaskPhase.restoringBackup => l10n.settingsBackupPhaseRestoring,
    BackupTaskPhase.startingAfterRestore =>
      l10n.settingsBackupStartingAfterRestore,
  };
  final double? fraction = progress.fraction;
  if (fraction == null) {
    return base;
  }
  return '$base ${(fraction * 100).round()}%';
}

extension AppUnlockModePresentation on AppUnlockMode {
  String shortLabel(AppLocalizations l10n) => switch (this) {
    AppUnlockMode.none => l10n.settingsUnlockMethodSegmentNone,
    AppUnlockMode.deviceLock => l10n.settingsUnlockMethodSegmentDeviceLock,
    AppUnlockMode.biometric => l10n.settingsUnlockMethodSegmentBiometric,
  };

  String fullLabel(AppLocalizations l10n) => switch (this) {
    AppUnlockMode.none => l10n.settingsUnlockModeFullNone,
    AppUnlockMode.deviceLock => l10n.settingsUnlockModeFullDeviceLock,
    AppUnlockMode.biometric => l10n.settingsUnlockModeFullBiometric,
  };

  String description(AppLocalizations l10n) => switch (this) {
    AppUnlockMode.none => l10n.settingsUnlockModeDescriptionNone,
    AppUnlockMode.deviceLock => l10n.settingsUnlockModeDescriptionDeviceLock,
    AppUnlockMode.biometric => l10n.settingsUnlockModeDescriptionBiometric,
  };
}

String settingsUnlockMethodSectionDescription(
  AppLocalizations l10n,
  Duration sessionTimeout,
) => l10n.settingsUnlockMethodSectionDescription(
  sessionBackgroundTimeoutLabel(sessionTimeout, l10n),
);

String unlockModeChangeMessage(
  AppLocalizations l10n,
  UnlockModeChangeMessageKind kind,
) {
  return switch (kind) {
    UnlockModeChangeMessageKind.requiresUnlockedSession =>
      l10n.sessionUnlockModeChangeNeedsUnlockMessage,
    UnlockModeChangeMessageKind.requiresDeviceLock =>
      l10n.sessionUnlockModeNeedsDeviceLockMessage,
    UnlockModeChangeMessageKind.requiresBiometricEnrollment =>
      l10n.sessionBiometricNotEnrolledSwitchModeMessage,
    UnlockModeChangeMessageKind.changeCancelled =>
      l10n.settingsUnlockModeChangeCancelled,
    UnlockModeChangeMessageKind.authFailed =>
      l10n.settingsUnlockModeChangeAuthFailed,
  };
}

String settingsSessionTimeoutAboutBackgroundTimeoutBody(
  AppLocalizations l10n,
  Duration timeout,
) => l10n.settingsSessionTimeoutAboutBackgroundTimeoutBody(
  sessionBackgroundTimeoutLabel(timeout, l10n),
);

String settingsSecurityOverviewUnlockModeProtectedMessage(
  AppLocalizations l10n,
  String unlockModeLabel,
) => l10n.settingsSecurityOverviewUnlockModeProtectedMessage(unlockModeLabel);

String settingsLocalBackupSectionDescriptionEnabled(AppLocalizations l10n) =>
    l10n.settingsLocalBackupSectionDescriptionEnabled;

String localBackupSectionDescription(
  AppLocalizations l10n,
  VaultTransferCapabilities transferCapabilities,
) {
  if (transferCapabilities.canBackup) {
    return settingsLocalBackupSectionDescriptionEnabled(l10n);
  }
  return l10n.vaultTransferLocalSectionDescriptionBackupLocked;
}

String? localBackupLockedBannerMessage(
  AppLocalizations l10n,
  VaultTransferCapabilities transferCapabilities,
) {
  if (!transferCapabilities.canBackup && !transferCapabilities.canRestore) {
    return transferCapabilities.restoreDisabledReason ??
        transferCapabilities.backupDisabledReason;
  }
  if (!transferCapabilities.canBackup) {
    return transferCapabilities.backupDisabledReason ??
        l10n.vaultTransferLocalBackupActionsLockedHint;
  }
  if (!transferCapabilities.canRestore) {
    return transferCapabilities.restoreDisabledReason;
  }
  return null;
}

String settingsDriveBackupSectionDescriptionEnabled(AppLocalizations l10n) =>
    l10n.settingsDriveBackupSectionDescriptionEnabled;

String settingsImportExportMessageForFailureCode(
  AppLocalizations l10n,
  String? failureCode,
) {
  return switch (failureCode) {
    PortableImportFailureCode.selectedFilesUnreadable =>
      l10n.settingsImportExportFailureSelectedFilesUnreadable,
    PortableImportFailureCode.zipNoEntries =>
      l10n.settingsImportExportFailureZipNoEntries,
    PortableImportFailureCode.easyDiaryRealmReadFailed =>
      l10n.settingsImportExportFailureEasyDiaryRealmReadFailed,
    PortableImportFailureCode.easyDiaryEmptyBackup =>
      l10n.settingsImportExportFailureEasyDiaryEmptyBackup,
    PortableImportFailureCode.easyDiaryAllEncrypted =>
      l10n.settingsImportExportFailureEasyDiaryAllEncrypted,
    _ => '',
  };
}

String settingsDriveLinkSuccess(AppLocalizations l10n, String? accountLabel) {
  if (accountLabel == null || accountLabel.trim().isEmpty) {
    return l10n.settingsDriveBackupLinkSuccessEmpty;
  }
  return l10n.settingsDriveBackupLinkSuccess(accountLabel);
}

String settingsDriveSwitchAccountSuccess(
  AppLocalizations l10n,
  String? accountLabel,
) {
  if (accountLabel == null || accountLabel.trim().isEmpty) {
    return l10n.settingsDriveBackupSwitchAccountSuccessEmpty;
  }
  return l10n.settingsDriveBackupSwitchAccountSuccess(accountLabel);
}

bool repairReportNeedsAttention(VaultRepairReport report) {
  return report.skippedCorruptEntries > 0 ||
      report.removedDuplicateEntries > 0 ||
      report.removedOrphanAssets > 0 ||
      report.relocatedEntries > 0 ||
      report.warnings.isNotEmpty;
}

SettingsHealthLevel settingsIndexHealthLevel({
  required AppLocalizations l10n,
  required AppSessionState? sessionState,
  required bool hasUnlockedSession,
  VaultRepairReport? repairReport,
}) {
  if (isIndexRelatedSessionMessage(l10n, sessionState?.message)) {
    return SettingsHealthLevel.error;
  }
  if (!hasUnlockedSession) {
    return SettingsHealthLevel.warning;
  }
  if (repairReport != null && repairReportNeedsAttention(repairReport)) {
    return SettingsHealthLevel.warning;
  }
  return SettingsHealthLevel.ok;
}

String settingsIndexStatusMessage(
  AppLocalizations l10n, {
  required AppSessionState? sessionState,
  required bool hasUnlockedSession,
  VaultRepairReport? repairReport,
}) {
  if (isIndexRelatedSessionMessage(l10n, sessionState?.message)) {
    final String? trimmedMessage = sessionState?.message?.trim();
    if (trimmedMessage != null && trimmedMessage.isNotEmpty) {
      return trimmedMessage;
    }
    return sessionIndexDatabaseUnreadableMessage(l10n);
  }
  if (repairReport != null) {
    return l10n.settingsRepairVaultCompleted(
      repairReport.entryCount,
      DisplayFormat.formatDateTime(l10n, repairReport.finishedAt),
    );
  }
  return hasUnlockedSession
      ? l10n.settingsRepairVaultReadyMessage
      : l10n.settingsRepairVaultLockedMessage;
}

String driveAwarePostRestoreSnackBarMessage({
  required AppLocalizations l10n,
  required AppLockStatus status,
  String? driveBackupName,
}) {
  final String statusMessage = snackbarMessageForPostRestore(l10n, status);
  if (driveBackupName == null || driveBackupName.trim().isEmpty) {
    return statusMessage;
  }
  final String driveMessage = l10n.settingsDriveBackupRestoreSuccess(
    driveBackupName.trim(),
  );
  if (status == AppLockStatus.unlocked &&
      statusMessage == l10n.sessionRestoreSuccessUnlockedMessage) {
    return driveMessage;
  }
  return '$driveMessage\n$statusMessage';
}
