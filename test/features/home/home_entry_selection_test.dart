import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/features/home/state/home_state.dart';
import 'package:quill_diary/infrastructure/database/index_database.dart';

import '../../helpers/shared/entry_index_fixtures.dart';

void main() {
  group('HomeEntrySelectionController', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('selectAll 會切換全選與取消全選並保留凍結順序', () {
      const List<String> frozenOrder = <String>['a', 'b', 'c'];
      final HomeEntrySelectionController controller = container.read(
        homeEntrySelectionProvider.notifier,
      );

      controller.enterSelection(frozenOrder);
      controller.selectAll(<String>['a', 'b', 'c']);

      expect(
        container.read(homeEntrySelectionProvider).frozenDisplayOrder,
        frozenOrder,
      );
      expect(container.read(homeEntrySelectionProvider).selectedIds, <String>{
        'a',
        'b',
        'c',
      });

      controller.selectAll(<String>['a', 'b', 'c']);

      expect(container.read(homeEntrySelectionProvider).selectedIds, isEmpty);
      expect(
        container.read(homeEntrySelectionProvider).frozenDisplayOrder,
        frozenOrder,
      );
    });

    test('syncFrozenDisplayOrder 與 pruneToVisible 只在選取模式生效', () {
      final HomeEntrySelectionController controller = container.read(
        homeEntrySelectionProvider.notifier,
      );

      controller.syncFrozenDisplayOrder(<String>['x', 'y']);
      expect(
        container.read(homeEntrySelectionProvider).frozenDisplayOrder,
        isEmpty,
      );

      controller.enterSelection(<String>['a']);
      controller.syncFrozenDisplayOrder(<String>['x', 'y']);
      controller.toggle('a', displayOrder: const <String>[]);
      controller.toggle('b', displayOrder: const <String>[]);
      controller.pruneToVisible(<String>['a']);

      expect(
        container.read(homeEntrySelectionProvider).frozenDisplayOrder,
        <String>['x', 'y'],
      );
      expect(container.read(homeEntrySelectionProvider).selectedIds, <String>{
        'a',
      });
    });

    test('resyncHomeSelectionDisplayOrder 會依釘選優先重算凍結順序', () {
      final EntryIndexRecord pinned = buildEntryIndexRecord(
        id: 'pinned',
        date: const DateOnly('2026-01-01'),
      );
      final EntryIndexRecord newer = buildEntryIndexRecord(
        id: 'newer',
        date: const DateOnly('2026-06-01'),
      );

      final HomeEntrySelectionController controller = container.read(
        homeEntrySelectionProvider.notifier,
      );
      controller.enterSelection(<String>['newer', 'pinned']);

      resyncHomeSelectionDisplayOrder(
        selectionController: controller,
        selection: container.read(homeEntrySelectionProvider),
        pinnedIds: <String>{'pinned'},
        rawEntries: <EntryIndexRecord>[newer, pinned],
      );

      expect(
        container.read(homeEntrySelectionProvider).frozenDisplayOrder,
        <String>['pinned', 'newer'],
      );
    });
  });
}
