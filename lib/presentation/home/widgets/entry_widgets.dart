import 'dart:async' show unawaited;
import 'package:quill_diary/l10n/l10n.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/database/index_database.dart';
import 'package:quill_diary/app/app_colors.dart';
import 'package:quill_diary/shared/presentation/display_format.dart';
import 'package:quill_diary/shared/presentation/page_style.dart';
import 'package:quill_diary/shared/presentation/widgets/entry_date_time_column.dart';
import 'package:quill_diary/shared/presentation/tag_visual.dart';
import 'package:quill_diary/shared/presentation/widgets/entry_cover_thumbnail.dart';
import 'package:quill_diary/shared/presentation/widgets/tag_chip.dart';
import 'package:quill_diary/application/tag/tag_providers.dart';
import '../../editor/providers/editor_draft_providers.dart';
import 'package:quill_diary/application/settings/personalization_providers.dart';
import '../home_entry_helpers.dart';
import 'package:quill_diary/infrastructure/preferences/editor_typography_preferences.dart';
import '../home_layout.dart';
import '../providers/home_providers.dart';
import '../state/home_state.dart';
import 'home_entry_preview_body.dart';
import 'home_pin_glyph.dart';

class HomeTimelineEntryShell extends StatelessWidget {
  const HomeTimelineEntryShell({
    required this.child,
    this.selected = false,
    this.nestedInSection = false,
    super.key,
  });

  final Widget child;
  final bool selected;

  final bool nestedInSection;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final AppColors colors = context.appColors;
    final Color color = nestedInSection
        ? colors.sectionInset
        : colors.sectionCard;
    final double radius = nestedInSection
        ? PageStyle.radiusPanel
        : PageStyle.radiusEntry;
    return Material(
      color: color,
      elevation: nestedInSection ? 0 : 1,
      shadowColor: cs.shadow.withValues(alpha: nestedInSection ? 0 : 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: selected
            ? BorderSide(color: colors.entrySelectedBorder, width: 1.5)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class HomeEntryList extends ConsumerWidget {
  const HomeEntryList({required this.entries, this.controller, super.key});

  final List<EntryIndexRecord> entries;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final HomeEntrySelectionState selection = ref.watch(
      homeEntrySelectionProvider,
    );
    final Map<String, int> tagAccents = ref
        .watch(tagAccentArgbMapProvider)
        .maybeWhen(
          data: (Map<String, int> m) => m,
          orElse: () => const <String, int>{},
        );
    final Set<String> draftEntryIds = ref
        .watch(editorDraftKeysProvider)
        .maybeWhen(
          data: (Set<String> draftKeys) => draftKeys,
          orElse: () => const <String>{},
        );
    final Set<EntryId> pinnedEntryIds = ref
        .watch(homePinnedEntryIdsProvider)
        .maybeWhen(
          data: (Set<EntryId> ids) => ids,
          orElse: () => const <EntryId>{},
        );
    final EditorTypographyPreferences typography =
        watchPersonalizationPreferences(ref).typography;
    final List<EntryId> displayOrder = entries
        .map((EntryIndexRecord item) => item.id)
        .toList();
    final Color pinnedSectionDividerColor = context.appColors.outlineMuted
        .withValues(alpha: 0.42);

    return NotificationListener<OverscrollIndicatorNotification>(
      onNotification: (OverscrollIndicatorNotification notification) {
        notification.disallowIndicator();
        return false;
      },
      child: ListView.separated(
        controller: controller,
        primary: controller == null,
        padding: const EdgeInsets.only(bottom: 16),
        scrollCacheExtent: HomeLayout.entryListCacheExtent,
        itemCount: entries.length,
        separatorBuilder: (BuildContext context, int index) {
          final bool showPinnedSectionDivider =
              !selection.isActive &&
              pinnedEntryIds.contains(entries[index].id) &&
              index + 1 < entries.length &&
              !pinnedEntryIds.contains(entries[index + 1].id);
          if (showPinnedSectionDivider) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Divider(
                height: 1,
                thickness: 1,
                color: pinnedSectionDividerColor,
              ),
            );
          }
          return const SizedBox(height: 14);
        },
        itemBuilder: (BuildContext context, int index) {
          final EntryIndexRecord entry = entries[index];
          final bool selected = selection.selectedIds.contains(entry.id);
          return HomeTimelineEntryShell(
            key: ValueKey<String>(entry.id),
            selected: selection.isActive && selected,
            child: HomeEntryCard(
              entry: entry,
              typography: typography,
              selectionActive: selection.isActive,
              selected: selected,
              tagAccents: tagAccents,
              showUnsavedDraft: draftEntryIds.contains(entry.id),
              isPinned: pinnedEntryIds.contains(entry.id),
              onTap: () {
                if (selection.isActive) {
                  ref
                      .read(homeEntrySelectionProvider.notifier)
                      .toggle(entry.id, displayOrder: displayOrder);
                  return;
                }
                unawaited(context.push('/editor/${entry.id}'));
              },
              onLongPress: () {
                if (selection.isActive) {
                  ref
                      .read(homeEntrySelectionProvider.notifier)
                      .toggle(entry.id, displayOrder: displayOrder);
                  return;
                }
                ref
                    .read(homeEntrySelectionProvider.notifier)
                    .enterWith(entry.id, displayOrder: displayOrder);
              },
            ),
          );
        },
      ),
    );
  }
}

