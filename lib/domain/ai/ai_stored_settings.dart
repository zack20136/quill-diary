import 'package:quill_diary/domain/ai/ai_connection_settings.dart';
import 'package:quill_diary/shared/data_versions.dart';

/// 日記整理的提示詞覆寫。空白欄位代表使用內建提示詞。
class DiaryOrganizationPromptSettings {
  const DiaryOrganizationPromptSettings({
    this.conversationOverride,
    this.generationOverride,
  });

  final String? conversationOverride;
  final String? generationOverride;
}

class ChatDiaryPromptSettings {
  const ChatDiaryPromptSettings({
    this.personalityOverride,
    this.guidanceOverride,
    this.generationOverride,
  });

  final String? personalityOverride;
  final String? guidanceOverride;
  final String? generationOverride;
}

/// 會隨日記庫備份的 AI 設定。不含 API 金鑰。
///
/// 頂層 `ai_enabled`、`hide_people` 為全域開關。提示詞有覆寫時才寫進
/// `chat_diary`、`diary_organization`。編解碼不更新模型目錄或改寫檔案。
class AiStoredSettings {
  const AiStoredSettings({
    this.connection = const AiConnectionSettings(),
    this.aiEnabled = true,
    this.hidePersonNames = true,
    this.chatDiaryPrompts = const ChatDiaryPromptSettings(),
    this.organizationPrompts = const DiaryOrganizationPromptSettings(),
  });

  final AiConnectionSettings connection;
  final bool aiEnabled;
  final bool hidePersonNames;
  final ChatDiaryPromptSettings chatDiaryPrompts;
  final DiaryOrganizationPromptSettings organizationPrompts;

  factory AiStoredSettings.fromJson(Map<String, dynamic> json) {
    if (json['version'] is! int || json['version'] != DataVersions.aiSettings) {
      throw const FormatException('AI 設定版本不支援。');
    }
    final chat = json['chat_diary'] as Map? ?? const {};
    final organization = json['diary_organization'] as Map? ?? const {};
    return AiStoredSettings(
      connection: AiConnectionSettings.fromJson(
        Map<String, dynamic>.from(json['connection'] as Map),
      ),
      aiEnabled: json['ai_enabled'] as bool? ?? true,
      hidePersonNames: json['hide_people'] as bool? ?? true,
      chatDiaryPrompts: ChatDiaryPromptSettings(
        personalityOverride: _nonBlank(
          chat['personality_prompt_override'] as String?,
        ),
        guidanceOverride: _nonBlank(
          chat['guidance_prompt_override'] as String?,
        ),
        generationOverride: _nonBlank(
          chat['generation_prompt_override'] as String?,
        ),
      ),
      organizationPrompts: DiaryOrganizationPromptSettings(
        conversationOverride: _nonBlank(
          organization['conversation_prompt_override'] as String?,
        ),
        generationOverride: _nonBlank(
          organization['generation_prompt_override'] as String?,
        ),
      ),
    );
  }

  Map<String, Object?> toJson() {
    final chat = {
      'personality_prompt_override': ?_nonBlank(
        chatDiaryPrompts.personalityOverride,
      ),
      'guidance_prompt_override': ?_nonBlank(chatDiaryPrompts.guidanceOverride),
      'generation_prompt_override': ?_nonBlank(
        chatDiaryPrompts.generationOverride,
      ),
    };
    final organization = {
      'conversation_prompt_override': ?_nonBlank(
        organizationPrompts.conversationOverride,
      ),
      'generation_prompt_override': ?_nonBlank(
        organizationPrompts.generationOverride,
      ),
    };
    return {
      'version': DataVersions.aiSettings,
      'connection': connection.toJson(),
      'ai_enabled': aiEnabled,
      'hide_people': hidePersonNames,
      if (chat.isNotEmpty) 'chat_diary': chat,
      if (organization.isNotEmpty) 'diary_organization': organization,
    };
  }

  AiStoredSettings copyWith({
    AiConnectionSettings? connection,
    bool? aiEnabled,
    bool? hidePersonNames,
    ChatDiaryPromptSettings? chatDiaryPrompts,
    DiaryOrganizationPromptSettings? organizationPrompts,
  }) => AiStoredSettings(
    connection: connection ?? this.connection,
    aiEnabled: aiEnabled ?? this.aiEnabled,
    hidePersonNames: hidePersonNames ?? this.hidePersonNames,
    chatDiaryPrompts: chatDiaryPrompts ?? this.chatDiaryPrompts,
    organizationPrompts: organizationPrompts ?? this.organizationPrompts,
  );
}

String? _nonBlank(String? value) =>
    value == null || value.trim().isEmpty ? null : value;

enum AiSettingsStatus { missing, ready, unreadable }

/// 唯讀檢查結果及樂觀鎖定指紋，不寫入磁碟。
class AiSettingsInspection {
  const AiSettingsInspection({
    required this.vaultId,
    required this.revision,
    required this.status,
    this.settings,
  });
  final String vaultId;
  final String revision;
  final AiSettingsStatus status;
  final AiStoredSettings? settings;
}
