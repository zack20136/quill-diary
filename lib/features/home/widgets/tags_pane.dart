import 'package:flutter/material.dart';
import '../home_formatters.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/security/unlocked_vault_session.dart';
import '../../../domain/shared/value_objects.dart';
import '../../../infrastructure/database/index_database.dart';
import '../../../infrastructure/storage/tag_styles_store.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/presentation/app_feedback.dart';
import '../../../shared/presentation/app_scrollbar.dart';
import '../../../app/app_colors.dart';
import '../../../shared/presentation/page_style.dart';
import '../../../shared/presentation/tag_visual.dart';
import '../../../shared/presentation/widgets/tag_accent_composer_dialog.dart';
import '../../../shared/providers/core_providers.dart';
import '../../../shared/providers/tag_providers.dart';
import '../../../shared/utils/diary_presence_tag_counts.dart';
import '../../../shared/utils/entry_sorting.dart';
import '../../../shared/utils/tag_catalog_merge.dart';
import '../../session/state/app_session_state.dart';
import '../home_layout.dart';
import '../providers/home_providers.dart';
import 'entry_widgets.dart';
import 'home_scroll_affordance.dart';
import 'home_selection_toolbar.dart';
import 'home_shared_widgets.dart';

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

  /// 用於預覽：已選標籤的顯示字串（見 [normalizeText] 比對實際日記）。
  String? _selectedTagLabel;
  bool _seedingDefaultTags = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
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
    if (!mounted) {
      return;
    }
    final Color dialogBarrierColor = context.appColors.scrim;
    final String? savedLabel = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierColor: dialogBarrierColor,
      builder: (BuildContext ctx) {
        return AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(
            left: 22,
            right: 22,
            top: 26,
            bottom: 26 + MediaQuery.viewInsetsOf(ctx).bottom,
          ),
          child: Align(
            child: Material(
              color: Colors.transparent,
              child: TagAccentComposerDialog(
                titleText: existingLabel == null
                    ? ctx.l10n.tagAddTitle
                    : ctx.l10n.tagEditTitle,
                initialDisplayLabel: existingLabel,
                sessionForRename: existingLabel == null ? null : session,
                initialAccentArgb: initialArgb,
                initialAccentIsCustom: initialAccentIsCustom,
                primaryButtonLabel: ctx.l10n.tagSaveButton,
                onDelete: existingLabel == null || session == null
                    ? null
                    : () => _deleteTag(existingLabel, session: session),
              ),
            ),
          ),
        );
      },
    );
    if (!mounted || savedLabel == null) {
      return;
    }

    if (existingLabel != null) {
      await refreshHomeIndexCaches(ref);
      if (_selectedTagLabel != null &&
          normalizeText(_selectedTagLabel!) == normalizeText(existingLabel)) {
        setState(() => _selectedTagLabel = savedLabel);
      }
    }
  }

  Future<void> _deleteTag(
    String label, {
    required UnlockedVaultSession session,
  }) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.homeDeleteTagTitle),
        content: Text(dialogContext.l10n.homeDeleteTagConfirm(label)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.l10n.commonActionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: Text(dialogContext.l10n.commonActionDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    final List<EntryIndexRecord> records =
        ref.read(allEntryIndexRecordsProvider).value ??
        const <EntryIndexRecord>[];
    final int entryCount = _entriesMatchingTag(records, label).length;

    await ref
        .read(vaultRepositoryProvider)
        .removeTagFromAllEntries(session, label);
    ref.invalidate(tagCatalogProvider);
    ref.invalidate(tagAccentArgbMapProvider);
    await refreshHomeIndexCaches(ref);

    if (!mounted) {
      return;
    }

    if (_selectedTagLabel != null &&
        normalizeText(_selectedTagLabel!) == normalizeText(label)) {
      setState(() => _selectedTagLabel = null);
    }

    showAppFeedbackSnackBar(
      context,
      entryCount == 0
          ? context.l10n.homeTagDeleted(label)
          : homeTagRemovedFromEntries(context.l10n, entryCount, label),
    );
  }

  List<EntryIndexRecord> _entriesMatchingTag(
    List<EntryIndexRecord> all,
    String displayLabel,
  ) {
    final String norm = normalizeText(displayLabel);
    final List<EntryIndexRecord> out = all
        .where(
          (EntryIndexRecord e) =>
              e.tags.any((String t) => normalizeText(t) == norm),
        )
        .toList();
    out.sort(compareEntriesNewestFirst);
    return out;
  }

  void _toggleSelectTag(String label) {
    final String normalized = normalizeText(label);
    if (_selectedTagLabel != null &&
        normalizeText(_selectedTagLabel!) == normalized) {
      setState(() => _selectedTagLabel = null);
    } else {
      setState(() => _selectedTagLabel = label);
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
            locale: Localizations.localeOf(context),
          );
      ref.invalidate(tagCatalogProvider);
      ref.invalidate(tagAccentArgbMapProvider);
      await refreshHomeIndexCaches(ref);
      if (!mounted) {
        return;
      }
      if (created) {
        showAppFeedbackSnackBar(
          context,
          context.l10n.homeCreateDefaultTagsButton,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _seedingDefaultTags = false);
      }
    }
  }

  Widget _tagDiaryPreviewPanel(
    List<EntryIndexRecord> records,
    ThemeData theme,
    ColorScheme cs,
  ) {
    if (_selectedTagLabel == null) {
      return HomeSectionCard(
        title: context.l10n.homeTagPreviewTitle,
        stripeColor: cs.primary,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.swipe_vertical_rounded, size: 40, color: cs.outline),
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
      );
    }

    final List<EntryIndexRecord> matched = _entriesMatchingTag(
      records,
      _selectedTagLabel!,
    );

    if (matched.isEmpty) {
      return HomeSectionCard(
        title: context.l10n.homeDiarySectionTag(_selectedTagLabel!),
        stripeColor: cs.primary,
        titleTrail: HomeDiarySectionCloseButton(
          onPressed: () => setState(() => _selectedTagLabel = null),
        ),
        child: HomePaneEmptyHint(
          text: context.l10n.homeTagIndexEmptyForTag(_selectedTagLabel!),
        ),
      );
    }

    return HomeDiaryListSectionCard(
      title: context.l10n.homeDiarySectionTag(_selectedTagLabel!),
      stripeColor: cs.primary,
      titleTrail: HomeDiarySectionCloseButton(
        onPressed: () => setState(() => _selectedTagLabel = null),
      ),
      child: HomeCompactEntryList(entries: matched),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.sessionState.isUnlocked ||
        widget.sessionState.session == null) {
      return HomeBlockedEntriesPane(sessionState: widget.sessionState);
    }

    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final AsyncValue<List<EntryIndexRecord>> entriesAsync = ref.watch(
      allEntryIndexRecordsProvider,
    );
    final Map<String, int> accentMap = ref
        .watch(tagAccentArgbMapProvider)
        .maybeWhen(
          data: (Map<String, int> m) => m,
          orElse: () => const <String, int>{},
        );

    final String q = _searchCtrl.text.trim().toLowerCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          height: kHomeSearchRowControlHeight,
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
                onPressed: () => _presentComposer(accentMap: accentMap),
                icon: Icons.add_rounded,
                size: kHomeSearchRowControlHeight,
                backgroundColor: cs.primaryContainer,
                foregroundColor: cs.onPrimaryContainer,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: entriesAsync.when(
            data: (List<EntryIndexRecord> records) {
              final Map<String, int> freq = diaryPresenceTagCounts(records);
              final List<TagCatalogUsageItem> mergedTags =
                  mergeTagCatalogWithUsage(
                    ref
                        .watch(tagCatalogProvider)
                        .maybeWhen(
                          data: (List<TagCatalogItem> items) => items,
                          orElse: () => const <TagCatalogItem>[],
                        ),
                    freq,
                  );
              if (mergedTags.isEmpty) {
                return HomeStateCard(
                  icon: Icons.label_outline_rounded,
                  title: context.l10n.homeNoTagsTitle,
                  message: context.l10n.homeNoTagsMessage,
                  actionLabel: _seedingDefaultTags
                      ? null
                      : context.l10n.homeCreateDefaultTagsButton,
                  onAction: _seedingDefaultTags ? null : _seedDefaultTags,
                );
              }
              final List<TagCatalogUsageItem> list = mergedTags
                  .where(
                    (TagCatalogUsageItem item) =>
                        q.isEmpty || item.label.toLowerCase().contains(q),
                  )
                  .toList();
              if (list.isEmpty) {
                return Center(
                  child: Text(
                    context.l10n.commonNoTagSearchResults,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: cs.outline,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                );
              }
              final UnlockedVaultSession? session = widget.sessionState.session;
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
                      final bool isRowSelected =
                          _selectedTagLabel != null &&
                          normalizeText(_selectedTagLabel!) ==
                              normalizeText(e.label);

                      return Material(
                        color: context.appColors.sectionInset,
                        elevation: isRowSelected ? 1.5 : 0,
                        shadowColor: cs.shadow.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(
                          PageStyle.radiusPanel,
                        ),
                        child: ListTile(
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
                          onTap: () => _toggleSelectTag(e.label),
                          leading: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: bg,
                              border: () {
                                final BorderSide? side = tagChipBorderSide(
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
                          ),
                          trailing: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 78),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                HomeCircleIconButton(
                                  tooltip: context.l10n.homeTooltipEditTag,
                                  onPressed: () => _presentComposer(
                                    accentMap: accentMap,
                                    existingLabel: e.label,
                                  ),
                                  icon: Icons.edit_outlined,
                                  size: kHomeToolbarActionCircleSize,
                                  backgroundColor: cs.secondaryContainer,
                                  foregroundColor: cs.onSecondaryContainer,
                                ),
                                const SizedBox(width: 6),
                                HomeCircleIconButton(
                                  tooltip: context.l10n.homeTooltipDeleteTag,
                                  onPressed: session == null
                                      ? null
                                      : () => _deleteTag(
                                          e.label,
                                          session: session,
                                        ),
                                  icon: Icons.delete_outline_rounded,
                                  size: kHomeToolbarActionCircleSize,
                                  backgroundColor: cs.errorContainer,
                                  foregroundColor: cs.error,
                                ),
                              ],
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
                  child: CustomScrollView(
                    controller: _pageScrollController,
                    scrollCacheExtent: HomeLayout.entryListCacheExtent,
                    slivers: <Widget>[
                      SliverToBoxAdapter(
                        child: HomeSectionCard(
                          title: homeTagsSectionTitle(
                            context.l10n,
                            list.length,
                          ),
                          stripeColor: cs.tertiary,
                          child: SizedBox(
                            height: HomeLayout.tagListSectionHeight,
                            child: NestedPanelScrollbar(
                              controller: _tagListScrollController,
                              contentPadding: const EdgeInsets.only(right: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: tagTiles,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(
                        child: SizedBox(height: HomeLayout.sectionGap),
                      ),
                      SliverToBoxAdapter(
                        child: _tagDiaryPreviewPanel(records, theme, cs),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    ],
                  ),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (Object err, StackTrace _) => HomeStateCard(
              icon: Icons.error_outline_rounded,
              title: context.l10n.commonReadFailureTitle,
              message: '$err',
            ),
          ),
        ),
      ],
    );
  }
}
