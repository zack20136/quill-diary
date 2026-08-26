import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
    localizationsDelegates: AppLocalizations.localizationsDelegates,
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

ButtonStyle _buttonStyle(WidgetTester tester, Finder finder) {
  final Widget button = tester.widget(finder);
  return switch (button) {
    TextButton(:final ButtonStyle? style) => style!,
    FilledButton(:final ButtonStyle? style) => style!,
    IconButton(:final ButtonStyle? style) => style!,
    _ => throw StateError('找不到按鈕樣式'),
  };
}

void _expectButtonColors(
  WidgetTester tester,
  Finder finder, {
  required Color background,
  required Color foreground,
  Set<WidgetState> states = const <WidgetState>{},
}) {
  final ButtonStyle style = _buttonStyle(tester, finder);
  expect(style.backgroundColor?.resolve(states), background);
  expect(style.foregroundColor?.resolve(states), foreground);
}

void _expectPlainOption(
  WidgetTester tester,
  Finder finder,
  ColorScheme colors,
) {
  _expectButtonColors(
    tester,
    finder,
    background: Colors.transparent,
    foreground: colors.onSurfaceVariant,
  );
  expect(
    _buttonStyle(tester, finder).side?.resolve(<WidgetState>{}),
    BorderSide.none,
  );
}

void _expectSelectedOption(
  WidgetTester tester,
  Finder finder,
  ColorScheme colors,
) {
  _expectButtonColors(
    tester,
    finder,
    background: colors.primary,
    foreground: colors.onPrimary,
  );
}

