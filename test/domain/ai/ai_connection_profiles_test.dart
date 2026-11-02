import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/ai/ai_catalog.dart';
import 'package:quill_diary/domain/ai/ai_connection_settings.dart';
import 'package:quill_diary/domain/ai/ai_model_thinking_override.dart';

void main() {
  const a = AiConnectionConfig(
    provider: AiProvider.custom,
    customConnectionId: 'aic_a',
    displayName: '工作',
    baseUrl: 'https://same.example/v1',
    model: 'same-model',
    addedModels: ['same-model'],
    enabledModels: ['same-model'],
  );
  final b = a.copyWith(customConnectionId: 'aic_b', displayName: '個人');

  test('同網址同模型的不同連線有各自金鑰，改名不改金鑰識別', () {
    expect(a.credentialId, isNot(b.credentialId));
    expect(a.copyWith(displayName: '改名').credentialId, a.credentialId);
    expect(
      a.copyWith(baseUrl: 'https://SAME.example/v1/').credentialId,
      a.credentialId,
    );
    expect(
      a.copyWith(baseUrl: 'https://other.example/v1').credentialId,
      isNot(a.credentialId),
    );
    expect(
      const AiConnectionConfig(
        provider: AiProvider.custom,
        baseUrl: 'https://same.example/v1',
      ).credentialId,
      'custom:https://same.example/v1',
    );
  });

  test('同名模型依連線區分，刪除後目前聊天仍保留原選項', () {
    final settings = AiConnectionSettings(
      activeConnectionId: a.connectionId,
      connections: {a.connectionId: a, b.connectionId: b},
    );
    final menu = chatModelMenu(
      settings: settings,
      chatConfig: a,
      hasApiKey: (_) => false,
    );
    expect(menu.models.map((m) => m.connectionId), ['aic_a', 'aic_b']);
    expect(menu.currentIsExtra, isFalse);
    final removed = AiConnectionSettings(
      activeConnectionId: b.connectionId,
      connections: {b.connectionId: b},
    );
    final next = chatModelMenu(
      settings: removed,
      chatConfig: a,
      hasApiKey: (_) => false,
    );
    expect(next.models.map((m) => m.connectionId), ['aic_b', 'aic_a']);
    expect(next.models.last.isCurrentSnapshot, isTrue);
    expect(next.models.last.connectionConfig, same(a));
  });

  test('同一連線變更目的地時，舊聊天保留不同的目前選項', () {
    final changed = a.copyWith(baseUrl: 'https://new.example/v1');
    final menu = chatModelMenu(
      settings: AiConnectionSettings(
        activeConnectionId: a.connectionId,
        connections: {a.connectionId: changed},
      ),
      chatConfig: a,
      hasApiKey: (_) => false,
    );
    expect(menu.models, hasLength(2));
    expect(
      menu.models.first.connectionConfig.effectiveBaseUrl,
      changed.effectiveBaseUrl,
    );
    expect(
      menu.models.last.connectionConfig.effectiveBaseUrl,
      a.effectiveBaseUrl,
    );
    expect(menu.currentIsExtra, isTrue);
  });

  test('連線集合往返，舊自訂保留識別且舊封存項目不再列入', () {
    final settings = AiConnectionSettings(
      activeConnectionId: b.connectionId,
      connections: {a.connectionId: a, b.connectionId: b},
    );
    final restored = AiConnectionSettings.fromJson(settings.toJson());
    expect(restored.activeConfig.connectionId, b.connectionId);
    expect(restored.connectionFor(a.connectionId).displayName, a.displayName);
    final withoutRemoved = AiConnectionSettings.fromJson({
      'active_connection_id': a.connectionId,
      'connections': {
        a.connectionId: {...a.toStoredJson(), 'archived': true},
        b.connectionId: b.toStoredJson(),
      },
    });
    expect(withoutRemoved.connections.containsKey(a.connectionId), isFalse);
    expect(withoutRemoved.activeConfig.connectionId, b.connectionId);
    final legacy = AiConnectionSettings.fromJson({
      'provider': 'custom',
      'configs': {
        'custom': {
          'provider': 'custom',
          'model': 'old',
          'base_url': 'https://old.example/v1',
        },
      },
    });
    expect(legacy.activeConfig.connectionId, 'custom');
    expect(legacy.activeConfig.credentialId, 'custom:https://old.example/v1');
    expect(legacy.toJson().containsKey('configs'), isFalse);
  });

  test('Thinking 對照保留 JSON 型別、巢狀合併與獨立快照', () {
    final fields = <String, Object?>{
      'generationConfig': <String, Object?>{
        'thinkingConfig': {'budget': 1024},
      },
      'think': true,
      'extra': [1, null, 'high'],
    };
    final override = AiModelThinkingOverride(
      defaultLevel: AiThinkingLevel.high,
      levels: {AiThinkingLevel.high: fields},
    );
    (fields['generationConfig']! as Map)['thinkingConfig'] = {'budget': 2};
    expect(
      (override.levels[AiThinkingLevel.high]!['generationConfig']!
          as Map)['thinkingConfig'],
      {'budget': 1024},
    );
    final config = a.copyWith(
      thinkingOverrides: {
        a.model: override,
        'unrelated': AiModelThinkingOverride.omit(),
      },
    );
    expect(thinkingChoicesFor(config, a.model), [AiThinkingLevel.high]);
    expect(resolvedThinkingLevel(config), AiThinkingLevel.high);
    final body = mergeThinkingRequestFields({
      'generationConfig': {'temperature': 0.5},
      'model': a.model,
    }, thinkingRequestFields(config));
    expect(body['generationConfig'], {
      'temperature': 0.5,
      'thinkingConfig': {'budget': 1024},
    });
    final snapshot = AiConnectionConfig.fromJson(config.toJson());
    expect(snapshot.thinkingOverrides.keys, [a.model]);
    expect(thinkingRequestFields(snapshot), thinkingRequestFields(config));
  });

  test('不傳送模式取代協定原欄位，手動對照保留自訂強度', () {
    final omitted = a.copyWith(
      thinkingOverrides: {a.model: AiModelThinkingOverride.omit()},
    );
    expect(thinkingRequestFields(omitted), isEmpty);
    expect(thinkingChoicesFor(omitted, a.model), isEmpty);
    final levels = a.copyWith(
      thinkingOverrides: {
        a.model: AiModelThinkingOverride(
          defaultLevel: AiThinkingLevel.low,
          levels: {
            AiThinkingLevel.low: {'think': 'low'},
            AiThinkingLevel.high: {'think': 'high'},
          },
        ),
      },
    );
    expect(
      thinkingRequestFields(
        setThinkingLevel(levels, a.model, AiThinkingLevel.high),
      ),
      {'think': 'high'},
    );
  });

  test('Thinking 拒絕非物件、訊息覆寫與無效預設', () {
    expect(() => parseThinkingObject('[]'), throwsFormatException);
    expect(() => parseThinkingObject('{bad'), throwsFormatException);
    for (final field in [
      'model',
      'messages',
      'input',
      'instructions',
      'contents',
      'system',
      'systemInstruction',
      'stream',
      'store',
    ]) {
      expect(
        () => AiModelThinkingOverride(
          defaultLevel: AiThinkingLevel.low,
          levels: {
            AiThinkingLevel.low: {field: null},
          },
        ),
        throwsFormatException,
        reason: field,
      );
    }
    expect(
      () => AiModelThinkingOverride(
        defaultLevel: AiThinkingLevel.high,
        levels: {AiThinkingLevel.low: {}},
      ),
      throwsFormatException,
    );
    expect(aiJsonEquals({'a': 1, 'b': true}, {'b': true, 'a': 1}), isTrue);
  });
}
