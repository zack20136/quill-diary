import '../../infrastructure/security/app_unlock_mode.dart';
import '../../infrastructure/security/unlock_mode_change_service.dart';
import '../../infrastructure/storage/backup_task_progress.dart';
import '../../infrastructure/storage/restore_precheck.dart';
import '../../infrastructure/storage/shared/portable_import_result.dart';
import '../../l10n/l10n.dart';
import '../session/session_messages.dart';
import '../session/session_timeout_policy.dart';
import '../session/state/app_session_state.dart';

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
    PortableImportFailureCode.easyDiaryUnsupportedPlatform =>
      l10n.settingsImportExportFailureEasyDiaryUnsupportedPlatform,
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

String driveAwarePostRestoreSnackBarMessage({
  required AppLocalizations l10n,
  required AppLockStatus status,
  String? sessionMessage,
  String? driveBackupName,
}) {
  final String statusMessage = snackbarMessageForPostRestore(
    l10n,
    status,
    sessionMessage: sessionMessage,
  );
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

List<String> buildRestoreConfirmBulletPoints(
  AppLocalizations l10n,
  RestorePrecheck precheck,
) {
  final List<String> bullets = <String>[
    l10n.settingsRestoreBulletOverwriteWarning,
    l10n.settingsRestoreBulletRebuildIndex,
  ];

  if (!precheck.backupHasRecovery) {
    bullets.add(l10n.settingsRestoreBulletBackupWithoutRecovery);
    return bullets;
  }

  if (precheck.recoveryKeyRotatedSinceBackup) {
    bullets.add(l10n.settingsRestoreBulletRotatedBackup);
    final String? hint = precheck.backupRecoveryHint;
    if (hint != null && hint.isNotEmpty) {
      bullets.add(settingsRecoveryKeyHintLine(l10n, hint));
    }
  } else if (precheck.expectsTrustedUnlockAfterRestore) {
    bullets.add(l10n.settingsRestoreBulletTrustedAutoUnlock);
    bullets.add(l10n.settingsRestoreBulletTrustedAutoUnlockFallback);
  } else if (precheck.expectsRecoveryKeyAfterRestore) {
    bullets.add(l10n.settingsRestoreBulletRecoveryKeyAfterRestore);
    final String? hint = precheck.backupRecoveryHint;
    if (hint != null && hint.isNotEmpty) {
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
