import '../../../infrastructure/database/index_database.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/presentation/display_format.dart';

class OverviewScopeMetrics {
  const OverviewScopeMetrics({
    required this.totalEntries,
    required this.totalWords,
    required this.totalCharacters,
    required this.totalAttachments,
    required this.activeDays,
    required this.longestWritingStreakDays,
    required this.maxEntriesOnSingleDay,
    required this.entriesWithTags,
    required this.entriesWithAttachments,
    required this.totalPhotoAttachments,
    required this.totalFileAttachments,
    required this.avgWordsPerEntryRounded,
  });

  final int totalEntries;
  final int totalWords;
  final int totalCharacters;
  final int totalAttachments;
  final int activeDays;
  final int longestWritingStreakDays;
  final int maxEntriesOnSingleDay;
  final int entriesWithTags;
  final int entriesWithAttachments;
  final int totalPhotoAttachments;
  final int totalFileAttachments;
  final int avgWordsPerEntryRounded;

  int get avgCharactersPerEntryRounded =>
      totalEntries == 0 ? 0 : (totalCharacters / totalEntries).round();

  factory OverviewScopeMetrics.empty() => const OverviewScopeMetrics(
        totalEntries: 0,
        totalWords: 0,
        totalCharacters: 0,
        totalAttachments: 0,
        activeDays: 0,
        longestWritingStreakDays: 0,
        maxEntriesOnSingleDay: 0,
        entriesWithTags: 0,
        entriesWithAttachments: 0,
        totalPhotoAttachments: 0,
        totalFileAttachments: 0,
        avgWordsPerEntryRounded: 0,
      );

  factory OverviewScopeMetrics.fromEntries(List<EntryIndexRecord> entries) {
    if (entries.isEmpty) {
      return OverviewScopeMetrics.empty();
    }
    int totalWords = 0;
    int totalCharacters = 0;
    int totalAttachments = 0;
    int tagged = 0;
    int withAttachments = 0;
    int photoAttachments = 0;
    int fileAttachments = 0;

    for (final EntryIndexRecord entry in entries) {
      totalWords += entry.wordCount;
      totalCharacters += entry.charCount;
      totalAttachments += entry.attachmentCount;
      photoAttachments += entry.imageAttachmentCount;
      fileAttachments += entry.fileAttachmentCount;
      if (entry.tags.isNotEmpty) {
        tagged++;
      }
      if (entry.attachmentCount > 0) {
        withAttachments++;
      }
    }

    final int activeDays =
        entries.map((EntryIndexRecord item) => item.date.value).toSet().length;
    final int avgWordsRounded = (totalWords / entries.length).round();
    final int longestStreakDays = _longestWritingStreakDays(entries);
    final int maxEntriesOnSingleDay = _maxEntriesOnSingleDay(entries);

    return OverviewScopeMetrics(
      totalEntries: entries.length,
      totalWords: totalWords,
      totalCharacters: totalCharacters,
      totalAttachments: totalAttachments,
      activeDays: activeDays,
      longestWritingStreakDays: longestStreakDays,
      maxEntriesOnSingleDay: maxEntriesOnSingleDay,
      entriesWithTags: tagged,
      entriesWithAttachments: withAttachments,
      totalPhotoAttachments: photoAttachments,
      totalFileAttachments: fileAttachments,
      avgWordsPerEntryRounded: avgWordsRounded,
    );
  }

  String attachmentDetail(AppLocalizations l10n) =>
      l10n.homeOverviewAttachmentDetail(totalPhotoAttachments, totalFileAttachments);

  String? mostEntriesInSingleDayDetail(AppLocalizations l10n) {
    if (maxEntriesOnSingleDay <= 0) {
      return null;
    }
    return l10n.homeOverviewMostEntriesInSingleDay(
      DisplayFormat.formatCountUnit(
        maxEntriesOnSingleDay,
        l10n.localeName.startsWith('en') ? 'entries' : '篇',
      ),
    );
  }

  static int _longestWritingStreakDays(List<EntryIndexRecord> entries) {
    final List<DateTime> uniqueDates = entries
        .map((EntryIndexRecord item) => item.date.toDateTime())
        .toSet()
        .toList()
      ..sort();
    if (uniqueDates.isEmpty) {
      return 0;
    }

    int best = 1;
    int current = 1;
    for (int i = 1; i < uniqueDates.length; i++) {
      final int diff = uniqueDates[i].difference(uniqueDates[i - 1]).inDays;
      if (diff == 1) {
        current++;
        if (current > best) {
          best = current;
        }
        continue;
      }
      current = 1;
    }
    return best;
  }

  static int _maxEntriesOnSingleDay(List<EntryIndexRecord> entries) {
    int best = 0;
    final Map<String, int> counts = <String, int>{};
    for (final EntryIndexRecord entry in entries) {
      final int next = (counts[entry.date.value] ?? 0) + 1;
      counts[entry.date.value] = next;
      if (next > best) {
        best = next;
      }
    }
    return best;
  }
}
