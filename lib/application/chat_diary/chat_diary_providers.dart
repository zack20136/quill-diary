import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_diary/application/chat_diary/chat_diary_controller.dart';
import 'package:quill_diary/application/diary/diary_entry_providers.dart';
import 'package:quill_diary/application/session/session_providers.dart';
import 'package:quill_diary/application/vault/vault_providers.dart';
import 'package:quill_diary/domain/chat_diary/chat_diary_session.dart';
import 'package:quill_diary/infrastructure/chat_diary/chat_diary_store.dart';

final chatDiaryStoreProvider = Provider<ChatDiaryStore>(
  (ref) => ChatDiaryStore(
    paths: ref.watch(vaultPathStrategyProvider),
    crypto: ref.watch(cryptoServiceProvider),
    repository: ref.watch(vaultRepositoryProvider),
    editorDraftStore: ref.watch(editorDraftStoreProvider),
  ),
);
final chatDiarySessionsProvider = FutureProvider<List<ChatDiarySession>>((
  ref,
) async {
  ref.watch(diaryRevisionProvider);
  final session = await ref.watch(activeVaultSessionProvider.future);
  if (session == null) {
    return const [];
  }
  return ref.read(chatDiaryStoreProvider).list(session);
});
final chatDiaryForEntryProvider = FutureProvider.autoDispose
    .family<ChatDiarySession?, String>((ref, entryId) async {
      final session = await ref.watch(activeVaultSessionProvider.future);
      if (session == null) {
        return null;
      }
      return ref.read(chatDiaryStoreProvider).loadForEntry(entryId, session);
    });
final chatDiaryControllerProvider = Provider.autoDispose
    .family<ChatDiaryController, String>((ref, id) {
      final controller = ChatDiaryController(ref);
      ref.onDispose(controller.dispose);
      return controller;
    });
