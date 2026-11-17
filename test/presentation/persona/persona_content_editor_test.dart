import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/domain/persona/persona.dart';
import 'package:quill_diary/domain/persona/persona_content.dart';
import 'package:quill_diary/presentation/persona/persona_content_editor.dart';

import '../../helpers/shared/widget_test_app.dart';

void main() {
  testWidgets('姓名編輯保留代號，鍵盤開閉不重設游標，名冊改名不寫回姓名副本', (tester) async {
    var candidate = PersonaCandidate(text: '和{{PER_01}}散步。', tokens: {'{{PER_01}}': 'a'});
    var name = '小明';
    late StateSetter update;
    await tester.pumpWidget(
      widgetTestApp(
        child: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return PersonaContentEditor(
              card: candidate,
              kind: PersonaCardKind.memory,
              names: {'a': name},
              style: Theme.of(context).textTheme.bodyLarge!,
              valid: true,
              onChanged: (text) => setState(
                () => candidate = PersonaCandidate(
                  text: text,
                  tokens: candidate.tokens,
                ),
              ),
            );
          },
        ),
      ),
    );
    final field = find.byType(TextFormField);
    expect(tester.widget<TextFormField>(field).controller!.text, '和小明散步。');
    await tester.enterText(field, '今天和小明散步。');
    await tester.pump();
    expect(candidate.text, '今天和{{PER_01}}散步。');
    final controller = tester.widget<TextFormField>(field).controller!;
    controller.selection = const TextSelection.collapsed(offset: 2);
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    expect(controller.selection.baseOffset, 2);
    update(() => name = '王小明');
    await tester.pump();
    expect(controller.text, '今天和王小明散步。');
    expect(candidate.text, '今天和{{PER_01}}散步。');
  });
  test('編輯前後文保留姓名識別，刪改一處姓名不影響另一處', () {
    final controller = PersonaContentController();
    addTearDown(controller.dispose);
    controller.setContent(
      PersonaContent(
        PersonaCandidate(text: '和{{PER_01}}散步，再與{{PER_01}}喝茶。', tokens: {'{{PER_01}}': 'a'}),
        {'a': '小明'},
        unknownPerson: (n) => '其他人物$n',
      ),
    );
    expect(controller.text, '和小明散步，再與小明喝茶。');
    controller.value = TextEditingValue(text: '😀和小明散步，再與小明喝茶。');
    expect(controller.protectedText, '😀和{{PER_01}}散步，再與{{PER_01}}喝茶。');
    controller.value = TextEditingValue(text: '😀和小華散步，再與小明喝茶。');
    expect(controller.protectedText, '😀和小華散步，再與{{PER_01}}喝茶。');
    controller.value = TextEditingValue(text: '😀和小華散步。');
    expect(controller.protectedText, '😀和小華散步。');
  });
}
