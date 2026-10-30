import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/ai/ai_connection_settings.dart';

void main() {
  test('舊設定只有模型名稱時，把它當成唯一打開的預設', () {
    final AiConnectionConfig builtin = AiConnectionConfig.fromJson({
      'provider': 'openai',
      'model': 'gpt-6.1-terra',
      'base_url': '',
      'workspace_id': '',
      'custom_protocol': 'chatCompletions',
    });
    expect(builtin.model, 'gpt-6.1-terra');
    expect(builtin.addedModels, isEmpty);
    expect(builtin.enabledModels, ['gpt-6.1-terra']);

    final AiConnectionConfig manual = AiConnectionConfig.fromJson({
      'provider': 'openai',
      'model': 'gpt-4.1',
    });
    expect(manual.model, 'gpt-4.1');
    expect(manual.addedModels, ['gpt-4.1']);
    expect(manual.enabledModels, ['gpt-4.1']);
  });

  test('舊清單裡的寫死名稱只記成打開，不放進手動加入', () {
    final AiConnectionConfig config = AiConnectionConfig.fromJson({
      'provider': 'openai',
      'model': 'gpt-6.1-sol',
      'listed_models': ['gpt-6.1-terra', 'gpt-6.1-sol', 'kept-model'],
      'enabled_models': ['gpt-6.1-sol', 'kept-model'],
      'custom_protocol': 'responses',
    });

    expect(config.model, 'gpt-6.1-sol');
    expect(config.addedModels, ['kept-model']);
    expect(config.enabledModels, ['gpt-6.1-sol', 'kept-model']);
    expect(config.catalog, [
      ...builtinModelsFor(AiProvider.openai),
      'kept-model',
    ]);
  });

  test('設定檔只寫有意義的欄位，聊天快照不帶清單', () {
    const AiConnectionConfig official = AiConnectionConfig(
      provider: AiProvider.claude,
      model: 'claude-opus-5-5',
      enabledModels: ['claude-opus-5-5'],
    );
    expect(official.toStoredJson(), {
      'provider': 'claude',
      'default_model': 'claude-opus-5-5',
      'enabled_models': ['claude-opus-5-5'],
      'added_models': <String>[],
      'known_builtin_models': builtinModelsFor(AiProvider.claude),
    });
    expect(official.toJson().keys, ['provider', 'default_model']);

    const AiConnectionConfig custom = AiConnectionConfig(
      provider: AiProvider.custom,
      model: 'google/gemma-4-26b',
      baseUrl: 'https://openrouter.ai/api/v1',
      customProtocol: AiApiProtocol.chatCompletions,
      addedModels: ['google/gemma-4-26b'],
      enabledModels: ['google/gemma-4-26b'],
      workspaceId: '  ',
    );
    expect(custom.toStoredJson().containsKey('workspace_id'), isFalse);
    expect(custom.toStoredJson()['known_builtin_models'], isEmpty);
    expect(custom.toJson(), {
      'provider': 'custom',
      'default_model': 'google/gemma-4-26b',
      'base_url': 'https://openrouter.ai/api/v1',
      'protocol': 'chatCompletions',
    });
    expect(AiConnectionConfig.fromJson(custom.toStoredJson()).addedModels, [
      'google/gemma-4-26b',
    ]);
  });

  test('加入時去掉空白，重複的名稱改成打開而不多一列', () {
    const AiConnectionConfig config = AiConnectionConfig(
      provider: AiProvider.openai,
    );
    final AiConnectionConfig added = addModel(config, '  kept-model  ');
    expect(added.addedModels, ['kept-model']);
    expect(added.enabledModels, ['kept-model']);
    expect(added.model, 'kept-model');

    final AiConnectionConfig off = setModelEnabled(
      added,
      'kept-model',
      enabled: false,
    );
    final AiConnectionConfig again = addModel(off, 'kept-model');
    expect(again.addedModels, ['kept-model']);
    expect(again.enabledModels, ['kept-model']);

    final AiConnectionConfig builtin = addModel(config, ' gpt-6-luna ');
    expect(builtin.addedModels, isEmpty);
    expect(builtin.enabledModels, ['gpt-6-luna']);
    expect(builtin.model, 'gpt-6-luna');
    expect(addModel(builtin, '   '), builtin);
  });

  test('關掉或移除預設時改指到下一個打開的模型，寫死的列不能刪', () {
    const AiConnectionConfig config = AiConnectionConfig(
      provider: AiProvider.openai,
      model: 'gpt-6.1-terra',
      addedModels: ['extra'],
      enabledModels: ['gpt-6.1-terra', 'gpt-6.1-sol', 'extra'],
    );

    final AiConnectionConfig next = setModelEnabled(
      config,
      'gpt-6.1-terra',
      enabled: false,
    );
    expect(next.model, 'gpt-6.1-sol');
    expect(next.catalog, contains('gpt-6.1-terra'));

    final AiConnectionConfig kept = removeAddedModel(next, 'gpt-6.1-sol');
    expect(kept.addedModels, ['extra']);
    expect(kept.model, 'gpt-6.1-sol');

    final AiConnectionConfig removed = removeAddedModel(config, 'extra');
    expect(removed.addedModels, isEmpty);
    expect(removed.model, 'gpt-6.1-terra');

    final AiConnectionConfig cleared = removeAddedModel(
      AiConnectionConfig(
        provider: AiProvider.custom,
        model: 'only',
        baseUrl: 'https://example.com/v1',
        addedModels: const ['only'],
        enabledModels: const ['only'],
      ),
      'only',
    );
    expect(cleared.addedModels, isEmpty);
    expect(cleared.enabledModels, isEmpty);
    expect(cleared.model, '');
    expect(cleared.toStoredJson()['added_models'], isEmpty);
  });

  test('聊天選單讀設定，這一則正在用但已關閉的名稱留在最後', () {
    const AiConnectionConfig stored = AiConnectionConfig(
      provider: AiProvider.custom,
      model: 'default-model',
      baseUrl: 'https://openrouter.ai/api/v1',
      addedModels: ['default-model', 'hidden-model'],
      enabledModels: ['default-model'],
    );
    final AiConnectionSettings settings = AiConnectionSettings(
      provider: AiProvider.custom,
      configs: {AiProvider.custom: stored},
    );
    final menu = chatModelMenu(
      settings: settings,
      chatConfig: stored.copyWith(model: 'hidden-model'),
      hasApiKey: (_) => false,
    );

    expect(menu.models.map((ChatModelOption option) => option.modelId), [
      'default-model',
      'hidden-model',
    ]);
    expect(
      menu.models.every((option) => option.provider == AiProvider.custom),
      isTrue,
    );
    expect(menu.currentIsExtra, isTrue);
  });

  test('還沒存過才套預設開啟，存過且全關就維持關閉', () {
    expect(defaultConnection(AiProvider.openai).enabledModels, [
      'gpt-6.1-terra',
    ]);
    expect(defaultConnection(AiProvider.claude).model, 'claude-sonnet-5-5');
    expect(defaultConnection(AiProvider.xai).model, 'grok-4.3');
    expect(defaultConnection(AiProvider.gemini).model, 'gemini-3.8-flash');
    expect(defaultConnection(AiProvider.custom).enabledModels, isEmpty);

    const AiConnectionConfig saved = AiConnectionConfig(
      provider: AiProvider.openai,
    );
    expect(normalizeModelCatalog(saved).enabledModels, isEmpty);
    expect(normalizeModelCatalog(saved).model, isEmpty);
  });

  test('舊檔沒有 known 時開關不變，新的預設開啟 id 才打開', () {
    const AiConnectionConfig unseen = AiConnectionConfig(
      provider: AiProvider.openai,
      model: 'gpt-6.1-sol',
      enabledModels: ['gpt-6.1-sol'],
    );
    final AiConnectionConfig frozen = adoptCatalogModels(unseen);
    expect(frozen.enabledModels, ['gpt-6.1-sol']);
    expect(frozen.model, 'gpt-6.1-sol');
    expect(frozen.knownBuiltinModels, builtinModelsFor(AiProvider.openai));

    final AiConnectionConfig partial = adoptCatalogModels(
      frozen.copyWith(knownBuiltinModels: const ['gpt-6.1-sol']),
    );
    expect(partial.enabledModels, contains('gpt-6.1-terra'));
    expect(partial.enabledModels, isNot(contains('gpt-6-luna')));
    expect(partial.model, 'gpt-6.1-sol');
    expect(partial.knownBuiltinModels, builtinModelsFor(AiProvider.openai));

    final AiConnectionConfig keptOff = adoptCatalogModels(
      AiConnectionConfig(
        provider: AiProvider.openai,
        knownBuiltinModels: builtinModelsFor(AiProvider.openai),
      ),
    );
    expect(keptOff.enabledModels, isEmpty);
    expect(keptOff.model, isEmpty);

    final settings = adoptConnectionCatalog(
      AiConnectionSettings(configs: {AiProvider.openai: unseen}),
    );
    expect(settings.writeBack, isTrue);
    expect(adoptConnectionCatalog(settings.settings).writeBack, isFalse);
  });

  test('移除唯一啟用的舊官方模型時採用新預設，後續讀取不再變動', () {
    final adopted = adoptConnectionCatalog(
      const AiConnectionSettings(
        configs: {
          AiProvider.openai: AiConnectionConfig(
            provider: AiProvider.openai,
            model: 'gpt-5.6-sol',
            enabledModels: ['gpt-5.6-sol'],
            knownBuiltinModels: ['gpt-5.6-sol', 'gpt-6.1-terra'],
          ),
        },
      ),
    );
    expect(adopted.writeBack, isTrue);
    final next = adopted.settings.configFor(AiProvider.openai);
    expect(next.model, 'gpt-6.1-terra');
    expect(next.enabledModels, ['gpt-6.1-terra']);
    expect(next.addedModels, isEmpty);
    expect(adoptConnectionCatalog(adopted.settings).writeBack, isFalse);
  });

  test('移除舊官方模型時保留其他啟用模型及自訂名稱', () {
    for (final remaining in ['gpt-6-luna', 'manual-model']) {
      final next = adoptCatalogModels(
        AiConnectionConfig(
          provider: AiProvider.openai,
          model: 'gpt-5.6-sol',
          addedModels: const ['manual-model'],
          enabledModels: ['gpt-5.6-sol', remaining],
          knownBuiltinModels: [
            'gpt-5.6-sol',
            ...builtinModelsFor(AiProvider.openai),
          ],
        ),
      );
      expect(next.model, remaining);
      expect(next.enabledModels, [remaining]);
      expect(next.addedModels, ['manual-model']);
    }
  });

  test('明確全部關閉不因官方模型移除而重新開啟', () {
    final next = adoptCatalogModels(
      AiConnectionConfig(
        provider: AiProvider.openai,
        knownBuiltinModels: [
          'gpt-5.6-sol',
          ...builtinModelsFor(AiProvider.openai),
        ],
      ),
    );
    expect(next.enabledModels, isEmpty);
    expect(next.model, isEmpty);
  });

  test('舊名稱沒有官方來源記錄時保留為手動模型', () {
    final restored = AiConnectionConfig.fromJson({
      'provider': 'openai',
      'model': 'gpt-5.6-sol',
    });
    expect(restored.model, 'gpt-5.6-sol');
    expect(restored.addedModels, ['gpt-5.6-sol']);
    expect(adoptCatalogModels(restored).enabledModels, ['gpt-5.6-sol']);
  });

  test('清除失去模型引用的思考設定時會回寫且只做一次', () {
    final current = defaultConnection(
      AiProvider.openai,
    ).copyWith(thinkingLevels: const {'removed-model': AiThinkingLevel.high});
    final adopted = adoptConnectionCatalog(
      AiConnectionSettings(configs: {AiProvider.openai: current}),
    );
    expect(adopted.writeBack, isTrue);
    expect(
      adopted.settings.configFor(AiProvider.openai).thinkingLevels,
      isEmpty,
    );
    expect(adoptConnectionCatalog(adopted.settings).writeBack, isFalse);
  });

  test('有金鑰才把官方模型放進聊天選單', () {
    final AiConnectionConfig openai = defaultConnection(AiProvider.openai);
    final menu = chatModelMenu(
      settings: AiConnectionSettings(configs: {AiProvider.openai: openai}),
      chatConfig: openai,
      hasApiKey: (AiProvider provider) => provider == AiProvider.openai,
    );

    expect(menu.models, hasLength(1));
    expect(menu.models.single.provider, AiProvider.openai);
    expect(menu.models.single.modelId, 'gpt-6.1-terra');
    expect(menu.currentIsExtra, isFalse);
  });
}
