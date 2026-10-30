/// 設定選單看得到的供應商。新的官方協定仍要在連線客戶端補請求，不能只改這份名單。
enum AiProvider { openai, claude, gemini, xai, custom }

/// 畫面上的思考強度。各模型能選的值，以及實際送出的欄位，都不相同。
enum AiThinkingLevel { off, low, medium, high }

/// 官方模型怎麼把思考強度寫進請求。自訂服務不使用這個，改看協定。
enum AiThinkingProfile {
  openaiResponses,
  openaiResponsesNoOff,
  claudeSonnet,
  claudeHaiku,
  claudeAlwaysOn,
  geminiLevel,
  geminiLite,
  xaiChat,
  xaiChatNoOff,
  xaiOmit,
}

const List<AiThinkingLevel> aiThinkingLevels = [
  AiThinkingLevel.off,
  AiThinkingLevel.low,
  AiThinkingLevel.medium,
  AiThinkingLevel.high,
];

const List<AiThinkingLevel> aiThinkingLevelsWithoutOff = [
  AiThinkingLevel.low,
  AiThinkingLevel.medium,
  AiThinkingLevel.high,
];

/// 一列官方模型。之後要增減名稱、預設開關或思考強度，改這個檔即可。
class AiCatalogModel {
  const AiCatalogModel(
    this.id, {
    this.enabledByDefault = false,
    required this.defaultThinking,
    required this.thinkingProfile,
    this.thinkingChoices = aiThinkingLevels,
    this.thinkingFixed = false,
  });

  final String id;

  /// 這個供應商還沒存過設定時，開關要不要先打開。
  final bool enabledByDefault;

  /// 使用者還沒改過時送出的強度。
  final AiThinkingLevel defaultThinking;

  final AiThinkingProfile thinkingProfile;

  /// 空清單表示不顯示選單。
  final List<AiThinkingLevel> thinkingChoices;

  final bool thinkingFixed;
}

/// 設定選單的供應商順序。從這裡拿掉就不再出現；舊設定檔仍讀得開。
const List<AiProvider> aiCatalogProviders = [
  AiProvider.openai,
  AiProvider.claude,
  AiProvider.gemini,
  AiProvider.xai,
  AiProvider.custom,
];

/// 官方聊天模型。畫面用這份補上，不寫進設定檔，也不再向服務查詢。
const Map<AiProvider, List<AiCatalogModel>> aiModelCatalog = {
  AiProvider.openai: [
    AiCatalogModel(
      'gpt-6.1-terra',
      enabledByDefault: true,
      defaultThinking: AiThinkingLevel.off,
      thinkingProfile: AiThinkingProfile.openaiResponses,
    ),
    AiCatalogModel(
      'gpt-6-luna',
      defaultThinking: AiThinkingLevel.off,
      thinkingProfile: AiThinkingProfile.openaiResponses,
    ),
    AiCatalogModel(
      'gpt-6.1-sol',
      defaultThinking: AiThinkingLevel.low,
      thinkingProfile: AiThinkingProfile.openaiResponsesNoOff,
      thinkingChoices: aiThinkingLevelsWithoutOff,
    ),
    AiCatalogModel(
      'gpt-6-astra',
      defaultThinking: AiThinkingLevel.low,
      thinkingProfile: AiThinkingProfile.openaiResponsesNoOff,
      thinkingChoices: aiThinkingLevelsWithoutOff,
    ),
  ],
  AiProvider.claude: [
    AiCatalogModel(
      'claude-sonnet-5-5',
      enabledByDefault: true,
      defaultThinking: AiThinkingLevel.low,
      thinkingProfile: AiThinkingProfile.claudeSonnet,
      thinkingChoices: aiThinkingLevelsWithoutOff,
    ),
    AiCatalogModel(
      'claude-haiku-5-5',
      defaultThinking: AiThinkingLevel.low,
      thinkingProfile: AiThinkingProfile.claudeHaiku,
    ),
    AiCatalogModel(
      'claude-opus-5-5',
      defaultThinking: AiThinkingLevel.low,
      thinkingProfile: AiThinkingProfile.claudeAlwaysOn,
      thinkingChoices: aiThinkingLevelsWithoutOff,
    ),
    AiCatalogModel(
      'claude-fable-5-1',
      defaultThinking: AiThinkingLevel.low,
      thinkingProfile: AiThinkingProfile.claudeAlwaysOn,
      thinkingChoices: aiThinkingLevelsWithoutOff,
    ),
  ],
  AiProvider.gemini: [
    AiCatalogModel(
      'gemini-3.8-flash',
      enabledByDefault: true,
      defaultThinking: AiThinkingLevel.low,
      thinkingProfile: AiThinkingProfile.geminiLevel,
      thinkingChoices: aiThinkingLevelsWithoutOff,
    ),
    AiCatalogModel(
      'gemini-3.5-flash-lite',
      defaultThinking: AiThinkingLevel.off,
      thinkingProfile: AiThinkingProfile.geminiLite,
    ),
    AiCatalogModel(
      'gemini-4-argon',
      defaultThinking: AiThinkingLevel.low,
      thinkingProfile: AiThinkingProfile.geminiLevel,
      thinkingChoices: aiThinkingLevelsWithoutOff,
    ),
  ],
  AiProvider.xai: [
    AiCatalogModel(
      'grok-4.3',
      enabledByDefault: true,
      defaultThinking: AiThinkingLevel.off,
      thinkingProfile: AiThinkingProfile.xaiChat,
    ),
    AiCatalogModel(
      'grok-4.20-non-reasoning',
      defaultThinking: AiThinkingLevel.off,
      thinkingProfile: AiThinkingProfile.xaiOmit,
      thinkingChoices: [],
      thinkingFixed: true,
    ),
    AiCatalogModel(
      'grok-4.7',
      defaultThinking: AiThinkingLevel.low,
      thinkingProfile: AiThinkingProfile.xaiChatNoOff,
      thinkingChoices: aiThinkingLevelsWithoutOff,
    ),
  ],
};

List<String> builtinModelsFor(AiProvider provider) => [
  for (final AiCatalogModel model in aiModelCatalog[provider] ?? const [])
    model.id,
];

AiCatalogModel? catalogModelFor(AiProvider provider, String modelId) {
  for (final AiCatalogModel model in aiModelCatalog[provider] ?? const []) {
    if (model.id == modelId) return model;
  }
  return null;
}
