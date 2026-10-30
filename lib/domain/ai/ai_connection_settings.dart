import 'package:quill_diary/domain/ai/ai_catalog.dart';

export 'package:quill_diary/domain/ai/ai_catalog.dart';

enum AiApiProtocol {
  chatCompletions,
  responses,
  claudeMessages,
  geminiContent,
  ollamaChat,
}

extension AiApiProtocolDetails on AiApiProtocol {
  String get pathPrefix => switch (this) {
    AiApiProtocol.chatCompletions => '',
    AiApiProtocol.responses || AiApiProtocol.claudeMessages => '/v1',
    AiApiProtocol.geminiContent => '/v1beta',
    AiApiProtocol.ollamaChat => '/api',
  };
}

extension AiProviderDetails on AiProvider {
  String get defaultBaseUrl => switch (this) {
    AiProvider.openai => 'https://api.openai.com',
    AiProvider.claude => 'https://api.anthropic.com',
    AiProvider.gemini => 'https://generativelanguage.googleapis.com',
    AiProvider.xai => 'https://api.x.ai/v1',
    AiProvider.custom => '',
  };

  bool get requiresApiKey => switch (this) {
    AiProvider.openai ||
    AiProvider.claude ||
    AiProvider.gemini ||
    AiProvider.xai => true,
    _ => false,
  };
  bool get hasCustomUrl => this == AiProvider.custom;
}

/// 還沒存過的供應商：只打開目錄裡標成預設的模型。
AiConnectionConfig defaultConnection(AiProvider provider) {
  final List<String> enabled = [
    for (final AiCatalogModel model in aiModelCatalog[provider] ?? const [])
      if (model.enabledByDefault) model.id,
  ];
  return AiConnectionConfig(
    provider: provider,
    model: enabled.isEmpty ? '' : enabled.first,
    enabledModels: enabled,
    knownBuiltinModels: [
      for (final AiCatalogModel model in aiModelCatalog[provider] ?? const [])
        model.id,
    ],
  );
}

/// 官方要有金鑰，自訂要有網址，才會出現在聊天選單。
bool chatProviderCanList(AiConnectionConfig config, {required bool hasApiKey}) {
  if (config.effectiveBaseUrl.isEmpty) return false;
  if (config.provider.requiresApiKey) return hasApiKey;
  return true;
}

class ChatModelOption {
  const ChatModelOption({required this.provider, required this.modelId});

  final AiProvider provider;
  final String modelId;
}

class AiConnectionConfig {
  const AiConnectionConfig({
    required this.provider,
    this.model = '',
    this.baseUrl = '',
    this.workspaceId = '',
    this.customProtocol = AiApiProtocol.chatCompletions,
    this.addedModels = const [],
    this.enabledModels = const [],
    this.knownBuiltinModels,
    this.thinkingLevels = const {},
  });

  final AiProvider provider;

  /// 下一則新聊天使用的模型。聊天室選模型時寫回這裡。
  final String model;
  final String baseUrl;
  final String workspaceId;
  final AiApiProtocol customProtocol;

  /// 手動加入的模型 id，依加入順序。寫死名稱不放在這裡。
  final List<String> addedModels;

  /// 會出現在聊天選單的 id，含打開的寫死名稱與手動名稱。
  final List<String> enabledModels;

  /// 這個供應商已經看過的目錄 id。null 表示舊檔還沒記過，讀取時只補記、不改開關。
  final List<String>? knownBuiltinModels;

  /// 使用者改過、而且和目錄預設不同的思考強度。鍵是模型 id。
  final Map<String, AiThinkingLevel> thinkingLevels;

  AiApiProtocol get protocol => switch (provider) {
    AiProvider.openai => AiApiProtocol.responses,
    AiProvider.claude => AiApiProtocol.claudeMessages,
    AiProvider.gemini => AiApiProtocol.geminiContent,
    AiProvider.xai => AiApiProtocol.chatCompletions,
    AiProvider.custom => customProtocol,
  };

  String get effectiveBaseUrl => provider.hasCustomUrl
      ? baseUrl.trim().replaceFirst(RegExp(r'/+$'), '')
      : provider.defaultBaseUrl;
  bool get isConfigured =>
      model.trim().isNotEmpty && effectiveBaseUrl.isNotEmpty;

