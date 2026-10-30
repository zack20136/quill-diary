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

/// 畫面上的「供應商/模型 id」。斜線只是標籤，模型 id 本身可以再含有斜線。
String aiModelOptionLabel(
  AppLocalizations l10n,
  AiProvider provider,
  String modelId,
) => '${aiProviderLabel(l10n, provider)}/$modelId';

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
