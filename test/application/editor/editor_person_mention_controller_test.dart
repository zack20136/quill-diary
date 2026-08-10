import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/application/editor/editor_person_mention_controller.dart';

void main() {
  test('沒有建議項目時 Enter 不會被人物選單攔截', () {
    final TextEditingController text = TextEditingController(text: '@未知人物');
    final EditorPersonMentionController controller =
        EditorPersonMentionController()..bind(text);
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
    final EditorPersonMentionController controller =
        EditorPersonMentionController()..bind(text);
    addTearDown(controller.dispose);
    addTearDown(text.dispose);

    text.value = const TextEditingValue(
      text: '@小明',
      selection: TextSelection.collapsed(offset: 3),
      composing: TextRange(start: 1, end: 3),
    );

    expect(controller.isActive, isFalse);
  });

  test('建立人物後只會插入普通正式姓名文字', () {
    final TextEditingController text = TextEditingController(text: '今天遇到 @小');
    text.selection = TextSelection.collapsed(offset: text.text.length);
    final EditorPersonMentionController controller =
        EditorPersonMentionController()..bind(text);
    addTearDown(controller.dispose);
    addTearDown(text.dispose);

    expect(controller.applyCanonicalName('王小明'), isTrue);
    expect(text.text, '今天遇到 王小明');
    expect(text.text, isNot(contains('@')));
  });
}
