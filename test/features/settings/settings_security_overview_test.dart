import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/features/settings/widgets/settings_sections.dart';
import 'package:quill_diary/l10n/l10n.dart';

import '../../helpers/app_test_theme.dart';
import '../../helpers/shared/test_l10n.dart';

void main() {
  Future<void> pumpOverview(
    WidgetTester tester, {
    required SettingsHealthLevel indexHealthLevel,
    required String indexMessage,
  }) async {
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
            hasUnlockedSession: indexHealthLevel != SettingsHealthLevel.warning,
            hasTrustedDevice: true,
            unlockModeLabel: testL10n.settingsUnlockModeFullNone,
            indexMessage: indexMessage,
            indexHealthLevel: indexHealthLevel,
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

  testWidgets('索引卡片依傳入的 health level 顯示需注意', (WidgetTester tester) async {
    await pumpOverview(
      tester,
      indexHealthLevel: SettingsHealthLevel.warning,
      indexMessage: testL10n.settingsRepairVaultLockedMessage,
    );

    expect(
      find.text(testL10n.settingsSecurityOverviewHealthLevelWarning),
      findsOneWidget,
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
}
