import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/ai/ai_connection_providers.dart';
import 'package:quill_diary/application/chat_diary/chat_diary_providers.dart';
import 'package:quill_diary/application/diary_organization/diary_organization_controller.dart';
import 'package:quill_diary/application/session/session_providers.dart';
import 'package:quill_diary/domain/diary/diary_entry.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/navigation/app_routes.dart';
import 'package:quill_diary/shared/presentation/app_feedback.dart';
import 'package:quill_diary/shared/presentation/widgets/adaptive_panel.dart';
import 'package:quill_diary/shared/presentation/widgets/app_choice_card.dart';

class DiaryAiActionsButton extends ConsumerWidget {
  const DiaryAiActionsButton({
    super.key,
    required this.entryId,
    this.onEntryUpdated,
  });
  final String entryId;
  final ValueChanged<DiaryEntry>? onEntryUpdated;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chat = ref.watch(chatDiaryForEntryProvider(entryId));
    // AI 關閉時仍可開啟已保存的聊天，只停用整理。
    final enabled =
        !chat.isLoading && (ref.watch(aiEnabledProvider) || chat.value != null);
    final colors = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: context.l10n.organizationAiActions,
      style: IconButton.styleFrom(
        fixedSize: const Size.square(44),
        minimumSize: const Size.square(44),
        padding: EdgeInsets.zero,
        foregroundColor: Theme.of(context).colorScheme.primary,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: !enabled
          ? null
          : () async {
              final picker = _EntryAiActionPicker(entryId: entryId);
              final organize = await showAdaptivePanel<bool>(
                context: context,
                builder: (_) => picker,
              );
              if (!context.mounted ||
                  organize == null ||
                  (organize && !ref.read(aiEnabledProvider))) {
                return;
              }
              if (organize) {
                final saved = await context.push<DiaryEntry>(
                  AppRoutes.diaryOrganizationLocation(entryId),
                );
                if (context.mounted && saved != null) {
                  onEntryUpdated?.call(saved);
                }
              } else {
                await context.push<void>(
                  AppRoutes.chatDiaryEntryLocation(entryId),
                );
              }
              if (context.mounted) {
                ref.invalidate(chatDiaryForEntryProvider(entryId));
                ref.invalidate(organizationDraftProvider(entryId));
              }
            },
      icon: Text(
        context.l10n.chatDiaryAiIcon,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: enabled
              ? colors.primary
              : colors.onSurface.withValues(alpha: 0.38),
        ),
      ),
    );
  }
}

class _EntryAiActionPicker extends ConsumerStatefulWidget {
  const _EntryAiActionPicker({required this.entryId});
  final String entryId;
  @override
  ConsumerState<_EntryAiActionPicker> createState() =>
      _EntryAiActionPickerState();
}

class _EntryAiActionPickerState extends ConsumerState<_EntryAiActionPicker>
    with WidgetsBindingObserver {
  bool _closed = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void _dismiss() {
    if (!mounted || _closed) return;
    _closed = true;
    final route = ModalRoute.of(context);
    if (route != null && route.isActive) route.navigator?.removeRoute(route);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _dismiss();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(effectiveAppSessionProvider, (previous, next) {
      if (next.hasError ||
          previous?.value?.session != next.value?.session ||
          next.value?.isUnlocked == false) {
        _dismiss();
      }
    });
    final l10n = context.l10n;
    final chat = ref.watch(chatDiaryForEntryProvider(widget.entryId));
    final saved = ref.watch(organizationDraftProvider(widget.entryId));
    final aiEnabled = ref.watch(aiEnabledProvider);
    final controller = ref.watch(
      diaryOrganizationControllerProvider(widget.entryId),
    );
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final hasDraft =
            saved.value != null || controller.draft?.persisted == true;
        return AdaptiveChoicePanel(
          title: l10n.organizationAiActions,
          onClose: () => Navigator.pop(context),
          child: Column(
            children: [
              AppChoiceCard(
                key: const ValueKey('entry-ai-conversation'),
                icon: Icons.chat_bubble_outline,
                title: l10n.chatDiaryViewSavedConversation,
                description: chat.hasError
                    ? l10n.aiErrorStorage
                    : chat.value == null
                    ? l10n.organizationNoConversation
                    : l10n.organizationConversationDescription,
                onPressed:
                    chat.isLoading || !chat.hasError && chat.value == null
                    ? null
                    : () {
                        if (chat.hasError) {
                          ref.invalidate(
                            chatDiaryForEntryProvider(widget.entryId),
                          );
                          return;
                        }
                        Navigator.pop(context, false);
                      },
              ),
              const SizedBox(height: 12),
              AppChoiceCard(
                key: const ValueKey('entry-ai-organize'),
                icon: Icons.auto_fix_high_outlined,
                title: hasDraft || controller.busy
                    ? l10n.organizationResume
                    : l10n.organizationTitle,
                description: !aiEnabled
                    ? l10n.aiFeaturesDisabledHint
                    : controller.busy
                    ? l10n.organizationWorking
                    : saved.hasError
                    ? l10n.aiErrorStorage
                    : hasDraft
                    ? l10n.organizationPending
                    : l10n.organizationDescription,
                onPressed: !aiEnabled || saved.isLoading
                    ? null
                    : () {
                        if (saved.hasError) {
                          showAppFeedbackToast(
                            context,
                            l10n.aiErrorStorage,
                            tone: AppFeedbackTone.error,
                          );
                          ref.invalidate(
                            organizationDraftProvider(widget.entryId),
                          );
                          return;
                        }
                        Navigator.pop(context, true);
                      },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
