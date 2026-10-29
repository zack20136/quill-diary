import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_diary/application/home/home_browse_state.dart';
import 'package:quill_diary/application/home/home_entry_query_providers.dart';
import 'package:quill_diary/application/session/providers/session_providers.dart';
import 'package:quill_diary/application/session/state/app_session_state.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/storage/storage_providers.dart';
import 'package:quill_diary/infrastructure/storage/vault_archive_io.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/presentation/app_feedback.dart';
import 'package:quill_diary/shared/presentation/display_format.dart';
import 'package:quill_diary/shared/utils/user_facing_error.dart';

import '../../application/ai/ai_connection_providers.dart';
import '../../application/chat_diary/chat_diary_providers.dart';
import 'portable_export_confirm.dart';
import 'widgets/home_selection_toolbar.dart';

Future<void> exportSelectedHomeEntriesAsHtml(
  BuildContext context,
  WidgetRef ref,
  AppSessionState sessionState,
  Set<EntryId> selectedIds,
) async {
  if (sessionState.session == null || selectedIds.isEmpty) {
    return;
  }

  await exportEntriesAsHtml(context, ref, selectedIds);
}

Future<void> exportEntriesAsHtml(
  BuildContext context,
  WidgetRef ref,
  Set<EntryId> selectedIds, {
  String? scopeLabel,
}) async {
  if (selectedIds.isEmpty) {
    return;
  }

  final transferService = ref.read(vaultTransferServiceProvider);
  try {
    final HtmlExportEstimate estimate = await transferService
        .estimateSelectedHtmlExport(selectedIds);
    if (!context.mounted) {
      return;
    }
    final HtmlExportConfirmResult confirmation = await confirmHtmlExport(
      context: context,
      estimate: estimate,
      scopeLabel: scopeLabel,
    );
    if (!confirmation.confirmed ||
        !context.mounted ||
        confirmation.selectedEntryIds.isEmpty) {
      return;
    }

    final String? savedPath = await ref
        .read(appSessionProvider.notifier)
        .runSensitiveTask((UnlockedVaultSession activeSession) {
          return transferService.exportHtmlToDirectory(
            activeSession,
            confirmation.selectedEntryIds,
            context.l10n,
            options: confirmation.options,
          );
        });
    if (savedPath == null || !context.mounted) {
      return;
    }
    showAppFeedbackToast(
      context,
      context.l10n.homeHtmlExportSuccess(
        DisplayFormat.formatSavedFileNameForDisplay(savedPath),
      ),
      tone: AppFeedbackTone.success,
    );
  } catch (error) {
    if (!context.mounted) {
      return;
    }
    showAppFeedbackToast(
      context,
      userFacingErrorMessage(error, l10n: context.l10n),
      tone: AppFeedbackTone.error,
    );
  }
}

String overviewExportLabel(BuildContext context, MemoryScope scope) {
  return switch (scope) {
    MemoryScope.all => context.l10n.homeExportRecapAll,
    MemoryScope.year => context.l10n.homeExportRecapYear,
    MemoryScope.month => context.l10n.homeExportRecapMonth,
  };
}

Future<void> deleteSelectedHomeItems(
  BuildContext context,
  WidgetRef ref,
  AppSessionState sessionState,
  Set<EntryId> entryIds, {
  Set<String> chatIds = const {},
}) async {
  final session = sessionState.session;
  final count = entryIds.length + chatIds.length;
  if (session == null || count == 0) return;
  final confirmed = await confirmDeleteHomeItems(
    context,
    count,
    includesChatDrafts: chatIds.isNotEmpty,
  );
  bool vaultIsCurrent() =>
      ref.read(effectiveAppSessionProvider).value?.session == session;
  if (confirmed != true || !context.mounted || !vaultIsCurrent()) return;

  final entryStore = ref.read(vaultEntryStoreProvider);
  final chatStore = ref.read(chatDiaryStoreProvider);
  final keyFor = ref.read(aiConnectionSettingsStoreProvider).readApiKey;
  final selection = ref.read(homeEntrySelectionProvider.notifier);
  final deletedEntries = <EntryId>{};
  final deletedChats = <String>{};
  var failed = false;
  try {
    for (final id in entryIds) {
      if (!context.mounted || !vaultIsCurrent()) return;
      await entryStore.deleteEntry(session, id);
      deletedEntries.add(id);
    }
    for (final id in chatIds) {
      if (!context.mounted || !vaultIsCurrent()) return;
      await chatStore.delete(id, session: session);
      deletedChats.add(id);
      unawaited(
        chatStore
            .cleanupRemoteFiles(session, keyFor, chatId: id)
            .onError((_, _) => false),
      );
    }
  } on Object catch (error) {
    failed = true;
    if (context.mounted && vaultIsCurrent()) {
      showAppFeedbackToast(
        context,
        userFacingErrorMessage(error, l10n: context.l10n),
        tone: AppFeedbackTone.error,
      );
    }
  } finally {
    if (context.mounted && vaultIsCurrent()) {
      selection.deselectDeleted(
        entryIds: deletedEntries,
        chatIds: deletedChats,
      );
      if (deletedEntries.isNotEmpty) refreshHomeIndexCaches(ref);
      if (deletedChats.isNotEmpty) ref.invalidate(chatDiarySessionsProvider);
    }
  }
  if (!context.mounted || !vaultIsCurrent() || failed) return;
  selection.clear();
  showAppFeedbackToast(
    context,
    chatIds.isEmpty
        ? context.l10n.homeEntriesDeletedSuccess(count)
        : context.l10n.homeItemsDeletedSuccess(count),
    tone: AppFeedbackTone.success,
  );
}