  String get credentialId {
    if (!provider.hasCustomUrl) {
      return provider.name;
    }
    final uri = Uri.tryParse(effectiveBaseUrl);
    final normalized = uri == null || !uri.hasAuthority
        ? effectiveBaseUrl
        : uri
              .normalizePath()
              .replace(
                scheme: uri.scheme.toLowerCase(),
                host: uri.host.toLowerCase(),
              )
              .toString()
              .replaceFirst(RegExp(r'/+$'), '');
    return '${provider.name}:$normalized';
  }

  /// 畫面上這個提供商的模型：寫死名稱在前，手動加入的接在後面。
  List<String> get catalog {
    final List<String> builtins = builtinModelsFor(provider);
    return [
      ...builtins,
      for (final String id in addedModels)
        if (!builtins.contains(id)) id,
    ];
  }

  bool isBuiltinModel(String modelId) =>
      builtinModelsFor(provider).contains(modelId);

  AiConnectionConfig copyWith({
    String? model,
    String? baseUrl,
    String? workspaceId,
    AiApiProtocol? customProtocol,
    List<String>? addedModels,
    List<String>? enabledModels,
    Object? knownBuiltinModels = _keepKnown,
    Map<String, AiThinkingLevel>? thinkingLevels,
  }) => AiConnectionConfig(
    provider: provider,
    model: model ?? this.model,
    baseUrl: baseUrl ?? this.baseUrl,
    workspaceId: workspaceId ?? this.workspaceId,
    customProtocol: customProtocol ?? this.customProtocol,
    addedModels: addedModels ?? this.addedModels,
    enabledModels: enabledModels ?? this.enabledModels,
    knownBuiltinModels: identical(knownBuiltinModels, _keepKnown)
        ? this.knownBuiltinModels
        : knownBuiltinModels as List<String>?,
    thinkingLevels: thinkingLevels ?? this.thinkingLevels,
  );

  /// 送出這一則需要的連線。不帶模型清單。
  Map<String, Object?> toJson() => _connectionJson(this, includeCatalog: false);

  /// 設定檔裡的連線。含下一則要使用的模型、打開的名稱與手動加入的名稱。
  Map<String, Object?> toStoredJson() =>
      _connectionJson(adoptCatalogModels(this), includeCatalog: true);

  factory AiConnectionConfig.fromJson(Map<String, dynamic> json) =>
      normalizeModelCatalog(_connectionConfigFromJson(json));
}

const Object _keepKnown = Object();

AiConnectionConfig _connectionConfigFromJson(Map<String, dynamic> json) {
  final AiProvider provider = AiProvider.values.byName(
    json['provider'] as String,
  );
  final String model =
      ((json['default_model'] ?? json['model']) as String? ?? '').trim();
  final bool stored =
      json.containsKey('added_models') ||
      (json.containsKey('default_model') && json.containsKey('enabled_models'));
  final List<String> added;
  final List<String> enabled;
  if (stored) {
    added = _modelNames(json['added_models']);
    enabled = _modelNames(json['enabled_models']);
  } else if (json.containsKey('listed_models') ||
      json.containsKey('enabled_models')) {
    final List<String> listed = _modelNames(json['listed_models']);
    final List<String> oldEnabled = _modelNames(json['enabled_models'])
        .where(listed.toSet().contains)
        .toList();
    added = listed.isEmpty && oldEnabled.isEmpty ? const [] : listed;
    enabled = listed.isEmpty && oldEnabled.isEmpty ? const [] : oldEnabled;
  } else {
    added = const [];
    enabled = const [];
  }
  return AiConnectionConfig(
    provider: provider,
    model: model,
    baseUrl: json['base_url'] as String? ?? '',
    workspaceId: json['workspace_id'] as String? ?? '',
    customProtocol: AiApiProtocol.values.byName(
      json['protocol'] as String? ??
          json['custom_protocol'] as String? ??
          'chatCompletions',
    ),
    addedModels: added,
    enabledModels: enabled,
    knownBuiltinModels: json.containsKey('known_builtin_models')
        ? _modelNames(json['known_builtin_models'])
        : null,
    thinkingLevels: _thinkingLevels(json['thinking_levels']),
  );
}

Map<String, AiThinkingLevel> _thinkingLevels(Object? value) {
  if (value is! Map) return const {};
  final Map<String, AiThinkingLevel> levels = {};
  for (final MapEntry<Object?, Object?> entry in value.entries) {
    final Object? key = entry.key;
    final Object? level = entry.value;
    if (key is! String || level is! String) continue;
    final String id = key.trim();
    if (id.isEmpty) continue;
    for (final AiThinkingLevel choice in AiThinkingLevel.values) {
      if (choice.name == level) levels[id] = choice;
    }
  }
  return levels;
}

