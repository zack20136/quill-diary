import 'package:quill_diary/domain/ai/ai_request.dart';

class AiDiaryContext {
  const AiDiaryContext({required this.diaryBody});

  final String diaryBody;
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
    this.request,
    required this.instructions,
    required this.turns,
    this.diaryContext,
    this.conversationTurns,
    this.hasLocalPrivateNotes = false,
  });

  final String instructions;
  final PreparedAiRequest? request;

  AiRequestPreview effective() {
    final prepared = request;
    if (prepared == null) return this;
    return AiRequestPreview(
      request: prepared,
      instructions: prepared.instructions,
      diaryContext: prepared.diaryBody == null
          ? null
          : AiDiaryContext(diaryBody: prepared.diaryBody!),
      hasLocalPrivateNotes: hasLocalPrivateNotes,
      conversationTurns: conversationTurns == null
          ? null
          : [
              for (final turn in conversationTurns!)
                AiPreviewTurn(
                  isUser: turn.isUser,
                  text: turn.text,
                  imageIds: turn.imageIds,
                  pending: turn.pending,
                ),
            ],
      turns: [
        for (var i = 0; i < prepared.messages.length; i++)
          AiPreviewTurn(
            isUser: prepared.messages[i].isUser,
            text: prepared.messages[i].text,
            imageIds: prepared.messages[i].images
                .map((image) => image.id)
                .toList(),
            pending: i < turns.length && turns[i].pending,
          ),
      ],
    );
  }

  final AiDiaryContext? diaryContext;
  final List<AiPreviewTurn> turns;

  /// 生成會將對話打包為 JSON，預覽仍依原訊息排列。
  final List<AiPreviewTurn>? conversationTurns;
  final bool hasLocalPrivateNotes;

  String get systemPrompt =>
      aiSystemPrompt(instructions, diaryContext?.diaryBody);
}
