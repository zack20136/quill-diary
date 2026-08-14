import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/home/widgets/calendar/calendar_day_cell.dart';

import '../../helpers/app_test_theme.dart';

void main() {
  test('英文日記篇數使用正確單複數', () {
    final AppLocalizations l10n = lookupAppLocalizations(appEnLocale);

    expect(l10n.homeCalendarEntryCount(0), '0 entries');
    expect(l10n.homeCalendarEntryCount(1), '1 entry');
    expect(l10n.homeCalendarEntryCount(2), '2 entries');
  });

  testWidgets('日曆日期格提供日期、篇數、今天與選取狀態語意', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTestTheme(),
        locale: appZhLocale,
        supportedLocales: appSupportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: CalendarDayCell(
            day: DateTime(2026, 8, 13),
            entries: [],
            isSelected: true,
            isToday: true,
            isOutside: false,
            rowHeight: 60,
            tagAccents: {},
          ),
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
}
