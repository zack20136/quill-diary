import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../display_format.dart';

typedef AppMonthDay = ({int month, int day});

Future<DateTime?> showAppDatePickerDialog({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String? title,
}) {
  assert(!lastDate.isBefore(firstDate));
  assert(!initialDate.isBefore(firstDate) && !initialDate.isAfter(lastDate));
  return _showAppDatePicker<DateTime>(
    context: context,
    config: _AppDatePickerConfig<DateTime>(
      kind: _AppDatePickerKind.date,
      title: title ?? context.l10n.datePickerChooseDate,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      resultBuilder: (int year, int month, int day) =>
          DateTime(year, month, day),
    ),
  );
}

Future<DateTime?> showAppYearMonthPickerDialog({
  required BuildContext context,
  required DateTime initialMonth,
  required DateTime firstMonth,
  required DateTime lastMonth,
  String? title,
}) {
  final DateTime normalizedInitial = DateTime(
    initialMonth.year,
    initialMonth.month,
  );
  final DateTime normalizedFirst = DateTime(firstMonth.year, firstMonth.month);
  final DateTime normalizedLast = DateTime(
    lastMonth.year,
    lastMonth.month + 1,
    0,
  );
  assert(!normalizedLast.isBefore(normalizedFirst));
  assert(
    !normalizedInitial.isBefore(normalizedFirst) &&
        !normalizedInitial.isAfter(normalizedLast),
  );
  return _showAppDatePicker<DateTime>(
    context: context,
    config: _AppDatePickerConfig<DateTime>(
      kind: _AppDatePickerKind.yearMonth,
      title: title ?? context.l10n.datePickerChooseYearMonth,
      initialDate: normalizedInitial,
      firstDate: normalizedFirst,
      lastDate: normalizedLast,
      resultBuilder: (int year, int month, int _) => DateTime(year, month),
    ),
  );
}

Future<AppMonthDay?> showAppMonthDayPickerDialog({
  required BuildContext context,
  required int initialMonth,
  required int initialDay,
  String? title,
}) {
  final DateTime initialDate = DateTime(2000, initialMonth, initialDay);
  assert(
    initialDate.month == initialMonth && initialDate.day == initialDay,
    'initialMonth 與 initialDay 必須組成有效日期',
  );
  return _showAppDatePicker<AppMonthDay>(
    context: context,
    config: _AppDatePickerConfig<AppMonthDay>(
      kind: _AppDatePickerKind.monthDay,
      title: title ?? context.l10n.datePickerChooseDate,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2000, 12, 31),
      resultBuilder: (int _, int month, int day) => (month: month, day: day),
    ),
  );
}

Future<int?> showAppYearPickerDialog({
  required BuildContext context,
  required int initialYear,
  required int firstYear,
  required int lastYear,
  String? title,
}) {
  assert(firstYear <= lastYear);
  final int normalizedInitialYear = initialYear.clamp(firstYear, lastYear);
  return _showAppDatePicker<int>(
    context: context,
    config: _AppDatePickerConfig<int>(
      kind: _AppDatePickerKind.year,
      title: title ?? context.l10n.datePickerChooseYear,
      initialDate: DateTime(normalizedInitialYear),
      firstDate: DateTime(firstYear),
      lastDate: DateTime(lastYear, 12, 31),
      resultBuilder: (int year, int _, int _) => year,
    ),
  );
}

Future<T?> _showAppDatePicker<T>({
  required BuildContext context,
  required _AppDatePickerConfig<T> config,
}) {
  return showDialog<T>(
    context: context,
    builder: (BuildContext context) => _AppDatePickerDialog<T>(config: config),
  );
}

enum _AppDatePickerKind { date, yearMonth, monthDay, year }

enum _AppDatePickerView { day, month, year }

class _AppDatePickerConfig<T> {
  const _AppDatePickerConfig({
    required this.kind,
    required this.title,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.resultBuilder,
  });

