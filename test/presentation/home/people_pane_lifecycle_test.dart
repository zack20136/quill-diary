import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/home/home_browse_state.dart';
import 'package:quill_diary/application/home/home_entry_query_providers.dart';
import 'package:quill_diary/application/people/people_providers.dart';
import 'package:quill_diary/application/session/session_state.dart';
import 'package:quill_diary/domain/diary/diary_entry_summary.dart';
import 'package:quill_diary/domain/people/person.dart';
import 'package:quill_diary/domain/people/relationship_type.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/storage/vault_people_service.dart';
import 'package:quill_diary/presentation/home/widgets/home_tab_stack.dart';

import '../../helpers/shared/widget_test_app.dart';

void main() {
  testWidgets('人物資料首次進入分頁才載入且離開後保持訂閱', (WidgetTester tester) async {
    var catalogReads = 0;
    var statsReads = 0;
    final ProviderContainer container = ProviderContainer(
      overrides: [
        homeEntriesProvider.overrideWith(
          (Ref ref) =>
              const AsyncData<List<DiaryEntrySummary>>(<DiaryEntrySummary>[]),
        ),
        homeEntryIndexListProvider.overrideWith(
          (Ref ref) async => const HomeEntryQueryResult(
            query: '',
            entries: <DiaryEntrySummary>[],
          ),
        ),
        homePinnedEntryIdsProvider.overrideWith(
          (Ref ref) async => const <EntryId>{},
        ),
        peopleCatalogProvider.overrideWith((Ref ref) async {
          catalogReads += 1;
          return PeopleCatalog.empty();
        }),
        peopleMentionStatsMapProvider.overrideWith((Ref ref) async {
          statsReads += 1;
          return const <PersonId, PersonMentionStats>{};
        }),
        peopleAnalyticsProgressProvider.overrideWith(
          (Ref ref) => Stream<PeopleAnalyticsProgress>.value(
            const PeopleAnalyticsProgress.idle(),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final AppSessionState sessionState = AppSessionState(
      status: AppLockStatus.unlocked,
      session: UnlockedVaultSession(
        vaultId: 'vlt_people_pane_lifecycle',
        trustedDevice: true,
        recoveryWrapKey: const <int>[1, 2, 3],
      ),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: widgetTestApp(
          center: false,
          child: HomeTabStack(sessionState: sessionState),
        ),
      ),
    );
    await tester.pump();

    expect(catalogReads, 0);
    expect(statsReads, 0);

    container.read(homeTabProvider.notifier).set(HomeTab.people);
    await tester.pumpAndSettle();

    expect(catalogReads, 1);
    expect(statsReads, 1);

    container.read(homeTabProvider.notifier).set(HomeTab.home);
    await tester.pumpAndSettle();
    container.read(homeTabProvider.notifier).set(HomeTab.people);
    await tester.pumpAndSettle();

    expect(catalogReads, 1);
    expect(statsReads, 1);
  });

  testWidgets('人物分析進度依可用寬度縮放且不貼齊邊緣', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final ProviderContainer container = ProviderContainer(
      overrides: [
        peopleCatalogProvider.overrideWith(
          (Ref ref) async => PeopleCatalog.empty(),
        ),
        peopleMentionStatsMapProvider.overrideWith(
          (Ref ref) async => const <PersonId, PersonMentionStats>{},
        ),
        peopleAnalyticsProgressProvider.overrideWith(
          (Ref ref) => Stream<PeopleAnalyticsProgress>.value(
            const PeopleAnalyticsProgress(
              state: PeopleAnalyticsProgressState.analyzing,
              processedDocuments: 2,
              totalDocuments: 5,
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(homeTabProvider.notifier).set(HomeTab.people);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: widgetTestApp(
          center: false,
          child: HomeTabStack(
            sessionState: AppSessionState(
              status: AppLockStatus.unlocked,
              session: UnlockedVaultSession(
                vaultId: 'vlt_people_progress',
                trustedDevice: true,
                recoveryWrapKey: const <int>[1, 2, 3],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final Finder progressBar = find.byType(LinearProgressIndicator);
    expect(tester.getSize(progressBar).width, 345.6);
    expect(tester.getTopLeft(progressBar).dx, closeTo(19.2, 0.001));
    expect(tester.getSize(progressBar).width, lessThan(400));

    await tester.binding.setSurfaceSize(const Size(800, 800));
    await tester.pump();

    expect(tester.getSize(progressBar).width, 360);
  });

  testWidgets('總覽人物排行首次進入才載入且離開後保持訂閱', (WidgetTester tester) async {
    final List<OverviewScope> readScopes = <OverviewScope>[];
    final ProviderContainer container = ProviderContainer(
      overrides: [
        homeEntriesProvider.overrideWith(
          (Ref ref) =>
              const AsyncData<List<DiaryEntrySummary>>(<DiaryEntrySummary>[]),
        ),
        homeEntryIndexListProvider.overrideWith(
          (Ref ref) async => const HomeEntryQueryResult(
            query: '',
            entries: <DiaryEntrySummary>[],
          ),
        ),
        homePinnedEntryIdsProvider.overrideWith(
          (Ref ref) async => const <EntryId>{},
        ),
        allDiaryEntrySummariesProvider.overrideWith(
          (Ref ref) async => const <DiaryEntrySummary>[],
        ),
        overviewEntriesProvider.overrideWith(
          (Ref ref) async => const <DiaryEntrySummary>[],
        ),
        overviewPeopleTop5Provider.overrideWith((Ref ref, key) async {
          readScopes.add(key.scope);
          return const <OverviewPersonRankItem>[];
        }),
      ],
    );
    addTearDown(container.dispose);

    final AppSessionState sessionState = AppSessionState(
      status: AppLockStatus.unlocked,
      session: UnlockedVaultSession(
        vaultId: 'vlt_overview_pane_lifecycle',
        trustedDevice: true,
        recoveryWrapKey: const <int>[1, 2, 3],
      ),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: widgetTestApp(
          center: false,
          child: HomeTabStack(sessionState: sessionState),
        ),
      ),
    );
    await tester.pump();

    expect(readScopes, isEmpty);

    container.read(homeTabProvider.notifier).set(HomeTab.overview);
    await tester.pumpAndSettle();
    expect(readScopes, <OverviewScope>[OverviewScope.month]);

    container.read(homeTabProvider.notifier).set(HomeTab.home);
    await tester.pumpAndSettle();
    container.read(homeTabProvider.notifier).set(HomeTab.overview);
    await tester.pumpAndSettle();
    expect(readScopes, <OverviewScope>[OverviewScope.month]);

    container.read(overviewScopeProvider.notifier).set(OverviewScope.all);
    await tester.pumpAndSettle();
    expect(readScopes, <OverviewScope>[OverviewScope.month, OverviewScope.all]);
  });
}
