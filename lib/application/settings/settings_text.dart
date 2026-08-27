import 'package:quill_diary/domain/shared/value_objects.dart';
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

/// 無法對應到日記的 finding 共用分組鍵。
const String kUnrecognizedVaultFindingGroupKey = 'unrecognized';

/// 以日記為單位分組；無法對應者合併為一組。
String vaultFindingGroupKey(VaultFinding finding) {
  final String? entryId = finding.entryId?.trim();
  if (entryId != null && entryId.isNotEmpty) {
    return 'entry:$entryId';
  }
  return kUnrecognizedVaultFindingGroupKey;
}

Map<String, List<VaultFinding>> groupVaultFindings(
  Iterable<VaultFinding> findings,
) {
  final Map<String, List<VaultFinding>> grouped =
      <String, List<VaultFinding>>{};
  for (final VaultFinding finding in findings) {
    if (finding.resolved) continue;
    grouped
        .putIfAbsent(vaultFindingGroupKey(finding), () => <VaultFinding>[])
        .add(finding);
  }
  return grouped;
}

int countAffectedVaultEntries(Iterable<VaultFinding> findings) =>
    groupVaultFindings(findings).length;

String settingsRecoveryKeyHintLine(AppLocalizations l10n, String hint) =>
    l10n.settingsRecoveryKeyHintLine(hint);

String settingsBackupTaskProgressLabel(
  AppLocalizations l10n,
  BackupTaskProgress progress,
) {
  // 百分比由阻塞進度遮罩顯示，此處只回傳階段文案。
  return switch (progress.phase) {
    BackupTaskPhase.creatingBackup => l10n.settingsBackupPhaseCreating,
    BackupTaskPhase.copyingBackup => l10n.settingsBackupPhaseCopying,
    BackupTaskPhase.uploadingDrive => l10n.settingsBackupPhaseUploadingDrive,
    BackupTaskPhase.downloadingDrive =>
      l10n.settingsBackupPhaseDownloadingDrive,
    BackupTaskPhase.restoringBackup => l10n.settingsBackupPhaseRestoring,
    BackupTaskPhase.startingAfterRestore =>
      l10n.settingsBackupStartingAfterRestore,
  };
}

String settingsDriveUploadPrepareProgressLabel(AppLocalizations l10n) =>
    l10n.settingsBackupPhasePreparingDriveUpload;


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

/// 設定頁「日記庫」卡片共用的最近一次維護摘要。
///
/// 以 [finishedAt] 選出唯一有效來源；時間相同時優先修復結果。
class VaultMaintenanceSnapshot {
  const VaultMaintenanceSnapshot._({
    required this.source,
    required this.entryCount,
    required this.finishedAt,
    required this.unresolvedFindings,
    required this.affectedEntryCount,
    this.backupFileName,
  });

  final VaultMaintenanceSnapshotSource source;
  final int entryCount;
  final DateTime finishedAt;
  final List<VaultFinding> unresolvedFindings;
  final int affectedEntryCount;
  final String? backupFileName;

  bool get hasIssues => affectedEntryCount > 0;
}

enum VaultMaintenanceSnapshotSource { inspect, repair }

VaultMaintenanceSnapshot? resolveVaultMaintenanceSnapshot({
  VaultInspectSummary? inspectSummary,
  VaultRepairSummary? repairSummary,
}) {
  if (inspectSummary == null && repairSummary == null) {
    return null;
  }
  final DateTime? inspectAt = inspectSummary?.finishedAt;
  final DateTime? repairAt = repairSummary?.finishedAt;
  // 同時間優先 repair：inspect 較新才選 inspect。
  final bool preferRepair =
      repairSummary != null &&
      (inspectSummary == null ||
          inspectAt == null ||
          !inspectAt.isAfter(repairAt!));

  if (preferRepair) {
    final VaultRepairSummary selectedRepair = repairSummary;
    final List<VaultFinding> unresolved = <VaultFinding>[
      for (final VaultFinding finding in selectedRepair.findings)
        if (!finding.resolved) finding,
    ];
    return VaultMaintenanceSnapshot._(
      source: VaultMaintenanceSnapshotSource.repair,
      entryCount: selectedRepair.entryCount,
      finishedAt: selectedRepair.finishedAt,
      unresolvedFindings: unresolved,
      affectedEntryCount: countAffectedVaultEntries(unresolved),
      backupFileName: selectedRepair.backupFileName,
    );
  }

  final List<VaultFinding> unresolved = <VaultFinding>[
    for (final VaultFinding finding in inspectSummary!.findings)
      if (!finding.resolved) finding,
  ];
  return VaultMaintenanceSnapshot._(
    source: VaultMaintenanceSnapshotSource.inspect,
    entryCount: inspectSummary.entryCount,
    finishedAt: inspectSummary.finishedAt,
    unresolvedFindings: unresolved,
    affectedEntryCount: countAffectedVaultEntries(unresolved),
  );
}

SettingsHealthLevel settingsIndexHealthLevel({
  required AppLocalizations l10n,
  required AppSessionState? sessionState,
  required bool hasUnlockedSession,
  VaultRepairSummary? repairSummary,
  VaultInspectSummary? inspectSummary,
}) {
  if (isIndexRelatedSessionMessage(l10n, sessionState?.message)) {
    return SettingsHealthLevel.error;
  }
  if (!hasUnlockedSession) {
    return SettingsHealthLevel.warning;
  }
  final VaultMaintenanceSnapshot? snapshot = resolveVaultMaintenanceSnapshot(
    inspectSummary: inspectSummary,
    repairSummary: repairSummary,
  );
  if (snapshot?.hasIssues ?? false) {
    return SettingsHealthLevel.warning;
  }
  return SettingsHealthLevel.ok;
}

