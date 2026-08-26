import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:quill_diary/app/app_colors.dart';
import 'package:quill_diary/infrastructure/database/index_database.dart';
import 'package:quill_diary/shared/presentation/page_style.dart';
import 'package:quill_diary/shared/presentation/widgets/app_surface.dart';

import 'diary_entry_date_time.dart';

class DiaryEntrySliverSection extends StatelessWidget {
  const DiaryEntrySliverSection({
    required this.title,
    required this.entries,
    this.stripeColor,
    this.trailing,
    super.key,
  });

  final String title;
  final List<EntryIndexRecord> entries;
  final Color? stripeColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => DecoratedSliver(
    decoration: BoxDecoration(
      color: context.appColors.sectionCard,
      borderRadius: BorderRadius.circular(PageStyle.radiusCard),
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: Theme.of(context).shadowColor.withValues(alpha: 0.08),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
      ],
    ),
    sliver: SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      sliver: SliverMainAxisGroup(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: AppSectionHeader(
              title: title,
              stripeColor: stripeColor,
              trailing: trailing,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 14)),
          SliverList.separated(
            itemCount: entries.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (BuildContext context, int index) =>
                _DiaryEntryCard(entry: entries[index]),
          ),
        ],
      ),
    ),
  );
}

class _DiaryEntryCard extends StatelessWidget {
  const _DiaryEntryCard({required this.entry});

  final EntryIndexRecord entry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String title = entry.title?.trim() ?? '';
    final String preview = entry.previewText.trim();
    return AppInsetPanel(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => unawaited(context.push('/editor/${entry.id}')),
          borderRadius: BorderRadius.circular(PageStyle.radiusPanel),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title.isNotEmpty ? title : preview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (title.isNotEmpty && preview.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 6),
                        Text(
                          preview,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                DiaryEntryDateTime(
                  date: entry.date,
                  at: entry.createdAt,
                  compact: true,
                  maxWidth: 88,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
