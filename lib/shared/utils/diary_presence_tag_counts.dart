import '../../domain/shared/value_objects.dart';
import '../../infrastructure/database/index_database.dart';

/// 各標籤在「有多少篇日記出現」的計數。
///
/// - 以 [normalizeText] 合併大小寫與留白差異；
/// - 同一篇若重複列出相同標籤（正規化後相同）只計一次；
/// - Map 的 key 為顯示用字串（同組內第一次看到時的留白折疊結果）。
/// Counts how many diary entries contain each normalized tag.
///
/// Repeated tags inside the same entry only count once after normalization.
Map<String, int> diaryPresenceTagCounts(List<EntryIndexRecord> entries) {
  final Map<String, int> countByNorm = <String, int>{};
  final Map<String, String> displayByNorm = <String, String>{};

  for (final EntryIndexRecord r in entries) {
    final Set<String> normsInEntry = <String>{};
    for (final String raw in r.tags) {
      final String display = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (display.isEmpty) {
        continue;
      }
      final String norm = normalizeText(raw);
      if (!normsInEntry.add(norm)) {
        continue;
      }
      countByNorm.update(norm, (int n) => n + 1, ifAbsent: () => 1);
      displayByNorm.putIfAbsent(norm, () => display);
    }
  }

  return <String, int>{
    for (final MapEntry<String, int> e in countByNorm.entries)
      displayByNorm[e.key]!: e.value,
  };
}
