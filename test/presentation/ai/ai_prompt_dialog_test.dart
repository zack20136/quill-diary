import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/domain/preferences/personalization_preferences.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/ai/ai_prompt_dialog.dart';

import '../../helpers/shared/widget_test_app.dart';

const _field = ValueKey('test-prompt');
const _open = ValueKey('open-prompt');

String _defaultPrompt(AppLanguage language) =>
    language == AppLanguage.en ? 'Default guidance' : '預設引導內容';

void main() {
  AiPromptEdit? result;
  var completed = false;

  Future<void> open(
    WidgetTester tester, {
    Locale locale = appZhLocale,
    String? customText,
    bool readOnly = false,
  }) async {
    result = null;
    completed = false;
    await tester.pumpWidget(
      widgetTestApp(
        locale: locale,
        child: Builder(
          builder: (context) => TextButton(
            key: _open,
            onPressed: () async {
              result = await showAiPromptDialog(
                context,
                title: (l) => l.chatDiaryGuidanceLabel,
                defaultPrompt: _defaultPrompt,
                fieldKey: _field,
                customText: customText,
                readOnly: readOnly,
              );
              completed = true;
            },
            child: Text(context.l10n.chatDiaryGuidanceLabel),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(_open));
    await tester.pumpAndSettle();
  }

  testWidgets('長提示詞可捲動，捲動後仍可編輯', (tester) async {
    final text = List.generate(80, (i) => '第 $i 段：保留可編輯的完整提示詞。').join('\n');
    await open(tester, customText: text);
    final Finder field = find.byKey(_field);
    final Finder scrollable = find.descendant(
      of: field,
      matching: find.byType(Scrollable),
    );
    await tester.drag(scrollable, const Offset(0, -160));
    await tester.pumpAndSettle();
    expect(
      tester.state<ScrollableState>(scrollable).position.pixels,
      greaterThan(0),
    );
    await tester.enterText(field, '更新後仍可編輯');
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field).controller!.text, '更新後仍可編輯');
    expect(tester.takeException(), isNull);
  });

  testWidgets('取消不回傳修改，套用保留自訂原文', (tester) async {
    final l = lookupAppLocalizations(appZhLocale);
    await open(tester, customText: '原有覆寫');
    await tester.enterText(find.byKey(_field), '未套用內容');
    await tester.tap(find.widgetWithText(TextButton, l.commonActionCancel));
    await tester.pumpAndSettle();
    expect(completed, isTrue);
    expect(result, isNull);

    await open(tester, customText: '原有覆寫');
    await tester.enterText(find.byKey(_field), '  保留空白的自訂內容  ');
    await tester.tap(find.widgetWithText(FilledButton, l.aiPromptApply));
    await tester.pumpAndSettle();
    expect(result!.customText, '  保留空白的自訂內容  ');
  });

  testWidgets('窄畫面鍵盤下可修正空白提示詞，還原預設後不存覆寫', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await open(tester, locale: appEnLocale);
    final l = lookupAppLocalizations(appEnLocale);
    final field = find.byKey(_field);
    final restore = find.widgetWithText(TextButton, l.aiPromptRestoreDefault);
    expect(tester.widget<TextButton>(restore).onPressed, isNull);
    await tester.enterText(field, ' ');
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    await tester.pumpAndSettle();
    final apply = find.widgetWithText(FilledButton, l.aiPromptApply);
    expect(
      tester.getTopLeft(restore).dx,
      lessThan(tester.getTopLeft(apply).dx),
    );
    await tester.tap(apply);
    await tester.pumpAndSettle();
    final error = find.text(l.aiPromptRequired);
    expect(error.hitTestable(), findsOneWidget);
    expect(tester.getRect(error).top, lessThan(tester.getRect(field).top));
    await tester.enterText(field, '修正後的提示詞');
    await tester.pumpAndSettle();
    expect(error, findsNothing);
    await tester.tap(restore);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(field).controller!.text,
      _defaultPrompt(AppLanguage.en),
    );
    expect(tester.widget<TextButton>(restore).onPressed, isNull);
    await tester.tap(apply);
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.customText, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('唯讀提示詞只提供關閉，不提供還原與套用', (tester) async {
    final l = lookupAppLocalizations(appZhLocale);
    await open(tester, readOnly: true);
    expect(tester.widget<TextField>(find.byKey(_field)).readOnly, isTrue);
    expect(
      find.widgetWithText(TextButton, l.aiPromptRestoreDefault),
      findsNothing,
    );
    expect(find.widgetWithText(FilledButton, l.aiPromptApply), findsNothing);
    await tester.tap(find.widgetWithText(TextButton, l.commonActionClose));
    await tester.pumpAndSettle();
    expect(completed, isTrue);
    expect(result, isNull);
  });
}
