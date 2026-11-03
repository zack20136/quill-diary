import 'package:quill_diary/application/errors/ai_error_text.dart';
import 'package:quill_diary/domain/chat_diary/chat_diary_generation.dart';
import 'package:quill_diary/l10n/app_localizations.dart';

String chatDiaryGenerationPhaseLabel(
  AppLocalizations l10n,
  ChatDiaryGenerationPhase phase,
) => switch (phase) {
  ChatDiaryGenerationPhase.preparing => l10n.chatDiaryGenerationPreparing,
  ChatDiaryGenerationPhase.waiting => l10n.chatDiaryGenerationWaiting,
  ChatDiaryGenerationPhase.writing => l10n.chatDiaryGenerationWriting,
  ChatDiaryGenerationPhase.saving => l10n.chatDiaryGenerationSaving,
  ChatDiaryGenerationPhase.completed => l10n.chatDiaryGenerationCompleted,
  ChatDiaryGenerationPhase.empty => l10n.chatDiaryGenerationEmpty,
  ChatDiaryGenerationPhase.failed => l10n.chatDiaryGenerationFailed,
  ChatDiaryGenerationPhase.cancelled => l10n.chatDiaryGenerationCancelled,
};

String? chatDiaryGenerationFailureDetail(
  AppLocalizations l10n,
  ChatDiaryGeneration generation,
) {
  if (generation.phase != ChatDiaryGenerationPhase.failed) return null;
  final error = generation.error;
  return error == null ? l10n.aiErrorUnexpected : aiErrorText(l10n, error);
}
