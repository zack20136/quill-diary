import 'dart:convert';

class AiDiaryContext {
  const AiDiaryContext({required this.originalBody});

  final String originalBody;

  String get systemPromptBlock =>
      '<diary_data>\n${jsonEncode({'original': originalBody})}\n</diary_data>';
}

class AiPreviewTurn {
  const AiPreviewTurn({
    required this.isUser,
    required this.text,
    required this.imageIds,
    this.pending = false,
  });

  final bool isUser;
  final String text;
  final List<String> imageIds;

  /// 輸入框裡尚未送出的文字或照片。
  final bool pending;
}

class AiRequestPreview {
  const AiRequestPreview({
    required this.instructions,
    required this.turns,
    this.diaryContext,
    this.conversationTurns,
  });

  final String instructions;
  final AiDiaryContext? diaryContext;
  final List<AiPreviewTurn> turns;

  /// 生成會將對話打包為 JSON，預覽仍依原訊息排列。
  final List<AiPreviewTurn>? conversationTurns;

  String get systemPrompt => diaryContext == null
      ? instructions
      : '$instructions\n\n${diaryContext!.systemPromptBlock}';
}
