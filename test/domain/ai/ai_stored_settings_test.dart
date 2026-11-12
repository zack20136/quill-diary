import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/ai/ai_catalog.dart';
import 'package:quill_diary/domain/ai/ai_connection_settings.dart';
import 'package:quill_diary/domain/ai/ai_stored_settings.dart';
import 'package:quill_diary/domain/persona/persona_reference.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/shared/data_versions.dart';

void main() {
  test('目前格式往返保留覆寫原文，可選欄位缺少時使用固定預設', () {
    const generation = '  這是既有的完整生成提示詞。\n請用 JSON 輸出。  ';
    const settings = AiStoredSettings(
      aiEnabled: false,
      hidePersonNames: false,
      chatDiaryPrompts: ChatDiaryPromptSettings(
        personalityOverride: '  保留換行\n與空白  ',
        guidanceOverride: ' ',
        generationOverride: generation,
      ),
      organizationPrompts: DiaryOrganizationPromptSettings(
        generationOverride: '整理內容',
      ),
    );
    final json =
        jsonDecode(jsonEncode(settings.toJson())) as Map<String, dynamic>;
    final restored = AiStoredSettings.fromJson(json);
    expect(restored.toJson(), settings.toJson());
    expect(restored.aiEnabled, isFalse);
    expect(restored.chatDiaryPrompts.personalityOverride, '  保留換行\n與空白  ');
    expect(restored.chatDiaryPrompts.generationOverride, generation);
    expect(
      (json['chat_diary'] as Map)['generation_prompt_override'],
      generation,
    );
    expect(
      (json['chat_diary'] as Map).containsKey('guidance_prompt_override'),
      isFalse,
    );
    final defaults = AiStoredSettings.fromJson({
      'version': DataVersions.aiSettings,
      'connection': const AiConnectionSettings().toJson(),
      'future_optional_field': true,
    });
    expect(defaults.aiEnabled, isTrue);
    expect(defaults.hidePersonNames, isTrue);
    expect(defaults.chatDiaryPrompts.personalityOverride, isNull);
    expect(defaults.organizationPrompts.generationOverride, isNull);
  });

  test('記住的夥伴可往返，缺省不寫出，格式錯誤拒讀整份設定', () {
    final persona = PersonaReference(
      personId: generatePersonId(),
      personaId: generatePersonaId(),
    );
    final settings = AiStoredSettings(
      chatDiaryPrompts: ChatDiaryPromptSettings(
        guidanceOverride: '保留引導',
        selectedPersona: persona,
      ),
    );
    final json =
        jsonDecode(jsonEncode(settings.toJson())) as Map<String, dynamic>;
    expect(json['version'], DataVersions.aiSettings);
    final chat = json['chat_diary'] as Map;
    expect(chat['guidance_prompt_override'], '保留引導');
    expect(chat['selected_persona'], persona.toJson());
    final restored = AiStoredSettings.fromJson(json);
    expect(
      restored.chatDiaryPrompts.selectedPersona?.personId,
      persona.personId,
    );
    expect(
      restored.chatDiaryPrompts.selectedPersona?.personaId,
      persona.personaId,
    );
    expect(restored.chatDiaryPrompts.guidanceOverride, '保留引導');

    final onlyPersona = const AiStoredSettings().copyWith(
      chatDiaryPrompts: ChatDiaryPromptSettings(selectedPersona: persona),
    );
    final onlyChat = onlyPersona.toJson()['chat_diary'] as Map;
    expect(onlyChat.containsKey('personality_prompt_override'), isFalse);
    expect(onlyChat['selected_persona'], persona.toJson());
    expect(
      const AiStoredSettings().toJson().containsKey('chat_diary'),
      isFalse,
    );

    expect(
      () => AiStoredSettings.fromJson({
        ...const AiStoredSettings().toJson(),
        'chat_diary': {'selected_persona': '不是物件'},
      }),
      throwsA(isA<TypeError>()),
    );
    expect(
      () => AiStoredSettings.fromJson({
        ...const AiStoredSettings().toJson(),
        'chat_diary': {
          'selected_persona': {'person_id': 'nope', 'persona_id': 'nope'},
        },
      }),
      throwsFormatException,
    );
  });

  test('舊版、未來版本與非整數版本拒讀，已知欄位型別錯誤不使用預設值掩蓋', () {
    for (final version in [1, 3, 2.0, '2', null]) {
      expect(
        () => AiStoredSettings.fromJson({
          ...const AiStoredSettings().toJson(),
          'version': version,
        }),
        throwsFormatException,
      );
    }
    expect(
      () => AiStoredSettings.fromJson({
        ...const AiStoredSettings().toJson(),
        'hide_people': 'false',
      }),
      throwsA(isA<TypeError>()),
    );
    expect(
      () => AiStoredSettings.fromJson({
        ...const AiStoredSettings().toJson(),
        'ai_enabled': 'false',
      }),
      throwsA(isA<TypeError>()),
    );
  });

  test('連線快照不受目前目錄影響，只保存本次模型的思考設定', () {
    const config = AiConnectionConfig(
      provider: AiProvider.openai,
      model: 'removed-model',
      addedModels: ['other-model'],
      enabledModels: ['other-model'],
      thinkingLevels: {
        'removed-model': AiThinkingLevel.high,
        'other-model': AiThinkingLevel.low,
      },
    );
    final json = config.toSnapshotJson();
    final restored = AiConnectionConfig.fromSnapshotJson(
      jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
    );
    expect(restored.model, 'removed-model');
    expect(restored.enabledModels, isEmpty);
    expect(restored.thinkingLevels, {'removed-model': AiThinkingLevel.high});
    expect(restored.toSnapshotJson(), json);
    expect(json.containsKey('known_builtin_models'), isFalse);
    expect(config.toStoredJson()['known_builtin_models'], isEmpty);
  });
}
