import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_diary/application/session/session_providers.dart';
import 'package:quill_diary/application/vault/vault_providers.dart';
import 'package:quill_diary/domain/persona/persona.dart';
import 'package:quill_diary/infrastructure/persona/persona_store.dart';

final personaStoreProvider = Provider<PersonaStore>(
  (ref) => PersonaStore(
    paths: ref.watch(vaultPathStrategyProvider),
    crypto: ref.watch(cryptoServiceProvider),
    repository: ref.watch(vaultRepositoryProvider),
  ),
);

final savedPersonasProvider = FutureProvider<List<PersonaRecord>>((ref) async {
  final state = await ref.watch(effectiveAppSessionProvider.future);
  if (!state.isUnlocked || state.session == null) return [];
  return ref.read(personaStoreProvider).list(state.session!);
});

final personaRecordProvider = FutureProvider.autoDispose
    .family<PersonaRecord?, String>((ref, id) async {
      final state = await ref.watch(effectiveAppSessionProvider.future);
      if (!state.isUnlocked || state.session == null) return null;
      return ref.read(personaStoreProvider).load(id, state.session!);
    });

class PersonaDeletions extends Notifier<Map<String, int>> {
  @override
  Map<String, int> build() => {};
  void mark(String personId) =>
      state = {...state, personId: (state[personId] ?? 0) + 1};
}

final personaDeletionsProvider =
    NotifierProvider<PersonaDeletions, Map<String, int>>(PersonaDeletions.new);
