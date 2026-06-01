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
  MemoryScope build() => MemoryScope.month;

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

class HomeEntrySelectionState {
  const HomeEntrySelectionState({
    this.isActive = false,
    this.selectedIds = const <EntryId>{},
  });

  final bool isActive;
  final Set<EntryId> selectedIds;

  HomeEntrySelectionState copyWith({
    bool? isActive,
    Set<EntryId>? selectedIds,
  }) {
    return HomeEntrySelectionState(
      isActive: isActive ?? this.isActive,
      selectedIds: selectedIds ?? this.selectedIds,
    );
  }
}

class HomeEntrySelectionController extends Notifier<HomeEntrySelectionState> {
  @override
  HomeEntrySelectionState build() => const HomeEntrySelectionState();

  void enterSelection() {
    state = const HomeEntrySelectionState(isActive: true);
  }

  void enterWith(EntryId id) {
    state = HomeEntrySelectionState(
      isActive: true,
      selectedIds: <EntryId>{id},
    );
  }

  void toggle(EntryId id) {
    if (!state.isActive) {
      enterWith(id);
      return;
    }
    final Set<EntryId> next = Set<EntryId>.from(state.selectedIds);
    if (next.contains(id)) {
      next.remove(id);
    } else {
      next.add(id);
    }
    if (next.isEmpty) {
      state = state.copyWith(selectedIds: next);
      return;
    }
    state = state.copyWith(selectedIds: next);
  }

  void selectAll(Iterable<EntryId> ids) {
    final Set<EntryId> all = ids.toSet();
    if (all.isEmpty) {
      return;
    }
    final bool allSelected =
        state.selectedIds.length == all.length && all.every(state.selectedIds.contains);
    if (allSelected) {
      state = HomeEntrySelectionState(isActive: true, selectedIds: const <EntryId>{});
      return;
    }
    state = HomeEntrySelectionState(isActive: true, selectedIds: all);
  }

  void clear() {
    state = const HomeEntrySelectionState();
  }

  void pruneToVisible(Iterable<EntryId> visibleIds) {
    if (!state.isActive) {
      return;
    }
    final Set<EntryId> visible = visibleIds.toSet();
    final Set<EntryId> next =
        state.selectedIds.where(visible.contains).toSet();
    if (next.isEmpty) {
      state = state.copyWith(selectedIds: next);
      return;
    }
    if (next.length != state.selectedIds.length) {
      state = state.copyWith(selectedIds: next);
    }
  }
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

final homeEntrySelectionProvider =
    NotifierProvider<HomeEntrySelectionController, HomeEntrySelectionState>(
  HomeEntrySelectionController.new,
);
