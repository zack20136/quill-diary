import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/application/home/home_browse_state.dart';
import 'package:quill_diary/infrastructure/database/index_database.dart';

Set<EntryId> resolveOverviewExportEntryIds({
  required MemoryScope scope,
  required List<EntryIndexRecord> allEntries,
  required List<EntryIndexRecord> scopedEntries,
}) {
  final Iterable<EntryIndexRecord> source = switch (scope) {
    MemoryScope.all => allEntries,
    MemoryScope.year => scopedEntries,
    MemoryScope.month => scopedEntries,
  };
  return source.map((EntryIndexRecord entry) => entry.id).toSet();
}