class HomeEntryCard extends StatelessWidget {
  const HomeEntryCard({
    required this.entry,
    required this.typography,
    required this.selectionActive,
    required this.selected,
    required this.tagAccents,
    required this.showUnsavedDraft,
    this.isPinned = false,
    required this.onTap,
    required this.onLongPress,
    super.key,
  });

  final EntryIndexRecord entry;
  final EditorTypographyPreferences typography;
  final bool selectionActive;
  final bool selected;
  final Map<String, int> tagAccents;
  final bool showUnsavedDraft;
  final bool isPinned;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final String? trimmedTitle = entry.title?.trim();
    final bool hasTitle = trimmedTitle != null && trimmedTitle.isNotEmpty;
    final bool showPreview =
        hasTitle &&
        (entry.previewMarkdown.trim().isNotEmpty ||
            entry.previewText.trim().isNotEmpty);
    final double selectionLeadingWidth = selectionActive ? 34 : 0;
    final TextStyle titleStyle = typography.listTitleTextStyle(theme.textTheme);
    final TextStyle previewStyle = typography.listPreviewTextStyle(
      theme.textTheme,
      color: cs.onSurfaceVariant,
    );

    return Material(
      color: selectionActive && selected
          ? Color.alphaBlend(
              cs.primaryContainer.withValues(alpha: 0.34),
              cs.surface,
            )
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(PageStyle.radiusEntry),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              HomeEntryCardHeader(
                entry: entry,
                titleStyle: titleStyle,
                showPinned: isPinned,
                trailing: HomeEntryCardRightDateTime(entry: entry),
                leading: selectionActive
                    ? Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          selected
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: selected ? cs.primary : cs.onSurfaceVariant,
                          size: 22,
                        ),
                      )
                    : null,
                leadingGap: selectionActive ? 12 : 0,
              ),
              HomeEntryListTagsWrap(
                tags: entry.tags,
                charCount: entry.charCount,
                tagAccents: tagAccents,
                showUnsavedDraft: showUnsavedDraft,
                padding: EdgeInsets.only(left: selectionLeadingWidth, top: 5),
              ),
              if (showPreview) ...<Widget>[
                const SizedBox(height: 8),
                Padding(
                  padding: EdgeInsets.only(left: selectionLeadingWidth),
                  child: HomeEntryPreviewBody(
                    previewMarkdown: entry.previewMarkdown,
                    fallbackText: entry.previewText,
                    textStyle: previewStyle,
                    maxLines: 3,
                    lineSpacing: typography.bodyParagraphSpacing,
                  ),
                ),
              ],
              if (entry.previewImagePaths.isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                Padding(
                  padding: EdgeInsets.only(left: selectionLeadingWidth),
                  child: HomeEntryPreviewImageStrip(
                    paths: entry.previewImagePaths,
                    thumbSize: 76,
                    lazyLoad: true,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class HomeCompactEntryList extends ConsumerWidget {
  const HomeCompactEntryList({required this.entries, super.key});

  final List<EntryIndexRecord> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final Map<String, int> tagAccents = ref
        .watch(tagAccentArgbMapProvider)
        .maybeWhen(
          data: (Map<String, int> m) => m,
          orElse: () => const <String, int>{},
        );
    final Set<String> draftEntryIds = ref
        .watch(editorDraftKeysProvider)
        .maybeWhen(
          data: (Set<String> draftKeys) => draftKeys,
          orElse: () => const <String>{},
        );
    final EditorTypographyPreferences typography =
        watchPersonalizationPreferences(ref).typography;
    final TextStyle titleStyle = typography.listTitleTextStyle(theme.textTheme);
    final TextStyle previewStyle = typography.listCompactPreviewTextStyle(
      theme.textTheme,
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Column(
      children: entries.map((EntryIndexRecord entry) {
        final String? trimmedTitle = entry.title?.trim();
        final bool hasTitle = trimmedTitle != null && trimmedTitle.isNotEmpty;
        final bool showPreview =
            hasTitle &&
            (entry.previewMarkdown.trim().isNotEmpty ||
                entry.previewText.trim().isNotEmpty);

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: HomeTimelineEntryShell(
            nestedInSection: true,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => unawaited(context.push('/editor/${entry.id}')),
                borderRadius: BorderRadius.circular(PageStyle.radiusPanel),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      HomeEntryCardHeader(
                        entry: entry,
                        titleStyle: titleStyle,
                        trailing: HomeEntryCardRightDateTime(
                          entry: entry,
                          compact: true,
                        ),
                      ),
                      HomeEntryListTagsWrap(
                        tags: entry.tags,
                        charCount: entry.charCount,
                        tagAccents: tagAccents,
                        showUnsavedDraft: draftEntryIds.contains(entry.id),
                        compactTags: true,
                        padding: const EdgeInsets.only(top: 4),
                      ),
                      if (showPreview) ...<Widget>[
                        const SizedBox(height: 6),
                        HomeEntryPreviewBody(
                          previewMarkdown: entry.previewMarkdown,
                          fallbackText: entry.previewText,
                          textStyle: previewStyle,
                          maxLines: 3,
                          lineSpacing: typography.bodyParagraphSpacing,
                        ),
                      ],
                      if (entry.previewImagePaths.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 8),
                        HomeEntryPreviewImageStrip(
                          paths: entry.previewImagePaths,
                          thumbSize: 52,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class HomeEntryListTagsWrap extends StatelessWidget {
  const HomeEntryListTagsWrap({
    required this.tags,
    required this.charCount,
    required this.tagAccents,
    required this.showUnsavedDraft,
    this.compactTags = false,
    this.padding,
    super.key,
  });

  final List<String> tags;
  final int charCount;
  final Map<String, int> tagAccents;
  final bool showUnsavedDraft;
  final bool compactTags;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<String> trimmedTags = tags
        .map((String t) => t.trim())
        .where((String t) => t.isNotEmpty)
        .toList();
    final bool showTagRow =
        trimmedTags.isNotEmpty || charCount > 0 || showUnsavedDraft;

    if (!showTagRow) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: SizedBox(
        width: double.infinity,
        child: Wrap(
          spacing: compactTags ? 5 : 6,
          runSpacing: 4,
          children: <Widget>[
            if (showUnsavedDraft)
              TagChip.pair(
                label: context.l10n.homeUnsavedDraftLabel,
                pair: tagUnsavedPair(theme.colorScheme, context.appColors),
                compact: compactTags,
              ),
            if (charCount > 0)
              TagChip.pair(
                label: DisplayFormat.formatCharCount(context.l10n, charCount),
                pair: tagCharCountPair(theme.colorScheme),
                compact: compactTags,
              ),
            ...trimmedTags.map(
              (String tag) => TagChip.pair(
                label: tag,
                pair: tagResolvedAccentPair(
                  tag,
                  theme.colorScheme,
                  tagAccents,
                  context.appColors,
                ),
                compact: compactTags,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeEntryCardHeader extends StatelessWidget {
  const HomeEntryCardHeader({
    required this.entry,
    required this.titleStyle,
    this.leading,
    this.leadingGap = 0,
    this.trailing,
    this.showPinned = false,
    super.key,
  });

  final EntryIndexRecord entry;
  final TextStyle? titleStyle;
  final Widget? leading;
  final double leadingGap;
  final Widget? trailing;
  final bool showPinned;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ?leading,
        if (leading != null && leadingGap > 0) SizedBox(width: leadingGap),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (showPinned) ...<Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: HomePinGlyph(
                    icon: Icons.push_pin_rounded,
                    size: 18,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  entryListHeadline(entry),
                  style: titleStyle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.start,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        trailing ?? HomeEntryCardRightDateTime(entry: entry),
      ],
    );
  }
}

class HomeEntryCardRightDateTime extends StatelessWidget {
  const HomeEntryCardRightDateTime({
    required this.entry,
    this.compact = false,
    super.key,
  });

  final EntryIndexRecord entry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return EntryDateTimeColumn(
      date: entry.date,
      at: entry.createdAt,
      compact: compact,
      maxWidth: compact ? 88 : 112,
    );
  }
}

class HomeEntryPreviewImageStrip extends StatelessWidget {
  const HomeEntryPreviewImageStrip({
    required this.paths,
    this.thumbSize = 72,
    this.lazyLoad = false,
    super.key,
  });

  final List<String> paths;
  final double thumbSize;
  final bool lazyLoad;

  @override
  Widget build(BuildContext context) {
    if (paths.isEmpty) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: thumbSize,
      child: ClipRect(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.hardEdge,
          child: Row(
            children: <Widget>[
              for (int i = 0; i < paths.length; i++)
                Padding(
                  padding: EdgeInsets.only(
                    right: i < paths.length - 1 ? 10 : 0,
                  ),
                  child: lazyLoad
                      ? LazyEntryCoverThumbnail(
                          encryptedFilePath: paths[i],
                          size: thumbSize,
                          staggerIndex: i,
                          borderRadius: BorderRadius.circular(
                            PageStyle.radiusThumbSmall,
                          ),
                        )
                      : EntryCoverThumbnail(
                          encryptedFilePath: paths[i],
                          size: thumbSize,
                          borderRadius: BorderRadius.circular(
                            PageStyle.radiusThumbSmall,
                          ),
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
