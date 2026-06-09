import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/features/home/providers/home_providers.dart';
import 'package:quill_diary/features/home/state/home_state.dart';

void main() {
  ProviderContainer buildContainer() {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  HomeEntrySelectionState selectionStateOf(ProviderContainer container) {
    return container.read(homeEntrySelectionProvider);
  }

  test('enterWith 啟動多選並選中一筆', () {
    final ProviderContainer container = buildContainer();
    final HomeEntrySelectionController controller =
        container.read(homeEntrySelectionProvider.notifier);

    controller.enterWith('entry-a');

    final HomeEntrySelectionState state = selectionStateOf(container);
    expect(state.isActive, isTrue);
    expect(state.selectedIds, <String>{'entry-a'});
  });

  test('enterSelection 啟動多選但不預選', () {
    final ProviderContainer container = buildContainer();
    final HomeEntrySelectionController controller =
        container.read(homeEntrySelectionProvider.notifier);

    controller.enterSelection();

    expect(selectionStateOf(container).isActive, isTrue);
    expect(selectionStateOf(container).selectedIds, isEmpty);
  });

  test('toggle 全不選時維持多選模式', () {
    final ProviderContainer container = buildContainer();
    final HomeEntrySelectionController controller =
        container.read(homeEntrySelectionProvider.notifier);

    controller.enterWith('entry-a');
    controller.toggle('entry-a');

    expect(selectionStateOf(container).isActive, isTrue);
    expect(selectionStateOf(container).selectedIds, isEmpty);
  });

  test('selectAll 全選後再次呼叫會取消全選但維持多選', () {
    final ProviderContainer container = buildContainer();
    final HomeEntrySelectionController controller =
        container.read(homeEntrySelectionProvider.notifier);

    controller.selectAll(<String>['entry-a', 'entry-b']);
    expect(selectionStateOf(container).selectedIds, containsAll(<String>{'entry-a', 'entry-b'}));

    controller.selectAll(<String>['entry-a', 'entry-b']);
    expect(selectionStateOf(container).isActive, isTrue);
    expect(selectionStateOf(container).selectedIds, isEmpty);
  });

  test('clear 重置多選狀態', () {
    final ProviderContainer container = buildContainer();
    final HomeEntrySelectionController controller =
        container.read(homeEntrySelectionProvider.notifier);

    controller.enterWith('entry-a');
    controller.clear();

    expect(selectionStateOf(container), const HomeEntrySelectionState());
  });

  test('pruneToVisible 移除不在列表中的選取', () {
    final ProviderContainer container = buildContainer();
    final HomeEntrySelectionController controller =
        container.read(homeEntrySelectionProvider.notifier);

    controller.selectAll(<String>['entry-a', 'entry-b', 'entry-c']);
    controller.pruneToVisible(<String>['entry-a', 'entry-c']);

    expect(selectionStateOf(container).selectedIds, containsAll(<String>{'entry-a', 'entry-c'}));
    expect(selectionStateOf(container).selectedIds, isNot(contains('entry-b')));
  });

  test('pruneToVisible 在全部移除時維持多選模式', () {
    final ProviderContainer container = buildContainer();
    final HomeEntrySelectionController controller =
        container.read(homeEntrySelectionProvider.notifier);

    controller.enterWith('entry-a');
    controller.pruneToVisible(<String>['entry-b']);

    expect(selectionStateOf(container).isActive, isTrue);
    expect(selectionStateOf(container).selectedIds, isEmpty);
  });
}
