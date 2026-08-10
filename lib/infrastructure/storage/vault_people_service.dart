import '../../domain/people/person.dart';
import '../../domain/security/unlocked_vault_session.dart';
import '../../domain/shared/value_objects.dart';
import '../database/index_database.dart';
import 'vault_repository.dart';

/// 人物名冊與統計的薄包裝；實作擁有權在 [VaultRepository]。
class VaultPeopleService {
  const VaultPeopleService(this._repository);

  final VaultRepository _repository;

  Stream<PeopleAnalyticsProgress> get peopleAnalyticsProgress =>
      _repository.peopleAnalyticsProgress;

  Future<List<Person>> listPeople(UnlockedVaultSession session) =>
      _repository.listPeople(session);

  Future<Person> createPerson(
    UnlockedVaultSession session,
    PersonDraft draft, {
    bool confirmWarnings = false,
  }) => _repository.createPerson(
    session,
    draft,
    confirmWarnings: confirmWarnings,
  );

  Future<Person> updatePerson(
    UnlockedVaultSession session,
    PersonId personId,
    PersonDraft draft, {
    bool confirmWarnings = false,
    bool addOldNameAsAlias = false,
  }) => _repository.updatePerson(
    session,
    personId,
    draft,
    confirmWarnings: confirmWarnings,
    addOldNameAsAlias: addOldNameAsAlias,
  );

  Future<void> deletePerson(UnlockedVaultSession session, PersonId id) =>
      _repository.deletePerson(session, id);

  Future<Map<PersonId, PersonMentionStats>> allPersonMentionStats(
    UnlockedVaultSession session, {
    DateTime? now,
  }) => _repository.allPersonMentionStats(session, now: now);

  Future<List<EntryIndexRecord>> relatedEntriesForPerson(
    UnlockedVaultSession session,
    PersonId personId,
  ) => _repository.relatedEntriesForPerson(session, personId);

  Future<List<PersonScopedMentionRank>> topMentionedPeople(
    UnlockedVaultSession session, {
    required int limit,
    String? yearPrefix,
    String? monthPrefix,
  }) => _repository.topMentionedPeople(
    session,
    limit: limit,
    yearPrefix: yearPrefix,
    monthPrefix: monthPrefix,
  );
}
