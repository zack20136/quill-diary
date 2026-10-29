import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_diary/application/home/home_entry_sorting.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/database/index_database.dart';

enum HomeTab { home, calendar, tags, people, overview }

enum MemoryScope { all, month, year }

({DateOnly first, DateOnly last}) calendarGridDateRange(DateTime month) {
  final DateTime firstOfMonth = DateTime(month.year, month.month);
  final DateTime firstGridDay = firstOfMonth.subtract(
    Duration(days: firstOfMonth.weekday % DateTime.daysPerWeek),
  );
  return (
    first: DateOnly.fromDateTime(firstGridDay),
    last: DateOnly.fromDateTime(firstGridDay.add(const Duration(days: 41))),
  );
}

DateOnly calendarSelectedDateForMonth(DateOnly selected, DateTime month) {
  final int lastDayOfMonth = DateTime(month.year, month.month + 1, 0).day;
  return DateOnly.fromDateTime(
    DateTime(
      month.year,
      month.month,
      selected.toDateTime().day.clamp(1, lastDayOfMonth),
    ),
  );
}

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
    this.selectedChatIds = const <String>{},
    this.frozenDisplayOrder = const <EntryId>[],
  });

  final bool isActive;
  final Set<EntryId> selectedIds;
  final Set<String> selectedChatIds;
  int get selectedCount => selectedIds.length + selectedChatIds.length;
  final List<EntryId> frozenDisplayOrder;

  HomeEntrySelectionState copyWith({
    bool? isActive,
    Set<EntryId>? selectedIds,
    Set<String>? selectedChatIds,
    List<EntryId>? frozenDisplayOrder,
  }) {
    return HomeEntrySelectionState(
      isActive: isActive ?? this.isActive,
      selectedIds: selectedIds ?? this.selectedIds,
      selectedChatIds: selectedChatIds ?? this.selectedChatIds,
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

  void toggleChat(String id, {required List<EntryId> displayOrder}) {
    if (!state.isActive) {
      state = HomeEntrySelectionState(
        isActive: true,
        selectedChatIds: {id},
        frozenDisplayOrder: List.of(displayOrder),
      );
      return;
    }
    final next = Set<String>.of(state.selectedChatIds);
    if (!next.remove(id)) next.add(id);
    state = state.copyWith(selectedChatIds: next);
  }

  void selectAll(Iterable<EntryId> ids, {Iterable<String> chatIds = const []}) {
    final entries = ids.toSet();
    final chats = chatIds.toSet();
    if (entries.isEmpty && chats.isEmpty) return;
    final allSelected =
        state.selectedCount == entries.length + chats.length &&
        entries.every(state.selectedIds.contains) &&
        chats.every(state.selectedChatIds.contains);
    state = state.copyWith(
      selectedIds: allSelected ? {} : entries,
      selectedChatIds: allSelected ? {} : chats,
    );
  }

  void deselectDeleted({
    Iterable<EntryId> entryIds = const [],
    Iterable<String> chatIds = const [],
  }) {
    state = state.copyWith(
      selectedIds: state.selectedIds.difference(entryIds.toSet()),
      selectedChatIds: state.selectedChatIds.difference(chatIds.toSet()),
    );
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

  void pruneToVisible(
    Iterable<EntryId> visibleIds, {
    Iterable<String> chatIds = const [],
  }) {
    if (!state.isActive) return;
    state = state.copyWith(
      selectedIds: state.selectedIds.intersection(visibleIds.toSet()),
      selectedChatIds: state.selectedChatIds.intersection(chatIds.toSet()),
    );
  }
}

void resyncHomeSelectionDisplayOrder({
  required HomeEntrySelectionController selectionController,
  required HomeEntrySelectionState selection,
  required Set<EntryId> pinnedIds,
  required List<EntryIndexRecord> rawEntries,
  Iterable<String> chatIds = const [],
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
    ..pruneToVisible(orderedIds, chatIds: chatIds);
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
