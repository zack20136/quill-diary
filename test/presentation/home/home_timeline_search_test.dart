import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/application/home/home_browse_state.dart';
import 'package:quill_diary/application/home/home_entry_query_providers.dart';
import 'package:quill_diary/application/session/state/app_session_state.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/database/index_database.dart';
import 'package:quill_diary/presentation/home/widgets/home_timeline_pane.dart';

import '../../helpers/shared/entry_index_fixtures.dart';
import '../../helpers/shared/widget_test_app.dart';

void main() {
  late AppSessionState sessionState;

  setUp(() {
    sessionState = AppSessionState(
      status: AppLockStatus.unlocked,
      session: UnlockedVaultSession(
        vaultId: 'vlt_home_search_test',
        trustedDevice: true,
        recoveryWrapKey: const <int>[1, 2, 3],
      ),
    );
  });

  Future<void> pumpPane(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: widgetTestApp(
          center: false,
          child: HomeTimelinePane(sessionState: sessionState),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('搜尋輸入等待 250 毫秒後才送出，清空則立即生效', (WidgetTester tester) async {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        homeEntryIndexListProvider.overrideWith((Ref ref) async {
          final String query = ref.watch(homeSearchQueryProvider);
          return HomeEntryQueryResult(
            query: query,
            entries: const <EntryIndexRecord>[],
          );
        }),
        homeEntriesProvider.overrideWith(
          (Ref ref) =>
              const AsyncData<List<EntryIndexRecord>>(<EntryIndexRecord>[]),
        ),
        homePinnedEntryIdsProvider.overrideWith(
          (Ref ref) async => const <EntryId>{},
        ),
      ],
    );
    addTearDown(container.dispose);
    await pumpPane(tester, container);

    await tester.enterText(find.byType(TextField).first, '回憶');
    await tester.pump(const Duration(milliseconds: 249));
    expect(container.read(homeSearchQueryProvider), isEmpty);

    await tester.pump(const Duration(milliseconds: 1));
    expect(container.read(homeSearchQueryProvider), '回憶');

    await tester.enterText(find.byType(TextField).first, '');
    await tester.pump();
    expect(container.read(homeSearchQueryProvider), isEmpty);
  });

  testWidgets('外部搜尋狀態會取消尚未送出的舊輸入', (WidgetTester tester) async {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        homeEntryIndexListProvider.overrideWith((Ref ref) async {
          final String query = ref.watch(homeSearchQueryProvider);
          return HomeEntryQueryResult(
            query: query,
            entries: const <EntryIndexRecord>[],
          );
        }),
        homeEntriesProvider.overrideWith(
          (Ref ref) =>
              const AsyncData<List<EntryIndexRecord>>(<EntryIndexRecord>[]),
        ),
        homePinnedEntryIdsProvider.overrideWith(
          (Ref ref) async => const <EntryId>{},
        ),
      ],
    );
    addTearDown(container.dispose);
    await pumpPane(tester, container);

    await tester.enterText(find.byType(TextField).first, '尚未送出的輸入');
    await tester.pump(const Duration(milliseconds: 100));
    expect(container.read(homeSearchQueryProvider), isEmpty);

    container.read(homeSearchQueryProvider.notifier).update('外部狀態');
    await tester.pump();

    final TextField searchField = tester.widget<TextField>(
      find.byType(TextField).first,
    );
    expect(searchField.controller?.text, '外部狀態');

    await tester.pump(const Duration(milliseconds: 200));
    expect(container.read(homeSearchQueryProvider), '外部狀態');
    expect(searchField.controller?.text, '外部狀態');
  });

  testWidgets('選取模式只接受最新搜尋結果同步顯示順序', (WidgetTester tester) async {
    final Map<String, Completer<HomeEntryQueryResult>> pending =
        <String, Completer<HomeEntryQueryResult>>{};
    final ProviderContainer container = ProviderContainer(
      overrides: [
        homeEntryIndexListProvider.overrideWith((Ref ref) async {
          final String query = ref.watch(homeSearchQueryProvider);
          if (query.isEmpty) {
            return const HomeEntryQueryResult(
              query: '',
              entries: <EntryIndexRecord>[],
            );
          }
          return pending
              .putIfAbsent(query, Completer<HomeEntryQueryResult>.new)
              .future;
        }),
        homeEntriesProvider.overrideWith(
          (Ref ref) =>
              const AsyncData<List<EntryIndexRecord>>(<EntryIndexRecord>[]),
        ),
        homePinnedEntryIdsProvider.overrideWith(
          (Ref ref) async => const <EntryId>{},
        ),
      ],
    );
    addTearDown(container.dispose);
    await pumpPane(tester, container);
    container
        .read(homeEntrySelectionProvider.notifier)
        .enterWith('old', displayOrder: const <EntryId>['old']);
    await tester.pump();

    container.read(homeSearchQueryProvider.notifier).update('第一輪');
    await tester.pump();
    container.read(homeSearchQueryProvider.notifier).update('第二輪');
    await tester.pump();

    pending['第一輪']!.complete(
      HomeEntryQueryResult(
        query: '第一輪',
        entries: <EntryIndexRecord>[buildEntryIndexRecord(id: 'stale')],
      ),
    );
    await tester.pump();
    pending['第二輪']!.complete(
      HomeEntryQueryResult(
        query: '第二輪',
        entries: <EntryIndexRecord>[buildEntryIndexRecord(id: 'latest')],
      ),
    );
    await tester.pump();

    final HomeEntrySelectionState selection = container.read(
      homeEntrySelectionProvider,
    );
    expect(selection.frozenDisplayOrder, const <EntryId>['latest']);
    expect(selection.selectedIds, isEmpty);
  });
}
