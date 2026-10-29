class ChatDiaryPromptSettings {
  const ChatDiaryPromptSettings({
    this.conversationOverride,
    this.generationOverride,
  });
  final String? conversationOverride;
  final String? generationOverride;
}

class ChatDiarySettings {
  const ChatDiarySettings({
    this.prompts = const ChatDiaryPromptSettings(),
    this.hidePersonNames = true,
  });
  final ChatDiaryPromptSettings prompts;
  final bool hidePersonNames;
  Map<String, Object?> toJson() => {
    'conversation_prompt_override': prompts.conversationOverride,
    'generation_prompt_override': prompts.generationOverride,
    'hide_people': hidePersonNames,
  };
  factory ChatDiarySettings.fromJson(Map<String, dynamic> json) =>
      ChatDiarySettings(
        prompts: ChatDiaryPromptSettings(
          conversationOverride: json['conversation_prompt_override'] as String?,
          generationOverride: json['generation_prompt_override'] as String?,
        ),
        hidePersonNames: json['hide_people'] as bool? ?? true,
      );
}
