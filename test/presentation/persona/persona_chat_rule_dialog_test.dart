import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/domain/persona/persona_chat_import.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/presentation/persona/persona_chat_rule_dialog.dart';
import 'package:quill_diary/presentation/persona/persona_speaker_role_dropdown.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_shell.dart';

import '../../helpers/shared/test_l10n.dart';
import '../../helpers/shared/widget_test_app.dart';

void main() {
  const sample = '小明說明天見面\n地址先不要送出';

  testWidgets('無法辨識的聊天顯示全文，可隱藏片段並指定人名', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    PersonaChatImport? chosen;
    await tester.pumpWidget(
      widgetTestApp(
        center: false,
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              chosen = await showAppDialog<PersonaChatImport>(
                context: context,
                builder: (_) => PersonaChatRuleDialog(
                  input: sample,
                  vaultId: 'vault',
                  personId: generatePersonId(),
                  personaId: generatePersonaId(),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text(sample), findsOneWidget);
    expect(find.text(testL10n.personaChatRuleNames), findsOneWidget);
    expect(find.byType(PersonaSpeakerRoleCard), findsNothing);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, testL10n.personaChatRuleImport),
          )
          .onPressed,
      isNotNull,
    );

    await tester.enterText(find.byType(TextField).first, '小明');
    await tester.tap(find.text(testL10n.personaChatRuleAddName));
    await tester.pump();
    expect(find.byType(PersonaSpeakerRoleCard), findsOneWidget);
    await tester.tap(find.text(testL10n.personaRoleUnknown));
    await tester.pumpAndSettle();
    await tester.tap(find.text(testL10n.personaRoleSubject).last);
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField).last);
    field.controller!.selection = TextSelection(
      baseOffset: 0,
      extentOffset: field.controller!.text.length,
    );
    await tester.pump();
    await tester.tap(find.byTooltip(testL10n.aiHideSelection));
    await tester.pump();
    expect(find.text(testL10n.personaChatRuleEmpty), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, testL10n.personaChatRuleImport),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(find.byTooltip(testL10n.aiUnhideSelection));
    await tester.pump();
    final start = field.controller!.text.indexOf('地址');
    field.controller!.selection = TextSelection(
      baseOffset: start,
      extentOffset: start + 2,
    );
    await tester.pump();
    await tester.tap(find.byTooltip(testL10n.aiHideSelection));
    await tester.pump();
    await tester.tap(find.text(testL10n.personaChatRuleImport));
    await tester.pumpAndSettle();

    expect(chosen, isNotNull);
    expect(chosen!.isRaw, isTrue);
    expect(chosen!.messages, isEmpty);
    expect(chosen!.rawText, sample);
    expect(chosen!.rawHidden.single.start, start);
    expect(chosen!.rawHidden.single.end, start + 2);
    expect(chosen!.speakers.single.label, '小明');
    expect(chosen!.speakers.single.id, 'named-s1');
    expect(chosen!.speakers.single.role, PersonaSpeakerRole.personaSubject);
  });
}
