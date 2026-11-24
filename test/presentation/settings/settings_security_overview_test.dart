import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/settings/settings_health.dart';
import 'package:quill_diary/application/settings/settings_providers.dart';
import 'package:quill_diary/infrastructure/security/app_unlock_mode.dart';
import 'package:quill_diary/infrastructure/storage/backup_status_store.dart';
import 'package:quill_diary/presentation/settings/widgets/settings_sections.dart';

import '../../helpers/shared/test_l10n.dart';
import '../../helpers/shared/widget_test_app.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  Future<void> pumpOverview(
    WidgetTester tester, {
    required SettingsHealthLevel indexHealthLevel,
    required String indexMessage,
    bool hasUnlockedSession = true,
    AppUnlockMode unlockMode = AppUnlockMode.deviceLock,
    BackupStatusSnapshot backupStatus = const BackupStatusSnapshot(),
    bool needsBackup = false,
    Object? backupStatusError,
  }) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      widgetTestApp(
        center: false,
        overrides: [
          recoveryBackupRequiredProvider.overrideWithValue(
            backupStatusError == null
                ? AsyncData(needsBackup)
                : AsyncError(backupStatusError, StackTrace.empty),
          ),
        ],
        child: SettingsSecurityOverview(
          hasRecoveryKey: true,
          recoveryKeyHint: 'ABCD',
          hasUnlockedSession: hasUnlockedSession,
          hasTrustedDevice: true,
          unlockMode: unlockMode,
          indexMessage: indexMessage,
          indexHealthLevel: indexHealthLevel,
          backupStatus: backupStatus,
          busy: false,
          onCreateRecoveryKey: () {},
          onRotateRecoveryKey: () {},
          onInspectVault: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('未啟用 App 解鎖的安全狀態標為需注意', (tester) async {
    await pumpOverview(
      tester,
      indexHealthLevel: SettingsHealthLevel.ok,
      indexMessage: testL10n.settingsRepairVaultReadyMessage,
      unlockMode: AppUnlockMode.none,
    );
    final tile = find
        .ancestor(
          of: find.text(
            testL10n.settingsSecurityOverviewUnlockModeDisabledMessage,
          ),
          matching: find.byType(DecoratedBox),
        )
        .first;
    expect(
      find.descendant(
        of: tile,
        matching: find.text(
          testL10n.settingsSecurityOverviewHealthLevelWarning,
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('更新金鑰後在既有安全卡顯示備份提醒，完成後恢復就緒', (tester) async {
    await pumpOverview(
      tester,
      indexHealthLevel: SettingsHealthLevel.ok,
      indexMessage: testL10n.settingsRepairVaultReadyMessage,
      needsBackup: true,
    );
    expect(
      find.text(testL10n.settingsRecoveryKeyBackupRequired),
      findsOneWidget,
    );
    await pumpOverview(
      tester,
      indexHealthLevel: SettingsHealthLevel.ok,
      indexMessage: testL10n.settingsRepairVaultReadyMessage,
    );
    expect(find.text(testL10n.settingsRecoveryKeyBackupRequired), findsNothing);
    expect(
      find.text(testL10n.settingsSecurityOverviewRecoveryKeyReady),
      findsOneWidget,
    );
  });

  testWidgets('備份提醒讀取失敗顯示錯誤與重試，恢復後才顯示就緒', (tester) async {
    await pumpOverview(
      tester,
      indexHealthLevel: SettingsHealthLevel.ok,
      indexMessage: testL10n.settingsRepairVaultReadyMessage,
      backupStatusError: const FormatException('損壞'),
    );
    expect(find.text(testL10n.settingsBackupStatusReadFailed), findsOneWidget);
    expect(
      find.text(testL10n.settingsSecurityOverviewRecoveryKeyReady),
      findsNothing,
    );
    expect(
      find.widgetWithText(TextButton, testL10n.commonActionRetry),
      findsOneWidget,
    );
    await pumpOverview(
      tester,
      indexHealthLevel: SettingsHealthLevel.ok,
      indexMessage: testL10n.settingsRepairVaultReadyMessage,
    );
    expect(find.text(testL10n.settingsBackupStatusReadFailed), findsNothing);
    expect(
      find.text(testL10n.settingsSecurityOverviewRecoveryKeyReady),
      findsOneWidget,
    );
  });

  testWidgets('索引卡片在 health level 為 ok 時顯示就緒訊息', (WidgetTester tester) async {
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

  testWidgets('可用的檢查日記庫操作使用 tonal 按鈕', (WidgetTester tester) async {
    await pumpOverview(
      tester,
      indexHealthLevel: SettingsHealthLevel.ok,
      indexMessage: testL10n.settingsRepairVaultReadyMessage,
    );

    expect(
      find.widgetWithText(
        FilledButton,
        testL10n.settingsSecurityOverviewInspectVaultButton,
      ),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(
        OutlinedButton,
        testL10n.settingsSecurityOverviewInspectVaultButton,
      ),
      findsNothing,
    );
  });

  testWidgets('設定卡不再顯示查看異常日記按鈕', (WidgetTester tester) async {
    await pumpOverview(
      tester,
      indexHealthLevel: SettingsHealthLevel.warning,
      indexMessage: testL10n.settingsInspectVaultCompletedWithIssues(
        2,
        '2026/08/20 10:00',
      ),
    );

    expect(
      find.text(testL10n.settingsSecurityOverviewInspectVaultButton),
      findsOneWidget,
    );
    expect(find.textContaining('異常日記'), findsNothing);
  });

  testWidgets('復原金鑰副標只有末四碼使用等寬字，標籤維持一般字', (WidgetTester tester) async {
    await pumpOverview(
      tester,
      indexHealthLevel: SettingsHealthLevel.ok,
      indexMessage: testL10n.settingsRepairVaultReadyMessage,
    );

    final Finder subtitle = find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          widget.textSpan?.toPlainText() ==
              '${testL10n.settingsRecoveryKeyHintPrefix}ABCD',
    );
    expect(subtitle, findsOneWidget);
    final spans = (tester.widget<Text>(subtitle).textSpan! as TextSpan)
        .children!
        .cast<TextSpan>();
    expect(spans, hasLength(2));
    expect(spans.first.text, testL10n.settingsRecoveryKeyHintPrefix);
    expect(spans.first.style?.fontFamily, isNull);
    expect(spans.last.text, 'ABCD');
    expect(spans.last.style?.fontFamily, 'monospace');
  });
}
