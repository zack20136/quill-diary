import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/presentation/widgets/recovery_key_text_field.dart';

import '../../helpers/app_test_theme.dart';
import '../../helpers/shared/test_l10n.dart';

void main() {
  testWidgets('復原金鑰欄位預設遮罩且關閉建議與自動填入', (WidgetTester tester) async {
    final TextEditingController controller = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        theme: appTestTheme(),
        darkTheme: appTestTheme(brightness: Brightness.dark),
        locale: appZhLocale,
        supportedLocales: appSupportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(body: RecoveryKeyTextField(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();

    final TextField field = tester.widget<TextField>(find.byType(TextField));
    expect(field.obscureText, isTrue);
    expect(field.enableSuggestions, isFalse);
    expect(field.enableIMEPersonalizedLearning, isFalse);
    expect(field.autofillHints, isEmpty);

    await tester.tap(find.byTooltip(testL10n.settingsRecoveryKeyShowTooltip));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(find.byType(TextField)).obscureText,
      isFalse,
    );
  });
}
