import 'package:quill_diary/application/session/session_messages.dart';
import 'package:quill_diary/application/session/session_state.dart';
import 'package:quill_diary/application/session/session_timeout_policy.dart';
import 'package:quill_diary/application/settings/settings_health.dart';
import 'package:quill_diary/application/settings/vault_transfer_capabilities.dart';
import 'package:quill_diary/application/transfer/transfer_feedback.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/security/app_unlock_mode.dart';
import 'package:quill_diary/infrastructure/security/unlock_mode_change_service.dart';
import 'package:quill_diary/infrastructure/storage/backup_task_progress.dart';
import 'package:quill_diary/infrastructure/storage/shared/portable_import_result.dart';
import 'package:quill_diary/infrastructure/storage/vault_maintenance_models.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/presentation/display_format.dart';

String settingsBackupTaskProgressLabel(
  AppLocalizations l10n,
  BackupTaskProgress progress,
) {
  // 百分比由阻塞進度遮罩顯示，此處只回傳階段文案。
  return switch (progress.phase) {
    BackupTaskPhase.creatingBackup => l10n.settingsBackupPhaseCreating,
    BackupTaskPhase.copyingBackup => l10n.settingsBackupPhaseCopying,
    BackupTaskPhase.downloadingDrive =>
      l10n.settingsBackupPhaseDownloadingDrive,
    BackupTaskPhase.restoringBackup => l10n.settingsBackupPhaseRestoring,
    BackupTaskPhase.startingAfterRestore =>
      l10n.settingsBackupStartingAfterRestore,
  };
}

extension AppUnlockModePresentation on AppUnlockMode {
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

String localBackupSectionDescription(
  AppLocalizations l10n,
  VaultTransferCapabilities transferCapabilities,
) {
  if (transferCapabilities.canBackup) {
    return l10n.settingsLocalBackupSectionDescriptionEnabled;
  }
  return l10n.vaultTransferLocalSectionDescriptionBackupLocked;
}

String? localBackupLockedBannerMessage(
  AppLocalizations l10n,
  VaultTransferCapabilities access,
) => access.backupSectionBlockedMessage(
  l10n,
  fallback: l10n.vaultTransferLocalBackupActionsLockedHint,
);

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

String settingsIndexStatusMessage(
  AppLocalizations l10n, {
  required AppSessionState? sessionState,
  required bool hasUnlockedSession,
  VaultRepairSummary? repairSummary,
  VaultInspectSummary? inspectSummary,
}) {
  if (sessionState?.failure == SessionFailure.unreadableIndex) {
    return l10n.sessionIndexDatabaseUnreadableMessage;
  }

  final VaultMaintenanceSnapshot? snapshot = resolveVaultMaintenanceSnapshot(
    inspectSummary: inspectSummary,
    repairSummary: repairSummary,
  );
  if (snapshot != null) {
    final String finishedAt = DisplayFormat.formatDateTimeWithoutWeekday(
      l10n,
      snapshot.finishedAt,
    );
    if (snapshot.source == VaultMaintenanceSnapshotSource.inspect) {
      if (snapshot.hasIssues) {
        return l10n.settingsInspectVaultCompletedWithIssues(
          snapshot.affectedEntryCount,
          finishedAt,
        );
      }
      return l10n.settingsInspectVaultCompleted(
        snapshot.entryCount,
        finishedAt,
      );
    }
    if (snapshot.hasIssues) {
      return l10n.settingsRepairVaultCompletedWithIssues(
        snapshot.affectedEntryCount,
        finishedAt,
      );
    }
    return l10n.settingsRepairVaultCompleted(snapshot.entryCount, finishedAt);
  }

  return hasUnlockedSession
      ? l10n.settingsRepairVaultReadyMessage
      : l10n.settingsRepairVaultLockedMessage;
}

String settingsRepairIssueLabel(
  AppLocalizations l10n,
  VaultRepairIssueKind kind,
) {
  return switch (kind) {
    VaultRepairIssueKind.invalidEntryMetadata =>
      l10n.settingsRepairIssueInvalidEntryMetadata,
    VaultRepairIssueKind.unreadableEntry =>
      l10n.settingsRepairIssueUnreadableEntry,
    VaultRepairIssueKind.entryIdentityMismatch =>
      l10n.settingsRepairIssueEntryIdentityMismatch,
    VaultRepairIssueKind.conflictingEntry =>
      l10n.settingsRepairIssueConflictingEntry,
    VaultRepairIssueKind.missingAsset => l10n.settingsRepairIssueMissingAsset,
    VaultRepairIssueKind.unreadableAsset =>
      l10n.settingsRepairIssueUnreadableAsset,
    VaultRepairIssueKind.assetIdentityMismatch =>
      l10n.settingsRepairIssueAssetIdentityMismatch,
    VaultRepairIssueKind.conflictingAsset =>
      l10n.settingsRepairIssueConflictingAsset,
    VaultRepairIssueKind.unverifiedOrphanAsset =>
      l10n.settingsRepairIssueUnverifiedOrphanAsset,
    VaultRepairIssueKind.cleanupFailure =>
      l10n.settingsRepairIssueCleanupFailure,
  };
}

String settingsPlannedActionLabel(
  AppLocalizations l10n,
  VaultPlannedAction action,
) {
  return switch (action) {
    VaultPlannedAction.quarantine => l10n.settingsInspectVaultPlannedQuarantine,
    VaultPlannedAction.removeReference =>
      l10n.settingsInspectVaultPlannedRemoveReference,
    VaultPlannedAction.splitAttachment =>
      l10n.settingsInspectVaultPlannedSplitAttachment,
    VaultPlannedAction.relocateToCanonical =>
      l10n.settingsInspectVaultPlannedRelocate,
    VaultPlannedAction.deleteDuplicate =>
      l10n.settingsInspectVaultPlannedDeleteDuplicate,
    VaultPlannedAction.none ||
    VaultPlannedAction.reindex => l10n.settingsInspectVaultPlannedNone,
  };
}

String settingsFindingTitle(AppLocalizations l10n, VaultFinding finding) {
  final String? title = finding.entryTitle?.trim();
  if (title != null && title.isNotEmpty) return title;
  return l10n.settingsInspectVaultUnrecognizedEntry;
}

String settingsFindingDateLabel(AppLocalizations l10n, VaultFinding finding) {
  final DateOnly? date = finding.entryDate;
  if (date == null) return l10n.settingsInspectVaultEntryDateUnknown;
  return DisplayFormat.formatDateOnly(l10n, date);
}

/// 舊版呼叫端仍使用的「上次修復紀錄」行。
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
  if (status == AppLockStatus.unlocked) {
    return driveMessage;
  }
  return '$driveMessage\n$statusMessage';
}
