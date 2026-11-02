import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_diary/application/chat_diary/chat_diary_commands.dart';
import 'package:quill_diary/application/vault/vault_providers.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';

class HomeItemsDeletion {
  const HomeItemsDeletion({
    required this.entryIds,
    required this.chatIds,
    required this.completed,
  });

  final Set<EntryId> entryIds;
  final Set<String> chatIds;
  final bool completed;
}

class HomeItemsDeletionException implements Exception {
  const HomeItemsDeletionException(this.deletion, this.cause);

  final HomeItemsDeletion deletion;
  final Object cause;
}

Future<HomeItemsDeletion> deleteHomeItems(
  WidgetRef ref,
  UnlockedVaultSession session, {
  required Set<EntryId> entryIds,
  required Set<String> chatIds,
  required bool Function() isSessionCurrent,
}) async {
  final entries = ref.read(vaultRepositoryProvider);
  final deletedEntries = <EntryId>{};
  final deletedChats = <String>{};
  try {
    for (final EntryId id in entryIds) {
      if (!isSessionCurrent()) {
        return HomeItemsDeletion(
          entryIds: deletedEntries,
          chatIds: deletedChats,
          completed: false,
        );
      }
      await entries.deleteEntry(session, id);
      deletedEntries.add(id);
    }
    for (final String id in chatIds) {
      if (!isSessionCurrent()) {
        return HomeItemsDeletion(
          entryIds: deletedEntries,
          chatIds: deletedChats,
          completed: false,
        );
      }
      await deleteChatDiaryData(ref, id, session);
      deletedChats.add(id);
    }
  } on Object catch (error) {
    throw HomeItemsDeletionException(
      HomeItemsDeletion(
        entryIds: deletedEntries,
        chatIds: deletedChats,
        completed: false,
      ),
      error,
    );
  }
  return HomeItemsDeletion(
    entryIds: deletedEntries,
    chatIds: deletedChats,
    completed: true,
  );
}

Future<void> setHomeEntriesPinned(
  WidgetRef ref,
  Set<EntryId> entryIds, {
  required bool pinned,
}) {
  return ref
      .read(vaultRepositoryProvider)
      .setEntriesPinned(entryIds, pinned: pinned);
}
