import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/ai/ai_connection_settings.dart';

void main() {
  test('目錄預設屬於允許的思考強度，固定模型不顯示選單', () {
    for (final provider in aiCatalogProviders) {
      for (final model
          in aiModelCatalog[provider] ?? const <AiCatalogModel>[]) {
        final config = AiConnectionConfig(provider: provider, model: model.id);
        expect(resolvedThinkingLevel(config), model.defaultThinking);
        if (model.thinkingFixed) {
          expect(thinkingChoicesFor(config, model.id), isEmpty);
        } else {
          expect(
            thinkingChoicesFor(config, model.id),
            contains(model.defaultThinking),
          );
        }
      }
    }
  });

  test('各模型套用自己的思考欄位，固定非推理模型省略參數', () {
    final examples = [
      (
        provider: AiProvider.openai,
        model: 'gpt-6.1-terra',
        level: AiThinkingLevel.off,
        fields: <String, Object?>{
          'reasoning': {'effort': 'none'},
        },
      ),
      (
        provider: AiProvider.openai,
        model: 'gpt-6.1-sol',
        level: AiThinkingLevel.off,
        fields: <String, Object?>{
          'reasoning': {'effort': 'low'},
        },
      ),
      (
        provider: AiProvider.claude,
        model: 'claude-sonnet-5-5',
        level: AiThinkingLevel.high,
        fields: <String, Object?>{
          'thinking': {'type': 'between_tools'},
          'output_config': {'effort': 'high'},
        },
      ),
      (
        provider: AiProvider.claude,
        model: 'claude-haiku-5-5',
        level: AiThinkingLevel.off,
        fields: <String, Object?>{
          'thinking': {'type': 'disabled'},
          'output_config': {'effort': 'low'},
        },
      ),
      (
        provider: AiProvider.claude,
        model: 'claude-opus-5-5',
        level: AiThinkingLevel.medium,
        fields: <String, Object?>{
          'output_config': {'effort': 'medium'},
        },
      ),
      (
        provider: AiProvider.gemini,
        model: 'gemini-3.8-flash',
        level: AiThinkingLevel.high,
        fields: <String, Object?>{
          'generationConfig': {
            'thinkingConfig': {'thinkingLevel': 'high'},
          },
        },
      ),
      (
        provider: AiProvider.gemini,
        model: 'gemini-3.5-flash-lite',
        level: AiThinkingLevel.off,
        fields: <String, Object?>{
          'generationConfig': {
            'thinkingConfig': {'thinkingLevel': 'minimal'},
          },
        },
      ),
      (
        provider: AiProvider.xai,
        model: 'grok-4.3',
        level: AiThinkingLevel.high,
        fields: <String, Object?>{'reasoning_effort': 'high'},
      ),
      (
        provider: AiProvider.xai,
        model: 'grok-4.7',
        level: AiThinkingLevel.off,
        fields: <String, Object?>{'reasoning_effort': 'low'},
      ),
      (
        provider: AiProvider.xai,
        model: 'grok-4.20-non-reasoning',
        level: AiThinkingLevel.high,
        fields: <String, Object?>{},
      ),
    ];
    for (final example in examples) {
      final config = AiConnectionConfig(
        provider: example.provider,
        model: example.model,
        thinkingLevels: {example.model: example.level},
      );
      expect(
        thinkingRequestFields(config),
        example.fields,
        reason: example.model,
      );
    }
  });

  test('思考覆寫依模型保存，還原預設會移除覆寫，無效選項保持原值', () {
    final original = defaultConnection(AiProvider.openai);
    final changed = setThinkingLevel(
      original,
      original.model,
      AiThinkingLevel.high,
    );
    final restored = AiConnectionConfig.fromJson(changed.toStoredJson());
    expect(restored.thinkingLevels, {original.model: AiThinkingLevel.high});
    expect(
      AiConnectionConfig.fromJson(changed.toJson()).thinkingLevels,
      restored.thinkingLevels,
    );
    expect(
      setThinkingLevel(
        changed,
        original.model,
        AiThinkingLevel.off,
      ).thinkingLevels,
      isEmpty,
    );
    expect(
      setThinkingLevel(changed, 'gpt-6.1-sol', AiThinkingLevel.off),
      same(changed),
    );
    final fixed = defaultConnection(AiProvider.xai)
        .copyWith(model: 'grok-4.20-non-reasoning');
    expect(
      setThinkingLevel(fixed, fixed.model, AiThinkingLevel.high),
      same(fixed),
    );
  });

  test('舊資料缺少思考設定時使用預設，未知值與無模型引用會略過', () {
    final restored = AiConnectionConfig.fromJson({
      'provider': 'openai',
      'model': 'gpt-6.1-terra',
      'thinking_levels': {
        'gpt-6.1-terra': 'unknown',
        'removed': 'high',
        '': 'low',
      },
    });
    expect(restored.thinkingLevels, isEmpty);
    expect(resolvedThinkingLevel(restored), AiThinkingLevel.off);
  });
}
