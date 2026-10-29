enum AiProvider { openai, claude, gemini, custom }

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
    AiProvider.custom => '',
  };

  bool get requiresApiKey => switch (this) {
    AiProvider.openai || AiProvider.claude || AiProvider.gemini => true,
    _ => false,
  };
  bool get hasCustomUrl => this == AiProvider.custom;
}

class AiConnectionConfig {
  const AiConnectionConfig({
    required this.provider,
    this.model = '',
    this.baseUrl = '',
    this.workspaceId = '',
    this.customProtocol = AiApiProtocol.chatCompletions,
  });

  final AiProvider provider;
  final String model;
  final String baseUrl;
  final String workspaceId;
  final AiApiProtocol customProtocol;
  AiApiProtocol get protocol => switch (provider) {
    AiProvider.openai => AiApiProtocol.responses,
    AiProvider.claude => AiApiProtocol.claudeMessages,
    AiProvider.gemini => AiApiProtocol.geminiContent,
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

  Map<String, Object?> toJson() => {
    'provider': provider.name,
    'model': model,
    'base_url': baseUrl,
    'workspace_id': workspaceId,
    'custom_protocol': customProtocol.name,
  };

  factory AiConnectionConfig.fromJson(Map<String, dynamic> json) =>
      AiConnectionConfig(
        provider: AiProvider.values.byName(json['provider'] as String),
        model: json['model'] as String? ?? '',
        baseUrl: json['base_url'] as String? ?? '',
        workspaceId: json['workspace_id'] as String? ?? '',
        customProtocol: AiApiProtocol.values.byName(
          json['custom_protocol'] as String? ?? 'chatCompletions',
        ),
      );
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
      for (final entry in configs.entries) entry.key.name: entry.value.toJson(),
    },
  };
  factory AiConnectionSettings.fromJson(Map<String, dynamic> json) =>
      AiConnectionSettings(
        provider: AiProvider.values.byName(
          json['provider'] as String? ?? 'openai',
        ),
        configs: {
          for (final entry
              in (json['configs'] as Map<String, dynamic>? ?? {}).entries)
            AiProvider.values.byName(entry.key): AiConnectionConfig.fromJson(
              (entry.value as Map).cast<String, dynamic>(),
            ),
        },
      );
}
