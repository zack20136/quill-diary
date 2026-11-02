import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/chat_diary/chat_diary_providers.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/navigation/app_routes.dart';
import 'package:quill_diary/shared/presentation/app_feedback.dart';

class ChatDiarySavedConversationButton extends ConsumerWidget {
  const ChatDiarySavedConversationButton({super.key, required this.entryId});
  final String entryId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chat = ref.watch(chatDiaryForEntryProvider(entryId));
    return IconButton(
      tooltip: context.l10n.chatDiaryViewSavedConversation,
      style: IconButton.styleFrom(
        fixedSize: const Size.square(44),
        minimumSize: const Size.square(44),
        padding: EdgeInsets.zero,
        foregroundColor: Theme.of(context).colorScheme.primary,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: chat.isLoading
          ? null
          : () async {
              if (chat.hasError) {
                showAppFeedbackToast(
                  context,
                  context.l10n.aiErrorStorage,
                  tone: AppFeedbackTone.error,
                );
                ref.invalidate(chatDiaryForEntryProvider(entryId));
                return;
              }
              if (chat.value == null) {
                showAppFeedbackToast(
                  context,
                  context.l10n.chatDiaryNoSavedConversation,
                );
                return;
              }
              await context.push(AppRoutes.chatDiaryEntryLocation(entryId));
              if (context.mounted) {
                ref.invalidate(chatDiaryForEntryProvider(entryId));
              }
            },
      icon: Text(
        context.l10n.chatDiaryAiIcon,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
    );
  }
}
