import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../application/chat_diary/chat_diary_providers.dart';
import '../../l10n/l10n.dart';

class ChatDiarySavedConversationButton extends ConsumerWidget {
  const ChatDiarySavedConversationButton({super.key, required this.entryId});
  final String entryId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chat = ref.watch(chatDiaryForEntryProvider(entryId));
    final session = chat.asData?.value;
    if (session == null) {
      return const SizedBox.shrink();
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () async {
          await context.push(AppRouter.chatDiaryEntryLocation(entryId));
          if (context.mounted) {
            ref.invalidate(chatDiaryForEntryProvider(entryId));
          }
        },
        icon: const Icon(Icons.forum_outlined),
        label: Text(context.l10n.chatDiaryViewSavedConversation),
      ),
    );
  }
}
