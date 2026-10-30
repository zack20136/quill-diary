import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/chat_diary/chat_diary_providers.dart';
import 'package:quill_diary/application/home/home_browse_state.dart';
import 'package:quill_diary/application/settings/personalization_providers.dart';
import 'package:quill_diary/domain/chat_diary/chat_diary_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/diary/widgets/diary_entry_date_time.dart';
import 'package:quill_diary/presentation/home/widgets/entry_widgets.dart';
import 'package:quill_diary/shared/navigation/app_routes.dart';
import 'package:quill_diary/shared/presentation/app_colors.dart';
import 'package:quill_diary/shared/presentation/editor_typography_visual.dart';
import 'package:quill_diary/shared/presentation/page_style.dart';
import 'package:quill_diary/shared/presentation/tag_visual.dart';
import 'package:quill_diary/shared/presentation/widgets/accent_chip.dart';

class HomeChatDiaryDraftCard extends ConsumerWidget {
  const HomeChatDiaryDraftCard({
    super.key,
    required this.chat,
    required this.entryDisplayOrder,
  });
  final ChatDiarySession chat;
  final List<EntryId> entryDisplayOrder;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final first = chat.activeMessages
        .where((message) => message.isUser && message.text.trim().isNotEmpty)
        .firstOrNull
        ?.text
        .trim();
    final title =
        first ??
        (chat.composerText.trim().isEmpty
            ? context.l10n.chatDiaryUntitledDraft
            : chat.composerText.trim());
    final theme = Theme.of(context);
    final typography = watchPersonalizationPreferences(ref).typography;
    final selection = ref.watch(homeEntrySelectionProvider);
    final selected = selection.selectedChatIds.contains(chat.id);
    void toggleSelection() => ref
        .read(homeEntrySelectionProvider.notifier)
        .toggleChat(chat.id, displayOrder: entryDisplayOrder);
    return HomeTimelineEntryShell(
      selected: selection.isActive && selected,
      child: InkWell(
        borderRadius: BorderRadius.circular(PageStyle.radiusEntry),
        onLongPress: toggleSelection,
        onTap: () async {
          if (selection.isActive) {
            toggleSelection();
            return;
          }
          await context.push(AppRoutes.chatDiaryLocation(chat.id));
          if (context.mounted) {
            ref.invalidate(chatDiarySessionsProvider);
          }
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (selection.isActive) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        selected
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: selected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.chat_bubble_outline, size: 18),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            title,
                            style: typography.listTitleTextStyle(
                              theme.textTheme,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  DiaryEntryDateTime(
                    date: DateOnly(chat.date),
                    at: chat.createdAt,
                    maxWidth: 112,
                  ),
                ],
              ),
              Padding(
                padding: EdgeInsets.only(
                  left: selection.isActive ? 34 : 0,
                  top: 8,
                ),
                child: AccentChip.pair(
                  label: context.l10n.chatDiaryDraftLabel,
                  pair: tagUnsavedPair(context.appColors),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