String settingsIndexStatusMessage(
  AppLocalizations l10n, {
  required AppSessionState? sessionState,
  required bool hasUnlockedSession,
  VaultRepairSummary? repairSummary,
  VaultInspectSummary? inspectSummary,
}) {
  if (isIndexRelatedSessionMessage(l10n, sessionState?.message)) {
    final String? trimmedMessage = sessionState?.message?.trim();
    if (trimmedMessage != null && trimmedMessage.isNotEmpty) {
      return trimmedMessage;
    }
    return sessionIndexDatabaseUnreadableMessage(l10n);
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
List<String> settingsLastRepairLogLines(
  AppLocalizations l10n,
  VaultRepairSummary? summary,
) {
  if (summary == null) {
    return <String>[l10n.settingsLastRepairLogEmpty];
  }
  final List<String> lines = <String>[
    l10n.settingsLastRepairLogFinishedAt(
      DisplayFormat.formatDateTime(l10n, summary.finishedAt),
    ),
    l10n.settingsLastRepairLogCheckedEntries(summary.entryCount),
  ];
  final String? backup = summary.backupFileName?.trim();
  if (backup != null && backup.isNotEmpty) {
    lines.add(l10n.settingsLastRepairLogBackupFile(backup));
  }
  void addCount(String Function(int count) label, int count) {
    if (count > 0) lines.add(label(count));
  }

  addCount(
    l10n.settingsLastRepairLogRelocatedEntries,
    summary.relocatedEntries,
  );
  addCount(l10n.settingsLastRepairLogRelocatedAssets, summary.relocatedAssets);
  addCount(
    l10n.settingsLastRepairLogRecoveredAttachments,
    summary.recoveredAttachments,
  );
  addCount(
    l10n.settingsLastRepairLogRemovedBrokenReferences,
    summary.removedBrokenReferences,
  );
  addCount(
    l10n.settingsLastRepairLogSplitAttachments,
    summary.splitAttachments,
  );
  addCount(
    l10n.settingsLastRepairLogRemovedDuplicates,
    summary.removedDuplicateEntries,
  );
  addCount(
    l10n.settingsLastRepairLogRemovedOrphans,
    summary.removedOrphanAssets,
  );
  addCount(l10n.settingsLastRepairLogQuarantined, summary.quarantinedCount);
  addCount(l10n.settingsLastRepairLogPurgedBadAssets, summary.purgedBadAssets);
  addCount(
    l10n.settingsRepairDetailPurgedOldQuarantine,
    summary.purgedOldQuarantine,
  );
  final int unresolved = countAffectedVaultEntries(summary.findings);
  if (unresolved > 0) {
    lines.add(l10n.settingsLastRepairLogUnresolved(unresolved));
  } else if (!summary.hasCompletedActions) {
    lines.add(l10n.settingsLastRepairLogNoActions);
  }
  return lines;
}

/// 舊版呼叫端仍使用的逐篇／全域動作文案。
List<String> settingsRepairDetailLines(
  AppLocalizations l10n,
  VaultRepairSummary? summary,
) {
  if (summary == null) {
    return <String>[l10n.settingsRepairDetailEmpty];
  }
  final List<String> lines = <String>[];
  void addCount(String Function(int count) label, int count) {
    if (count > 0) lines.add(label(count));
  }

  addCount(l10n.settingsRepairDetailGlobalOrphans, summary.removedOrphanAssets);
  addCount(l10n.settingsRepairDetailGlobalPurgedBad, summary.purgedBadAssets);
  addCount(
    l10n.settingsRepairDetailPurgedOldQuarantine,
    summary.purgedOldQuarantine,
  );

  if (summary.entryActionLogs.isEmpty && lines.isEmpty) {
    return <String>[l10n.settingsRepairDetailEmpty];
  }

  for (final VaultRepairEntryActionLog log in summary.entryActionLogs) {
    final String title = log.title.trim().isEmpty
        ? l10n.settingsInspectVaultUnrecognizedEntry
        : log.title.trim();
    final String dateLabel = log.date == null
        ? l10n.settingsInspectVaultEntryDateUnknown
        : DisplayFormat.formatDateOnly(l10n, log.date!);
    lines.add('$title · $dateLabel');
    addCount(
      l10n.settingsRepairDetailRecoveredAttachments,
      log.recoveredAttachments,
    );
    addCount(
      l10n.settingsRepairDetailRemovedMissingAttachments,
      log.removedMissingAttachments,
    );
    addCount(
      l10n.settingsRepairDetailPurgedBadAttachments,
      log.purgedBadAttachments,
    );
    addCount(l10n.settingsRepairDetailSplitAttachments, log.splitAttachments);
    addCount(l10n.settingsRepairDetailRelocatedEntries, log.relocatedEntries);
    addCount(l10n.settingsRepairDetailQuarantinedItems, log.quarantinedItems);
  }
  return lines;
}

String settingsManualGuide(
  AppLocalizations l10n,
  VaultManualAction action, {
  String? backupFileName,
}) {
  // 新流程改以修復結果就地處理，不再顯示手動教學文案。
  return '';
}

String settingsRestoreFromBackupGuide(
  AppLocalizations l10n,
  String? backupFileName,
) {
  return '';
}

List<VaultFinding> settingsUnresolvedFindings({
  VaultInspectSummary? inspectSummary,
  VaultRepairSummary? repairSummary,
}) {
  return resolveVaultMaintenanceSnapshot(
        inspectSummary: inspectSummary,
        repairSummary: repairSummary,
      )?.unresolvedFindings ??
      const <VaultFinding>[];
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
