import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/chat_diary/chat_diary_providers.dart';
import 'package:quill_diary/application/diary_organization/diary_organization_controller.dart';
import 'package:quill_diary/application/session/session_providers.dart';
import 'package:quill_diary/domain/diary/diary_entry.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/navigation/app_routes.dart';
import 'package:quill_diary/shared/presentation/app_feedback.dart';
import 'package:quill_diary/shared/presentation/page_style.dart';
import 'package:quill_diary/shared/presentation/widgets/app_choice_card.dart';
import 'package:quill_diary/shared/presentation/widgets/app_layout.dart';

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
    return IconButton(
      tooltip: context.l10n.organizationAiActions,
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
              final wide = MediaQuery.sizeOf(context).width >= 600;
              final picker = _EntryAiActionPicker(entryId: entryId, wide: wide);
              final colors = Theme.of(context).colorScheme;
              final organize = wide
                  ? await showDialog<bool>(
                      context: context,
                      builder: (_) => Center(
                        child: AppResponsiveWidth(
                          maxWidth: 480,
                          child: Dialog(
                            insetPadding: EdgeInsets.zero,
                            backgroundColor: colors.surfaceContainerHigh,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                PageStyle.radiusCard,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: picker,
                          ),
                        ),
                      ),
                    )
                  : await showModalBottomSheet<bool>(
                      context: context,
                      useRootNavigator: true,
                      useSafeArea: true,
                      isScrollControlled: true,
                      showDragHandle: false,
                      backgroundColor: colors.surfaceContainerHigh,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(PageStyle.radiusCard),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      builder: (_) => picker,
                    );
              if (!context.mounted || organize == null) return;
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
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _EntryAiActionPicker extends ConsumerStatefulWidget {
  const _EntryAiActionPicker({required this.entryId, required this.wide});
  final String entryId;
  final bool wide;
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
    final controller = ref.watch(
      diaryOrganizationControllerProvider(widget.entryId),
    );
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final hasDraft =
            saved.value != null || controller.draft?.persisted == true;
        return LayoutBuilder(
          builder: (context, constraints) => ConstrainedBox(
            constraints: BoxConstraints(maxHeight: constraints.maxHeight * 0.8),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, widget.wide ? 16 : 12, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!widget.wide) ...[
                      Center(
                        child: Container(
                          width: 32,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                            borderRadius: BorderRadius.circular(
                              PageStyle.radiusPanel,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.organizationAiActions,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          tooltip: l10n.commonCloseTooltip,
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: SingleChildScrollView(
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
                                  chat.isLoading ||
                                      !chat.hasError && chat.value == null
                                  ? null
                                  : () {
                                      if (chat.hasError) {
                                        ref.invalidate(
                                          chatDiaryForEntryProvider(
                                            widget.entryId,
                                          ),
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
                              description: controller.busy
                                  ? l10n.organizationWorking
                                  : saved.hasError
                                  ? l10n.aiErrorStorage
                                  : hasDraft
                                  ? l10n.organizationPending
                                  : l10n.organizationDescription,
                              onPressed: saved.isLoading
                                  ? null
                                  : () {
                                      if (saved.hasError) {
                                        showAppFeedbackToast(
                                          context,
                                          l10n.aiErrorStorage,
                                          tone: AppFeedbackTone.error,
                                        );
                                        ref.invalidate(
                                          organizationDraftProvider(
                                            widget.entryId,
                                          ),
                                        );
                                        return;
                                      }
                                      Navigator.pop(context, true);
                                    },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
