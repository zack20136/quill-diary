import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/infrastructure/database/index_database.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/home/widgets/calendar/calendar_day_cell.dart';
import 'package:quill_diary/shared/presentation/accent_visual.dart';

import '../../helpers/app_test_theme.dart';
import '../../helpers/shared/entry_index_fixtures.dart';
import '../../helpers/shared/widget_test_app.dart';

void main() {
  test('英文日記篇數使用正確單複數', () {
    final AppLocalizations l10n = lookupAppLocalizations(appEnLocale);

    expect(l10n.homeCalendarEntryCount(0), '0 entries');
    expect(l10n.homeCalendarEntryCount(1), '1 entry');
    expect(l10n.homeCalendarEntryCount(2), '2 entries');
  });

  testWidgets('日曆日期格提供日期、篇數、今天與選取狀態語意', (WidgetTester tester) async {
    await tester.pumpWidget(
      widgetTestApp(
        center: false,
        child: CalendarDayCell(
          day: DateTime(2026, 8, 13),
          entries: const <EntryIndexRecord>[],
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
    expect(node.label, contains('0 篇日記'));
    expect(node.label, contains('今天'));
    expect(node.label, contains('已選取'));
    expect(node.flagsCollection.isSelected, Tristate.isTrue);
  });

  testWidgets('暗色模式有日記格子使用 primary 淡色，不用標籤混色', (
    WidgetTester tester,
  ) async {
    final ThemeData darkTheme = appTestTheme(brightness: Brightness.dark);
    final ColorScheme cs = darkTheme.colorScheme;
    final Color expected = Color.alphaBlend(
      cs.primary.withValues(alpha: 0.14),
      cs.surface,
    );
    final Color muddyTagTint = Color.alphaBlend(
      Color.alphaBlend(
        kAccentColorPresets.first.withValues(alpha: 0.18),
        cs.surface,
      ).withValues(alpha: 0.22),
      cs.surface,
    );

    await tester.pumpWidget(
      widgetTestApp(
        brightness: Brightness.dark,
        center: false,
        child: CalendarDayCell(
          day: DateTime(2026, 8, 5),
          entries: <EntryIndexRecord>[
            buildEntryIndexRecord(
              title: '有日記',
              tags: const <String>['心得'],
            ),
          ],
          isSelected: false,
          isToday: false,
          isOutside: false,
          rowHeight: 72,
          tagAccents: <String, int>{
            '心得': colorArgb32(kAccentColorPresets.first),
          },
        ),
      ),
    );

    final DecoratedBox box = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(CalendarDayCell),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final BoxDecoration decoration = box.decoration as BoxDecoration;
    expect(decoration.color, expected);
    expect(decoration.color, isNot(muddyTagTint));
  });
}
