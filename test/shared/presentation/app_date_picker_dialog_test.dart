import 'dart:async' show unawaited;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/presentation/date_picker/app_date_picker_dialog.dart';

import '../../helpers/app_test_theme.dart';

Widget _pickerApp({
  required Locale locale,
  required Future<void> Function(BuildContext context) onOpen,
  Brightness brightness = Brightness.light,
}) {
  return MaterialApp(
    theme: appTestTheme(brightness: brightness),
    locale: locale,
    supportedLocales: appSupportedLocales,
    localizationsDelegates: appLocalizationsDelegates,
    home: Builder(
      builder: (BuildContext context) => Scaffold(
        body: Center(
          child: FilledButton(
            key: const Key('open-picker'),
            onPressed: () => unawaited(onOpen(context)),
            child: const Text('開啟'),
          ),
        ),
      ),
    ),
  );
}

void _useCompactLargeTextView(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, 568);
  tester.platformDispatcher.textScaleFactorTestValue = 1.3;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

void main() {
  testWidgets('今天按鈕會返回日期格並在套用後回傳今天', (WidgetTester tester) async {
    final DateTime now = DateTime.now();
    DateTime? result;
    await tester.pumpWidget(
      _pickerApp(
        locale: appZhLocale,
        onOpen: (BuildContext context) async {
          result = await showAppDatePickerDialog(
            context: context,
            initialDate: DateTime(now.year, now.month - 1, 15),
            firstDate: DateTime(now.year, now.month - 2),
            lastDate: DateTime(now.year, now.month + 2, 0),
          );
        },
      ),
    );
    await tester.tap(find.byKey(const Key('open-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('app-date-picker-period-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('app-date-picker-month-view')), findsOneWidget);

    await tester.tap(find.byKey(const Key('app-date-picker-today')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('app-date-picker-day-view')), findsOneWidget);
    await tester.tap(find.byKey(const Key('app-date-picker-apply')));
    await tester.pumpAndSettle();

    expect(result, DateTime(now.year, now.month, now.day));
  });

  testWidgets('完整日期可依手勢門檻左右切換月份且不越界', (WidgetTester tester) async {
    DateTime? result;
    await tester.pumpWidget(
      _pickerApp(
        locale: appZhLocale,
        onOpen: (BuildContext context) async {
          result = await showAppDatePickerDialog(
            context: context,
            initialDate: DateTime(2025, 1, 31),
            firstDate: DateTime(2025, 1),
            lastDate: DateTime(2025, 3, 31),
          );
        },
      ),
    );
    await tester.tap(find.byKey(const Key('open-picker')));
    await tester.pumpAndSettle();
    final Finder swipeArea = find.byKey(
      const Key('app-date-picker-month-swipe-area'),
    );
    const Key januaryOutside = ValueKey<String>(
      'app-date-picker-adjacent-2024-12-29',
    );

    await tester.timedDrag(
      swipeArea,
      const Offset(60, 0),
      const Duration(seconds: 1),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(januaryOutside), findsOneWidget);

    await tester.timedDrag(
      swipeArea,
      const Offset(-20, 0),
      const Duration(seconds: 2),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(januaryOutside), findsOneWidget);

    await tester.timedDrag(
      swipeArea,
      const Offset(0, -60),
      const Duration(seconds: 1),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(januaryOutside), findsOneWidget);

    await tester.timedDrag(
      swipeArea,
      const Offset(-60, 0),
      const Duration(seconds: 1),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('app-date-picker-adjacent-2025-1-26')),
      findsOneWidget,
    );

    await tester.timedDrag(
      swipeArea,
      const Offset(60, 0),
      const Duration(seconds: 1),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(januaryOutside), findsOneWidget);

    final GestureDetector gesture = tester.widget<GestureDetector>(swipeArea);
    gesture.onHorizontalDragDown!(
      DragDownDetails(globalPosition: const Offset(100, 0)),
    );
    gesture.onHorizontalDragUpdate!(
      DragUpdateDetails(
        globalPosition: const Offset(80, 0),
        delta: const Offset(-20, 0),
        primaryDelta: -20,
      ),
    );
    gesture.onHorizontalDragEnd!(
      DragEndDetails(
        velocity: const Velocity(pixelsPerSecond: Offset(-400, 0)),
        primaryVelocity: -400,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('app-date-picker-adjacent-2025-1-26')),
      findsOneWidget,
    );

    await tester.timedDrag(
      swipeArea,
      const Offset(60, 0),
      const Duration(seconds: 1),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(januaryOutside), findsOneWidget);

    await tester.tap(find.byKey(const Key('app-date-picker-apply')));
    await tester.pumpAndSettle();
    expect(result, DateTime(2025, 1, 28));
  });

  testWidgets('完整日期在英文大字體下可逐層選擇並夾到月底', (WidgetTester tester) async {
    _useCompactLargeTextView(tester);
    DateTime? result;
    await tester.pumpWidget(
      _pickerApp(
        locale: appEnLocale,
        onOpen: (BuildContext context) async {
          result = await showAppDatePickerDialog(
            context: context,
            initialDate: DateTime(2025, 1, 31),
            firstDate: DateTime(2025, 1, 15),
            lastDate: DateTime(2025, 3, 10),
          );
        },
      ),
    );
    await tester.tap(find.byKey(const Key('open-picker')));
    await tester.pumpAndSettle();

    expect(find.text('Choose date'), findsOneWidget);
    expect(find.byKey(const Key('app-date-picker-day-view')), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('app-date-picker-today')))
          .onPressed,
      isNull,
    );
    final Finder dayGrid = find.descendant(
      of: find.byKey(const Key('app-date-picker-day-view')),
      matching: find.byType(GridView),
    );
    final double januaryGridHeight = tester.getSize(dayGrid).height;
    final Finder previousMonthDate = find.byKey(
      const ValueKey<String>('app-date-picker-adjacent-2024-12-29'),
    );
    final Finder nextMonthDate = find.byKey(
      const ValueKey<String>('app-date-picker-adjacent-2025-2-8'),
    );
    expect(previousMonthDate, findsOneWidget);
    expect(nextMonthDate, findsOneWidget);
    expect(tester.widget<TextButton>(previousMonthDate).onPressed, isNull);
    expect(tester.widget<TextButton>(nextMonthDate).onPressed, isNull);
    final ButtonStyle? adjacentStyle = tester
        .widget<TextButton>(previousMonthDate)
        .style;
    expect(
      adjacentStyle?.backgroundColor?.resolve(<WidgetState>{
        WidgetState.disabled,
      }),
      Colors.transparent,
    );
    expect(
      adjacentStyle?.side?.resolve(<WidgetState>{WidgetState.disabled}),
      BorderSide.none,
    );
    expect(
      adjacentStyle?.shape?.resolve(<WidgetState>{WidgetState.disabled}),
      isA<CircleBorder>(),
    );
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const Key('app-date-picker-previous-month')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(
            find.byKey(const ValueKey('app-date-picker-day-14')),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const Key('app-date-picker-period-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('app-date-picker-month-view')), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(
            find.byKey(const ValueKey('app-date-picker-month-4')),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const ValueKey('app-date-picker-month-2')));
    await tester.pumpAndSettle();
    expect(tester.getSize(dayGrid).height, januaryGridHeight);
    expect(
      tester
          .widget<TextButton>(
            find.byKey(
              const ValueKey<String>('app-date-picker-adjacent-2025-1-26'),
            ),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(
            find.byKey(
              const ValueKey<String>('app-date-picker-adjacent-2025-3-8'),
            ),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const Key('app-date-picker-apply')));
    await tester.pumpAndSettle();

    expect(result, DateTime(2025, 2, 28));
    expect(tester.takeException(), isNull);
  });

  testWidgets('生日月日模式可選擇二月二十九日', (WidgetTester tester) async {
    AppMonthDay? result;
    await tester.pumpWidget(
      _pickerApp(
        locale: appZhLocale,
        onOpen: (BuildContext context) async {
          result = await showAppMonthDayPickerDialog(
            context: context,
            initialMonth: 1,
            initialDay: 31,
            title: '選擇生日',
          );
        },
      ),
    );
    await tester.tap(find.byKey(const Key('open-picker')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('app-date-picker-today')), findsNothing);
    expect(
      find.byKey(const Key('app-date-picker-month-swipe-area')),
      findsNothing,
    );
    await tester.tap(find.byKey(const Key('app-date-picker-period-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('app-date-picker-month-2')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('app-date-picker-day-29')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextButton>(
            find.byKey(const ValueKey('app-date-picker-day-29')),
          )
          .style
          ?.shape
          ?.resolve(<WidgetState>{}),
      isA<CircleBorder>(),
    );
    await tester.tap(find.byKey(const ValueKey('app-date-picker-day-29')));
    await tester.tap(find.byKey(const Key('app-date-picker-apply')));
    await tester.pumpAndSettle();

    expect(result, (month: 2, day: 29));
  });

  testWidgets('年月模式年份與月份可捲到底且取消不回傳結果', (WidgetTester tester) async {
    _useCompactLargeTextView(tester);
    DateTime? result;
    final int lastYear = DateTime.now().year + 1;
    await tester.pumpWidget(
      _pickerApp(
        locale: appZhLocale,
        onOpen: (BuildContext context) async {
          result = await showAppYearMonthPickerDialog(
            context: context,
            initialMonth: DateTime(2026, 1),
            firstMonth: DateTime(2000, 1),
            lastMonth: DateTime(lastYear, 12),
          );
        },
      ),
    );
    await tester.tap(find.byKey(const Key('open-picker')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('app-date-picker-today')), findsNothing);
    expect(
      tester
          .widget<TextButton>(
            find.byKey(const ValueKey('app-date-picker-month-1')),
          )
          .style
          ?.shape
          ?.resolve(<WidgetState>{}),
      isA<RoundedRectangleBorder>(),
    );

    final ScrollbarTheme monthScrollbar = tester.widget(
      find.byKey(const Key('app-date-picker-month-scrollbar-theme')),
    );
    expect(monthScrollbar.data.mainAxisMargin, 0);
    final SingleChildScrollView monthView = tester.widget(
      find.byKey(const Key('app-date-picker-month-view')),
    );
    monthView.controller!.jumpTo(
      monthView.controller!.position.maxScrollExtent,
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('app-date-picker-month-12')),
      findsOneWidget,
    );
    monthView.controller!.jumpTo(0);
    await tester.pump();

    await tester.tap(find.byKey(const Key('app-date-picker-year-chooser')));
    await tester.pumpAndSettle();
    final GridView yearGrid = tester.widget(
      find.byKey(const Key('app-date-picker-year-grid')),
    );
    expect(
      tester
          .widget<TextButton>(
            find.byKey(ValueKey<String>('app-date-picker-year-$lastYear')),
          )
          .style
          ?.shape
          ?.resolve(<WidgetState>{}),
      isA<RoundedRectangleBorder>(),
    );
    yearGrid.controller!.jumpTo(yearGrid.controller!.position.maxScrollExtent);
    await tester.pump();
    expect(
      find.byKey(ValueKey<String>('app-date-picker-year-$lastYear')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<ScrollbarTheme>(
            find.byKey(const Key('app-date-picker-year-scrollbar-theme')),
          )
          .data
          .mainAxisMargin,
      0,
    );
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('年份模式可從第一年捲到目前年份並套用', (WidgetTester tester) async {
    int? result;
    final int currentYear = DateTime.now().year;
    await tester.pumpWidget(
      _pickerApp(
        locale: appZhLocale,
        onOpen: (BuildContext context) async {
          result = await showAppYearPickerDialog(
            context: context,
            initialYear: currentYear,
            firstYear: 1,
            lastYear: currentYear,
          );
        },
      ),
    );
    await tester.tap(find.byKey(const Key('open-picker')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('app-date-picker-today')), findsNothing);

    final GridView yearGrid = tester.widget(
      find.byKey(const Key('app-date-picker-year-grid')),
    );
    final ScrollController controller = yearGrid.controller!;
    controller.jumpTo(0);
    await tester.pump();
    expect(
      find.byKey(const ValueKey('app-date-picker-year-1')),
      findsOneWidget,
    );
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    expect(
      find.byKey(ValueKey<String>('app-date-picker-year-$currentYear')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(ValueKey<String>('app-date-picker-year-$currentYear')),
    );
    await tester.tap(find.byKey(const Key('app-date-picker-apply')));
    await tester.pumpAndSettle();

    expect(result, currentYear);
  });

  testWidgets('年份初始值早於範圍時定位到第一年且取消不回傳結果', (WidgetTester tester) async {
    int? result;
    await tester.pumpWidget(
      _pickerApp(
        locale: appZhLocale,
        onOpen: (BuildContext context) async {
          result = await showAppYearPickerDialog(
            context: context,
            initialYear: 1899,
            firstYear: 1900,
            lastYear: 2026,
          );
        },
      ),
    );
    await tester.tap(find.byKey(const Key('open-picker')));
    await tester.pumpAndSettle();

    final TextButton firstYear = tester.widget<TextButton>(
      find.byKey(const ValueKey<String>('app-date-picker-year-1900')),
    );
    expect(
      firstYear.style?.backgroundColor?.resolve(<WidgetState>{}),
      Theme.of(tester.element(find.byType(AlertDialog))).colorScheme.primary,
    );
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });

  testWidgets('年份初始值晚於範圍時定位到最後一年並只在套用後回傳', (WidgetTester tester) async {
    int? result;
    await tester.pumpWidget(
      _pickerApp(
        locale: appZhLocale,
        onOpen: (BuildContext context) async {
          result = await showAppYearPickerDialog(
            context: context,
            initialYear: 9999,
            firstYear: 1900,
            lastYear: 2026,
          );
        },
      ),
    );
    await tester.tap(find.byKey(const Key('open-picker')));
    await tester.pumpAndSettle();
    expect(result, isNull);

    await tester.tap(find.byKey(const Key('app-date-picker-apply')));
    await tester.pumpAndSettle();

    expect(result, 2026);
  });
}