Map<String, AiThinkingLevel> _keptThinking(
  Map<String, AiThinkingLevel> levels,
  List<String> catalog,
) {
  final Set<String> allowed = catalog.toSet();
  return {
    for (final MapEntry<String, AiThinkingLevel> entry in levels.entries)
      if (allowed.contains(entry.key)) entry.key: entry.value,
  };
}

bool _sameThinking(
  Map<String, AiThinkingLevel> left,
  Map<String, AiThinkingLevel> right,
) {
  if (left.length != right.length) return false;
  for (final MapEntry<String, AiThinkingLevel> entry in left.entries) {
    if (right[entry.key] != entry.value) return false;
  }
  return true;
}

List<String> _modelNames(Object? value) {
  if (value is! List) return const [];
  final List<String> names = [];
  final Set<String> seen = {};
  for (final Object? item in value) {
    if (item is! String) continue;
    final String name = item.trim();
    if (name.isEmpty || !seen.add(name)) continue;
    names.add(name);
  }
  return names;
}

bool _sameNames(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

Map<String, Object?> _connectionJson(
  AiConnectionConfig config, {
  required bool includeCatalog,
}) => {
  'provider': config.provider.name,
  'default_model': config.model.trim(),
  if (includeCatalog) ...{
    'enabled_models': config.enabledModels,
    'added_models': config.addedModels,
    'known_builtin_models': config.knownBuiltinModels ?? const <String>[],
  },
  if (config.thinkingLevels.isNotEmpty)
    'thinking_levels': {
      for (final MapEntry<String, AiThinkingLevel> entry
          in config.thinkingLevels.entries)
        entry.key: entry.value.name,
    },
  if (config.provider == AiProvider.custom) ...{
    'base_url': config.baseUrl,
    'protocol': config.customProtocol.name,
  },
  if (config.workspaceId.trim().isNotEmpty)
    'workspace_id': config.workspaceId.trim(),
};

List<String> _enabledInOrder(List<String> catalog, Iterable<String> enabled) {
  final Set<String> on = enabled.toSet();
  return [
    for (final String id in catalog)
      if (on.contains(id)) id,
  ];
}

/// 關掉或移除預設時，改指到清單裡下一個還開著的模型。
String _nextEnabled(
  List<String> catalog,
  List<String> enabled,
  String removed,
) {
  final int index = catalog.indexOf(removed);
  for (var cursor = index + 1; cursor < catalog.length; cursor++) {
    if (enabled.contains(catalog[cursor])) return catalog[cursor];
  }
  for (final String id in enabled) {
    if (id != removed) return id;
  }
  return '';
}

/// 寫死名稱留在程式清單。沒有清單的舊資料，那個模型就是唯一打開的預設。
AiConnectionConfig normalizeModelCatalog(AiConnectionConfig config) {
  final List<String> builtins = builtinModelsFor(config.provider);
  final List<String> added = _modelNames(config.addedModels)
      .where((String id) => !builtins.contains(id))
      .toList();
  List<String> enabled = _modelNames(config.enabledModels);
  String model = config.model.trim();
  if (added.isEmpty && enabled.isEmpty && model.isNotEmpty) {
    if (!builtins.contains(model)) added.add(model);
    enabled = [model];
  }
  final List<String> catalog = [...builtins, ...added];
  enabled = _enabledInOrder(catalog, enabled);
  if (model.isNotEmpty && !enabled.contains(model)) {
    model = enabled.isEmpty ? '' : enabled.first;
  }
  final Map<String, AiThinkingLevel> thinking = _keptThinking(
    config.thinkingLevels,
    catalog,
  );
  if (model == config.model &&
      _sameNames(added, config.addedModels) &&
      _sameNames(enabled, config.enabledModels) &&
      _sameThinking(thinking, config.thinkingLevels)) {
    return config;
  }
  return config.copyWith(
    model: model,
    addedModels: added,
    enabledModels: enabled,
    thinkingLevels: thinking,
  );
}

/// 舊檔只補記目前目錄。之後新增的 id 才套預設開關；已經看過的維持使用者的選擇。
/// 若刪掉的官方模型原本開著，而且刪完沒有任何還開著的模型，才改開新的預設。
AiConnectionConfig adoptCatalogModels(AiConnectionConfig config) {
  final List<AiCatalogModel> models =
      aiModelCatalog[config.provider] ?? const [];
  final List<String> current = [
    for (final AiCatalogModel model in models) model.id,
  ];
  final Set<String> currentSet = current.toSet();
  final Set<String> added = _modelNames(config.addedModels)
      .where((String id) => !currentSet.contains(id))
      .toSet();
  final List<String>? known = config.knownBuiltinModels;
  final List<String> enabled = [..._modelNames(config.enabledModels)];
  final Set<String> removed = known == null
      ? {
          for (final String id in enabled)
            if (!currentSet.contains(id) && !added.contains(id)) id,
        }
      : known.where((String id) => !currentSet.contains(id)).toSet();
  if (known != null) {
    final Set<String> seen = known.toSet();
    for (final AiCatalogModel model in models) {
      if (seen.contains(model.id)) continue;
      if (model.enabledByDefault && !enabled.contains(model.id)) {
        enabled.add(model.id);
      }
    }
  }
  final bool hadEnabledRemoved = enabled.any(removed.contains);
  final bool officialLeft = enabled.any(currentSet.contains);
  final bool manualLeft = enabled.any(
    (String id) => added.contains(id) && !removed.contains(id),
  );
  if (hadEnabledRemoved && !officialLeft && !manualLeft) {
    for (final AiCatalogModel model in models) {
      if (model.enabledByDefault && !enabled.contains(model.id)) {
        enabled.add(model.id);
      }
    }
  }
  return normalizeModelCatalog(
    config.copyWith(knownBuiltinModels: current, enabledModels: enabled),
  );
}

/// 設定檔讀取後，若目錄有新 id 或還沒記過看過的名稱，回傳要寫回的設定。
({AiConnectionSettings settings, bool writeBack}) adoptConnectionCatalog(
  AiConnectionSettings settings,
) {
  var writeBack = false;
  final Map<AiProvider, AiConnectionConfig> configs = {};
  for (final MapEntry<AiProvider, AiConnectionConfig> entry
      in settings.configs.entries) {
    final AiConnectionConfig next = adoptCatalogModels(entry.value);
    final List<String>? known = entry.value.knownBuiltinModels;
    if (known == null ||
        !_sameNames(known, next.knownBuiltinModels ?? const []) ||
        !_sameNames(entry.value.addedModels, next.addedModels) ||
        !_sameNames(entry.value.enabledModels, next.enabledModels) ||
        !_sameThinking(entry.value.thinkingLevels, next.thinkingLevels) ||
        entry.value.model != next.model) {
      writeBack = true;
    }
    configs[entry.key] = next;
  }
  if (!writeBack) return (settings: settings, writeBack: false);
  return (
    settings: AiConnectionSettings(
      provider: settings.provider,
      configs: configs,
    ),
    writeBack: true,
  );
}

/// 這一列可以選的思考強度。空清單表示不顯示選單。
List<AiThinkingLevel> thinkingChoicesFor(
  AiConnectionConfig config,
  String modelId,
) {
  final AiCatalogModel? model = catalogModelFor(
    config.provider,
    modelId.trim(),
  );
  if (model != null) {
    return model.thinkingFixed ? const [] : model.thinkingChoices;
  }
  return _protocolThinkingChoices(config.protocol);
}

/// 請求實際使用的強度。沒改過就用目錄或協定的預設。
AiThinkingLevel resolvedThinkingLevel(
  AiConnectionConfig config, [
  String? modelId,
]) {
  final String id = (modelId ?? config.model).trim();
  final AiCatalogModel? model = catalogModelFor(config.provider, id);
  if (model?.thinkingFixed == true) return model!.defaultThinking;
  final List<AiThinkingLevel> choices = thinkingChoicesFor(config, id);
  final AiThinkingLevel? stored = config.thinkingLevels[id];
  if (stored != null && choices.contains(stored)) return stored;
  if (model != null) return model.defaultThinking;
  return _protocolDefaultThinking(config.protocol);
}

AiConnectionConfig setThinkingLevel(
  AiConnectionConfig config,
  String modelId,
  AiThinkingLevel level,
) {
  final String id = modelId.trim();
  final List<AiThinkingLevel> choices = thinkingChoicesFor(config, id);
  if (id.isEmpty || !choices.contains(level)) return config;
  final Map<String, AiThinkingLevel> next = Map.of(config.thinkingLevels);
  final AiCatalogModel? model = catalogModelFor(config.provider, id);
  final AiThinkingLevel fallback =
      model?.defaultThinking ?? _protocolDefaultThinking(config.protocol);
  if (level == fallback) {
    next.remove(id);
  } else {
    next[id] = level;
  }
  return config.copyWith(thinkingLevels: next);
}

/// 依官方模型或自訂協定，產生要併進請求本文的欄位。不該送的模型回傳空。
Map<String, Object?> thinkingRequestFields(AiConnectionConfig config) {
  final String id = config.model.trim();
  if (id.isEmpty) return const {};
  final AiCatalogModel? model = catalogModelFor(config.provider, id);
  final AiThinkingLevel level = resolvedThinkingLevel(config, id);
  if (model != null) return _profileFields(model.thinkingProfile, level);
  return _protocolFields(config.protocol, level);
}

List<AiThinkingLevel> _protocolThinkingChoices(AiApiProtocol protocol) =>
    switch (protocol) {
      AiApiProtocol.claudeMessages ||
      AiApiProtocol.geminiContent => aiThinkingLevelsWithoutOff,
      _ => aiThinkingLevels,
    };

AiThinkingLevel _protocolDefaultThinking(AiApiProtocol protocol) =>
    switch (protocol) {
      AiApiProtocol.claudeMessages ||
      AiApiProtocol.geminiContent => AiThinkingLevel.low,
      _ => AiThinkingLevel.off,
    };

String _effort(AiThinkingLevel level) => switch (level) {
  AiThinkingLevel.off => 'none',
  AiThinkingLevel.low => 'low',
  AiThinkingLevel.medium => 'medium',
  AiThinkingLevel.high => 'high',
};

AiThinkingLevel _atLeastLow(AiThinkingLevel level) =>
    level == AiThinkingLevel.off ? AiThinkingLevel.low : level;

Map<String, Object?> _profileFields(
  AiThinkingProfile profile,
  AiThinkingLevel level,
) => switch (profile) {
  AiThinkingProfile.openaiResponses => {
    'reasoning': {'effort': _effort(level)},
  },
  AiThinkingProfile.xaiChat => {'reasoning_effort': _effort(level)},
  AiThinkingProfile.openaiResponsesNoOff => {
    'reasoning': {'effort': _effort(_atLeastLow(level))},
  },
  AiThinkingProfile.xaiChatNoOff => {
    'reasoning_effort': _effort(_atLeastLow(level)),
  },
  AiThinkingProfile.xaiOmit => const {},
  AiThinkingProfile.claudeSonnet => {
    'thinking': {'type': 'between_tools'},
    'output_config': {'effort': _effort(_atLeastLow(level))},
  },
  AiThinkingProfile.claudeHaiku =>
    level == AiThinkingLevel.off
        ? {
            'thinking': {'type': 'disabled'},
            'output_config': {'effort': 'low'},
          }
        : {
            'output_config': {'effort': _effort(level)},
          },
  AiThinkingProfile.claudeAlwaysOn => {
    'output_config': {'effort': _effort(_atLeastLow(level))},
  },
  AiThinkingProfile.geminiLevel => _geminiThinking(_effort(_atLeastLow(level))),
  AiThinkingProfile.geminiLite => _geminiThinking(
    level == AiThinkingLevel.off ? 'minimal' : _effort(level),
  ),
};

Map<String, Object?> _protocolFields(
  AiApiProtocol protocol,
  AiThinkingLevel level,
) => switch (protocol) {
  AiApiProtocol.responses => {
    'reasoning': {'effort': _effort(level)},
  },
  AiApiProtocol.chatCompletions => {'reasoning_effort': _effort(level)},
  AiApiProtocol.claudeMessages => {
    'output_config': {'effort': _effort(_atLeastLow(level))},
  },
  AiApiProtocol.geminiContent => _geminiThinking(_effort(_atLeastLow(level))),
  AiApiProtocol.ollamaChat => {'think': level != AiThinkingLevel.off},
};

Map<String, Object?> _geminiThinking(String level) => {
  'generationConfig': {
    'thinkingConfig': {'thinkingLevel': level},
  },
};

/// 去掉空白。已經在清單裡的名稱不再多一列；若它是關著的，改成打開。
AiConnectionConfig addModel(AiConnectionConfig config, String raw) {
  final String id = raw.trim();
  final AiConnectionConfig current = normalizeModelCatalog(config);
  if (id.isEmpty) return current;
  if (current.catalog.contains(id) && current.enabledModels.contains(id)) {
    return current;
  }
  return setModelEnabled(current, id, enabled: true);
}

AiConnectionConfig setModelEnabled(
  AiConnectionConfig config,
  String modelId, {
  required bool enabled,
}) {
  final AiConnectionConfig current = normalizeModelCatalog(config);
  final String id = modelId.trim();
  if (id.isEmpty) return current;
  final List<String> added = [...current.addedModels];
  if (!current.isBuiltinModel(id) && !added.contains(id)) added.add(id);
  final List<String> catalog = [
    ...builtinModelsFor(current.provider),
    ...added,
  ];
  if (!catalog.contains(id)) return current;
  final Set<String> on = current.enabledModels.toSet();
  if (enabled) {
    on.add(id);
  } else {
    on.remove(id);
  }
  final List<String> enabledModels = _enabledInOrder(catalog, on);
  var model = current.model.trim();
  if (enabled && model.isEmpty) model = id;
  if (!enabled && model == id) model = _nextEnabled(catalog, enabledModels, id);
  return current.copyWith(
    model: model,
    addedModels: added,
    enabledModels: enabledModels,
  );
}

/// 只拿掉手動加入的名稱。寫死的列留在區塊裡。它若是預設，就改指到下一個打開的模型。
AiConnectionConfig removeAddedModel(AiConnectionConfig config, String modelId) {
  final AiConnectionConfig current = normalizeModelCatalog(config);
  final String id = modelId.trim();
  if (id.isEmpty ||
      current.isBuiltinModel(id) ||
      !current.addedModels.contains(id)) {
    return current;
  }
  final List<String> added = [...current.addedModels]..remove(id);
  final List<String> catalog = [
    ...builtinModelsFor(current.provider),
    ...added,
  ];
  final List<String> enabled = _enabledInOrder(
    catalog,
    current.enabledModels.where((String name) => name != id),
  );
  var model = current.model.trim();
  if (model == id) model = _nextEnabled(catalog, enabled, id);
  return current.copyWith(
    model: model,
    addedModels: added,
    enabledModels: enabled,
  );
}

/// 聊天選單列出所有連得上、而且打開的模型。這一則正在用、但已關掉或金鑰已清掉的名稱仍留在最後。
({List<ChatModelOption> models, bool currentIsExtra}) chatModelMenu({
  required AiConnectionSettings settings,
  required AiConnectionConfig chatConfig,
  required bool Function(AiProvider provider) hasApiKey,
}) {
  final List<ChatModelOption> models = [];
  for (final AiProvider provider in aiCatalogProviders) {
    final AiConnectionConfig config = settings.configs.containsKey(provider)
        ? normalizeModelCatalog(settings.configs[provider]!)
        : defaultConnection(provider);
    if (!chatProviderCanList(config, hasApiKey: hasApiKey(provider))) {
      continue;
    }
    for (final String id in config.enabledModels) {
      models.add(ChatModelOption(provider: provider, modelId: id));
    }
  }
  final String current = chatConfig.model.trim();
  final bool listed = models.any(
    (ChatModelOption option) =>
        option.provider == chatConfig.provider && option.modelId == current,
  );
  final bool currentIsExtra = current.isNotEmpty && !listed;
  if (currentIsExtra) {
    models.add(
      ChatModelOption(provider: chatConfig.provider, modelId: current),
    );
  }
  return (models: models, currentIsExtra: currentIsExtra);
}

class AiConnectionSettings {
  const AiConnectionSettings({
    this.provider = AiProvider.openai,
    this.configs = const {},
  });
  final AiProvider provider;
  final Map<AiProvider, AiConnectionConfig> configs;
  AiConnectionConfig configFor(AiProvider value) =>
      configs[value] ?? AiConnectionConfig(provider: value);
  AiConnectionConfig get activeConfig => configFor(provider);
  Map<String, Object?> toJson() => {
    'provider': provider.name,
    'configs': {
      for (final entry in configs.entries)
        entry.key.name: entry.value.toStoredJson(),
    },
  };
  factory AiConnectionSettings.fromJson(
    Map<String, dynamic> json, {
    bool adoptCatalog = true,
  }) {
    final AiConnectionSettings parsed = AiConnectionSettings(
      provider: AiProvider.values.byName(
        json['provider'] as String? ?? 'openai',
      ),
      configs: {
        for (final entry
            in (json['configs'] as Map<String, dynamic>? ?? {}).entries)
          AiProvider.values.byName(entry.key): _connectionConfigFromJson(
            (entry.value as Map).cast<String, dynamic>(),
          ),
      },
    );
    if (!adoptCatalog) return parsed;
    return adoptConnectionCatalog(parsed).settings;
  }
}
