part of '../../pages/home_page.dart';

class _CalendarDayCell extends ConsumerWidget {
  const _CalendarDayCell({
    required this.day,
    required this.entries,
    required this.isSelected,
    required this.isToday,
    required this.isOutside,
    required this.rowHeight,
  });

  final DateTime day;
  final List<EntryIndexRecord> entries;
  final bool isSelected;
  final bool isToday;
  final bool isOutside;
  final double rowHeight;

  Color _entryTintBackground(
    ColorScheme cs,
    EntryIndexRecord entry,
    Map<String, int> accents,
  ) {
    final String tagLabel = _firstNonemptyTag(entry.tags);
    final (Color bg, _) = tagLabel.isEmpty
        ? tagNeutralAccentPair(cs)
        : tagResolvedAccentPair(tagLabel, cs, accents);
    return Color.alphaBlend(bg.withValues(alpha: 0.22), cs.surface);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Map<String, int> accents = ref.watch(tagAccentArgbMapProvider).maybeWhen(
          data: (Map<String, int> m) => m,
          orElse: () => const <String, int>{},
        );
    final double contentOpacity = isOutside ? 0.4 : 1.0;
    final bool showTitles = calendarShouldShowEntryTitles(rowHeight);
    final List<EntryIndexRecord> visibleEntries = showTitles
        ? entries.take(kCalendarMaxEntriesPerCell).toList()
        : const <EntryIndexRecord>[];
    final double entryFontSize = calendarEntryFontSize(rowHeight);

    Color cellColor = cs.surface;
    if (visibleEntries.isNotEmpty) {
      cellColor = _entryTintBackground(cs, visibleEntries.first, accents);
    }
    if (isSelected) {
      cellColor = Color.alphaBlend(
        cs.primaryContainer.withValues(alpha: 0.48),
        cellColor,
      );
    }

    return SizedBox(
      height: rowHeight,
      width: double.infinity,
      child: Opacity(
        opacity: contentOpacity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: cellColor,
            border: isSelected
                ? Border.all(color: cs.primary.withValues(alpha: 0.55), width: 1.2)
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 3, 3, 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _CalendarDayNumberBadge(
                  day: day.day,
                  date: day,
                  isSelected: isSelected,
                  isToday: isToday,
                ),
                if (visibleEntries.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  for (final EntryIndexRecord entry in visibleEntries)
                    _CalendarEntryPreviewRow(
                      label: calendarEntryPreviewLabel(_entryListHeadline(entry)),
                      tagLabel: _firstNonemptyTag(entry.tags),
                      accents: accents,
                      fontSize: entryFontSize,
                    ),
                  if (entries.length > kCalendarMaxEntriesPerCell)
                    Text(
                      '+${entries.length - kCalendarMaxEntriesPerCell}',
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: entryFontSize - 0.5,
                        height: 1,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarDayNumberBadge extends StatelessWidget {
  const _CalendarDayNumberBadge({
    required this.day,
    required this.date,
    required this.isSelected,
    required this.isToday,
  });

  final int day;
  final DateTime date;
  final bool isSelected;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    const double fontSize = 10;

    if (isToday) {
      return Container(
        width: 17,
        height: 17,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: cs.primary,
          shape: BoxShape.circle,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: cs.primary.withValues(alpha: 0.28),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          '$day',
          style: TextStyle(
            color: cs.onPrimary,
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      );
    }

    final Color textColor = isSelected
        ? cs.primary
        : calendarIsSunday(date)
            ? cs.error.withValues(alpha: 0.78)
            : calendarIsSaturday(date)
                ? cs.primary.withValues(alpha: 0.72)
                : cs.onSurface.withValues(alpha: 0.86);

    return Text(
      '$day',
      style: TextStyle(
        color: textColor,
        fontSize: fontSize,
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        height: 1.1,
      ),
    );
  }
}

class _CalendarEntryPreviewRow extends StatelessWidget {
  const _CalendarEntryPreviewRow({
    required this.label,
    required this.tagLabel,
    required this.accents,
    required this.fontSize,
  });

  final String label;
  final String tagLabel;
  final Map<String, int> accents;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final (_, Color accent) = tagLabel.isEmpty
        ? tagNeutralAccentPair(cs)
        : tagResolvedAccentPair(tagLabel, cs, accents);

    return Padding(
      padding: const EdgeInsets.only(bottom: 1),
      child: Row(
        children: <Widget>[
          Container(
            width: 2,
            height: fontSize + 1,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          const SizedBox(width: 3),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: TextStyle(
                fontSize: fontSize,
                height: 1.1,
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
