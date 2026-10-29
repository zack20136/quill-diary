class ChatDiaryPreviewTurn {
  const ChatDiaryPreviewTurn({
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

class ChatDiaryRequestPreview {
  const ChatDiaryRequestPreview({
    required this.systemPrompt,
    required this.turns,
  });

  final String systemPrompt;
  final List<ChatDiaryPreviewTurn> turns;
}
