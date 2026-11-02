import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/chat_diary/chat_diary_commands.dart';
import 'package:quill_diary/application/chat_diary/chat_diary_providers.dart';
import 'package:quill_diary/application/errors/ai_error_text.dart';
import 'package:quill_diary/application/session/session_providers.dart';
import 'package:quill_diary/domain/ai/ai_failure.dart';
import 'package:quill_diary/domain/chat_diary/chat_diary_session.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/ai/ai_connection_settings_dialog.dart';
import 'package:quill_diary/shared/navigation/app_routes.dart';
import 'package:quill_diary/shared/presentation/app_feedback.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_shell.dart';

Future<void> startChatDiary(BuildContext context, WidgetRef ref) async {
  final vault = ref.read(effectiveAppSessionProvider).value?.session;
  if (vault == null) return;
  bool available() =>
      context.mounted &&
      ref.read(effectiveAppSessionProvider).value?.session == vault;
  try {
    var ready = await hasReadyChatDiaryConnection(ref, vault);
    if (!context.mounted || !available()) return;
    if (!ready) {
      if (!context.mounted ||
          !available() ||
          await showAiConnectionSettingsDialog(context) == null ||
          !available()) {
        return;
      }
      ready = await hasReadyChatDiaryConnection(ref, vault);
    }
    if (!context.mounted || !available()) return;
    if (!ready) throw const AiFailure(AiErrorCode.configuration);
    final chatId = generateChatDiaryId();
    Future<void> openChatAndRefreshDrafts() async {
      await context.push<void>(AppRoutes.newChatDiaryLocation(chatId));
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
  UnlockedVaultSession session,
) async {
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
    await deleteChatDiaryData(
      ref,
      chat.id,
      session,
      entryId: chat.finished ? chat.generatedEntryId : null,
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
