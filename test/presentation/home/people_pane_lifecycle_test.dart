import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/application/home/home_browse_state.dart';
import 'package:quill_diary/application/people/people_providers.dart';
import 'package:quill_diary/application/session/state/app_session_state.dart';
import 'package:quill_diary/domain/people/person.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/database/index_database.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/home/widgets/people_pane.dart';

import '../../helpers/app_test_theme.dart';

void main() {
  testWidgets('人物資料首次進入分頁才載入且離開後保持訂閱', (WidgetTester tester) async {
    var catalogReads = 0;
    var statsReads = 0;
    final ProviderContainer container = ProviderContainer(
      overrides: [
        peopleCatalogProvider.overrideWith((Ref ref) async {
          catalogReads += 1;
          return const <Person>[];
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
        child: MaterialApp(
          theme: appTestTheme(),
          locale: appZhLocale,
          supportedLocales: appSupportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(body: PeoplePane(sessionState: sessionState)),
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
}
