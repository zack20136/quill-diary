import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/chat_diary/chat_diary_session.dart';
import '../../infrastructure/chat_diary/chat_diary_settings_store.dart';
import '../../infrastructure/chat_diary/chat_diary_store.dart';
import '../../infrastructure/crypto/crypto_providers.dart';
import '../../infrastructure/storage/storage_path_providers.dart';
import '../../infrastructure/storage/storage_providers.dart';
import '../editor/editor_entry_providers.dart';
import '../session/providers/session_providers.dart';
import 'chat_diary_controller.dart';

final chatDiarySettingsStoreProvider = Provider<ChatDiarySettingsStore>(
  (ref) => ChatDiarySettingsStore(),
);
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
  ref.watch(entryIndexRevisionProvider);
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
