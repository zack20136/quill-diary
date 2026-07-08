import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/presentation/settings/backup_security_overview.dart';
import 'package:quill_diary/presentation/settings/security_overview_item.dart';
import 'package:quill_diary/application/settings/settings_health_level.dart';
import 'package:quill_diary/infrastructure/storage/backup_status_store.dart';
import 'package:quill_diary/l10n/l10n.dart';

import '../../helpers/shared/test_l10n.dart';

void main() {
  final AppLocalizations l10n = testL10n;
  final DateTime now = DateTime(2026, 7, 3, 12);

  group('settingsLocalBackupSecurityOverview', () {
    test('從未備份時顯示建議儘快備份', () {
      final SecurityOverviewItem item = settingsLocalBackupSecurityOverview(
        l10n,
        const BackupStatusSnapshot(),
        now,
      );

      expect(item.level, SettingsHealthLevel.warning);
      expect(item.message, l10n.settingsSecurityOverviewLocalBackupNever);
      expect(item.subtitle, isNull);
    });

    test('30 天內匯出備份會以方式在前、時間在後且不含星期', () {
      final DateTime exportedAt = DateTime(2026, 7, 3, 9, 4);
      final SecurityOverviewItem item = settingsLocalBackupSecurityOverview(
        l10n,
        BackupStatusSnapshot(lastExternalExportAt: exportedAt),
        now,
      );

      expect(item.level, SettingsHealthLevel.ok);
      expect(
        item.message,
        l10n.settingsSecurityOverviewLocalBackupLast(
          '2026年7月3日 09:04',
          l10n.settingsLocalBackupExportToExternalButton,
        ),
      );
      expect(item.message, isNot(contains('星期五')));
    });

    test('超過 30 天未備份時主訊息為過期提醒', () {
      final DateTime staleAt = now.subtract(const Duration(days: 31));
      final SecurityOverviewItem item = settingsLocalBackupSecurityOverview(
        l10n,
        BackupStatusSnapshot(lastLocalBackupAt: staleAt),
        now,
      );

      expect(item.level, SettingsHealthLevel.warning);
      expect(item.message, l10n.settingsSecurityOverviewLocalBackupStale);
      expect(item.subtitle, isNotNull);
    });

    test('本機備份失敗會顯示於副說明', () {
      final SecurityOverviewItem item = settingsLocalBackupSecurityOverview(
        l10n,
        BackupStatusSnapshot(
          lastLocalBackupAt: now,
          lastFailure: BackupFailureRecord(
            action: BackupStatusAction.localBackup,
            message: 'inspect failed',
            occurredAt: now,
          ),
        ),
        now,
      );

      expect(item.level, SettingsHealthLevel.warning);
      expect(
        item.subtitle,
        l10n.settingsSecurityOverviewBackupRecentFailure(
          l10n.settingsLocalBackupCreateButton,
        ),
      );
    });
  });

  group('settingsDriveBackupSecurityOverview', () {
    test('從未上傳時顯示建議儘快備份', () {
      final SecurityOverviewItem item = settingsDriveBackupSecurityOverview(
        l10n,
        const BackupStatusSnapshot(),
        now,
      );

      expect(item.level, SettingsHealthLevel.warning);
      expect(item.message, l10n.settingsSecurityOverviewDriveBackupNever);
    });

    test('有帳號時顯示上傳時間與帳號', () {
      final DateTime uploadedAt = DateTime(2026, 7, 3, 8, 53);
      final SecurityOverviewItem item = settingsDriveBackupSecurityOverview(
        l10n,
        BackupStatusSnapshot(
          lastDriveUploadAt: uploadedAt,
          lastDriveAccountLabel: 'user@example.com',
        ),
        now,
      );

      expect(item.level, SettingsHealthLevel.ok);
      expect(
        item.message,
        l10n.settingsSecurityOverviewDriveBackupLastWithAccount(
          '2026年7月3日 08:53',
          'user@example.com',
        ),
      );
    });
  });
}
