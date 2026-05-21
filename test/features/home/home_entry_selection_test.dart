import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_lock_diary/features/home/state/home_state.dart';

void main() {
  ProviderContainer buildContainer() {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  test('enterWith 啟動多選並選中一筆', () {
    final ProviderContainer container = buildContainer();
    final HomeEntrySelectionController controller =
        container.read(homeEntrySelectionProvider.notifier);

    controller.enterWith('entry-a');

    final HomeEntrySelectionState state = container.read(homeEntrySelectionProvider);
    expect(state.isActive, isTrue);
    expect(state.selectedIds, <String>{'entry-a'});
  });

  test('enterSelection 啟動多選但不預選', () {
    final ProviderContainer container = buildContainer();
    final HomeEntrySelectionController controller =
        container.read(homeEntrySelectionProvider.notifier);

    controller.enterSelection();

    expect(container.read(homeEntrySelectionProvider).isActive, isTrue);
    expect(container.read(homeEntrySelectionProvider).selectedIds, isEmpty);
  });

  test('toggle 全不選時維持多選模式', () {
    final ProviderContainer container = buildContainer();
    final HomeEntrySelectionController controller =
        container.read(homeEntrySelectionProvider.notifier);

    controller.enterWith('entry-a');
    controller.toggle('entry-a');

    expect(container.read(homeEntrySelectionProvider).isActive, isTrue);
    expect(container.read(homeEntrySelectionProvider).selectedIds, isEmpty);
  });

  test('selectAll 全選後再次呼叫會取消全選但維持多選', () {
    final ProviderContainer container = buildContainer();
    final HomeEntrySelectionController controller =
        container.read(homeEntrySelectionProvider.notifier);

    controller.selectAll(<String>['entry-a', 'entry-b']);
    expect(container.read(homeEntrySelectionProvider).selectedIds,
        containsAll(<String>{'entry-a', 'entry-b'}));

    controller.selectAll(<String>['entry-a', 'entry-b']);
    expect(container.read(homeEntrySelectionProvider).isActive, isTrue);
    expect(container.read(homeEntrySelectionProvider).selectedIds, isEmpty);
  });

  test('clear 重置多選狀態', () {
    final ProviderContainer container = buildContainer();
    final HomeEntrySelectionController controller =
        container.read(homeEntrySelectionProvider.notifier);

    controller.enterWith('entry-a');
    controller.clear();

    expect(container.read(homeEntrySelectionProvider), const HomeEntrySelectionState());
  });

  test('pruneToVisible 移除不在列表中的選取', () {
    final ProviderContainer container = buildContainer();
    final HomeEntrySelectionController controller =
        container.read(homeEntrySelectionProvider.notifier);

    controller.selectAll(<String>['entry-a', 'entry-b', 'entry-c']);
    controller.pruneToVisible(<String>['entry-a', 'entry-c']);

    expect(container.read(homeEntrySelectionProvider).selectedIds,
        containsAll(<String>{'entry-a', 'entry-c'}));
    expect(container.read(homeEntrySelectionProvider).selectedIds, isNot(contains('entry-b')));
  });

  test('pruneToVisible 在全部移除時維持多選模式', () {
    final ProviderContainer container = buildContainer();
    final HomeEntrySelectionController controller =
        container.read(homeEntrySelectionProvider.notifier);

    controller.enterWith('entry-a');
    controller.pruneToVisible(<String>['entry-b']);

    expect(container.read(homeEntrySelectionProvider).isActive, isTrue);
    expect(container.read(homeEntrySelectionProvider).selectedIds, isEmpty);
  });
}
