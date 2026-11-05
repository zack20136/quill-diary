import 'package:quill_diary/domain/ai/ai_connection_settings.dart';

/// 聊天或日記整理的提示詞覆寫。空白欄位代表使用內建提示詞。
class AiPromptOverrides {
  const AiPromptOverrides({this.conversationOverride, this.generationOverride});

  final String? conversationOverride;
  final String? generationOverride;
}

/// 會隨日記庫備份的 AI 設定。不含 API 金鑰。
///
/// 人物隱藏寫在頂層 `hide_people`。提示詞有覆寫時才寫進 `chat_diary`、
/// `diary_organization`。欄位對應只由設定儲存負責。
class AiStoredSettings {
  const AiStoredSettings({
    this.connection = const AiConnectionSettings(),
    this.hidePersonNames = true,
    this.chatDiaryPrompts = const AiPromptOverrides(),
    this.organizationPrompts = const AiPromptOverrides(),
  });

  final AiConnectionSettings connection;
  final bool hidePersonNames;
  final AiPromptOverrides chatDiaryPrompts;
  final AiPromptOverrides organizationPrompts;

  AiStoredSettings copyWith({
    AiConnectionSettings? connection,
    bool? hidePersonNames,
    AiPromptOverrides? chatDiaryPrompts,
    AiPromptOverrides? organizationPrompts,
  }) => AiStoredSettings(
    connection: connection ?? this.connection,
    hidePersonNames: hidePersonNames ?? this.hidePersonNames,
    chatDiaryPrompts: chatDiaryPrompts ?? this.chatDiaryPrompts,
    organizationPrompts: organizationPrompts ?? this.organizationPrompts,
  );
}
