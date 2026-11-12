import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/domain/persona/persona.dart';
import 'package:quill_diary/domain/persona/persona_chat_import.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/presentation/persona/persona_material_dialogs.dart';
import 'package:quill_diary/shared/presentation/private_text_controller.dart';
import 'package:quill_diary/shared/presentation/widgets/private_text.dart';

import '../../helpers/shared/test_l10n.dart';
import '../../helpers/shared/widget_test_app.dart';

void main() {
  final chat = PersonaChatImport(
    vaultId: 'vault',
    personId: generatePersonId(),
    personaId: generatePersonaId(),
    importId: generatePersonaImportId(),
    importedAt: DateTime.utc(2026, 11, 9),
    speakers: [
      PersonaImportSpeaker(id: 's1', label: '我', role: PersonaSpeakerRole.user),
      PersonaImportSpeaker(
        id: 's2',
        label: '小明',
        role: PersonaSpeakerRole.personaSubject,
      ),
    ],
    messages: const [
      PersonaImportMessage(
        id: 'm1',
        speakerId: 's1',
        text: '早安，昨天那本旅行書看得怎麼樣？',
        sentAtLocal: '2026-11-08T09:12:00',
      ),
      PersonaImportMessage(
        id: 'm2',
        speakerId: 's2',
        text: '我看到北海道那一章，突然很想冬天去看看。',
        sentAtLocal: '2026-11-08T09:14:00',
      ),
    ],
  );

  testWidgets('確認說話者以角色卡呈現，並保留底部確認與取消操作', (tester) async {
    await tester.pumpWidget(
      widgetTestApp(
        center: false,
        wrapScaffold: false,
        child: PersonaRolesDialog(chat: chat),
      ),
    );

    expect(
      find.byType(DropdownButtonFormField<PersonaSpeakerRole>),
      findsNWidgets(2),
    );
    expect(find.text('我'), findsWidgets);
    expect(find.text('自己'), findsWidgets);
    expect(find.text('小明'), findsWidgets);
    expect(find.text('目標對象'), findsWidgets);
    final confirm = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(confirm.onPressed, isNotNull);
    expect(
      find.text(testL10n.commonActionCancel).hitTestable(),
      findsOneWidget,
    );
  });

  testWidgets('匯入聊天將角色、日期與訊息納入狀態分卡顯示', (tester) async {
    final source = PersonaChatSource(importId: chat.importId);
    List<String>? toggledMessages;
    bool? toggledIncluded;
    String? editedDate;
    List<String>? editedMessages;
    var editRolesCount = 0;
    await tester.pumpWidget(
      widgetTestApp(
        center: false,
        wrapScaffold: false,
        child: PersonaChatMaterialPage(
          source: source,
          readChat: () => chat,
          bodyStyle: const TextStyle(fontSize: 16),
          onEditRoles: () async => editRolesCount++,
          onClearDate: (_) {},
          onPickDate: (_) async {},
          onToggleDate: (messages, included) {
            toggledMessages = messages.map((message) => message.id).toList();
            toggledIncluded = included;
          },
          onEditDate: (date, messages) async {
            editedDate = date;
            editedMessages = messages.map((message) => message.id).toList();
          },
        ),
      ),
    );

    expect(find.text('納入 2 則訊息'), findsOneWidget);
    expect(find.text('2026-11-08'), findsOneWidget);
    expect(find.byType(Checkbox), findsOneWidget);
    expect(find.byType(PrivateText), findsNWidgets(2));
    await tester.tap(find.byType(Checkbox).first);
    expect(toggledMessages, ['m1', 'm2']);
    expect(toggledIncluded, isFalse);
    await tester.tap(find.text('編輯'));
    expect(editedDate, '2026-11-08');
    expect(editedMessages, ['m1', 'm2']);
    await tester.tap(find.text('確認說話者'));
    expect(editRolesCount, 1);
  });

  testWidgets('日期編輯在窄螢幕大字下可修改與隱藏文字，並提供刪除與套用取消', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      widgetTestApp(
        center: false,
        wrapScaffold: false,
        child: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 900),
            textScaler: TextScaler.linear(1.6),
          ),
          child: PersonaChatDateEditorDialog(
            title: '2026-11-08',
            messages: const [
              PersonaChatDateEditorMessage(
                messageId: 'm1',
                speaker: '自己',
                sentAtLocal: '2026-11-08T09:12:00',
                text: '早安',
              ),
              PersonaChatDateEditorMessage(
                messageId: 'm2',
                speaker: '小明',
                sentAtLocal: '2026-11-08T09:14:00',
                text: '午安',
              ),
            ],
            ranges: const {},
          ),
        ),
      ),
    );

    expect(find.text('自己 · 09:12'), findsOneWidget);
    expect(find.text('小明 · 09:14'), findsOneWidget);
    expect(find.byTooltip('刪除'), findsNWidgets(2));
    expect(
      find.text(testL10n.commonActionCancel).hitTestable(),
      findsOneWidget,
    );
    expect(find.text('套用').hitTestable(), findsOneWidget);
    expect(find.text('完成檢查'), findsNothing);
    final textFields = find.byType(TextField);
    expect(tester.widget<TextField>(textFields.first).readOnly, isFalse);
    final controller =
        tester.widget<TextField>(textFields.first).controller!
            as PrivateTextController;
    controller.selection = const TextSelection(baseOffset: 0, extentOffset: 2);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.visibility_off));

    expect(controller.privateRanges, hasLength(1));
    expect(controller.privateRanges.single.start, 0);
    expect(controller.privateRanges.single.end, 2);
    await tester.enterText(textFields.first, '早晨');
    expect(controller.text, '早晨');
    expect(tester.takeException(), isNull);
  });
}
