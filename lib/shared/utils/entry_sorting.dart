import '../../infrastructure/database/index_database.dart';

int compareEntriesNewestFirst(EntryIndexRecord a, EntryIndexRecord b) {
  final int byDate = b.date.value.compareTo(a.date.value);
  if (byDate != 0) {
    return byDate;
  }
  return b.updatedAt.compareTo(a.updatedAt);
}
