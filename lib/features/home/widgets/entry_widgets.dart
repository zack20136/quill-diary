import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../infrastructure/database/index_database.dart';
import '../../../shared/presentation/display_format.dart';
import '../../../shared/presentation/page_style.dart';
import '../../../shared/presentation/tag_visual.dart';
import '../../../shared/presentation/widgets/entry_cover_thumbnail.dart';
import '../../../shared/providers/tag_providers.dart';
import '../../../shared/utils/weekday_zh.dart';
import '../../editor/providers/editor_draft_providers.dart';
import '../../settings/providers/personalization_providers.dart';
import '../home_copy.dart';
import '../home_entry_helpers.dart';
import '../../../infrastructure/preferences/editor_typography_preferences.dart';
import '../home_layout.dart';
import '../state/home_state.dart';

class HomeTimelineEntryShell extends StatelessWidget {
  const HomeTimelineEntryShell({
    required this.child,
    this.tintedCard = false,
    this.selected = false,
    super.key,
  });

  final Widget child;
  final bool tintedCard;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final Color color = tintedCard ? cs.surfaceContainerLow : cs.surface;
    return Material(
      color: color,
      elevation: tintedCard ? 0 : 1,
      surfaceTintColor: Colors.transparent,
      shadowColor: cs.shadow.withValues(alpha: tintedCard ? 0 : 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          tintedCard ? PageStyle.radiusPanel : PageStyle.radiusEntry,
        ),
        side: selected
            ? BorderSide(color: cs.primary.withValues(alpha: 0.72), width: 1.5)
            : tintedCard
                ? BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4))
                : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class HomeEntryList extends ConsumerWidget {
  const HomeEntryList({required this.entries, super.key});

  final List<EntryIndexRecord> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final HomeEntrySelectionState selection = ref.watch(homeEntrySelectionProvider);
    final Color pageBackground = PageStyle.scaffoldWash(Theme.of(context).colorScheme);
    final Map<String, int> tagAccents = ref.watch(tagAccentArgbMapProvider).maybeWhen(
          data: (Map<String, int> m) => m,
          orElse: () => const <String, int>{},
        );
    final Set<String> draftEntryIds = ref.watch(editorDraftKeysProvider).maybeWhen(
          data: (Set<String> draftKeys) => draftKeys,
          orElse: () => const <String>{},
        );
    final EditorTypographyPreferences typography =
        watchPersonalizationPreferences(ref).typography;

    return NotificationListener<OverscrollIndicatorNotification>(
      onNotification: (OverscrollIndicatorNotification notification) {
        notification.disallowIndicator();
        return false;
      },
      child: ColoredBox(
        color: pageBackground,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
          scrollCacheExtent: HomeLayout.entryListCacheExtent,
          itemCount: entries.length,
          separatorBuilder: (_, _) => const SizedBox(height: 14),
          itemBuilder: (BuildContext context, int index) {
            final EntryIndexRecord entry = entries[index];
            final bool selected = selection.selectedIds.contains(entry.id);
            return HomeTimelineEntryShell(
              selected: selection.isActive && selected,
              child: HomeEntryCard(
                entry: entry,
                typography: typography,
                selectionActive: selection.isActive,
                selected: selected,
                tagAccents: tagAccents,
                showUnsavedDraft: draftEntryIds.contains(entry.id),
                onTap: () {
                  if (selection.isActive) {
                    ref.read(homeEntrySelectionProvider.notifier).toggle(entry.id);
                    return;
                  }
                  unawaited(context.push('/editor/${entry.id}'));
                },
                onLongPress: () {
                  if (selection.isActive) {
                    ref.read(homeEntrySelectionProvider.notifier).toggle(entry.id);
                    return;
                  }
                  ref.read(homeEntrySelectionProvider.notifier).enterWith(entry.id);
                },
              ),
            );
          },
        ),
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
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final String? trimmedTitle = entry.title?.trim();
    final bool hasTitle = trimmedTitle != null && trimmedTitle.isNotEmpty;
    final bool showPreview = hasTitle && entry.previewText.trim().isNotEmpty;
    final double selectionLeadingWidth = selectionActive ? 34 : 0;
    final TextStyle titleStyle = typography.listTitleTextStyle(theme.textTheme);
    final TextStyle previewStyle = typography.listPreviewTextStyle(
      theme.textTheme,
      color: cs.onSurfaceVariant,
    );

    return Material(
      color: selectionActive && selected
          ? Color.alphaBlend(cs.primaryContainer.withValues(alpha: 0.34), cs.surface)
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
                padding: EdgeInsets.only(
                  left: selectionLeadingWidth,
                  top: 5,
                ),
              ),
              if (showPreview) ...<Widget>[
                const SizedBox(height: 8),
                Padding(
                  padding: EdgeInsets.only(left: selectionLeadingWidth),
                  child: Text(
                    entry.previewText,
                    style: previewStyle,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.start,
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
    final Map<String, int> tagAccents = ref.watch(tagAccentArgbMapProvider).maybeWhen(
          data: (Map<String, int> m) => m,
          orElse: () => const <String, int>{},
        );
    final Set<String> draftEntryIds = ref.watch(editorDraftKeysProvider).maybeWhen(
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
      children: entries
          .map(
            (EntryIndexRecord entry) {
              final String? trimmedTitle = entry.title?.trim();
              final bool hasTitle = trimmedTitle != null && trimmedTitle.isNotEmpty;
              final bool showPreview = hasTitle && entry.previewText.trim().isNotEmpty;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: HomeTimelineEntryShell(
                  tintedCard: true,
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
                              trailing: HomeEntryCardRightDateTime(entry: entry, compact: true),
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
                              Text(
                                entry.previewText,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: previewStyle,
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
            },
          )
          .toList(),
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
    final List<String> trimmedTags =
        tags.map((String t) => t.trim()).where((String t) => t.isNotEmpty).toList();
    final bool showTagRow = trimmedTags.isNotEmpty || charCount > 0 || showUnsavedDraft;

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
              HomeEntryListTagChip(
                label: HomeCopy.unsavedDraftLabel,
                background: Color.alphaBlend(
                  theme.colorScheme.error.withValues(alpha: 0.14),
                  theme.colorScheme.surface,
                ),
                foreground: theme.colorScheme.error,
                compact: compactTags,
              ),
            if (charCount > 0)
              HomeEntryListTagChip(
                label: DisplayFormat.formatCountUnit(charCount, '字'),
                background: Color.alphaBlend(
                  theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.12),
                  theme.colorScheme.surface,
                ),
                foreground: theme.colorScheme.onSurfaceVariant,
                compact: compactTags,
              ),
            ...trimmedTags.map((String tag) {
              final (Color bg, Color fg) =
                  tagResolvedAccentPair(tag, theme.colorScheme, tagAccents);
              return HomeEntryListTagChip(
                label: tag,
                background: bg,
                foreground: fg,
                compact: compactTags,
              );
            }),
          ],
        ),
      ),
    );
  }
}

class HomeEntryListTagChip extends StatelessWidget {
  const HomeEntryListTagChip({
    required this.label,
    required this.background,
    required this.foreground,
    this.compact = false,
    super.key,
  });

  final String label;
  final Color background;
  final Color foreground;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double maxWidth = MediaQuery.sizeOf(context).width * (compact ? 0.38 : 0.52);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: background.withValues(alpha: 0.92),
        border: Border.all(
          color: foreground.withValues(alpha: 0.32),
          width: 0.9,
        ),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth.clamp(120, 260).toDouble()),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: (compact ? theme.textTheme.labelSmall : theme.textTheme.labelMedium)?.copyWith(
            color: foreground,
            fontWeight: FontWeight.w700,
          ),
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
    super.key,
  });

  final EntryIndexRecord entry;
  final TextStyle? titleStyle;
  final Widget? leading;
  final double leadingGap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ?leading,
        if (leading != null && leadingGap > 0) SizedBox(width: leadingGap),
        Expanded(
          child: Text(
            entryListHeadline(entry),
            style: titleStyle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.start,
          ),
        ),
        const SizedBox(width: 10),
        trailing ?? HomeEntryCardRightDateTime(entry: entry),
      ],
    );
  }
}

class HomeEntryCardRightDateTime extends StatelessWidget {
  const HomeEntryCardRightDateTime({required this.entry, this.compact = false, super.key});

  final EntryIndexRecord entry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle? base = compact ? theme.textTheme.labelSmall : theme.textTheme.labelMedium;
    final TextStyle? muted = base?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final double maxWidth = compact ? 88 : 112;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            DisplayFormat.formatDateOnlyZh(entry.date),
            style: muted,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          ),
          Text(
            '${weekdayZhLongFromDateOnly(entry.date)} ${entryListTimeLabel(entry.createdAt)}',
            style: muted,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          ),
        ],
      ),
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
                  padding: EdgeInsets.only(right: i < paths.length - 1 ? 10 : 0),
                  child: lazyLoad
                      ? LazyEntryCoverThumbnail(
                          encryptedFilePath: paths[i],
                          size: thumbSize,
                          staggerIndex: i,
                          borderRadius: BorderRadius.circular(PageStyle.radiusThumbSmall),
                        )
                      : EntryCoverThumbnail(
                          encryptedFilePath: paths[i],
                          size: thumbSize,
                          borderRadius: BorderRadius.circular(PageStyle.radiusThumbSmall),
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
