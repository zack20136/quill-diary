import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/application/settings/settings_health_level.dart';
import 'package:quill_diary/presentation/settings/widgets/settings_sections.dart';
import 'package:quill_diary/infrastructure/storage/backup_status_store.dart';
import 'package:quill_diary/l10n/l10n.dart';

import '../../helpers/app_test_theme.dart';
import '../../helpers/shared/test_l10n.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  Future<void> pumpOverview(
    WidgetTester tester, {
    required SettingsHealthLevel indexHealthLevel,
    required String indexMessage,
    bool hasUnlockedSession = true,
    BackupStatusSnapshot backupStatus = const BackupStatusSnapshot(),
  }) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: appTestTheme(),
        darkTheme: appTestTheme(brightness: Brightness.dark),
        locale: appZhLocale,
        supportedLocales: appSupportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: SettingsSecurityOverview(
            hasRecoveryKey: true,
            recoveryKeyHint: 'ABCD',
            hasUnlockedSession: hasUnlockedSession,
            hasTrustedDevice: true,
            unlockModeLabel: testL10n.settingsUnlockModeFullNone,
            indexMessage: indexMessage,
            indexHealthLevel: indexHealthLevel,
            backupStatus: backupStatus,
            busy: false,
            onCreateRecoveryKey: () {},
            onRotateRecoveryKey: () {},
            onRepairVault: () {},
            lockPanel: null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('索引卡片依傳入的 health level 顯示正常', (WidgetTester tester) async {
    await pumpOverview(
      tester,
      indexHealthLevel: SettingsHealthLevel.ok,
      indexMessage: testL10n.settingsRepairVaultReadyMessage,
    );

    expect(find.text(testL10n.settingsRepairVaultReadyMessage), findsOneWidget);
    expect(
      find.text(testL10n.settingsSecurityOverviewIndexTitle),
      findsOneWidget,
    );
  });

  testWidgets('索引卡片依傳入的 health level 顯示需注意', (WidgetTester tester) async {
    await pumpOverview(
      tester,
      indexHealthLevel: SettingsHealthLevel.warning,
      indexMessage: testL10n.settingsRepairVaultLockedMessage,
      hasUnlockedSession: false,
      backupStatus: BackupStatusSnapshot(
        lastLocalBackupAt: DateTime(2026, 7, 3),
        lastDriveUploadAt: DateTime(2026, 7, 3),
      ),
    );

    expect(
      find.text(testL10n.settingsRepairVaultLockedMessage),
      findsOneWidget,
    );
  });

  testWidgets('索引卡片依傳入的 health level 顯示錯誤', (WidgetTester tester) async {
    const String errorMessage = '搜尋索引無法讀取，可能已損壞。';

    await pumpOverview(
      tester,
      indexHealthLevel: SettingsHealthLevel.error,
      indexMessage: errorMessage,
    );

    expect(
      find.text(testL10n.settingsSecurityOverviewHealthLevelError),
      findsOneWidget,
    );
    expect(find.text(errorMessage), findsOneWidget);
  });

  testWidgets('安全狀態會顯示本機與 Drive 備份卡片', (WidgetTester tester) async {
    await pumpOverview(
      tester,
      indexHealthLevel: SettingsHealthLevel.ok,
      indexMessage: testL10n.settingsRepairVaultReadyMessage,
      backupStatus: BackupStatusSnapshot(
        lastLocalBackupAt: DateTime(2026, 7, 3, 8, 53),
        lastDriveUploadAt: DateTime(2026, 7, 3, 8, 53),
        lastDriveAccountLabel: 'user@example.com',
      ),
    );

    expect(
      find.text(testL10n.settingsSecurityOverviewLocalBackupTitle),
      findsOneWidget,
    );
    expect(
      find.text(testL10n.settingsSecurityOverviewDriveBackupTitle),
      findsOneWidget,
    );
  });
}
