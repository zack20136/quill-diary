import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/people/people_providers.dart';
import 'package:quill_diary/application/people/person_mention_controller.dart';
import 'package:quill_diary/application/session/session_providers.dart';
import 'package:quill_diary/domain/people/person.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/people/widgets/person_composer_dialog.dart';
import 'package:quill_diary/presentation/people/widgets/person_mention_text_field.dart';
import 'package:quill_diary/presentation/people/widgets/person_suggestion_panel.dart';
import 'package:quill_diary/shared/presentation/private_text_controller.dart';

class AiChatInputPanel extends ConsumerStatefulWidget {
  const AiChatInputPanel({
    super.key,
    this.editing = false,
    this.imageIds = const [],
    this.hintText,
    required this.composerKey,
    required this.isBusy,
    required this.canSend,
    required this.composerController,
    required this.composerFocusNode,
    this.imageBuilder,
    this.onCancelEditing,
    this.onPickImages,
    required this.onOpenSettings,
    required this.onSend,
    this.onStop,
    this.maxLines = 5,
  });
  final bool editing;
  final List<String> imageIds;
  final String? hintText;
  final Key composerKey;
  final bool isBusy;
  final bool canSend;
  final PrivateTextController composerController;
  final FocusNode composerFocusNode;
  final Widget Function(String imageId)? imageBuilder;
  final VoidCallback? onCancelEditing;
  final VoidCallback? onPickImages;
  final VoidCallback onOpenSettings;
  final VoidCallback onSend;
  final VoidCallback? onStop;
  final int maxLines;

  @override
  ConsumerState<AiChatInputPanel> createState() => _AiChatInputPanelState();
}

