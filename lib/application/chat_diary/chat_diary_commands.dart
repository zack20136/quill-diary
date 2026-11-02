import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_diary/application/ai/ai_connection_providers.dart';
import 'package:quill_diary/application/chat_diary/chat_diary_providers.dart';
import 'package:quill_diary/domain/ai/ai_connection_settings.dart';
import 'package:quill_diary/domain/chat_diary/chat_diary_session.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/infrastructure/ai/ai_client.dart';

Future<bool> hasReadyChatDiaryConnection(
  WidgetRef ref,
  UnlockedVaultSession session,
) async {
  final settingsStore = ref.read(aiSettingsStoreProvider);
  final connection = (await settingsStore.read(session))
      .connection
      .activeConfig;
  if (!connection.isConfigured ||
      (connection.provider.requiresApiKey &&
          (await settingsStore.readApiKey(connection)).isEmpty)) {
    return false;
  }
  validateAiEndpoint(connection);
  return true;
}

Future<void> deleteChatDiaryData(
  WidgetRef ref,
  ChatDiarySession chat,
  UnlockedVaultSession session, {
  Future<void> Function()? deleteLocalChat,
}) async {
  final store = ref.read(chatDiaryStoreProvider);
  if (deleteLocalChat != null) {
    await deleteLocalChat();
  } else {
    await store.delete(
      chat.id,
      session: session,
      entryId: chat.generatedEntryId,
    );
  }
  final keyFor = ref.read(aiSettingsStoreProvider).readApiKey;
  unawaited(
    store
        .cleanupRemoteFiles(session, keyFor, chatId: chat.id)
        .onError((_, _) => false),
  );
}

Future<bool> completeChatDiaryAfterEntrySave(
  WidgetRef ref, {
  required String chatId,
  required String entryId,
  required UnlockedVaultSession session,
  void Function()? onRemoteCleanupIncomplete,
}) async {
  final store = ref.read(chatDiaryStoreProvider);
  var completed = true;
  try {
    await store.complete(chatId, entryId, session);
  } on Object {
    completed = false;
  }
  final keyFor = ref.read(aiSettingsStoreProvider).readApiKey;
  unawaited(
    store.cleanupRemoteFiles(session, keyFor, chatId: chatId).then((
      bool cleaned,
    ) {
      if (!cleaned) onRemoteCleanupIncomplete?.call();
    }, onError: (_, _) => onRemoteCleanupIncomplete?.call()),
  );
  if (completed) {
    ref.invalidate(chatDiarySessionsProvider);
  }
  return completed;
}
