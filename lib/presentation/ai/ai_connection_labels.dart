import '../../domain/ai/ai_connection_settings.dart';
import '../../l10n/l10n.dart';

/// 提供商名稱除「自訂」外是專有名詞，中英相同。
String aiProviderLabel(AppLocalizations l10n, AiProvider provider) =>
    switch (provider) {
      AiProvider.openai => 'OpenAI',
      AiProvider.claude => 'Claude',
      AiProvider.gemini => 'Gemini',
      AiProvider.custom => l10n.aiProviderCustom,
    };

/// 協定名稱對應 API 文件，中英相同。
String aiProtocolLabel(AiApiProtocol protocol) => switch (protocol) {
  AiApiProtocol.chatCompletions => 'OpenAI Chat Completions',
  AiApiProtocol.responses => 'OpenAI Responses',
  AiApiProtocol.claudeMessages => 'Claude Messages',
  AiApiProtocol.geminiContent => 'Gemini GenerateContent',
  AiApiProtocol.ollamaChat => 'Ollama Chat',
};
