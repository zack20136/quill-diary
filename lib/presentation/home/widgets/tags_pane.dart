import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/diary/diary_entry_providers.dart';
import 'package:quill_diary/application/errors/user_facing_error.dart';
import 'package:quill_diary/application/home/home_browse_state.dart';
import 'package:quill_diary/application/home/home_entry_query_providers.dart';
import 'package:quill_diary/application/session/session_providers.dart';
import 'package:quill_diary/application/session/session_state.dart';
import 'package:quill_diary/application/tag/tag_catalog_usage.dart';
import 'package:quill_diary/application/tag/tag_defaults.dart';
import 'package:quill_diary/application/tag/tag_providers.dart';
import 'package:quill_diary/application/vault/vault_providers.dart';
import 'package:quill_diary/domain/diary/diary_entry_summary.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/domain/tag/tag.dart';
import 'package:quill_diary/infrastructure/database/entry_index_sorting.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/home/home_formatters.dart';
import 'package:quill_diary/presentation/home/home_layout.dart';
import 'package:quill_diary/presentation/home/widgets/home_scroll_affordance.dart';
import 'package:quill_diary/presentation/home/widgets/home_selection_toolbar.dart';
import 'package:quill_diary/presentation/home/widgets/home_shared_widgets.dart';
import 'package:quill_diary/presentation/tag/widgets/tag_accent_composer_dialog.dart';
import 'package:quill_diary/shared/presentation/accent_visual.dart';
import 'package:quill_diary/shared/presentation/app_colors.dart';
import 'package:quill_diary/shared/presentation/app_feedback.dart';
import 'package:quill_diary/shared/presentation/app_scrollbar.dart';
import 'package:quill_diary/shared/presentation/page_style.dart';
import 'package:quill_diary/shared/presentation/tag_visual.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_shell.dart';
import 'package:quill_diary/shared/presentation/widgets/app_loading_state.dart';
import 'package:quill_diary/shared/presentation/widgets/app_state_card.dart';

class TagsManagePane extends ConsumerStatefulWidget {
  const TagsManagePane({required this.sessionState, super.key});

  final AppSessionState sessionState;

  @override
  ConsumerState<TagsManagePane> createState() => _TagsManagePaneState();
}

class _TagsManagePaneState extends ConsumerState<TagsManagePane> {
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _pageScrollController = ScrollController();
  final ScrollController _tagListScrollController = ScrollController();

