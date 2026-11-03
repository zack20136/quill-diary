import 'package:flutter/foundation.dart';

import 'package:quill_diary/domain/ai/ai_failure.dart';

enum ChatDiaryGenerationPhase {
  preparing,
  waiting,
  writing,
  saving,
  completed,
  empty,
  failed,
  cancelled;

  bool get isActive => switch (this) {
    preparing || waiting || writing || saving => true,
    _ => false,
  };
}

@immutable
class ChatDiaryGeneration {
  const ChatDiaryGeneration({
    required this.id,
    required this.vaultId,
    required this.chatId,
    required this.phase,
    this.error,
  });

  final String id;
  final String vaultId;
  final String chatId;
  final ChatDiaryGenerationPhase phase;
  final AiErrorCode? error;

  ChatDiaryGeneration withPhase(
    ChatDiaryGenerationPhase phase, {
    AiErrorCode? error,
  }) => ChatDiaryGeneration(
    id: id,
    vaultId: vaultId,
    chatId: chatId,
    phase: phase,
    error: error,
  );
}
