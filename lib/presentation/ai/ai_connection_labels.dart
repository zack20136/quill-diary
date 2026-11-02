import 'package:quill_diary/domain/ai/ai_catalog.dart';
import 'package:quill_diary/domain/ai/ai_connection_settings.dart';
import 'package:quill_diary/l10n/l10n.dart';

/// 提供商名稱除「自訂」外是專有名詞，中英相同。
String aiProviderLabel(AppLocalizations l10n, AiProvider provider) =>
    switch (provider) {
      AiProvider.openai => 'OpenAI',
      AiProvider.claude => 'Claude',
      AiProvider.gemini => 'Gemini',
      AiProvider.xai => 'xAI',
      AiProvider.custom => l10n.aiProviderCustom,
    };

String aiConnectionLabel(AppLocalizations l10n, AiConnectionConfig config) =>
    config.provider == AiProvider.custom && config.displayName.trim().isNotEmpty
    ? config.displayName.trim()
    : aiProviderLabel(l10n, config.provider);

String aiConnectionModelLabel(
  AppLocalizations l10n,
  AiConnectionConfig config,
) => '${aiConnectionLabel(l10n, config)}/${config.model}';

String aiChatModelLabel(AppLocalizations l10n, AiConnectionConfig config) {
  if (config.provider != AiProvider.custom) {
    return aiConnectionModelLabel(l10n, config);
  }
  final destination = config.effectiveBaseUrl.replaceFirst(
    RegExp(r'^https?://', caseSensitive: false),
    '',
  );
  return '${destination.isEmpty ? l10n.aiConnectionNotConfigured : destination}/${config.model}';
}

String aiThinkingLabel(AppLocalizations l10n, AiThinkingLevel level) =>
    switch (level) {
      AiThinkingLevel.off => l10n.aiThinkingOff,
      AiThinkingLevel.low => l10n.aiThinkingLow,
      AiThinkingLevel.medium => l10n.aiThinkingMedium,
      AiThinkingLevel.high => l10n.aiThinkingHigh,
    };

/// 協定名稱對應 API 文件，中英相同。
String aiProtocolLabel(AiApiProtocol protocol) => switch (protocol) {
  AiApiProtocol.chatCompletions => 'OpenAI Chat Completions',
  AiApiProtocol.responses => 'OpenAI Responses',
  AiApiProtocol.claudeMessages => 'Claude Messages',
  AiApiProtocol.geminiContent => 'Gemini GenerateContent',
  AiApiProtocol.ollamaChat => 'Ollama Chat',
};
