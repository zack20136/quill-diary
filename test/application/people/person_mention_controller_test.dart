import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/people/person_mention_controller.dart';

void main() {
  test('沒有建議項目時 Enter 不會被人物選單攔截', () {
    final TextEditingController text = TextEditingController(text: '@未知人物');
    final PersonMentionController controller = PersonMentionController()
      ..bind(text);
    addTearDown(controller.dispose);
    addTearDown(text.dispose);

    final result = controller.handleKeyEvent(
      const KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.enter,
        logicalKey: LogicalKeyboardKey.enter,
        timeStamp: Duration.zero,
      ),
      suggestionCount: 0,
    );

    expect(result.result, KeyEventResult.ignored);
    expect(result.shouldApplySelection, isFalse);
  });

  test('中文輸入法組字期間不會啟用人物查詢', () {
    final TextEditingController text = TextEditingController();
    final PersonMentionController controller = PersonMentionController()
      ..bind(text);
    addTearDown(controller.dispose);
    addTearDown(text.dispose);

    text.value = const TextEditingValue(
      text: '@小明',
      selection: TextSelection.collapsed(offset: 3),
      composing: TextRange(start: 1, end: 3),
    );

    expect(controller.isActive, isFalse);
  });

  test('建立人物後會插入指定的日記名稱文字', () {
    final TextEditingController text = TextEditingController(text: '今天遇到 @小');
    text.selection = TextSelection.collapsed(offset: text.text.length);
    final PersonMentionController controller = PersonMentionController()
      ..bind(text);
    addTearDown(controller.dispose);
    addTearDown(text.dispose);

    expect(controller.applyMentionLabel('阿明'), isTrue);
    expect(text.text, '今天遇到 阿明');
    expect(text.text, isNot(contains('@')));
  });

  test('已有建議時的中文組字確認鍵不會套用人物', () {
    final text = TextEditingController(text: '@');
    final controller = PersonMentionController()..bind(text);
    addTearDown(text.dispose);
    addTearDown(controller.dispose);
    expect(controller.isActive, isTrue);
    text.value = const TextEditingValue(
      text: '@明',
      selection: TextSelection.collapsed(offset: 2),
      composing: TextRange(start: 1, end: 2),
    );
    final result = controller.handleKeyEvent(
      const KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.enter,
        logicalKey: LogicalKeyboardKey.enter,
        timeStamp: Duration.zero,
      ),
      suggestionCount: 1,
    );
    expect(result.result, KeyEventResult.ignored);
    expect(result.shouldApplySelection, isFalse);
    expect(text.text, '@明');
  });
}
