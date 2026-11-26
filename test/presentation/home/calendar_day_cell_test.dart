import 'dart:ui' show Tristate;

import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/diary/diary_entry_summary.dart';
import 'package:quill_diary/presentation/home/widgets/calendar/calendar_day_cell.dart';

import '../../helpers/shared/test_l10n.dart';
import '../../helpers/shared/widget_test_app.dart';

void main() {
  testWidgets('日曆日期格提供日期、篇數、今天與選取狀態語意', (WidgetTester tester) async {
    await tester.pumpWidget(
      widgetTestApp(
        center: false,
        child: CalendarDayCell(
          day: DateTime(2026, 8, 13),
          entries: const <DiaryEntrySummary>[],
          isSelected: true,
          isToday: true,
          isOutside: false,
          rowHeight: 60,
          tagAccents: const <String, int>{},
        ),
      ),
    );

    final SemanticsNode node = tester.getSemantics(
      find.byType(CalendarDayCell),
    );
    expect(node.label, contains('2026'));
    expect(node.label, contains(testL10n.homeCalendarEntryCount(0)));
    expect(node.label, contains(testL10n.commonRelativeToday));
    expect(node.label, contains(testL10n.homeCalendarSelectedStatus));
    expect(node.flagsCollection.isSelected, Tristate.isTrue);
  });
}
