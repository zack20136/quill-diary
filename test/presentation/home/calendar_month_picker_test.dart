import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/application/home/home_browse_state.dart';
import 'package:quill_diary/application/home/home_entry_query_providers.dart';
import 'package:quill_diary/application/session/state/app_session_state.dart';
import 'package:quill_diary/application/tag/tag_providers.dart';
import 'package:quill_diary/domain/diary/diary_date_policy.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/database/index_database.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/home/widgets/calendar/calendar_pane.dart';

import '../../helpers/app_test_theme.dart';

void main() {
  testWidgets('年月面板可捲到最後一年並將超出日期調整到月底', (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final ProviderContainer container = ProviderContainer(
      overrides: [
        calendarGridEntriesProvider.overrideWith(
          (Ref ref) async => const <EntryIndexRecord>[],
        ),
        calendarEntriesProvider.overrideWith(
          (Ref ref) async => const <EntryIndexRecord>[],
        ),
        entryDateBoundsProvider.overrideWith((Ref ref) async => null),
        tagAccentArgbMapProvider.overrideWith(
          (Ref ref) async => const <String, int>{},
        ),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(calendarVisibleMonthProvider.notifier)
        .set(DateTime(2026, DateTime.january));
    container
        .read(calendarSelectedDateProvider.notifier)
        .set(DateOnly('2026-01-31'));
    final AppSessionState sessionState = AppSessionState(
      status: AppLockStatus.unlocked,
      session: UnlockedVaultSession(
        vaultId: 'vlt_calendar_month_picker',
        trustedDevice: true,
        recoveryWrapKey: const <int>[1, 2, 3],
      ),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: appTestTheme(),
          locale: appZhLocale,
          supportedLocales: appSupportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(body: CalendarPane(sessionState: sessionState)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder titleButton = find.byKey(
      const Key('calendar-month-title-button'),
    );
    expect(titleButton, findsOneWidget);
    expect(tester.getSize(titleButton).height, greaterThanOrEqualTo(44));
    await tester.tap(titleButton);
    await tester.pumpAndSettle();

    expect(find.text('選擇年月'), findsOneWidget);
    expect(find.byType(DropdownButton<int>), findsNothing);
    expect(find.byKey(const Key('app-date-picker-month-view')), findsOneWidget);
    final ScrollbarTheme monthScrollbarTheme = tester.widget(
      find.byKey(const Key('app-date-picker-month-scrollbar-theme')),
    );
    expect(monthScrollbarTheme.data.mainAxisMargin, 0);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('app-date-picker-month-1')))
          .height,
      greaterThanOrEqualTo(kMinInteractiveDimension),
    );
    final SingleChildScrollView monthGrid = tester.widget(
      find.byKey(const Key('app-date-picker-month-view')),
    );
    final ScrollController monthController = monthGrid.controller!;
    expect(monthController.position.maxScrollExtent, greaterThan(0));
    monthController.jumpTo(monthController.position.maxScrollExtent);
    await tester.pump();
    expect(
      find.byKey(const ValueKey('app-date-picker-month-12')),
      findsOneWidget,
    );
    monthController.jumpTo(0);
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('app-date-picker-year-chooser')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('app-date-picker-year-view')), findsOneWidget);
    final ScrollbarTheme yearScrollbarTheme = tester.widget(
      find.byKey(const Key('app-date-picker-year-scrollbar-theme')),
    );
    expect(yearScrollbarTheme.data.mainAxisMargin, 0);
    final GridView yearGrid = tester.widget(
      find.byKey(const Key('app-date-picker-year-grid')),
    );
    final ScrollController yearController = yearGrid.controller!;
    yearController.jumpTo(yearController.position.maxScrollExtent);
    await tester.pump();
    expect(yearController.offset, yearController.position.maxScrollExtent);
    final int lastYear = DiaryDatePolicy.latestSelectableDate().year;
    expect(
      find.byKey(ValueKey<String>('app-date-picker-year-$lastYear')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(ValueKey<String>('app-date-picker-year-$lastYear')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('app-date-picker-month-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('app-date-picker-apply')));
    await tester.pumpAndSettle();

    final int lastDayOfFebruary = DateTime(lastYear, 3, 0).day;
    expect(container.read(calendarVisibleMonthProvider), DateTime(lastYear, 2));
    expect(
      container.read(calendarSelectedDateProvider)?.value,
      DateOnly.fromDateTime(DateTime(lastYear, 2, lastDayOfFebruary)).value,
    );
    expect(find.text('$lastYear年2月'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
