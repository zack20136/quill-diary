import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/shared/value_objects.dart';

enum HomeTab { home, calendar, overview, tags }

enum MemoryScope { all, month, year }

class HomeTabController extends Notifier<HomeTab> {
  @override
  HomeTab build() => HomeTab.home;

  void set(HomeTab value) => state = value;
}

class HomeSearchQueryController extends Notifier<String> {
  @override
  String build() => '';

  void update(String value) => state = value;
}

class CalendarSelectedDateController extends Notifier<DateOnly?> {
  @override
  DateOnly? build() => DateOnly.fromDateTime(DateTime.now());

  void set(DateOnly? value) => state = value;
}

class CalendarVisibleMonthController extends Notifier<DateTime> {
  @override
  DateTime build() {
    final DateTime now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  void set(DateTime value) => state = DateTime(value.year, value.month);
}

class OverviewTagFilterController extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? value) => state = value;
}

class MemoryScopeController extends Notifier<MemoryScope> {
  @override
  MemoryScope build() => MemoryScope.all;

  void set(MemoryScope value) => state = value;
}

class MemoryFocusedMonthController extends Notifier<DateTime> {
  @override
  DateTime build() {
    final DateTime now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  void set(DateTime value) => state = DateTime(value.year, value.month);
}

class MemoryFocusedYearController extends Notifier<int> {
  @override
  int build() => DateTime.now().year;

  void set(int value) => state = value;
}

final homeTabProvider = NotifierProvider<HomeTabController, HomeTab>(
  HomeTabController.new,
);

final homeSearchQueryProvider = NotifierProvider<HomeSearchQueryController, String>(
  HomeSearchQueryController.new,
);

final calendarSelectedDateProvider =
    NotifierProvider<CalendarSelectedDateController, DateOnly?>(
  CalendarSelectedDateController.new,
);

final calendarVisibleMonthProvider =
    NotifierProvider<CalendarVisibleMonthController, DateTime>(
  CalendarVisibleMonthController.new,
);

final overviewTagFilterProvider = NotifierProvider<OverviewTagFilterController, String?>(
  OverviewTagFilterController.new,
);

final memoryScopeProvider = NotifierProvider<MemoryScopeController, MemoryScope>(
  MemoryScopeController.new,
);

final memoryFocusedMonthProvider =
    NotifierProvider<MemoryFocusedMonthController, DateTime>(
  MemoryFocusedMonthController.new,
);

final memoryFocusedYearProvider = NotifierProvider<MemoryFocusedYearController, int>(
  MemoryFocusedYearController.new,
);
