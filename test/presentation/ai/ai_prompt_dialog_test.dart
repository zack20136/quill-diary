import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/domain/preferences/personalization_preferences.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/ai/ai_prompt_dialog.dart';
import 'package:quill_diary/shared/presentation/app_scrollbar.dart';

import '../../helpers/shared/widget_test_app.dart';

const _field = ValueKey('test-prompt');
const _open = ValueKey('open-prompt');

String _defaultPrompt(AppLanguage language) =>
    language == AppLanguage.en ? 'Default guidance' : '預設引導內容';

void main() {
  AiPromptEdit? result;
  var completed = false;

  setUpAll(() async {
    for (final family in ['Inter', 'NotoSansTC']) {
      await (FontLoader(
        family,
      )..addFont(rootBundle.load('assets/fonts/$family-Regular.ttf'))).load();
    }
  });

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
                help: (l) => l.chatDiaryGuidanceHelp,
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

  for (final (locale, width, scale) in [
    (appZhLocale, 520.0, 1.0),
    (appEnLocale, 320.0, 2.0),
  ]) {
    testWidgets('${locale.languageCode} 提示詞操作靠兩側，還原狀態隨內容更新且預設不存覆寫', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await open(tester, locale: locale);
      final l = lookupAppLocalizations(locale);
      final restore = find.widgetWithText(TextButton, l.aiPromptRestoreDefault);
      final cancel = find.widgetWithText(TextButton, l.commonActionCancel);
      final apply = find.widgetWithText(FilledButton, l.aiPromptApply);
      final actions = find
          .ancestor(of: restore, matching: find.byType(LayoutBuilder))
          .first;
      expect(
        tester.getRect(restore).left,
        closeTo(tester.getRect(actions).left, 0.1),
      );
      expect(
        tester.getRect(apply).right,
        closeTo(tester.getRect(actions).right, 0.1),
      );
      expect(
        tester.getRect(cancel).bottom,
        lessThanOrEqualTo(tester.getRect(apply).bottom),
      );
      expect(tester.widget<TextButton>(restore).onPressed, isNull);

      await tester.enterText(find.byKey(_field), '自訂內容');
      await tester.pump();
      expect(tester.widget<TextButton>(restore).onPressed, isNotNull);
      await tester.tap(restore);
      await tester.pumpAndSettle();
      final language = locale == appEnLocale ? AppLanguage.en : AppLanguage.zh;
      expect(
        tester.widget<TextField>(find.byKey(_field)).controller!.text,
        _defaultPrompt(language),
      );
      expect(tester.widget<TextButton>(restore).onPressed, isNull);

      await tester.enterText(find.byKey(_field), '另一份內容');
      await tester.enterText(find.byKey(_field), _defaultPrompt(language));
      await tester.pump();
      expect(tester.widget<TextButton>(restore).onPressed, isNull);
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.showKeyboard(find.byKey(_field));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(apply);
      await tester.pumpAndSettle();
      expect(completed, isTrue);
      expect(result, isNotNull);
      expect(result!.customText, isNull);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('長提示詞使用共用位置提示，捲動與編輯不被 scrollbar 接管', (tester) async {
    final text = List.generate(80, (i) => '第 $i 段：保留可編輯的完整提示詞。').join('\n');
    await open(tester, customText: text);
    expect(find.byType(AppScrollbar), findsOneWidget);
    expect(find.byType(RawScrollbar), findsNothing);
    final field = tester.widget<TextField>(find.byKey(_field));
    expect(field.scrollController!.position.maxScrollExtent, greaterThan(0));
    expect(
      find.byKey(const ValueKey('app-scrollbar-thumb')),
      findsOneWidget,
    );
    final before = field.scrollController!.offset;
    await tester.drag(find.byKey(_field), const Offset(0, -160));
    await tester.pumpAndSettle();
    expect(field.scrollController!.offset, greaterThan(before));
    expect(field.controller!.text, text);
    await tester.enterText(find.byKey(_field), '更新後仍可編輯');
    await tester.pumpAndSettle();
    expect(field.controller!.text, '更新後仍可編輯');
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