void main() {
  testWidgets('完整日期標題不顯示圖示且今天使用淺色提示', (WidgetTester tester) async {
    _useCompactLargeTextView(tester);
    final DateTime now = DateTime.now();
    final int otherDay = now.day == 1 ? 2 : 1;
    DateTime? result;
    await tester.pumpWidget(
      _pickerApp(
        locale: appZhLocale,
        onOpen: (BuildContext context) async {
          result = await showAppDatePickerDialog(
            context: context,
            initialDate: DateTime(now.year, now.month, otherDay),
            firstDate: DateTime(now.year, now.month - 1),
            lastDate: DateTime(now.year, now.month + 2, 0),
          );
        },
      ),
    );
    await tester.tap(find.byKey(const Key('open-picker')));
    await tester.pumpAndSettle();

    final Finder dialog = find.byType(AlertDialog);
    expect(
      find.descendant(
        of: dialog,
        matching: find.byIcon(Icons.calendar_month_rounded),
      ),
      findsNothing,
    );
    final Finder today = find.byKey(
      ValueKey<String>('app-date-picker-day-${now.day}'),
    );
    final TextButton todayButton = tester.widget<TextButton>(today);
    final ColorScheme colors = Theme.of(tester.element(dialog)).colorScheme;
    final Text sunday = tester.widget<Text>(
      find.byKey(const ValueKey<String>('app-date-picker-weekday-0')),
    );
    final Text monday = tester.widget<Text>(
      find.byKey(const ValueKey<String>('app-date-picker-weekday-1')),
    );
    final Text saturday = tester.widget<Text>(
      find.byKey(const ValueKey<String>('app-date-picker-weekday-6')),
    );
    expect(sunday.style?.color, colors.error.withValues(alpha: 0.78));
    expect(saturday.style?.color, colors.error.withValues(alpha: 0.78));
    expect(monday.style?.color, colors.onSurfaceVariant);
    expect(
      todayButton.style?.backgroundColor?.resolve(<WidgetState>{}),
      colors.primaryContainer,
    );
    expect(
      todayButton.style?.foregroundColor?.resolve(<WidgetState>{}),
      colors.onPrimaryContainer,
    );
    expect(
      todayButton.style?.side?.resolve(<WidgetState>{})?.color,
      colors.primaryContainer,
    );
    expect(
      todayButton.style?.shape?.resolve(<WidgetState>{}),
      isA<CircleBorder>(),
    );
    expect(tester.getSize(today).height, 44);
    final int neutralDay = <int>[
      1,
      2,
      3,
      4,
    ].firstWhere((int day) => day != now.day && day != otherDay);
    final Finder neutralDayButton = find.byKey(
      ValueKey<String>('app-date-picker-day-$neutralDay'),
    );
    _expectPlainOption(tester, neutralDayButton, colors);
    expect(
      _buttonStyle(tester, neutralDayButton).shape?.resolve(<WidgetState>{}),
      isA<CircleBorder>(),
    );
    _expectButtonColors(
      tester,
      neutralDayButton,
      states: const <WidgetState>{WidgetState.pressed},
      background: colors.primaryContainer,
      foreground: colors.onPrimaryContainer,
    );
    final Finder oldSelection = find.byKey(
      ValueKey<String>('app-date-picker-day-$otherDay'),
    );
    await tester.tap(neutralDayButton);
    await tester.pump();
    final TextButton oldSelectionButton = tester.widget<TextButton>(
      oldSelection,
    );
    expect(oldSelectionButton.style?.animationDuration, Duration.zero);
    expect(
      oldSelectionButton.style?.side?.resolve(<WidgetState>{}),
      BorderSide.none,
    );
    _expectSelectedOption(tester, neutralDayButton, colors);
    final Finder todayAction = find.byKey(const Key('app-date-picker-today'));
    expect(tester.getSize(todayAction).height, greaterThanOrEqualTo(44));
    expect(
      tester.getSize(find.byKey(const Key('app-date-picker-cancel'))).height,
      greaterThanOrEqualTo(44),
    );
    expect(
      tester.getSize(find.byKey(const Key('app-date-picker-apply'))).height,
      greaterThanOrEqualTo(44),
    );
    expect(
      tester.getCenter(todayAction).dx,
      greaterThan(tester.getCenter(find.text('選擇日期')).dx),
    );

    await tester.tap(todayAction);
    await tester.pumpAndSettle();
    _expectSelectedOption(tester, today, colors);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('日期月份年份在亮暗色主題使用一致的狀態配色', (WidgetTester tester) async {
    for (final Brightness brightness in Brightness.values) {
      await tester.pumpWidget(
        _pickerApp(
          locale: appZhLocale,
          brightness: brightness,
          onOpen: (BuildContext context) => showAppDatePickerDialog(
            context: context,
            initialDate: DateTime(2025, 8, 13),
            firstDate: DateTime(2025, 8),
            lastDate: DateTime(2026, 12, 31),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('open-picker')));
      await tester.pumpAndSettle();

      final Finder dialog = find.byType(AlertDialog);
      final ColorScheme colors = Theme.of(tester.element(dialog)).colorScheme;
      _expectPlainOption(
        tester,
        find.byKey(const ValueKey<String>('app-date-picker-day-14')),
        colors,
      );
      expect(
        _buttonStyle(
          tester,
          find.byKey(const Key('app-date-picker-next-month')),
        ).foregroundColor?.resolve(<WidgetState>{}),
        colors.onSurfaceVariant,
      );

      await tester.tap(find.byKey(const Key('app-date-picker-period-button')));
      await tester.pumpAndSettle();

      final Finder yearControl = find.byKey(
        const Key('app-date-picker-year-chooser'),
      );
      expect(
        find.descendant(
          of: yearControl,
          matching: find.byIcon(Icons.calendar_view_month_rounded),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: yearControl,
          matching: find.byIcon(Icons.arrow_drop_down),
        ),
        findsOneWidget,
      );
      _expectButtonColors(
        tester,
        yearControl,
        background: colors.surfaceContainerLow,
        foreground: colors.onSurfaceVariant,
      );
      expect(find.byKey(const Key('app-date-picker-back')), findsNothing);
      expect(find.byKey(const Key('app-date-picker-back-label')), findsNothing);
      for (final String key in <String>[
        'app-date-picker-year-label',
        'app-date-picker-month-label',
      ]) {
        expect(
          tester.widget<Text>(find.byKey(Key(key))).style?.color,
          colors.onSurfaceVariant,
        );
      }

      final TextButton disabledMonth = tester.widget<TextButton>(
        find.byKey(const ValueKey<String>('app-date-picker-month-1')),
      );
      expect(disabledMonth.onPressed, isNull);
      _expectButtonColors(
        tester,
        find.byKey(const ValueKey<String>('app-date-picker-month-1')),
        states: const <WidgetState>{WidgetState.disabled},
        background: Colors.transparent,
        foreground: colors.onSurface.withValues(alpha: 0.32),
      );
      final Finder month = find.byKey(
        const ValueKey<String>('app-date-picker-month-9'),
      );
      _expectPlainOption(tester, month, colors);
      _expectButtonColors(
        tester,
        month,
        states: const <WidgetState>{WidgetState.pressed},
        background: colors.primaryContainer,
        foreground: colors.onPrimaryContainer,
      );
      _expectSelectedOption(
        tester,
        find.byKey(const ValueKey<String>('app-date-picker-month-8')),
        colors,
      );

      await tester.tap(find.byKey(const Key('app-date-picker-year-chooser')));
      await tester.pumpAndSettle();

      _expectSelectedOption(
        tester,
        find.byKey(const ValueKey<String>('app-date-picker-year-2025')),
        colors,
      );
      _expectPlainOption(
        tester,
        find.byKey(const ValueKey<String>('app-date-picker-year-2026')),
        colors,
      );

      await tester.tap(find.byKey(const Key('app-date-picker-cancel')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

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
