import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/features/home/overview_export.dart';
import 'package:quill_diary/features/home/state/home_state.dart';
import 'package:quill_diary/infrastructure/database/index_database.dart';

import '../../helpers/entry_index_fixtures.dart';

void main() {
  test('all scope exports every entry id', () {
    final List<EntryIndexRecord> allEntries = <EntryIndexRecord>[
      buildEntryIndexRecord(id: 'jrn_all_1'),
      buildEntryIndexRecord(id: 'jrn_all_2'),
      buildEntryIndexRecord(id: 'jrn_all_3'),
    ];
    final List<EntryIndexRecord> scopedEntries = <EntryIndexRecord>[
      allEntries.first,
    ];

    final Set<String> exportIds = resolveOverviewExportEntryIds(
      scope: MemoryScope.all,
      allEntries: allEntries,
      scopedEntries: scopedEntries,
    );

    expect(exportIds, <String>{'jrn_all_1', 'jrn_all_2', 'jrn_all_3'});
  });

  test('year and month scopes export only scoped entries', () {
    final List<EntryIndexRecord> allEntries = <EntryIndexRecord>[
      buildEntryIndexRecord(id: 'jrn_all_1'),
      buildEntryIndexRecord(id: 'jrn_all_2'),
      buildEntryIndexRecord(id: 'jrn_all_3'),
    ];
    final List<EntryIndexRecord> scopedEntries = <EntryIndexRecord>[
      allEntries[1],
      allEntries[2],
    ];

    final Set<String> yearExportIds = resolveOverviewExportEntryIds(
      scope: MemoryScope.year,
      allEntries: allEntries,
      scopedEntries: scopedEntries,
    );
    final Set<String> monthExportIds = resolveOverviewExportEntryIds(
      scope: MemoryScope.month,
      allEntries: allEntries,
      scopedEntries: scopedEntries,
    );

    expect(yearExportIds, <String>{'jrn_all_2', 'jrn_all_3'});
    expect(monthExportIds, <String>{'jrn_all_2', 'jrn_all_3'});
  });
}
