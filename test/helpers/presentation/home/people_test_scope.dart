import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/people/people_providers.dart';
import 'package:quill_diary/application/persona/persona_providers.dart';
import 'package:quill_diary/application/session/session_state.dart';
import 'package:quill_diary/application/vault/vault_providers.dart';
import 'package:quill_diary/domain/people/person.dart';
import 'package:quill_diary/domain/people/relationship_type.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/persona/persona_store.dart';
import 'package:quill_diary/infrastructure/storage/vault_people_service.dart';
import 'package:quill_diary/presentation/home/widgets/people_pane.dart';

import '../../shared/widget_test_app.dart';
import '../../vault/fake_entry_index_vault_repository.dart';

const peopleTestSessionState = AppSessionState(
  status: AppLockStatus.unlocked,
  session: UnlockedVaultSession(vaultId: 'people-vault', trustedDevice: true),
);

Person peopleTestPerson(String id, String name) => Person(
  id: id,
  name: name,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

class PeopleTestRepository extends FakeEntryIndexVaultRepository {
  PeopleTestRepository(this.people);

  final List<Person> people;
  final List<PersonId> deleteCalls = [];

  /// 第幾次刪除（從 1 起算）會丟出錯誤；null 表示全部成功。
  int? failOnCall;
  final failure = StateError('人物刪除失敗');

  @override
  Future<void> deletePerson(UnlockedVaultSession session, PersonId id) async {
    deleteCalls.add(id);
    if (deleteCalls.length == failOnCall) throw failure;
    people.removeWhere((Person person) => person.id == id);
  }
}

class _PeopleTestPersonaStore implements PersonaStore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<void> delete(String personId, UnlockedVaultSession session) async {}
}

ProviderContainer peopleTestContainer(
  PeopleTestRepository repository, {
  List<RelationshipType> relationshipTypes = const [],
}) {
  final container = ProviderContainer(
    overrides: [
      vaultRepositoryProvider.overrideWithValue(repository),
      personaStoreProvider.overrideWithValue(_PeopleTestPersonaStore()),
      peopleCatalogProvider.overrideWith(
        (ref) async => PeopleCatalog(
          relationshipTypes: relationshipTypes,
          people: List<Person>.of(repository.people),
        ),
      ),
      peopleMentionStatsMapProvider.overrideWith(
        (ref) async => const <PersonId, PersonMentionStats>{},
      ),
      peopleAnalyticsProgressProvider.overrideWith(
        (ref) => Stream<PeopleAnalyticsProgress>.value(
          const PeopleAnalyticsProgress.idle(),
        ),
      ),
    ],
  );
  return container;
}

Widget peopleTestApp(ProviderContainer container) => UncontrolledProviderScope(
  container: container,
  child: widgetTestApp(
    center: false,
    child: PeoplePane(sessionState: peopleTestSessionState),
  ),
);
