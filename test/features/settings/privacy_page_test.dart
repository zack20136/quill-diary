import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/features/settings/legal_disclosures.dart';
import 'package:quill_diary/features/settings/pages/privacy_page.dart';
import 'package:quill_diary/features/settings/privacy_copy.dart';

void main() {
  testWidgets('PrivacyPage 顯示標題與全部摘要章節', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PrivacyPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(SettingsPrivacyCopy.pageTitle), findsOneWidget);
    expect(find.textContaining(LegalDisclosures.privacyAuthoritativeNotice), findsOneWidget);

    for (final PrivacySectionCopy section in SettingsPrivacyCopy.sections) {
      await tester.scrollUntilVisible(find.text(section.title), 300);
      await tester.pumpAndSettle();
      expect(find.text(section.title), findsOneWidget);
    }

    await tester.scrollUntilVisible(
      find.text(SettingsPrivacyCopy.openInBrowserLabel),
      300,
    );
    await tester.pumpAndSettle();
    expect(find.text(SettingsPrivacyCopy.openInBrowserLabel), findsOneWidget);
  });
}
