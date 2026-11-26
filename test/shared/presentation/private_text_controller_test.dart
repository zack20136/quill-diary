import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/domain/ai/private_text.dart';
import 'package:quill_diary/domain/people/person.dart';
import 'package:quill_diary/domain/people/person_name_matcher.dart';
import 'package:quill_diary/shared/presentation/private_text_controller.dart';

import '../../helpers/shared/widget_test_app.dart';

void main() {
  testWidgets('載入與編輯會更新個資高亮，取消手動選取不會取消自動隱藏或誤存為手動區間', (tester) async {
    final controller = PrivateTextController()
      ..setDocument('手動 a+b@example.org', const [PrivateTextRange(0, 2)]);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      widgetTestApp(child: TextField(controller: controller)),
    );
    List<String> highlightedText() => controller.highlightRanges
        .map((range) => controller.text.substring(range.start, range.end))
        .toList();

    expect(highlightedText(), ['手動', 'a+b@example.org']);
    expect(controller.privateRanges, hasLength(1));
    controller.selection = const TextSelection(baseOffset: 0, extentOffset: 2);
    controller.unhideSelection();
    await tester.pump();
    expect(controller.privateRanges, isEmpty);
    expect(highlightedText(), ['a+b@example.org']);

    await tester.enterText(
      find.byType(TextField),
      '手動 next@example.org 0912345678',
    );
    await tester.pump();
    expect(highlightedText(), ['next@example.org', '0912345678']);
    expect(controller.privateRanges, isEmpty);
    controller.text = '只剩公開內容';
    await tester.pump();
    expect(highlightedText(), isEmpty);
  });

  testWidgets('選取自動標出的 email 可以取消隱藏，再隱藏會恢復', (tester) async {
    const email = 'a+b@example.org';
    const text = '信箱 $email';
    final start = text.indexOf(email);
    final controller = PrivateTextController()..setDocument(text, const []);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      widgetTestApp(child: TextField(controller: controller)),
    );
    List<String> highlightedText() => controller.highlightRanges
        .map((range) => controller.text.substring(range.start, range.end))
        .toList();

    expect(highlightedText(), [email]);
    controller.selection = TextSelection(
      baseOffset: start,
      extentOffset: start + email.length,
    );
    expect(controller.selectionIsHidden, isTrue);
    controller.unhideSelection();
    await tester.pump();
    expect(highlightedText(), isEmpty);
    expect(controller.privateRanges, isEmpty);
    expect(controller.revealedRanges.map((range) => (range.start, range.end)), [
      (start, start + email.length),
    ]);

    controller.selection = TextSelection(
      baseOffset: start,
      extentOffset: start + email.length,
    );
    expect(controller.selectionIsHidden, isFalse);
    controller.hideSelection();
    await tester.pump();
    expect(highlightedText(), [email]);
    expect(controller.revealedRanges, isEmpty);
    expect(controller.privateRanges, hasLength(1));
  });

  testWidgets('選取人名可以取消這一處，同名另一處仍標出', (tester) async {
    const text = '王小明找王小明';
    final controller = PrivateTextController(
      detectRanges: privacyRangeDetector(
        () => PersonNameMatcher([
          Person(
            id: 'p1',
            name: '王小明',
            createdAt: DateTime.utc(2026, 11, 16),
            updatedAt: DateTime.utc(2026, 11, 16),
          ),
        ]),
      ),
    )..setDocument(text, const []);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      widgetTestApp(child: TextField(controller: controller)),
    );
    List<String> highlightedText() => controller.highlightRanges
        .map((range) => controller.text.substring(range.start, range.end))
        .toList();

    expect(highlightedText(), ['王小明', '王小明']);
    controller.selection = const TextSelection(baseOffset: 0, extentOffset: 3);
    expect(controller.selectionIsHidden, isTrue);
    controller.unhideSelection();
    await tester.pump();
    expect(highlightedText(), ['王小明']);
    expect(controller.revealedRanges.map((range) => (range.start, range.end)), [
      (0, 3),
    ]);
  });
}
