import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/shared/presentation/widgets/recovery_key_text_field.dart';

import '../../helpers/shared/test_l10n.dart';
import '../../helpers/shared/widget_test_app.dart';

void main() {
  testWidgets('復原金鑰欄位預設顯示且關閉建議與自動填入', (WidgetTester tester) async {
    final TextEditingController controller = TextEditingController();

    await tester.pumpWidget(
      widgetTestApp(
        includeDarkTheme: true,
        center: false,
        child: RecoveryKeyTextField(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    final TextField field = tester.widget<TextField>(find.byType(TextField));
    expect(field.obscureText, isFalse);
    expect(field.enableSuggestions, isFalse);
    expect(field.enableIMEPersonalizedLearning, isFalse);
    expect(field.autofillHints, isEmpty);

    await tester.tap(find.byTooltip(testL10n.settingsRecoveryKeyHideTooltip));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(find.byType(TextField)).obscureText,
      isTrue,
    );
  });

  testWidgets('手動輸入八個字元會自動補上橫線', (WidgetTester tester) async {
    final TextEditingController controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      widgetTestApp(
        includeDarkTheme: true,
        center: false,
        child: RecoveryKeyTextField(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'abcdefgh');
    await tester.pump();

    expect(controller.text, 'ABCD-EFGH');
  });

  test('連打八個字元會分成兩組且游標留在結尾', () {
    const RecoveryKeyInputFormatter formatter = RecoveryKeyInputFormatter();
    TextEditingValue value = const TextEditingValue(
      selection: TextSelection.collapsed(offset: 0),
    );
    for (final String char in 'abcdefgh'.split('')) {
      value = _insert(formatter, value, char);
    }

    expect(value.text, 'ABCD-EFGH');
    expect(value.selection.extentOffset, value.text.length);
  });

  test('在中間打橫線不會產生連續橫線', () {
    const RecoveryKeyInputFormatter formatter = RecoveryKeyInputFormatter();
    const TextEditingValue current = TextEditingValue(
      text: 'ABCD-EFGH',
      selection: TextSelection.collapsed(offset: 2),
    );

    final TextEditingValue next = formatter.formatEditUpdate(
      current,
      const TextEditingValue(
        text: 'AB-CD-EFGH',
        selection: TextSelection.collapsed(offset: 3),
      ),
    );

    expect(next.text, 'ABCD-EFGH');
    expect(next.selection.extentOffset, 2);
  });

  test('貼上含橫線、小寫與空白會整理成同一組大寫分組', () {
    const RecoveryKeyInputFormatter formatter = RecoveryKeyInputFormatter();
    const String formatted = 'ABCD-EFGH-IJKL-MNOP-QRST-UVWX';

    expect(_replaceAll(formatter, formatted).text, formatted);
    expect(
      _replaceAll(formatter, 'abcd efgh\nijkl mnop qrst uvwx').text,
      formatted,
    );
    expect(
      _replaceAll(formatter, 'ABCD－EFGH－IJKL－MNOP－QRST－UVWX').text,
      formatted,
    );
    expect(_replaceAll(formatter, formatted).selection.extentOffset, 29);
  });

  test('在橫線上按退格會刪掉前一個字元', () {
    const RecoveryKeyInputFormatter formatter = RecoveryKeyInputFormatter();
    const TextEditingValue current = TextEditingValue(
      text: 'ABCD-EFGH',
      selection: TextSelection.collapsed(offset: 5),
    );

    final TextEditingValue next = formatter.formatEditUpdate(
      current,
      const TextEditingValue(
        text: 'ABCDEFGH',
        selection: TextSelection.collapsed(offset: 4),
      ),
    );

    expect(next.text, 'ABCE-FGH');
    expect(next.selection.extentOffset, 3);
  });
}

TextEditingValue _insert(
  RecoveryKeyInputFormatter formatter,
  TextEditingValue current,
  String inserted,
) {
  final int at = current.selection.extentOffset;
  return formatter.formatEditUpdate(
    current,
    TextEditingValue(
      text: current.text.replaceRange(at, at, inserted),
      selection: TextSelection.collapsed(offset: at + inserted.length),
    ),
  );
}

TextEditingValue _replaceAll(RecoveryKeyInputFormatter formatter, String text) {
  return formatter.formatEditUpdate(
    TextEditingValue.empty,
    TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    ),
  );
}