class _AiChatInputPanelState extends ConsumerState<AiChatInputPanel>
    with WidgetsBindingObserver {
  final _mention = PersonMentionController();
  Route<Person>? _personDialog;
  int _mentionVersion = 0;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _mention.addListener(_mentionChanged);
  }

  void _mentionChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(AiChatInputPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isBusy ||
        oldWidget.composerController != widget.composerController ||
        oldWidget.editing != widget.editing) {
      _dismissMention();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() => _foreground = state == AppLifecycleState.resumed);
    if (!_foreground) {
      widget.composerFocusNode.unfocus();
      _dismissMention();
    }
  }

  void _dismissMention() {
    _mentionVersion++;
    _mention.dismiss();
    final route = _personDialog;
    _personDialog = null;
    if (route != null) {
      void remove() {
        if (route.isActive) route.navigator?.removeRoute(route);
      }

      if (SchedulerBinding.instance.schedulerPhase ==
          SchedulerPhase.persistentCallbacks) {
        WidgetsBinding.instance.addPostFrameCallback((_) => remove());
      } else {
        remove();
      }
    }
  }

  List<PersonSuggestion> _suggestions({List<Person>? catalog}) {
    if (widget.isBusy || !_foreground || !_mention.isActive) return const [];
    // 沿用已載入的統計排序，不因輸入 @ 啟動全庫人物分析。
    final stats = ref.exists(peopleMentionStatsMapProvider)
        ? ref.read(peopleMentionStatsMapProvider).asData?.value
        : null;
    return filterPersonSuggestions(
      catalog:
          catalog ??
          ref.read(peopleCatalogProvider).asData?.value.people ??
          const [],
      query: _mention.query,
      mentionedEntryCountById: stats == null
          ? null
          : {
              for (final entry in stats.entries)
                entry.key: entry.value.mentionedEntryCount,
            },
    );
  }

  KeyEventResult _onMentionKeyEvent(FocusNode _, KeyEvent event) {
    if (widget.isBusy) return KeyEventResult.ignored;
    final suggestions = _suggestions();
    final handled = _mention.handleKeyEvent(
      event,
      suggestionCount: suggestions.length,
    );
    if (handled.shouldApplySelection) {
      _applyMention(
        suggestions[_mention.highlightIndex.clamp(0, suggestions.length - 1)],
      );
    }
    return handled.result;
  }

  void _applyMention(PersonSuggestion suggestion) {
    if (widget.isBusy) return;
    _mention.applyMentionLabel(suggestion.person.diaryMentionLabel);
    widget.composerFocusNode.requestFocus();
  }

  Future<void> _createPerson() async {
    final target = _mention.captureReplacementTarget();
    final session = ref.read(effectiveAppSessionProvider).value?.session;
    if (target == null ||
        widget.isBusy ||
        _personDialog != null ||
        session == null) {
      return;
    }
    final version = ++_mentionVersion;
    final person = await showPersonComposerDialog(
      context,
      initialName: _mention.query.trim(),
      onRouteCreated: (route) => _personDialog = route,
    );
    if (!mounted || version != _mentionVersion) return;
    _personDialog = null;
    if (person == null ||
        widget.isBusy ||
        ref.read(effectiveAppSessionProvider).value?.session != session ||
        target.controller != widget.composerController) {
      return;
    }
    if (_mention.applyMentionLabelToTarget(target, person.diaryMentionLabel)) {
      widget.composerFocusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mention.removeListener(_mentionChanged);
    _mention.dispose();
    final route = _personDialog;
    // 父層移除輸入區可能發生於 build，延至此幀結束再關閉對話框。
    if (route != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (route.isActive) route.navigator?.removeRoute(route);
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(effectiveAppSessionProvider, (previous, next) {
      if (next.value?.isUnlocked != true ||
          previous?.value?.session != next.value?.session) {
        _dismissMention();
      }
    });
    final canMention =
        !widget.isBusy &&
        _foreground &&
        ref.watch(effectiveAppSessionProvider).value?.isUnlocked == true;
    final catalog = canMention && _mention.isActive
        ? ref.watch(peopleCatalogProvider).asData?.value
        : null;
    final suggestions = _suggestions(catalog: catalog?.people);
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            key: const ValueKey('ai-composer-surface'),
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.editing)
                  Padding(
                    padding: const EdgeInsets.only(left: 16, right: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.edit_outlined, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.chatDiaryEditingMessage,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ),
                        TextButton(
                          onPressed: widget.isBusy
                              ? null
                              : widget.onCancelEditing,
                          child: Text(l10n.commonActionCancel),
                        ),
                      ],
                    ),
                  ),
                if (widget.imageIds.isNotEmpty)
                  SizedBox(
                    height: 96,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.all(8),
                      children: [
                        for (final id in widget.imageIds)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: widget.imageBuilder!(id),
                          ),
                      ],
                    ),
                  ),
                PersonMentionTextField(
                  fieldKey: widget.composerKey,
                  style: Theme.of(context).textTheme.bodyLarge!,
                  mentionController: canMention ? _mention : null,
                  onMentionKeyEvent: _onMentionKeyEvent,
                  controller: widget.composerController,
                  focusNode: widget.composerFocusNode,
                  minLines: 1,
                  maxLines: widget.maxLines,
                  enabled: !widget.isBusy && _foreground,
                  decoration: InputDecoration(
                    hintText: widget.hintText ?? l10n.chatDiaryMessageHint,
                    hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontStyle: FontStyle.normal,
                    ),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 6, 6),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: widget.isBusy ? null : widget.onOpenSettings,
                        tooltip: l10n.aiSettings,
                        icon: const Icon(Icons.settings_outlined),
                      ),
                      if (widget.onPickImages != null)
                        IconButton(
                          onPressed: widget.isBusy ? null : widget.onPickImages,
                          tooltip: l10n.chatDiaryChooseImages,
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                        ),
                      IconButton(
                        tooltip:
                            !widget.composerController.selection.isValid ||
                                widget.composerController.selection.isCollapsed
                            ? l10n.aiSelectPrivateText
                            : widget.composerController.selectionIsPrivate
                            ? l10n.aiUnhideSelection
                            : l10n.aiHideSelection,
                        onPressed:
                            widget.isBusy ||
                                !widget.composerController.selection.isValid ||
                                widget
                                    .composerController
                                    .selection
                                    .isCollapsed ||
                                (widget
                                        .composerController
                                        .value
                                        .composing
                                        .isValid &&
                                    !widget
                                        .composerController
                                        .value
                                        .composing
                                        .isCollapsed)
                            ? null
                            : () {
                                if (widget
                                    .composerController
                                    .selectionIsPrivate) {
                                  widget.composerController.unhideSelection();
                                } else {
                                  widget.composerController.hideSelection();
                                }
                                widget.composerFocusNode.requestFocus();
                              },
                        icon: Icon(
                          widget.composerController.selectionIsPrivate
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                      const Spacer(),
                      IconButton.filled(
                        onPressed: widget.isBusy
                            ? widget.onStop
                            : widget.canSend
                            ? widget.onSend
                            : null,
                        tooltip: widget.isBusy
                            ? widget.onStop != null
                                  ? l10n.aiStopGeneration
                                  : l10n.chatDiaryWorking
                            : !widget.editing
                            ? l10n.chatDiarySend
                            : l10n.chatDiaryResendMessage,
                        icon: widget.isBusy && widget.onStop != null
                            ? const Icon(Icons.stop_rounded)
                            : widget.isBusy
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.arrow_upward_rounded),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (canMention && _mention.isActive)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: PersonSuggestionPanel(
                suggestions: suggestions,
                highlightIndex: _mention.highlightIndex,
                catalogEmpty: catalog != null && catalog.people.isEmpty,
                background: false,
                onSelected: _applyMention,
                onCreatePerson: () => unawaited(_createPerson()),
              ),
            ),
        ],
      ),
    );
  }
}
