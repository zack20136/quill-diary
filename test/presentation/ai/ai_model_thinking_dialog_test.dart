import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/domain/ai/ai_catalog.dart';
import 'package:quill_diary/domain/ai/ai_connection_settings.dart';
import 'package:quill_diary/domain/ai/ai_model_thinking_override.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/ai/ai_model_thinking_dialog.dart';

import '../../helpers/shared/widget_test_app.dart';

void main() {
  const config = AiConnectionConfig(
    provider: AiProvider.custom,
    model: 'custom-model',
  );
  AiThinkingEditResult? result;
  Future<void> open(
    WidgetTester tester, {
    Locale locale = appZhLocale,
    Brightness brightness = Brightness.light,
    AiConnectionConfig connection = config,
  }) async {
    result = null;
    await tester.pumpWidget(
      widgetTestApp(
        locale: locale,
        brightness: brightness,
        child: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await showAiModelThinkingDialog(
                context,
                connection,
                connection.model,
              );
            },
            child: const Text('開啟'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('開啟'));
    await tester.pumpAndSettle();
  }

  Future<void> selectFormat(WidgetTester tester, String label) async {
    await tester.tap(find.byKey(const ValueKey('thinking-format')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(MenuItemButton, label));
    await tester.tap(find.widgetWithText(MenuItemButton, label));
    await tester.pumpAndSettle();
  }

  testWidgets('手動 JSON 直接顯示進階欄位，無效輸入可修正並保留原生型別', (tester) async {
    await open(tester);
    await selectFormat(tester, '手動 JSON');
    expect(find.byType(ExpansionTile), findsNothing);
    final low = find.byKey(const ValueKey('thinking-json-low'));
    await tester.ensureVisible(low);
    await tester.enterText(low, '{bad');
    await tester.tap(find.widgetWithText(FilledButton, '套用'));
    await tester.pumpAndSettle();
    expect(find.text('請輸入有效的 JSON 物件。'), findsOneWidget);
    expect(tester.widget<TextField>(low).controller!.text, '{bad');
    expect(result, isNull);
    await tester.enterText(low, '{"messages": []}');
    await tester.tap(find.widgetWithText(FilledButton, '套用'));
    await tester.pumpAndSettle();
    expect(find.text('只能填參數片段，不能覆寫模型、訊息或請求控制欄位。'), findsOneWidget);
    await tester.enterText(
      low,
      '{"think":"xhigh","extra":{"enabled":true,"budget":1024}}',
    );
    await tester.tap(find.widgetWithText(FilledButton, '套用'));
    await tester.pumpAndSettle();
    expect(result!.override!.levels[AiThinkingLevel.low], {
      'think': 'xhigh',
      'extra': {'enabled': true, 'budget': 1024},
    });
    expect(config.thinkingOverrides, isEmpty);
  });

  testWidgets('不傳送模式可套用，取消與沿用預設各自回傳不同結果', (tester) async {
    await open(tester);
    await selectFormat(tester, '不傳送 Thinking 參數');
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    await tester.tap(find.text('開啟'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '套用'));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.override, isNull);
    await tester.tap(find.text('開啟'));
    await tester.pumpAndSettle();
    await selectFormat(tester, '不傳送 Thinking 參數');
    await tester.tap(find.widgetWithText(FilledButton, '套用'));
    await tester.pumpAndSettle();
    expect(result!.override!.levels, isEmpty);
  });

  testWidgets('舊自訂對照原樣載入，切換三種模式保留尚未套用的 JSON', (tester) async {
    final existing = AiModelThinkingOverride(
      defaultLevel: AiThinkingLevel.low,
      levels: {
        AiThinkingLevel.low: {'think': 'low', 'budget': 1024},
        AiThinkingLevel.high: {'think': 'high'},
      },
    );
    await open(
      tester,
      connection: config.copyWith(thinkingOverrides: {config.model: existing}),
    );
    expect(find.text('手動 JSON'), findsOneWidget);
    expect(find.byType(ExpansionTile), findsNothing);
    final low = find.byKey(const ValueKey('thinking-json-low'));
    await tester.ensureVisible(low);
    expect(tester.widget<TextField>(low).controller!.text, contains('1024'));
    await tester.enterText(low, '{"think":"xhigh","extra":[true,null,2048]}');
    await tester.pumpAndSettle();
    for (final label in ['不傳送 Thinking 參數', '沿用目前協定', '手動 JSON']) {
      await tester.ensureVisible(find.byKey(const ValueKey('thinking-format')));
      await selectFormat(tester, label);
    }
    await tester.ensureVisible(low);
    expect(
      tester.widget<TextField>(low).controller!.text,
      '{"think":"xhigh","extra":[true,null,2048]}',
    );
    await tester.tap(find.widgetWithText(FilledButton, '套用'));
    await tester.pumpAndSettle();
    expect(result!.override!.levels[AiThinkingLevel.low], {
      'think': 'xhigh',
      'extra': [true, null, 2048],
    });
    expect(
      result!.override!.levels[AiThinkingLevel.high],
      existing.levels[AiThinkingLevel.high],
    );
  });

  testWidgets('只列三種格式，全部強度停用時保留輸入並提示有效預設', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('thinking-format')));
    await tester.pumpAndSettle();
    expect(find.byType(MenuItemButton), findsNWidgets(3));
    await tester.tap(find.widgetWithText(MenuItemButton, '手動 JSON'));
    await tester.pumpAndSettle();
    expect(find.byType(ExpansionTile), findsNothing);
    for (final level in AiThinkingLevel.values) {
      final toggle = find.byKey(ValueKey('thinking-enabled-${level.name}'));
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.widgetWithText(FilledButton, '套用'));
    await tester.pumpAndSettle();
    expect(find.text('至少啟用一個檔位，並選擇有效的預設強度。'), findsOneWidget);
    expect(result, isNull);
    expect(tester.takeException(), isNull);
  });

  for (final locale in [appZhLocale, appEnLocale]) {
    testWidgets('${locale.languageCode} 暗色窄畫面與大字級可編輯 Thinking', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(tester.view.resetViewInsets);
      final l10n = lookupAppLocalizations(locale);
      await open(tester, locale: locale, brightness: Brightness.dark);
      await selectFormat(tester, l10n.aiThinkingCustom);
      expect(find.byType(ExpansionTile), findsNothing);
      final low = find.byKey(const ValueKey('thinking-json-low'));
      await tester.ensureVisible(low);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.showKeyboard(low);
      await tester.enterText(low, '{"think":"low"}');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(
        find.widgetWithText(FilledButton, l10n.commonActionApply),
      );
      await tester.pumpAndSettle();
      expect(result!.override!.levels[AiThinkingLevel.low], {'think': 'low'});
    });
  }
}
