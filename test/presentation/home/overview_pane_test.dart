import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/presentation/home/widgets/overview_presentation.dart';

import '../../helpers/shared/entry_index_fixtures.dart';

void main() {
  test('標籤篩選會同時決定總覽指標與匯出的日記範圍', () {
    final entries = [
      buildDiaryEntrySummary(id: 'travel', tags: const <String>['旅行']),
      buildDiaryEntrySummary(id: 'life', tags: const <String>['生活']),
      buildDiaryEntrySummary(id: 'both', tags: const <String>['旅行', '生活']),
    ];

    expect(
      overviewEntriesForTag(entries, '旅行').map((entry) => entry.id),
      <String>['travel', 'both'],
    );
    expect(
      overviewEntriesForTag(entries, null).map((entry) => entry.id),
      <String>['travel', 'life', 'both'],
    );
  });
}
