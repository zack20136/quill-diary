import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_diary/application/people/people_providers.dart';
import 'package:quill_diary/application/persona/persona_providers.dart';
import 'package:quill_diary/application/vault/vault_providers.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';

/// 刪除單一人物的名冊與本機 AI 分身；不修改任何日記內容。
Future<void> deletePersonWithPersona(
  WidgetRef ref,
  UnlockedVaultSession session,
  PersonId personId,
) async {
  ref.read(personaDeletionsProvider.notifier).mark(personId);
  await ref.read(personaStoreProvider).delete(personId, session);
  ref.invalidate(savedPersonasProvider);
  ref.invalidate(personaRecordProvider(personId));
  await ref.read(vaultRepositoryProvider).deletePerson(session, personId);
  ref.invalidate(peopleCatalogProvider);
}
