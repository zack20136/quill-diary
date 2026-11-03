import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:quill_diary/domain/ai/ai_failure.dart';
import 'package:quill_diary/domain/chat_diary/chat_diary_generation.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';

final chatDiaryGenerationsProvider =
    NotifierProvider<
      ChatDiaryGenerations,
      Map<(String, String), ChatDiaryGeneration>
    >(ChatDiaryGenerations.new);

class ChatDiaryGenerations
    extends Notifier<Map<(String, String), ChatDiaryGeneration>> {
  @override
  Map<(String, String), ChatDiaryGeneration> build() => const {};

  ChatDiaryGeneration begin({required String vaultId, required String chatId}) {
    final generation = ChatDiaryGeneration(
      id: generateChatDiaryMessageId(),
      vaultId: vaultId,
      chatId: chatId,
      phase: ChatDiaryGenerationPhase.preparing,
    );
    state = {...state, (vaultId, chatId): generation};
    return generation;
  }

  void update(
    ChatDiaryGeneration generation,
    ChatDiaryGenerationPhase phase, {
    AiErrorCode? error,
  }) {
    final key = (generation.vaultId, generation.chatId);
    final current = state[key];
    if (current?.id != generation.id || !current!.phase.isActive) return;
    state = {...state, key: generation.withPhase(phase, error: error)};
  }

  void forget(String vaultId, String chatId) {
    final key = (vaultId, chatId);
    final generation = state[key];
    if (generation == null || generation.phase.isActive) return;
    state = {...state}..remove(key);
  }
}