  final _AppDatePickerKind kind;
  final String title;
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final T Function(int year, int month, int day) resultBuilder;
}

class _AppDatePickerDialog<T> extends StatefulWidget {
  const _AppDatePickerDialog({required this.config});

  final _AppDatePickerConfig<T> config;

  @override
  State<_AppDatePickerDialog<T>> createState() =>
      _AppDatePickerDialogState<T>();
}

class _AppDatePickerDialogState<T> extends State<_AppDatePickerDialog<T>> {
  static const double _optionHeight = kMinInteractiveDimension;
  static const double _dayOptionHeight = 44;
  static const double _optionSpacing = 8;
  static const double _dayOptionSpacing = 2;
  static const double _monthSwipeDistanceThreshold = 48;
  static const double _monthSwipeVelocityThreshold = 300;

  late int _selectedYear = widget.config.initialDate.year;
  late int _selectedMonth = widget.config.initialDate.month;
  late int _selectedDay = widget.config.initialDate.day;
  late _AppDatePickerView _view = switch (widget.config.kind) {
    _AppDatePickerKind.date ||
    _AppDatePickerKind.monthDay => _AppDatePickerView.day,
    _AppDatePickerKind.yearMonth => _AppDatePickerView.month,
    _AppDatePickerKind.year => _AppDatePickerView.year,
  };
  late final ScrollController _dayScrollController = ScrollController();
  late final ScrollController _monthScrollController = ScrollController();
  late final ScrollController _yearScrollController = ScrollController();
  double _monthSwipeDistance = 0;
  double? _monthSwipeStartX;

  bool get _hasYear => widget.config.kind != _AppDatePickerKind.monthDay;
  bool get _hasMonth => widget.config.kind != _AppDatePickerKind.year;
  bool get _hasDay =>
      widget.config.kind == _AppDatePickerKind.date ||
      widget.config.kind == _AppDatePickerKind.monthDay;

