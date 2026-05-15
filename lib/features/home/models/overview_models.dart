import '../../../infrastructure/database/index_database.dart';

class OverviewTagStat {
  const OverviewTagStat({
    required this.label,
    required this.count,
  });

  final String label;
  final int count;
}

class OverviewMoodStat {
  const OverviewMoodStat({
    required this.label,
    required this.count,
  });

  final String label;
  final int count;
}

class OverviewSummary {
  const OverviewSummary({
    required this.totalEntries,
    required this.totalWords,
    required this.totalCharacters,
    required this.totalAttachments,
    required this.activeDays,
    required this.entriesWithTags,
    required this.entriesWithAttachments,
    required this.entriesWithMoodSet,
    required this.avgWordsPerEntryRounded,
    required this.topTags,
    required this.moods,
  });

  final int totalEntries;
  final int totalWords;
  final int totalCharacters;
  final int totalAttachments;
  final int activeDays;
  final int entriesWithTags;
  final int entriesWithAttachments;
  final int entriesWithMoodSet;
  final int avgWordsPerEntryRounded;
  final List<OverviewTagStat> topTags;
  final List<OverviewMoodStat> moods;
}

class OverviewScopeMetrics {
  const OverviewScopeMetrics({
    required this.totalEntries,
    required this.totalWords,
    required this.totalCharacters,
    required this.totalAttachments,
    required this.activeDays,
    required this.entriesWithTags,
    required this.entriesWithAttachments,
    required this.entriesWithMoodSet,
    required this.avgWordsPerEntryRounded,
  });

  final int totalEntries;
  final int totalWords;
  final int totalCharacters;
  final int totalAttachments;
  final int activeDays;
  final int entriesWithTags;
  final int entriesWithAttachments;
  final int entriesWithMoodSet;
  final int avgWordsPerEntryRounded;

  factory OverviewScopeMetrics.empty() => const OverviewScopeMetrics(
        totalEntries: 0,
        totalWords: 0,
        totalCharacters: 0,
        totalAttachments: 0,
        activeDays: 0,
        entriesWithTags: 0,
        entriesWithAttachments: 0,
        entriesWithMoodSet: 0,
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
    int withMood = 0;

    for (final EntryIndexRecord entry in entries) {
      totalWords += entry.wordCount;
      totalCharacters += entry.charCount;
      totalAttachments += entry.attachmentCount;
      if (entry.tags.isNotEmpty) {
        tagged++;
      }
      if (entry.attachmentCount > 0) {
        withAttachments++;
      }
      final String? mood = entry.mood?.trim();
      if (mood != null && mood.isNotEmpty) {
        withMood++;
      }
    }

    final int activeDays =
        entries.map((EntryIndexRecord item) => item.date.value).toSet().length;
    final int avgWordsRounded = (totalWords / entries.length).round();

    return OverviewScopeMetrics(
      totalEntries: entries.length,
      totalWords: totalWords,
      totalCharacters: totalCharacters,
      totalAttachments: totalAttachments,
      activeDays: activeDays,
      entriesWithTags: tagged,
      entriesWithAttachments: withAttachments,
      entriesWithMoodSet: withMood,
      avgWordsPerEntryRounded: avgWordsRounded,
    );
  }

  String? writingDensitySubtitle() {
    if (totalEntries <= 0 || activeDays <= 0) {
      return null;
    }
    final int numerator = totalEntries * 10 ~/ activeDays;
    final int hi = numerator ~/ 10;
    final int lo = numerator % 10;
    final String pace = lo == 0 ? '$hi' : '$hi.$lo';
    return 'Average $pace entries per day';
  }

  String annotationMixedDetail() =>
      '$entriesWithTags tagged, $entriesWithAttachments with attachments, $entriesWithMoodSet with mood';
}
