import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/shared/value_objects.dart';
import '../../../infrastructure/database/index_database.dart';
import '../../../shared/utils/entry_sorting.dart';

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
    this.frozenDisplayOrder = const <EntryId>[],
  });

  final bool isActive;
  final Set<EntryId> selectedIds;

  /// 進入選取模式當下的列表順序，避免切換排序造成項目跳動。
  final List<EntryId> frozenDisplayOrder;

  HomeEntrySelectionState copyWith({
    bool? isActive,
    Set<EntryId>? selectedIds,
    List<EntryId>? frozenDisplayOrder,
  }) {
    return HomeEntrySelectionState(
      isActive: isActive ?? this.isActive,
      selectedIds: selectedIds ?? this.selectedIds,
      frozenDisplayOrder: frozenDisplayOrder ?? this.frozenDisplayOrder,
    );
  }
}

class HomeEntrySelectionController extends Notifier<HomeEntrySelectionState> {
  @override
  HomeEntrySelectionState build() => const HomeEntrySelectionState();

  void enterSelection(List<EntryId> displayOrder) {
    state = HomeEntrySelectionState(
      isActive: true,
      frozenDisplayOrder: List<EntryId>.from(displayOrder),
    );
  }

  void enterWith(EntryId id, {required List<EntryId> displayOrder}) {
    state = HomeEntrySelectionState(
      isActive: true,
      selectedIds: <EntryId>{id},
      frozenDisplayOrder: List<EntryId>.from(displayOrder),
    );
  }

  void toggle(EntryId id, {required List<EntryId> displayOrder}) {
    if (!state.isActive) {
      enterWith(id, displayOrder: displayOrder);
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
        state.selectedIds.length == all.length &&
        all.every(state.selectedIds.contains);
    if (allSelected) {
      state = state.copyWith(selectedIds: const <EntryId>{});
      return;
    }
    state = state.copyWith(selectedIds: all);
  }

  void syncFrozenDisplayOrder(List<EntryId> displayOrder) {
    if (!state.isActive) {
      return;
    }
    state = state.copyWith(
      frozenDisplayOrder: List<EntryId>.from(displayOrder),
    );
  }

  void clear() {
    state = const HomeEntrySelectionState();
  }

  void pruneToVisible(Iterable<EntryId> visibleIds) {
    if (!state.isActive) {
      return;
    }
    final Set<EntryId> visible = visibleIds.toSet();
    final Set<EntryId> next = state.selectedIds.where(visible.contains).toSet();
    if (next.isEmpty) {
      state = state.copyWith(selectedIds: next);
      return;
    }
    if (next.length != state.selectedIds.length) {
      state = state.copyWith(selectedIds: next);
    }
  }
}

/// 選取模式中搜尋結果更新後，依釘選優先重算凍結順序並修剪選取集合。
void resyncHomeSelectionDisplayOrder({
  required HomeEntrySelectionController selectionController,
  required HomeEntrySelectionState selection,
  required Set<EntryId> pinnedIds,
  required List<EntryIndexRecord> rawEntries,
}) {
  if (!selection.isActive) {
    return;
  }
  final List<EntryId> orderedIds = homeEntryDisplayOrder(
    entries: rawEntries,
    pinnedIds: pinnedIds,
  );
  selectionController
    ..syncFrozenDisplayOrder(orderedIds)
    ..pruneToVisible(orderedIds);
}

final homeTabProvider = NotifierProvider<HomeTabController, HomeTab>(
  HomeTabController.new,
);

final homeSearchQueryProvider =
    NotifierProvider<HomeSearchQueryController, String>(
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

final overviewTagFilterProvider =
    NotifierProvider<OverviewTagFilterController, String?>(
      OverviewTagFilterController.new,
    );

final memoryScopeProvider =
    NotifierProvider<MemoryScopeController, MemoryScope>(
      MemoryScopeController.new,
    );

final memoryFocusedMonthProvider =
    NotifierProvider<MemoryFocusedMonthController, DateTime>(
      MemoryFocusedMonthController.new,
    );

final memoryFocusedYearProvider =
    NotifierProvider<MemoryFocusedYearController, int>(
      MemoryFocusedYearController.new,
    );

final homeEntrySelectionProvider =
    NotifierProvider<HomeEntrySelectionController, HomeEntrySelectionState>(
      HomeEntrySelectionController.new,
    );
