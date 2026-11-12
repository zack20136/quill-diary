import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/ai/ai_catalog.dart';
import 'package:quill_diary/domain/ai/ai_connection_settings.dart';

void main() {
  test('擷取當時強度及完整參數對照，序列化不改動原設定', () {
    final original = defaultConnection(AiProvider.openai);
    final snapshot = original.captureRequestSnapshot();
    expect(original.thinkingOverrides, isEmpty);
    expect(snapshot.hasCompleteRequestSnapshot, isTrue);
    expect(snapshot.thinkingLevels[snapshot.model], AiThinkingLevel.off);
    for (final level in thinkingChoicesFor(original, original.model)) {
      expect(
        thinkingRequestFields(
          setThinkingLevel(snapshot, snapshot.model, level),
        ),
        thinkingRequestFields(
          setThinkingLevel(original, original.model, level),
        ),
      );
    }
    final restored = AiConnectionConfig.fromSnapshotJson(
      snapshot.toSnapshotJson(),
    );
    expect(restored.hasCompleteRequestSnapshot, isTrue);
    expect(thinkingRequestFields(restored), thinkingRequestFields(snapshot));
  });

  test('保存的 Thinking 參數不被目錄預設或 profile 重新解讀', () {
    final snapshot = AiConnectionConfig.fromSnapshotJson({
      'provider': AiProvider.claude.name,
      'default_model': 'claude-opus-5-5',
      'thinking_levels': {'claude-opus-5-5': 'off'},
      'thinking_overrides': {
        'claude-opus-5-5': {
          'default_level': 'off',
          'levels': {
            'off': {'saved_parameter': 7},
          },
        },
      },
    });
    expect(resolvedThinkingLevel(snapshot), AiThinkingLevel.off);
    expect(thinkingRequestFields(snapshot), {'saved_parameter': 7});
    expect(snapshot.toSnapshotJson()['thinking_overrides'], isNotNull);
  });

  for (final bad in [
    {
      'default_level': 'high',
      'levels': {'off': {}},
    },
    {
      'default_level': 'off',
      'levels': {'unknown': {}},
    },
    {
      'default_level': 'off',
      'levels': {
        'off': {'messages': []},
      },
    },
  ]) {
    test('快照損壞 Thinking 對照 $bad 拒讀，不回退目錄', () {
      expect(
        () => AiConnectionConfig.fromSnapshotJson({
          'provider': 'openai',
          'default_model': 'gpt-6.1-terra',
          'thinking_overrides': {'gpt-6.1-terra': bad},
        }),
        throwsA(anyOf(isA<FormatException>(), isA<ArgumentError>())),
      );
    });
  }

  test('舊快照解碼不擷取或回填目錄資訊', () {
    final old = AiConnectionConfig.fromSnapshotJson({
      'provider': 'openai',
      'default_model': 'gpt-6.1-terra',
    });
    expect(old.hasCompleteRequestSnapshot, isFalse);
    expect(old.toSnapshotJson().containsKey('thinking_overrides'), isFalse);
  });

  test('各供應商的思考欄位對應到該家 API 格式', () {
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
        provider: AiProvider.claude,
        model: 'claude-sonnet-5-5',
        level: AiThinkingLevel.high,
        fields: <String, Object?>{
          'thinking': {'type': 'between_tools'},
          'output_config': {'effort': 'high'},
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
        provider: AiProvider.xai,
        model: 'grok-4.3',
        level: AiThinkingLevel.high,
        fields: <String, Object?>{'reasoning_effort': 'high'},
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
    final restored = AiConnectionConfig.fromStoredJson(changed.toStoredJson());
    expect(restored.thinkingLevels, {original.model: AiThinkingLevel.high});
    expect(
      AiConnectionConfig.fromSnapshotJson(changed.toSnapshotJson())
          .thinkingLevels,
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
  });

  test('快照讀取不更新模型目錄，未知思考檔位拒讀', () {
    expect(
      () => AiConnectionConfig.fromSnapshotJson({
        'provider': 'openai',
        'default_model': 'gpt-6.1-terra',
        'thinking_levels': {'gpt-6.1-terra': 'unknown'},
      }),
      throwsArgumentError,
    );
  });
}
