import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../application/ai/ai_connection_providers.dart';
import '../../application/chat_diary/chat_diary_providers.dart';
import '../../application/session/providers/session_providers.dart';
import '../../domain/ai/ai_connection_settings.dart';
import '../../domain/chat_diary/chat_diary_session.dart';
import '../../domain/security/unlocked_vault_session.dart';
import '../../domain/shared/value_objects.dart';
import '../../infrastructure/ai/ai_client.dart';
import '../../l10n/l10n.dart';
import '../../shared/presentation/app_feedback.dart';
import '../../shared/presentation/widgets/app_dialog_shell.dart';
import '../ai/ai_connection_settings_dialog.dart';
import '../ai/ai_error_text.dart';

Future<void> startChatDiary(BuildContext context, WidgetRef ref) async {
  final vault = ref.read(effectiveAppSessionProvider).value?.session;
  if (vault == null) return;
  bool available() =>
      context.mounted &&
      ref.read(effectiveAppSessionProvider).value?.session == vault;
  try {
    final store = ref.read(aiConnectionSettingsStoreProvider);
    var settings = await store.read();
    if (!context.mounted || !available()) return;
    if (!settings.activeConfig.isConfigured ||
        (settings.provider.requiresApiKey &&
            (await store.readApiKey(settings.activeConfig)).isEmpty)) {
      if (!context.mounted ||
          !available() ||
          !await showAiConnectionSettingsDialog(context) ||
          !available()) {
        return;
      }
      settings = await store.read();
    }
    final connectionConfig = settings.activeConfig;
    final ready =
        connectionConfig.isConfigured &&
        (!connectionConfig.provider.requiresApiKey ||
            (await store.readApiKey(connectionConfig)).isNotEmpty);
    if (!context.mounted || !available()) return;
    if (!ready) throw const AiFailure(AiErrorCode.configuration);
    validateAiEndpoint(connectionConfig);
    final chatId = generateChatDiaryId();
    Future<void> openChatAndRefreshDrafts() async {
      await context.push<void>(AppRouter.newChatDiaryLocation(chatId));
      if (available()) ref.invalidate(chatDiarySessionsProvider);
    }

    unawaited(openChatAndRefreshDrafts());
  } on Object catch (error) {
    if (context.mounted && available()) {
      showAppFeedbackToast(
        context,
        aiErrorText(
          context.l10n,
          error is AiFailure ? error.code : AiErrorCode.storage,
        ),
        tone: AppFeedbackTone.error,
      );
    }
  }
}

Future<bool> deleteChatDiary(
  BuildContext context,
  WidgetRef ref,
  ChatDiarySession chat,
  UnlockedVaultSession session, {
  Future<void> Function()? deleteLocalChat,
}) async {
  if (!await showAppConfirmDialog(
    context: context,
    title: context.l10n.chatDiaryDeleteChat,
    content: Text(context.l10n.chatDiaryDeleteChatBody),
    cancelLabel: context.l10n.commonActionCancel,
    confirmLabel: context.l10n.commonActionDelete,
    confirmStyle: AppConfirmStyle.destructive,
  )) {
    return false;
  }
  if (!context.mounted ||
      ref.read(effectiveAppSessionProvider).value?.session != session) {
    return false;
  }
  try {
    final store = ref.read(chatDiaryStoreProvider);
    final keys = ref.read(aiConnectionSettingsStoreProvider);
    if (deleteLocalChat != null) {
      await deleteLocalChat();
    } else {
      await store.delete(
        chat.id,
        session: session,
        entryId: chat.generatedEntryId,
      );
    }
    unawaited(
      store
          .cleanupRemoteFiles(session, keys.readApiKey, chatId: chat.id)
          .onError((_, _) => false),
    );
    if (context.mounted) ref.invalidate(chatDiarySessionsProvider);
    return true;
  } on Object {
    if (context.mounted) {
      showAppFeedbackToast(
        context,
        context.l10n.aiErrorStorage,
        tone: AppFeedbackTone.error,
      );
    }
    return false;
  }
}
