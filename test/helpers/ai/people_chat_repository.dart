import 'package:quill_diary/domain/people/person.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';

import '../session/fake_session_vault_repository.dart';

class PeopleChatRepository extends FakeSessionVaultRepository {
  PeopleChatRepository(this.people);
  final List<Person> people;

  @override
  Future<List<Person>> listPeople(UnlockedVaultSession session) async => people;
}
