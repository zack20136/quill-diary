import 'package:flutter_test/flutter_test.dart';
import 'package:quill_lock_diary/features/home/models/overview_models.dart';
import 'package:quill_lock_diary/domain/shared/value_objects.dart';
import 'package:quill_lock_diary/infrastructure/database/index_database.dart';

import '../../helpers/entry_index_fixtures.dart';

void main() {
  test('OverviewScopeMetrics counts photo and file attachments', () {
    final OverviewScopeMetrics metrics = OverviewScopeMetrics.fromEntries(
      <EntryIndexRecord>[
        buildEntryIndexRecord(
          attachmentCount: 3,
          imageAttachmentCount: 2,
          fileAttachmentCount: 1,
          wordCount: 120,
          charCount: 180,
          date: const DateOnly('2026-05-01'),
        ),
        buildEntryIndexRecord(
          id: 'jrn_TEST0002',
          attachmentCount: 2,
          imageAttachmentCount: 0,
          fileAttachmentCount: 2,
          wordCount: 80,
          charCount: 120,
          date: const DateOnly('2026-05-01'),
        ),
        buildEntryIndexRecord(
          id: 'jrn_TEST0003',
          attachmentCount: 0,
          imageAttachmentCount: 0,
          fileAttachmentCount: 0,
          wordCount: 20,
          charCount: 40,
          date: const DateOnly('2026-05-02'),
        ),
      ],
    );

    expect(metrics.totalAttachments, 5);
    expect(metrics.totalPhotoAttachments, 2);
    expect(metrics.totalFileAttachments, 3);
    expect(metrics.avgCharactersPerEntryRounded, 113);
    expect(metrics.longestWritingStreakDays, 2);
    expect(metrics.maxEntriesOnSingleDay, 2);
    expect(
      metrics.mostEntriesInSingleDayDetail(),
      '\u55ae\u5929\u6700\u591a 2 \u7bc7',
    );
    expect(
      metrics.attachmentDetail(),
      '\u7167\u7247 2 \u30fb \u6a94\u6848 3',
    );
  });
}
