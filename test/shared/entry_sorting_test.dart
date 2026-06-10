import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/database/index_database.dart';
import 'package:quill_diary/shared/utils/entry_sorting.dart';

import '../helpers/entry_index_fixtures.dart';

void main() {
  test('不同日期以新到舊排序', () {
    final EntryIndexRecord older = buildEntryIndexRecord(
      id: 'jrn_old',
      date: const DateOnly('2026-05-10'),
    );
    final EntryIndexRecord newer = buildEntryIndexRecord(
      id: 'jrn_new',
      date: const DateOnly('2026-05-12'),
    );

    final List<EntryIndexRecord> sorted = <EntryIndexRecord>[older, newer]
      ..sort(compareEntriesNewestFirst);
    expect(sorted.first.id, 'jrn_new');
    expect(sorted.last.id, 'jrn_old');
  });

  test('同日期以 createdAt 新到舊排序', () {
    final EntryIndexRecord earlier = buildEntryIndexRecord(
      id: 'jrn_a',
      createdAt: DateTime.parse('2026-05-13T10:00:00Z'),
      updatedAt: DateTime.parse('2026-05-13T22:00:00Z'),
    );
    final EntryIndexRecord later = buildEntryIndexRecord(
      id: 'jrn_b',
      createdAt: DateTime.parse('2026-05-13T18:00:00Z'),
      updatedAt: DateTime.parse('2026-05-13T11:00:00Z'),
    );

    final List<EntryIndexRecord> sorted = <EntryIndexRecord>[earlier, later]
      ..sort(compareEntriesNewestFirst);
    expect(sorted.first.id, 'jrn_b');
    expect(sorted.last.id, 'jrn_a');
  });
}
