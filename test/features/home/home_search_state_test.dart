import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/features/home/pages/home_page.dart';
import 'package:quill_diary/features/home/providers/home_providers.dart';
import 'package:quill_diary/features/home/state/home_state.dart';
import 'package:quill_diary/infrastructure/database/index_database.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/features/session/providers/session_providers.dart';
import 'package:quill_diary/features/session/state/app_session_state.dart';
import 'package:quill_diary/l10n/app_localizations.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/providers/core_providers.dart';

import '../../helpers/entry_index_fixtures.dart';
import '../../helpers/fake_entry_index_vault_repository.dart';

void main() {
  const UnlockedVaultSession session = UnlockedVaultSession(
    vaultId: 'vlt_home_search_widget_test',
    trustedDevice: true,
    recoveryWrapKey: <int>[1, 2, 3],
  );

  ProviderContainer buildContainer() {
    final FakeEntryIndexVaultRepository repository = FakeEntryIndexVaultRepository(
      searchResponses: <String, List<EntryIndexRecord>>{
        'travel': <EntryIndexRecord>[
          buildEntryIndexRecord(
            id: 'jrn_TRAVEL_1',
            title: 'travel notes',
            previewText: 'packing list',
            tags: const <String>['travel'],
            date: const DateOnly('2026-05-20'),
          ),
        ],
      },
    );

    final ProviderContainer container = ProviderContainer(
      overrides: [
        supportedPlatformProvider.overrideWith((Ref ref) => true),
        vaultRepositoryProvider.overrideWithValue(repository),
        effectiveAppSessionProvider.overrideWith(
          (Ref ref) async => const AppSessionState(
            status: AppLockStatus.unlocked,
            session: session,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> pumpHomePage(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: appZhTwLocale,
          supportedLocales: appSupportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const HomePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder searchFieldFinder() => find.byType(TextField);

  TextField searchField(WidgetTester tester) {
    return tester.widget<TextField>(searchFieldFinder());
  }

  testWidgets('home search keeps text and query after tab switch', (WidgetTester tester) async {
    final ProviderContainer container = buildContainer();

    await pumpHomePage(tester, container);
    await tester.enterText(searchFieldFinder(), 'travel');
    await tester.pumpAndSettle();

    expect(container.read(homeSearchQueryProvider), 'travel');
    expect(
      (await container.read(homeEntriesProvider.future))
          .map((EntryIndexRecord entry) => entry.id),
      <String>['jrn_TRAVEL_1'],
    );

    container.read(homeTabProvider.notifier).set(HomeTab.overview);
    await tester.pumpAndSettle();
    container.read(homeTabProvider.notifier).set(HomeTab.home);
    await tester.pumpAndSettle();

    expect(container.read(homeSearchQueryProvider), 'travel');
    expect(searchField(tester).controller?.text, 'travel');
  });

  testWidgets('home search keeps text after selection toolbar roundtrip', (WidgetTester tester) async {
    final ProviderContainer container = buildContainer();

    await pumpHomePage(tester, container);
    await tester.enterText(searchFieldFinder(), 'travel');
    await tester.pumpAndSettle();

    container.read(homeEntrySelectionProvider.notifier).enterSelection();
    await tester.pumpAndSettle();
    container.read(homeEntrySelectionProvider.notifier).clear();
    await tester.pumpAndSettle();

    expect(container.read(homeSearchQueryProvider), 'travel');
    expect(searchField(tester).controller?.text, 'travel');
  });
}