  @override
  void initState() {
    super.initState();
    if (_view == _AppDatePickerView.year) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToYear());
    }
  }

  @override
  void dispose() {
    _dayScrollController.dispose();
    _monthScrollController.dispose();
    _yearScrollController.dispose();
    super.dispose();
  }

  int get _firstAvailableMonth => _selectedYear == widget.config.firstDate.year
      ? widget.config.firstDate.month
      : DateTime.january;

  int get _lastAvailableMonth => _selectedYear == widget.config.lastDate.year
      ? widget.config.lastDate.month
      : DateTime.december;

  int get _daysInSelectedMonth =>
      DateTime(_selectedYear, _selectedMonth + 1, 0).day;

  int get _yearColumnCount {
    return MediaQuery.textScalerOf(context).scale(1) >= 1.5 ? 2 : 3;
  }

  void _normalizeSelection() {
    _selectedMonth = _selectedMonth.clamp(
      _firstAvailableMonth,
      _lastAvailableMonth,
    );
    _selectedDay = _selectedDay.clamp(1, _daysInSelectedMonth);
    if (widget.config.kind == _AppDatePickerKind.date) {
      final DateTime selected = DateTime(
        _selectedYear,
        _selectedMonth,
        _selectedDay,
      );
      if (selected.isBefore(widget.config.firstDate)) {
        _selectedDay = widget.config.firstDate.day;
      } else if (selected.isAfter(widget.config.lastDate)) {
        _selectedDay = widget.config.lastDate.day;
      }
    }
  }

  void _setYear(int year) {
    setState(() {
      _selectedYear = year;
      _normalizeSelection();
      _view = widget.config.kind == _AppDatePickerKind.year
          ? _AppDatePickerView.year
          : _AppDatePickerView.month;
    });
  }

  void _setMonth(int month) {
    setState(() {
      _selectedMonth = month;
      _normalizeSelection();
      if (_hasDay) {
        _view = _AppDatePickerView.day;
      }
    });
  }

  void _setDay(int day) {
    setState(() => _selectedDay = day);
  }

  void _showMonthGrid() {
    setState(() => _view = _AppDatePickerView.month);
  }

  void _showYearGrid() {
    setState(() => _view = _AppDatePickerView.year);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToYear());
  }

  void _scrollToYear() {
    if (!mounted || !_yearScrollController.hasClients) {
      return;
    }
    final int selectedIndex = _selectedYear - widget.config.firstDate.year;
    final int selectedRow = selectedIndex ~/ _yearColumnCount;
    final double rowExtent = _optionHeight + _optionSpacing;
    final double centeredOffset =
        selectedRow * rowExtent -
        _yearScrollController.position.viewportDimension / 2 +
        _optionHeight / 2;
    _yearScrollController.jumpTo(
      centeredOffset.clamp(0, _yearScrollController.position.maxScrollExtent),
    );
  }

  DateTime _shiftedMonth(int delta) {
    if (widget.config.kind == _AppDatePickerKind.monthDay) {
      final int month = ((_selectedMonth - 1 + delta) % 12) + 1;
      return DateTime(2000, month);
    }
    return DateTime(_selectedYear, _selectedMonth + delta);
  }

  bool _canShiftMonth(int delta) {
    if (widget.config.kind == _AppDatePickerKind.monthDay) {
      return true;
    }
    final DateTime target = _shiftedMonth(delta);
    final DateTime first = DateTime(
      widget.config.firstDate.year,
      widget.config.firstDate.month,
    );
    final DateTime last = DateTime(
      widget.config.lastDate.year,
      widget.config.lastDate.month,
    );
    return !target.isBefore(first) && !target.isAfter(last);
  }

  void _shiftMonth(int delta) {
    final DateTime target = _shiftedMonth(delta);
    setState(() {
      _selectedYear = target.year;
      _selectedMonth = target.month;
      _normalizeSelection();
    });
  }

  void _prepareMonthSwipe(DragDownDetails details) {
    _monthSwipeStartX = details.globalPosition.dx;
    _monthSwipeDistance = 0;
  }

  void _updateMonthSwipe(DragUpdateDetails details) {
    // 從按下位置計算，避免手勢競爭消耗的觸控距離讓 48px 門檻失真。
    _monthSwipeDistance =
        details.globalPosition.dx -
        (_monthSwipeStartX ?? details.globalPosition.dx);
  }

  void _endMonthSwipe(DragEndDetails details) {
    final double velocity = details.primaryVelocity ?? 0;
    final double direction =
        _monthSwipeDistance.abs() >= _monthSwipeDistanceThreshold
        ? _monthSwipeDistance
        : velocity.abs() >= _monthSwipeVelocityThreshold
        ? velocity
        : 0;
    _monthSwipeDistance = 0;
    _monthSwipeStartX = null;
    if (direction < 0 && _canShiftMonth(1)) {
      _shiftMonth(1);
    } else if (direction > 0 && _canShiftMonth(-1)) {
      _shiftMonth(-1);
    }
  }

  bool get _canSelectToday {
    if (widget.config.kind != _AppDatePickerKind.date) {
      return false;
    }
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    return !today.isBefore(widget.config.firstDate) &&
        !today.isAfter(widget.config.lastDate);
  }

  void _selectToday() {
    final DateTime now = DateTime.now();
    setState(() {
      _selectedYear = now.year;
      _selectedMonth = now.month;
      _selectedDay = now.day;
      _view = _AppDatePickerView.day;
    });
  }

  bool _isMonthAvailable(int month) {
    return month >= _firstAvailableMonth && month <= _lastAvailableMonth;
  }

  bool _isDayAvailable(int day) {
    if (widget.config.kind == _AppDatePickerKind.monthDay) {
      return day <= _daysInSelectedMonth;
    }
    final DateTime date = DateTime(_selectedYear, _selectedMonth, day);
    return !date.isBefore(widget.config.firstDate) &&
        !date.isAfter(widget.config.lastDate);
  }

  ButtonStyle _optionStyle({required bool selected}) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return ButtonStyle(
      minimumSize: const WidgetStatePropertyAll<Size>(
        Size.fromHeight(_optionHeight),
      ),
      padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
        EdgeInsets.symmetric(horizontal: 6),
      ),
      backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.disabled)) {
          return Colors.transparent;
        }
        if (selected) {
          return colors.primary;
        }
        if (states.contains(WidgetState.pressed)) {
          return colors.primaryContainer;
        }
        return Colors.transparent;
      }),
      foregroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.disabled)) {
          return colors.onSurface.withValues(alpha: 0.32);
        }
        if (selected) {
          return colors.onPrimary;
        }
        if (states.contains(WidgetState.pressed)) {
          return colors.onPrimaryContainer;
        }
        return colors.onSurfaceVariant;
      }),
      overlayColor: WidgetStatePropertyAll<Color>(
        colors.primary.withValues(alpha: 0.08),
      ),
      side: const WidgetStatePropertyAll<BorderSide>(BorderSide.none),
      shape: WidgetStatePropertyAll<OutlinedBorder>(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      textStyle: WidgetStatePropertyAll<TextStyle>(
        TextStyle(fontWeight: selected ? FontWeight.w700 : FontWeight.w600),
      ),
    );
  }

  ButtonStyle _dayOptionStyle({required bool selected, bool isToday = false}) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return ButtonStyle(
      animationDuration: Duration.zero,
      minimumSize: const WidgetStatePropertyAll<Size>(
        Size.fromHeight(_dayOptionHeight),
      ),
      padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
        EdgeInsets.zero,
      ),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.disabled)) {
          return Colors.transparent;
        }
        if (selected) {
          return colors.primary;
        }
        if (isToday) {
          return colors.primaryContainer;
        }
        if (states.contains(WidgetState.pressed)) {
          return colors.primaryContainer;
        }
        return Colors.transparent;
      }),
      foregroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.disabled)) {
          return colors.onSurface.withValues(alpha: 0.32);
        }
        if (selected) {
          return colors.onPrimary;
        }
        if (states.contains(WidgetState.pressed)) {
          return colors.onPrimaryContainer;
        }
        return isToday ? colors.onPrimaryContainer : colors.onSurfaceVariant;
      }),
      overlayColor: WidgetStatePropertyAll<Color>(
        colors.primary.withValues(alpha: 0.08),
      ),
      side: WidgetStatePropertyAll<BorderSide>(
        selected
            ? BorderSide(color: colors.primary)
            : isToday
            ? BorderSide(color: colors.primaryContainer)
            : BorderSide.none,
      ),
      shape: const WidgetStatePropertyAll<OutlinedBorder>(CircleBorder()),
      textStyle: WidgetStatePropertyAll<TextStyle>(
        TextStyle(
          fontWeight: selected || isToday ? FontWeight.w700 : FontWeight.w600,
        ),
      ),
    );
  }

  ButtonStyle _navigationIconStyle({required double minimumSize}) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return IconButton.styleFrom(
      minimumSize: Size.square(minimumSize),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      foregroundColor: colors.onSurfaceVariant,
      disabledForegroundColor: colors.onSurface.withValues(alpha: 0.28),
    );
  }

  ButtonStyle _periodControlStyle({required double minimumHeight}) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return FilledButton.styleFrom(
      minimumSize: Size.fromHeight(minimumHeight),
      backgroundColor: colors.surfaceContainerLow,
      foregroundColor: colors.onSurfaceVariant,
      disabledBackgroundColor: colors.surfaceContainerLow.withValues(
        alpha: 0.45,
      ),
      disabledForegroundColor: colors.onSurface.withValues(alpha: 0.32),
      textStyle: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }

  Widget _scrollbar({
    required Key key,
    required ScrollController controller,
    required Widget child,
  }) {
    return ScrollbarTheme(
      key: key,
      data: ScrollbarTheme.of(context).copyWith(mainAxisMargin: 0),
      child: Scrollbar(
        controller: controller,
        thumbVisibility: true,
        trackVisibility: true,
        interactive: true,
        child: child,
      ),
    );
  }

  int get _monthColumnCount {
    final double textScale = MediaQuery.textScalerOf(context).scale(1);
    if (textScale >= 1.5) {
      return 2;
    }
    if (textScale >= 1.15) {
      return 3;
    }
    return 4;
  }

  double get _monthOptionHeight {
    final double textScale = MediaQuery.textScalerOf(context).scale(1);
    return (_optionHeight * textScale).clamp(_optionHeight, 72).toDouble();
  }

  Widget _buildBackHeader(String label, VoidCallback onBack) {
    return Row(
      children: <Widget>[
        IconButton(
          key: const Key('app-date-picker-back'),
          tooltip: label,
          onPressed: onBack,
          style: _navigationIconStyle(minimumSize: _dayOptionHeight),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          key: const Key('app-date-picker-back-label'),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildYearControl() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          context.l10n.datePickerYearLabel,
          key: const Key('app-date-picker-year-label'),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            IconButton(
              key: const Key('app-date-picker-previous-year'),
              tooltip: context.l10n.datePickerPreviousYear,
              onPressed: _selectedYear > widget.config.firstDate.year
                  ? () => _setYear(_selectedYear - 1)
                  : null,
              style: _navigationIconStyle(minimumSize: _optionHeight),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: FilledButton.tonal(
                key: const Key('app-date-picker-year-chooser'),
                onPressed: _showYearGrid,
                style: _periodControlStyle(minimumHeight: _optionHeight),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Flexible(child: Text('$_selectedYear')),
                    const SizedBox(width: 2),
                    const Icon(Icons.arrow_drop_down, size: 18),
                  ],
                ),
              ),
            ),
            IconButton(
              key: const Key('app-date-picker-next-year'),
              tooltip: context.l10n.datePickerNextYear,
              onPressed: _selectedYear < widget.config.lastDate.year
                  ? () => _setYear(_selectedYear + 1)
                  : null,
              style: _navigationIconStyle(minimumSize: _optionHeight),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMonthView() {
    return _scrollbar(
      key: const Key('app-date-picker-month-scrollbar-theme'),
      controller: _monthScrollController,
      child: SingleChildScrollView(
        key: const Key('app-date-picker-month-view'),
        controller: _monthScrollController,
        padding: const EdgeInsets.only(right: 12, bottom: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (_hasDay)
              _buildBackHeader(
                context.l10n.datePickerDayLabel,
                () => setState(() => _view = _AppDatePickerView.day),
              ),
            if (_hasDay) const SizedBox(height: 8),
            if (_hasYear) _buildYearControl(),
            if (_hasYear) const SizedBox(height: 18),
            Text(
              context.l10n.datePickerMonthLabel,
              key: const Key('app-date-picker-month-label'),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _monthColumnCount,
                mainAxisExtent: _monthOptionHeight,
                crossAxisSpacing: _optionSpacing,
                mainAxisSpacing: _optionSpacing,
              ),
              itemCount: DateTime.monthsPerYear,
              itemBuilder: (BuildContext context, int index) {
                final int month = index + 1;
                final bool selected = month == _selectedMonth;
                return TextButton(
                  key: ValueKey<String>('app-date-picker-month-$month'),
                  onPressed: _isMonthAvailable(month)
                      ? () => _setMonth(month)
                      : null,
                  style: _optionStyle(selected: selected),
                  child: Text(
                    context.l10n.datePickerMonthOption(month),
                    textAlign: TextAlign.center,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildYearView() {
    final int yearCount =
        widget.config.lastDate.year - widget.config.firstDate.year + 1;
    return Column(
      key: const Key('app-date-picker-year-view'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (_hasMonth)
          _buildBackHeader(
            context.l10n.datePickerMonthLabel,
            () => setState(() => _view = _AppDatePickerView.month),
          )
        else
          Text(
            context.l10n.datePickerYearLabel,
            key: const Key('app-date-picker-year-label'),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: _scrollbar(
            key: const Key('app-date-picker-year-scrollbar-theme'),
            controller: _yearScrollController,
            child: GridView.builder(
              key: const Key('app-date-picker-year-grid'),
              controller: _yearScrollController,
              padding: const EdgeInsets.only(right: 12, bottom: 4),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _yearColumnCount,
                mainAxisExtent: _optionHeight,
                crossAxisSpacing: _optionSpacing,
                mainAxisSpacing: _optionSpacing,
              ),
              itemCount: yearCount,
              itemBuilder: (BuildContext context, int index) {
                final int year = widget.config.firstDate.year + index;
                return TextButton(
                  key: ValueKey<String>('app-date-picker-year-$year'),
                  onPressed: () => _setYear(year),
                  style: _optionStyle(selected: year == _selectedYear),
                  child: Text('$year'),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  List<String> _weekdayLabels() => <String>[
    context.l10n.datePickerWeekdaySun,
    context.l10n.datePickerWeekdayMon,
    context.l10n.datePickerWeekdayTue,
    context.l10n.datePickerWeekdayWed,
    context.l10n.datePickerWeekdayThu,
    context.l10n.datePickerWeekdayFri,
    context.l10n.datePickerWeekdaySat,
  ];

  Widget _buildDayView() {
    final DateTime today = DateTime.now();
    final bool showWeekdays = widget.config.kind == _AppDatePickerKind.date;
    final int leadingDays = showWeekdays
        ? DateTime(_selectedYear, _selectedMonth).weekday % 7
        : 0;
    // 完整日期固定顯示六週，避免切換月份時對話框內容上下跳動。
    final int itemCount = showWeekdays
        ? DateTime.daysPerWeek * 6
        : _daysInSelectedMonth;
    final String periodLabel = showWeekdays
        ? DisplayFormat.formatYearMonth(
            context.l10n,
            _selectedYear,
            _selectedMonth,
          )
        : context.l10n.datePickerMonthOption(_selectedMonth);
    final List<String> weekdayLabels = _weekdayLabels();
    final Widget dayView = _scrollbar(
      key: const Key('app-date-picker-day-scrollbar-theme'),
      controller: _dayScrollController,
      child: SingleChildScrollView(
        key: const Key('app-date-picker-day-view'),
        controller: _dayScrollController,
        padding: const EdgeInsets.only(right: 12, bottom: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                IconButton(
                  key: const Key('app-date-picker-previous-month'),
                  tooltip: context.l10n.datePickerPreviousMonth,
                  onPressed: _canShiftMonth(-1) ? () => _shiftMonth(-1) : null,
                  style: _navigationIconStyle(minimumSize: _dayOptionHeight),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: FilledButton.tonal(
                    key: const Key('app-date-picker-period-button'),
                    onPressed: _showMonthGrid,
                    style: _periodControlStyle(minimumHeight: _dayOptionHeight),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Flexible(child: Text(periodLabel)),
                        const SizedBox(width: 2),
                        const Icon(Icons.arrow_drop_down, size: 18),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('app-date-picker-next-month'),
                  tooltip: context.l10n.datePickerNextMonth,
                  onPressed: _canShiftMonth(1) ? () => _shiftMonth(1) : null,
                  style: _navigationIconStyle(minimumSize: _dayOptionHeight),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (showWeekdays)
              Row(
                children: <Widget>[
                  for (int index = 0; index < weekdayLabels.length; index++)
                    Expanded(
                      child: Center(
                        child: Text(
                          weekdayLabels[index],
                          key: ValueKey<String>(
                            'app-date-picker-weekday-$index',
                          ),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: index == 0 || index == 6
                                    ? Theme.of(context).colorScheme.error
                                          .withValues(alpha: 0.78)
                                    : Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ),
                ],
              ),
            if (showWeekdays) const SizedBox(height: 4),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisExtent: _dayOptionHeight,
                crossAxisSpacing: _dayOptionSpacing,
                mainAxisSpacing: _dayOptionSpacing,
              ),
              itemCount: itemCount,
              itemBuilder: (BuildContext context, int index) {
                final int dayOffset = index - leadingDays;
                if (dayOffset < 0 || dayOffset >= _daysInSelectedMonth) {
                  final DateTime adjacentDate = DateTime(
                    _selectedYear,
                    _selectedMonth,
                    dayOffset + 1,
                  );
                  return TextButton(
                    key: ValueKey<String>(
                      'app-date-picker-adjacent-${adjacentDate.year}-${adjacentDate.month}-${adjacentDate.day}',
                    ),
                    onPressed: null,
                    style: _dayOptionStyle(selected: false),
                    child: Text('${adjacentDate.day}'),
                  );
                }
                final int day = dayOffset + 1;
                final bool isToday =
                    _selectedYear == today.year &&
                    _selectedMonth == today.month &&
                    day == today.day;
                return Semantics(
                  label: context.l10n.datePickerDayOption(day),
                  hint: isToday ? context.l10n.commonRelativeToday : null,
                  selected: day == _selectedDay,
                  button: true,
                  child: TextButton(
                    key: ValueKey<String>('app-date-picker-day-$day'),
                    onPressed: _isDayAvailable(day) ? () => _setDay(day) : null,
                    style: _dayOptionStyle(
                      selected: day == _selectedDay,
                      isToday: isToday,
                    ),
                    child: Text('$day'),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
    if (widget.config.kind != _AppDatePickerKind.date) {
      return dayView;
    }
    return GestureDetector(
      key: const Key('app-date-picker-month-swipe-area'),
      behavior: HitTestBehavior.opaque,
      onHorizontalDragDown: _prepareMonthSwipe,
      onHorizontalDragUpdate: _updateMonthSwipe,
      onHorizontalDragEnd: _endMonthSwipe,
      onHorizontalDragCancel: () {
        _monthSwipeDistance = 0;
        _monthSwipeStartX = null;
      },
      child: dayView,
    );
  }

  Widget _buildContent() {
    return switch (_view) {
      _AppDatePickerView.day => _buildDayView(),
      _AppDatePickerView.month => _buildMonthView(),
      _AppDatePickerView.year => _buildYearView(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final double contentHeight = (MediaQuery.sizeOf(context).height - 220)
        .clamp(280, 420)
        .toDouble();
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      actionsPadding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      title: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              widget.config.title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          if (widget.config.kind == _AppDatePickerKind.date)
            TextButton(
              key: const Key('app-date-picker-today'),
              onPressed: _canSelectToday ? _selectToday : null,
              style: TextButton.styleFrom(
                minimumSize: const Size(44, 44),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                foregroundColor: Theme.of(context).colorScheme.primary,
                disabledForegroundColor: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.32),
                textStyle: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              child: Text(context.l10n.commonRelativeToday),
            ),
        ],
      ),
      content: SizedBox(
        width: 340,
        height: contentHeight,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: KeyedSubtree(key: ValueKey(_view), child: _buildContent()),
        ),
      ),
      actions: <Widget>[
        TextButton(
          key: const Key('app-date-picker-cancel'),
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            minimumSize: const Size(44, 44),
            foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
            textStyle: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          child: Text(context.l10n.commonActionCancel),
        ),
        FilledButton.icon(
          key: const Key('app-date-picker-apply'),
          onPressed: () => Navigator.pop(
            context,
            widget.config.resultBuilder(
              _selectedYear,
              _selectedMonth,
              _selectedDay,
            ),
          ),
          style: FilledButton.styleFrom(
            minimumSize: const Size(44, 44),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            textStyle: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          icon: const Icon(Icons.check_rounded, size: 19),
          label: Text(context.l10n.commonActionApply),
        ),
      ],
    );
  }
}
