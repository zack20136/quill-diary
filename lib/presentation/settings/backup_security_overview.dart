import 'package:flutter/material.dart';

import 'package:quill_diary/infrastructure/storage/backup_status_store.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/application/settings/settings_health_level.dart';
import 'package:quill_diary/shared/presentation/display_format.dart';

import 'security_overview_item.dart';

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
