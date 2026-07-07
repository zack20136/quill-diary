import 'package:flutter/material.dart';

import 'package:quill_diary/infrastructure/security/app_unlock_mode.dart';
import 'package:quill_diary/infrastructure/security/unlock_mode_change_service.dart';
import 'package:quill_diary/infrastructure/storage/backup_status_store.dart';
import 'package:quill_diary/infrastructure/storage/backup_task_progress.dart';
import 'package:quill_diary/infrastructure/storage/restore_precheck.dart';
import 'package:quill_diary/infrastructure/storage/shared/portable_import_result.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/presentation/display_format.dart';
import 'package:quill_diary/application/session/session_messages.dart';
import 'package:quill_diary/application/session/session_timeout_policy.dart';
import 'package:quill_diary/application/session/state/app_session_state.dart';
import 'vault_transfer_access.dart';
import 'widgets/settings_sections.dart';

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

extension AppUnlockModeL10n on AppUnlockMode {
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
  VaultTransferAccess access,
) {
  if (access.canBackup) {
    return settingsLocalBackupSectionDescriptionEnabled(l10n);
  }
  return l10n.vaultTransferLocalSectionDescriptionBackupLocked;
}

String? localBackupLockedBannerMessage(
  AppLocalizations l10n,
  VaultTransferAccess access,
) {
  if (!access.canBackup && !access.canRestore) {
    return access.restoreDisabledReason ?? access.backupDisabledReason;
  }
  if (!access.canBackup) {
    return access.backupDisabledReason ??
        l10n.vaultTransferLocalBackupActionsLockedHint;
  }
  if (!access.canRestore) {
    return access.restoreDisabledReason;
  }
  return null;
}

String settingsDriveBackupSectionDescriptionEnabled(AppLocalizations l10n) =>
    l10n.settingsDriveBackupSectionDescriptionEnabled;