  String? _previewTagLabel;
  bool _seedingDefaultTags = false;
  bool _selectionMode = false;
  final Set<String> _selectedTagKeys = {};
  bool _deletingTags = false;
  int _deleteEpoch = 0;
  final ValueNotifier<bool> _tagListThumbDragging = ValueNotifier<bool>(false);
  ScrollHoldController? _pageScrollHold;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(covariant TagsManagePane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.sessionState.isUnlocked ||
        oldWidget.sessionState.session != widget.sessionState.session) {
      _clearSelection();
      _previewTagLabel = null;
      _deleteEpoch++;
      _deletingTags = false;
    }
  }

  void _clearSelection() {
    _selectionMode = false;
    _selectedTagKeys.clear();
  }

  void _toggleTagSelection(String label) {
    FocusScope.of(context).unfocus();
    setState(() {
      _selectionMode = true;
      final normalized = normalizeText(label);
      if (!_selectedTagKeys.remove(normalized)) {
        _selectedTagKeys.add(normalized);
      }
    });
  }

  bool _isCurrentSession(UnlockedVaultSession session) {
    if (!mounted ||
        !widget.sessionState.isUnlocked ||
        widget.sessionState.session != session) {
      return false;
    }
    final current = ref.read(effectiveAppSessionProvider);
    return !current.isLoading &&
        current.value?.isUnlocked == true &&
        current.value?.session == session;
  }

  @override
  void dispose() {
    _pageScrollHold?.cancel();
    _tagListThumbDragging.dispose();
    _searchCtrl.dispose();
    _pageScrollController.dispose();
    _tagListScrollController.dispose();
    super.dispose();
  }

  Future<void> _presentComposer({
    required Map<String, int> accentMap,
    String? existingLabel,
  }) async {
    final UnlockedVaultSession? session = widget.sessionState.session;
    if (session == null || !_isCurrentSession(session) || _deletingTags) return;
    final int? initialArgb = existingLabel == null
        ? null
        : accentMap[normalizeText(existingLabel)];
    bool? initialAccentIsCustom;
    if (existingLabel != null) {
      final List<TagCatalogItem> catalog = await ref.read(
        tagCatalogProvider.future,
      );
      for (final TagCatalogItem item in catalog) {
        if (item.normalized == normalizeText(existingLabel)) {
          initialAccentIsCustom = item.accentIsCustom;
          break;
        }
      }
    }
    if (!mounted || !_isCurrentSession(session)) {
      return;
    }
    final String? savedLabel = await showTagAccentComposerDialog(
      context: context,
      titleText: existingLabel == null
          ? context.l10n.tagAddTitle
          : context.l10n.tagEditTitle,
      initialDisplayLabel: existingLabel,
      sessionForRename: existingLabel == null ? null : session,
      initialAccentArgb: initialArgb,
      initialAccentIsCustom: initialAccentIsCustom,
      primaryButtonLabel: context.l10n.tagSaveButton,
      onDelete: existingLabel == null
          ? null
          : () => _deleteTags([existingLabel], session: session),
    );
    if (!_isCurrentSession(session) || savedLabel == null) {
      return;
    }

    if (existingLabel != null) {
      ref.read(diaryRevisionProvider.notifier).bump();
      if (_previewTagLabel != null &&
          normalizeText(_previewTagLabel!) == normalizeText(existingLabel)) {
        setState(() => _previewTagLabel = savedLabel);
      }
    }
  }

  Future<bool> _deleteTags(
    List<String> labels, {
    required UnlockedVaultSession session,
    bool fromSelection = false,
  }) async {
    if (labels.isEmpty || _deletingTags || !_isCurrentSession(session)) {
      return false;
    }
    final operation = ++_deleteEpoch;
    final deleted = <String>{};
    var started = false;
    var entryCount = 0;
    Object? failure;
    setState(() => _deletingTags = true);
    try {
      final confirmed = await showAppConfirmDialog(
        context: context,
        title: context.l10n.homeDeleteTagTitle,
        content: fromSelection
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(context.l10n.homeDeleteTagsConfirm(labels.length)),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.3,
                    ),
                    child: SingleChildScrollView(
                      child: Text(labels.join('\n')),
                    ),
                  ),
                ],
              )
            : Text(context.l10n.homeDeleteTagConfirm(labels.single)),
        cancelLabel: context.l10n.commonActionCancel,
        confirmLabel: context.l10n.commonActionDelete,
        confirmStyle: AppConfirmStyle.destructive,
      );
      if (!confirmed ||
          !_isCurrentSession(session) ||
          operation != _deleteEpoch) {
        return false;
      }
      final repository = ref.read(vaultRepositoryProvider);
      for (final label in labels) {
        if (!_isCurrentSession(session) || operation != _deleteEpoch) break;
        started = true;
        entryCount += await repository.removeTagFromAllEntries(session, label);
        deleted.add(normalizeText(label));
      }
    } on Object catch (error) {
      if (!_isCurrentSession(session) || operation != _deleteEpoch) {
        return false;
      }
      failure = error;
      if (!fromSelection) rethrow;
    } finally {
      if (_isCurrentSession(session) && operation == _deleteEpoch) {
        if (started) {
          ref.invalidate(tagCatalogProvider);
          ref.invalidate(tagAccentArgbMapProvider);
          ref.read(diaryRevisionProvider.notifier).bump();
        }
        setState(() {
          _deletingTags = false;
          if (deleted.contains(normalizeText(_previewTagLabel ?? ''))) {
            _previewTagLabel = null;
          }
          _selectedTagKeys.removeAll(deleted);
          if (fromSelection && deleted.length == labels.length) _clearSelection();
        });
      }
    }
    if (!mounted || !_isCurrentSession(session) || operation != _deleteEpoch) {
      return false;
    }
    if (failure != null) {
      showAppFeedbackToast(
        context,
        context.l10n.homeTagsDeletePartial(
          deleted.length,
          labels.length - deleted.length,
          userFacingErrorMessage(failure, l10n: context.l10n),
        ),
        tone: AppFeedbackTone.error,
      );
      return false;
    }
    if (deleted.length != labels.length) return false;
    showAppFeedbackToast(
      context,
      fromSelection
          ? context.l10n.homeTagsDeleted(labels.length)
          : entryCount == 0
          ? context.l10n.homeTagDeleted(labels.single)
          : homeTagRemovedFromEntries(context.l10n, entryCount, labels.single),
      tone: AppFeedbackTone.success,
    );
    return true;
  }

  List<DiaryEntrySummary> _entriesMatchingTag(
    List<DiaryEntrySummary> all,
    String displayLabel,
  ) {
    final String norm = normalizeText(displayLabel);
    final List<DiaryEntrySummary> out = all
        .where(
          (DiaryEntrySummary e) =>
              e.tags.any((String t) => normalizeText(t) == norm),
        )
        .toList();
    out.sort(compareEntriesNewestFirst);
    return out;
  }

  void _onTagTap(String label) {
    if (_selectionMode) {
      _toggleTagSelection(label);
      return;
    }
    final String normalized = normalizeText(label);
    if (_previewTagLabel != null &&
        normalizeText(_previewTagLabel!) == normalized) {
      setState(() => _previewTagLabel = null);
    } else {
      setState(() => _previewTagLabel = label);
    }
  }

  Future<void> _seedDefaultTags() async {
    if (_seedingDefaultTags) {
      return;
    }
    setState(() => _seedingDefaultTags = true);
    try {
      final bool created = await ref
          .read(vaultRepositoryProvider)
          .seedDefaultTagCatalogIfEmpty(
            defaultTagCatalogForLocale(Localizations.localeOf(context)),
          );
      ref.invalidate(tagCatalogProvider);
      ref.invalidate(tagAccentArgbMapProvider);
      ref.read(diaryRevisionProvider.notifier).bump();
      if (!mounted) {
        return;
      }
      if (created) {
        showAppFeedbackToast(
          context,
          context.l10n.homeCreateDefaultTagsSuccess,
          tone: AppFeedbackTone.success,
        );
      }
    } on Object catch (error) {
      if (mounted) {
        showAppFeedbackToast(
          context,
          userFacingErrorMessage(error, l10n: context.l10n),
          tone: AppFeedbackTone.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _seedingDefaultTags = false);
      }
    }
  }

  List<Widget> _tagDiaryPreviewSlivers(
    List<DiaryEntrySummary> records,
    ThemeData theme,
    ColorScheme cs,
  ) {
    if (_previewTagLabel == null) {
      return <Widget>[
        SliverToBoxAdapter(
          child: HomeSectionCard(
            title: context.l10n.homeTagPreviewTitle,
            stripeColor: cs.primary,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.swipe_vertical_rounded,
                    size: 40,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.homeTagPreviewTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.l10n.homeTagListGuide,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.42,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ];
    }

    final List<DiaryEntrySummary> matched = _entriesMatchingTag(
      records,
      _previewTagLabel!,
    );

    if (matched.isEmpty) {
      return <Widget>[
        SliverToBoxAdapter(
          child: HomeSectionCard(
            title: context.l10n.homeDiarySectionTag(_previewTagLabel!),
            stripeColor: cs.primary,
            child: HomePaneEmptyHint(
              text: context.l10n.homeTagIndexEmptyForTag(_previewTagLabel!),
            ),
          ),
        ),
      ];
    }

    return <Widget>[
      HomeDiarySliverSection(
        title: context.l10n.homeDiarySectionTag(_previewTagLabel!),
        stripeColor: cs.primary,
        entries: matched,
      ),
    ];
  }

  void _setTagListThumbDragging(bool dragging) {
    if (dragging) {
      if (_pageScrollController.hasClients) {
        _pageScrollHold?.cancel();
        _pageScrollHold = _pageScrollController.position.hold(() {});
      }
    } else {
      _pageScrollHold?.cancel();
      _pageScrollHold = null;
    }
    _tagListThumbDragging.value = dragging;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(homeTabProvider, (_, next) {
      if (next != HomeTab.tags && _selectionMode) {
        setState(_clearSelection);
      }
    });
    if (!widget.sessionState.isUnlocked ||
        widget.sessionState.session == null) {
      return HomeBlockedEntriesPane(sessionState: widget.sessionState);
    }

    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final AsyncValue<List<DiaryEntrySummary>> entriesAsync = ref.watch(
      allDiaryEntrySummariesProvider,
    );
    final Map<String, int> accentMap = ref
        .watch(tagAccentArgbMapProvider)
        .maybeWhen(
          data: (Map<String, int> m) => m,
          orElse: () => const <String, int>{},
        );

    final String q = _searchCtrl.text.trim().toLowerCase();
    final mergedTags = mergeTagCatalogWithUsage(
      ref.watch(tagCatalogProvider).value ?? const <TagCatalogItem>[],
      diaryPresenceTagCounts(entriesAsync.value ?? const []),
    );
    final list = mergedTags
        .where((item) => q.isEmpty || item.label.toLowerCase().contains(q))
        .toList();
    final selectedItems = list
        .where((item) => _selectedTagKeys.contains(normalizeText(item.label)))
        .toList();

    return PopScope(
      canPop: !_selectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selectionMode && !_deletingTags) {
          setState(_clearSelection);
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          HomeScrollbarGutter(
            child: _selectionMode
                ? HomeSelectionToolbar(
                    selectedCount: selectedItems.length,
                    allSelected:
                        list.isNotEmpty && selectedItems.length == list.length,
                    enabled: !_deletingTags,
                    onCancel: () => setState(_clearSelection),
                    onSelectAll: () => setState(() {
                      if (selectedItems.length == list.length) {
                        _selectedTagKeys.clear();
                      } else {
                        _selectedTagKeys
                          ..clear()
                          ..addAll(
                            list.map((item) => normalizeText(item.label)),
                          );
                      }
                    }),
                    actions: [
                      HomeSelectionAction(
                        tooltip: context.l10n.commonActionDelete,
                        icon: Icons.delete_outline_rounded,
                        destructive: true,
                        enabled: selectedItems.isNotEmpty,
                        iconWidget: _deletingTags
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : null,
                        onPressed: () => _deleteTags(
                          selectedItems.map((item) => item.label).toList(),
                          session: widget.sessionState.session!,
                          fromSelection: true,
                        ),
                      ),
                    ],
                  )
                : SizedBox(
                    height: HomeLayout.searchRowControlHeight,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Expanded(
                          child: HomeSearchTextField(
                            controller: _searchCtrl,
                            hintText: context.l10n.homeTagSearchHint,
                          ),
                        ),
                        const SizedBox(width: 8),
                        HomeCircleIconButton(
                          tooltip: context.l10n.homeTooltipAddTag,
                          onPressed: () =>
                              _presentComposer(accentMap: accentMap),
                          icon: Icons.add_rounded,
                          size: HomeLayout.searchRowControlHeight,
                          backgroundColor: cs.primaryContainer,
                          foregroundColor: cs.onPrimaryContainer,
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: entriesAsync.when(
              data: (List<DiaryEntrySummary> records) {
                if (mergedTags.isEmpty) {
                  return HomeScrollbarGutter(
                    child: AppStateCard(
                      icon: Icons.label_outline_rounded,
                      title: context.l10n.homeNoTagsTitle,
                      message: context.l10n.homeNoTagsMessage,
                      actionLabel: _seedingDefaultTags
                          ? null
                          : context.l10n.homeCreateDefaultTagsButton,
                      onAction: _seedingDefaultTags ? null : _seedDefaultTags,
                    ),
                  );
                }
                if (list.isEmpty && q.isNotEmpty) {
                  return HomeScrollbarGutter(
                    child: AppStateCard(
                      icon: Icons.search_off_rounded,
                      title: context.l10n.homeSearchNoResultsTitle,
                      message: context.l10n.homeSearchNoResultsMessage,
                      actionLabel: context.l10n.commonClearSearchTooltip,
                      onAction: _searchCtrl.clear,
                    ),
                  );
                }
                final List<Widget> tagTiles = <Widget>[
                  for (int i = 0; i < list.length; i++) ...<Widget>[
                    if (i > 0) const SizedBox(height: 6),
                    Builder(
                      builder: (BuildContext context) {
                        final TagCatalogUsageItem e = list[i];
                        final (Color bg, Color fg) = tagResolvedAccentPair(
                          e.label,
                          cs,
                          accentMap,
                          context.appColors,
                        );
                        final bool isRowSelected = _selectionMode
                            ? _selectedTagKeys.contains(normalizeText(e.label))
                            : _previewTagLabel != null &&
                                  normalizeText(_previewTagLabel!) ==
                                      normalizeText(e.label);

                        return Material(
                          color: context.appColors.sectionInset,
                          elevation: isRowSelected ? 1.5 : 0,
                          shadowColor: cs.shadow.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(
                            PageStyle.radiusPanel,
                          ),
                          child: ListTile(
                            key: ValueKey('tag-row-${normalizeText(e.label)}'),
                            dense: true,
                            minVerticalPadding: 0,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                PageStyle.radiusPanel,
                              ),
                              side: isRowSelected
                                  ? BorderSide(
                                      color: cs.primary.withValues(alpha: 0.55),
                                      width: 1.4,
                                    )
                                  : BorderSide.none,
                            ),
                            selected: isRowSelected,
                            selectedTileColor: cs.primaryContainer.withValues(
                              alpha: 0.42,
                            ),
                            onTap: _deletingTags
                                ? null
                                : () => _onTagTap(e.label),
                            onLongPress: _deletingTags
                                ? null
                                : () => _toggleTagSelection(e.label),
                            leading: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                if (_selectionMode) ...<Widget>[
                                  HomeSelectionIndicator(
                                    selected: isRowSelected,
                                  ),
                                  const SizedBox(width: 10),
                                ],
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: bg,
                                    border: () {
                                      final BorderSide? side =
                                          accentChipBorderSide(
                                            context.appColors,
                                            cs,
                                            bg,
                                            fg,
                                          );
                                      return side == null
                                          ? null
                                          : Border.fromBorderSide(side);
                                    }(),
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.sell_rounded,
                                    color: fg,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                            title: Text(
                              e.label,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(
                                  homeTagRowEntryCount(context.l10n, e.count),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                                if (!_selectionMode) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    context.l10n.homeTagRowTapHint,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant.withValues(
                                        alpha: 0.82,
                                      ),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            trailing: _selectionMode
                                ? null
                                : IconButton(
                                    tooltip: context.l10n.homeTooltipEditTag,
                                    onPressed: _deletingTags
                                        ? null
                                        : () => _presentComposer(
                                            accentMap: accentMap,
                                            existingLabel: e.label,
                                          ),
                                    style: IconButton.styleFrom(
                                      fixedSize: const Size(44, 44),
                                      backgroundColor: cs.surfaceContainerLow,
                                      foregroundColor: cs.onSurfaceVariant,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      size: 20,
                                    ),
                                  ),
                          ),
                        );
                      },
                    ),
                  ],
                ];

                return HomeScrollAffordance(
                  controller: _pageScrollController,
                  child: NotificationListener<OverscrollIndicatorNotification>(
                    onNotification:
                        (OverscrollIndicatorNotification notification) {
                          notification.disallowIndicator();
                          return false;
                        },
                    child: ValueListenableBuilder<bool>(
                      valueListenable: _tagListThumbDragging,
                      builder: (BuildContext context, bool dragging, _) {
                        return CustomScrollView(
                          controller: _pageScrollController,
                          physics: dragging
                              ? const NeverScrollableScrollPhysics()
                              : appBouncingScrollPhysics,
                          scrollCacheExtent: HomeLayout.entryListCacheExtent,
                          slivers: <Widget>[
                            SliverToBoxAdapter(
                              child: HomeSectionCard(
                                title: homeTagsSectionTitle(
                                  context.l10n,
                                  list.length,
                                ),
                                stripeColor: cs.tertiary,
                                padding: HomeLayout.tagListSectionCardPadding,
                                child: SizedBox(
                                  height: HomeLayout.tagListSectionHeight,
                                  child: NestedPanelScrollbar(
                                    controller: _tagListScrollController,
                                    onThumbDragChanged:
                                        _setTagListThumbDragging,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: tagTiles,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SliverToBoxAdapter(
                              child: SizedBox(height: HomeLayout.sectionGap),
                            ),
                            ..._tagDiaryPreviewSlivers(records, theme, cs),
                            const SliverToBoxAdapter(
                              child: SizedBox(height: 24),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                );
              },
              loading: () =>
                  const HomeScrollbarGutter(child: AppLoadingState()),
              error: (Object err, StackTrace _) => HomeScrollbarGutter(
                child: AppStateCard(
                  icon: Icons.error_outline_rounded,
                  title: context.l10n.commonReadFailureTitle,
                  message: userFacingErrorMessage(err, l10n: context.l10n),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
