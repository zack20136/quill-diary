import '../../domain/shared/value_objects.dart';
import '../../infrastructure/database/index_database.dart';
import 'state/home_state.dart';

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