class RestorePrecheckSummaryItem {
  const RestorePrecheckSummaryItem({
    required this.icon,
    required this.title,
    required this.body,
    this.isWarning = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool isWarning;
}

String restoreConfirmHeadline(AppLocalizations l10n, RestorePrecheck precheck) {
  if (precheck.willOverwriteLocalVault) {
    return l10n.settingsRestoreConfirmOverwriteHeadline;
  }
  return l10n.settingsRestoreConfirmFreshVaultHeadline;
}

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
    final String? message = sessionState?.message?.trim();
    if (message != null && message.isNotEmpty) {
      return message;
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

List<RestorePrecheckSummaryItem> buildRestorePrecheckSummaryItems(
  AppLocalizations l10n,
  RestorePrecheck precheck,
) {
  final List<RestorePrecheckSummaryItem> items = <RestorePrecheckSummaryItem>[];

  items.add(
    RestorePrecheckSummaryItem(
      icon: precheck.sameVaultId
          ? Icons.home_work_outlined
          : Icons.devices_other_outlined,
      title: precheck.sameVaultId
          ? l10n.settingsRestorePrecheckSameVaultTitle
          : l10n.settingsRestorePrecheckOtherVaultTitle,
      body: precheck.sameVaultId
          ? l10n.settingsRestorePrecheckSameVaultBody
          : l10n.settingsRestorePrecheckOtherVaultBody,
    ),
  );

  if (precheck.recoveryKeyRotatedSinceBackup) {
    items.add(
      RestorePrecheckSummaryItem(
        icon: Icons.autorenew_rounded,
        title: l10n.settingsRestorePrecheckRotatedTitle,
        body: l10n.settingsRestorePrecheckRotatedBody,
        isWarning: true,
      ),
    );
    final String hint = precheck.backupRecoveryHint;
    if (hint.isNotEmpty) {
      items.add(
        RestorePrecheckSummaryItem(
          icon: Icons.tips_and_updates_outlined,
          title: l10n.settingsRestorePrecheckHintTitle,
          body: settingsRecoveryKeyHintLine(l10n, hint),
        ),
      );
    }
  } else if (precheck.expectsTrustedUnlockAfterRestore) {
    items.add(
      RestorePrecheckSummaryItem(
        icon: Icons.verified_user_outlined,
        title: l10n.settingsRestorePrecheckTrustedUnlockTitle,
        body: l10n.settingsRestorePrecheckTrustedUnlockBody,
      ),
    );
  } else if (precheck.expectsRecoveryKeyAfterRestore) {
    items.add(
      RestorePrecheckSummaryItem(
        icon: Icons.vpn_key_outlined,
        title: l10n.settingsRestorePrecheckRecoveryKeyTitle,
        body: l10n.settingsRestorePrecheckRecoveryKeyBody,
        isWarning: true,
      ),
    );
    final String hint = precheck.backupRecoveryHint;
    if (hint.isNotEmpty) {
      items.add(
        RestorePrecheckSummaryItem(
          icon: Icons.tips_and_updates_outlined,
          title: l10n.settingsRestorePrecheckHintTitle,
          body: settingsRecoveryKeyHintLine(l10n, hint),
        ),
      );
    }
  }

  items.add(
    RestorePrecheckSummaryItem(
      icon: Icons.search_outlined,
      title: l10n.settingsRestorePrecheckRebuildIndexTitle,
      body: l10n.settingsRestorePrecheckRebuildIndexBody,
    ),
  );

  items.add(
    RestorePrecheckSummaryItem(
      icon: Icons.hourglass_top_outlined,
      title: l10n.settingsRestorePrecheckRewrapTitle,
      body: l10n.settingsRestorePrecheckRewrapBody,
    ),
  );

  return items;
}

List<String> buildRestoreConfirmBulletPoints(
  AppLocalizations l10n,
  RestorePrecheck precheck,
) {
  final List<String> bullets = <String>[];
  if (precheck.willOverwriteLocalVault) {
    bullets.add(l10n.settingsRestoreBulletOverwriteWarning);
  } else {
    bullets.add(l10n.settingsRestoreBulletFreshVaultNote);
  }
  bullets.add(l10n.settingsRestoreBulletRebuildIndex);

  if (precheck.recoveryKeyRotatedSinceBackup) {
    bullets.add(l10n.settingsRestoreBulletRotatedBackup);
    final String hint = precheck.backupRecoveryHint;
    if (hint.isNotEmpty) {
      bullets.add(settingsRecoveryKeyHintLine(l10n, hint));
    }
  } else if (precheck.expectsTrustedUnlockAfterRestore) {
    bullets.add(l10n.settingsRestoreBulletTrustedAutoUnlock);
    bullets.add(l10n.settingsRestoreBulletTrustedAutoUnlockFallback);
  } else if (precheck.expectsRecoveryKeyAfterRestore) {
    bullets.add(l10n.settingsRestoreBulletRecoveryKeyAfterRestore);
    final String hint = precheck.backupRecoveryHint;
    if (hint.isNotEmpty) {
      bullets.add(settingsRecoveryKeyHintLine(l10n, hint));
    }
  }

  bullets.add(l10n.settingsRestoreBulletRewrapNote);
  return bullets;
}

String restoreRecoveryKeyDialogSubtitle(
  AppLocalizations l10n,
  RestorePrecheck precheck,
) {
  if (precheck.recoveryKeyRotatedSinceBackup) {
    return l10n.settingsRestoreDialogSubtitleRotatedBackup;
  }
  if (precheck.sameVaultId) {
    return l10n.settingsRestoreDialogSubtitleSameVaultManual;
  }
  return l10n.settingsRestoreDialogSubtitleOtherVault;
}

class SupportNotice {
  const SupportNotice({required this.title, required this.body});

  final String title;
  final String body;
}

SupportNotice supportNoticeForProductLoadError(
  AppLocalizations l10n,
  String? errorCode,
) {
  return switch (errorCode) {
    'no_products' => SupportNotice(
      title: l10n.settingsSupportProductsNotReadyTitle,
      body: l10n.settingsSupportProductsNotReadyBody,
    ),
    'init_failed' => SupportNotice(
      title: l10n.settingsSupportProductsInitFailedTitle,
      body: l10n.settingsSupportProductsInitFailedBody,
    ),
    'query_failed' => SupportNotice(
      title: l10n.settingsSupportProductsQueryFailedTitle,
      body: l10n.settingsSupportProductsQueryFailedBody,
    ),
    _ => SupportNotice(
      title: l10n.settingsSupportProductLoadErrorTitle,
      body: l10n.settingsSupportProductLoadErrorBody,
    ),
  };
}

List<String> settingsSupportHeroChips(AppLocalizations l10n) => <String>[
  l10n.settingsSupportHeroChipNoExtraFeatures,
  l10n.settingsSupportHeroChipRepeatablePurchase,
  l10n.settingsSupportHeroChipGooglePlayPayment,
];

String _backupStatusActionLabel(
  AppLocalizations l10n,
  BackupStatusAction action,
) {
  return switch (action) {
    BackupStatusAction.localBackup => l10n.settingsLocalBackupCreateButton,
    BackupStatusAction.externalExport =>
      l10n.settingsLocalBackupExportToExternalButton,
    BackupStatusAction.driveUpload => l10n.settingsDriveBackupUploadButton,
  };
}

SecurityOverviewItem settingsLocalBackupSecurityOverview(
  AppLocalizations l10n,
  BackupStatusSnapshot status,
  DateTime now,
) {
  final DateTime? lastAt = status.lastLocalRelatedBackupAt;
  final BackupStatusAction? lastAction = status.lastLocalRelatedBackupAction;
  final String? failureSubtitle = _backupFailureSubtitle(
    l10n,
    status,
    isLocalScope: true,
  );

  if (lastAt == null) {
    return SecurityOverviewItem(
      icon: Icons.archive_outlined,
      title: l10n.settingsSecurityOverviewLocalBackupTitle,
      message: l10n.settingsSecurityOverviewLocalBackupNever,
      subtitle: failureSubtitle,
      level: SettingsHealthLevel.warning,
    );
  }

  final String lastLine = l10n.settingsSecurityOverviewLocalBackupLast(
    DisplayFormat.formatDateTimeWithoutWeekday(l10n, lastAt),
    _backupStatusActionLabel(l10n, lastAction!),
  );

  if (status.isLocalBackupStale(now)) {
    return SecurityOverviewItem(
      icon: Icons.archive_outlined,
      title: l10n.settingsSecurityOverviewLocalBackupTitle,
      message: l10n.settingsSecurityOverviewLocalBackupStale,
      subtitle: failureSubtitle ?? lastLine,
      level: SettingsHealthLevel.warning,
    );
  }

  return SecurityOverviewItem(
    icon: Icons.archive_outlined,
    title: l10n.settingsSecurityOverviewLocalBackupTitle,
    message: lastLine,
    subtitle: failureSubtitle,
    level: failureSubtitle != null
        ? SettingsHealthLevel.warning
        : SettingsHealthLevel.ok,
  );
}

SecurityOverviewItem settingsDriveBackupSecurityOverview(
  AppLocalizations l10n,
  BackupStatusSnapshot status,
  DateTime now,
) {
  final DateTime? lastAt = status.lastDriveUploadAt;
  final String? account = status.lastDriveAccountLabel?.trim();
  final String? failureSubtitle = _backupFailureSubtitle(
    l10n,
    status,
    isLocalScope: false,
  );

  if (lastAt == null) {
    return SecurityOverviewItem(
      icon: Icons.cloud_outlined,
      title: l10n.settingsSecurityOverviewDriveBackupTitle,
      message: l10n.settingsSecurityOverviewDriveBackupNever,
      subtitle: failureSubtitle,
      level: SettingsHealthLevel.warning,
    );
  }

  final String lastLine = account != null && account.isNotEmpty
      ? l10n.settingsSecurityOverviewDriveBackupLastWithAccount(
          DisplayFormat.formatDateTimeWithoutWeekday(l10n, lastAt),
          account,
        )
      : l10n.settingsSecurityOverviewDriveBackupLast(
          DisplayFormat.formatDateTimeWithoutWeekday(l10n, lastAt),
        );

  if (status.isDriveUploadStale(now)) {
    return SecurityOverviewItem(
      icon: Icons.cloud_outlined,
      title: l10n.settingsSecurityOverviewDriveBackupTitle,
      message: l10n.settingsSecurityOverviewDriveBackupStale,
      subtitle: failureSubtitle ?? lastLine,
      level: SettingsHealthLevel.warning,
    );
  }

  return SecurityOverviewItem(
    icon: Icons.cloud_outlined,
    title: l10n.settingsSecurityOverviewDriveBackupTitle,
    message: lastLine,
    subtitle: failureSubtitle,
    level: failureSubtitle != null
        ? SettingsHealthLevel.warning
        : SettingsHealthLevel.ok,
  );
}

String? _backupFailureSubtitle(
  AppLocalizations l10n,
  BackupStatusSnapshot status, {
  required bool isLocalScope,
}) {
  final BackupFailureRecord? failure = status.lastFailure;
  if (failure == null) {
    return null;
  }
  final bool matchesScope = isLocalScope
      ? failure.action == BackupStatusAction.localBackup ||
            failure.action == BackupStatusAction.externalExport
      : failure.action == BackupStatusAction.driveUpload;
  if (!matchesScope) {
    return null;
  }
  return l10n.settingsSecurityOverviewBackupRecentFailure(
    _backupStatusActionLabel(l10n, failure.action),
  );
}
