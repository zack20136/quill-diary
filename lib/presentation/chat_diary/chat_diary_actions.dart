import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/ai/ai_connection_providers.dart';
import 'package:quill_diary/application/chat_diary/chat_diary_commands.dart';
import 'package:quill_diary/application/chat_diary/chat_diary_providers.dart';
import 'package:quill_diary/application/session/session_providers.dart';
import 'package:quill_diary/domain/chat_diary/chat_diary_session.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/ai/ai_connection_settings_dialog.dart';
import 'package:quill_diary/presentation/ai/ai_feature_error_panel.dart';
import 'package:quill_diary/shared/navigation/app_routes.dart';
import 'package:quill_diary/shared/presentation/app_feedback.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_shell.dart';

Future<void> startChatDiary(BuildContext context, WidgetRef ref) async {
  if (!ref.read(aiEnabledProvider)) return;
  final vault = ref.read(effectiveAppSessionProvider).value?.session;
  if (vault == null) return;
  bool available() =>
      context.mounted &&
      ref.read(aiEnabledProvider) &&
      ref.read(effectiveAppSessionProvider).value?.session == vault;
  try {
    final ready = await hasReadyChatDiaryConnection(ref, vault);
    if (!context.mounted || !available()) return;
    if (!ready) {
      await showAiConnectionSettingsDialog(context);
    }
    if (!context.mounted || !available()) return;
    final chatId = generateChatDiaryId();
    Future<void> openChatAndRefreshDrafts() async {
      await context.push<void>(AppRoutes.newChatDiaryLocation(chatId));
      if (available()) ref.invalidate(chatDiaryDraftsProvider);
    }

    unawaited(openChatAndRefreshDrafts());
  } on Object catch (error) {
    if (context.mounted && available()) {
      reportAiError(context, error);
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
    if (context.mounted) ref.invalidate(chatDiaryDraftsProvider);
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
