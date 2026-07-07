import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/presentation/settings/pages/settings_page.dart';
import 'package:quill_diary/l10n/l10n.dart';

import '../../../helpers/app_test_theme.dart';
import '../../../helpers/presentation/settings/settings_test_scope.dart';
import '../../../helpers/shared/test_l10n.dart';

void main() {
  testWidgets('法務區塊會顯示 GitHub 相關連結', (WidgetTester tester) async {
    await tester.pumpWidget(
      settingsTestScope(
        child: MaterialApp(
          theme: appTestTheme(),
          darkTheme: appTestTheme(brightness: Brightness.dark),
          locale: appZhLocale,
          supportedLocales: appSupportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const SettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text(testL10n.settingsLegalSectionTitle),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text(testL10n.settingsLegalSectionTitle), findsOneWidget);
    expect(
      find.textContaining(testL10n.settingsLegalSectionDescription),
      findsOneWidget,
    );
    expect(find.text(testL10n.settingsLegalSourceCodeTitle), findsOneWidget);
    expect(find.text(testL10n.settingsLegalPrivacyPolicyTitle), findsOneWidget);
    expect(
      find.text(testL10n.settingsLegalThirdPartyNoticesTitle),
      findsOneWidget,
    );
    expect(find.text(testL10n.settingsLegalContactAuthorTitle), findsOneWidget);
  });
}
