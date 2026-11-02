import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_diary/application/chat_diary/chat_diary_providers.dart';
import 'package:quill_diary/application/diary/diary_entry_providers.dart';
import 'package:quill_diary/application/errors/user_facing_error.dart';
import 'package:quill_diary/application/home/home_browse_state.dart';
import 'package:quill_diary/application/home/home_entry_commands.dart';
import 'package:quill_diary/application/session/session_providers.dart';
import 'package:quill_diary/application/session/session_state.dart';
import 'package:quill_diary/application/vault/vault_providers.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/home/widgets/home_selection_toolbar.dart';
import 'package:quill_diary/presentation/transfer/portable_export_confirm.dart';
import 'package:quill_diary/shared/presentation/app_feedback.dart';
import 'package:quill_diary/shared/presentation/display_format.dart';

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

  final transferService = ref.read(portableTransferServiceProvider);
  try {
    final estimate = await transferService.estimateSelectedHtmlExport(
      selectedIds,
    );
    if (!context.mounted) {
      return;
    }
    if (estimate.entryCount == 0) {
      showAppFeedbackToast(
        context,
        context.l10n.settingsImportExportExportNoEntriesMessage,
      );
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

String overviewExportLabel(
  BuildContext context,
  OverviewScope scope, {
  String? selectedTag,
}) {
  final String base = switch (scope) {
    OverviewScope.all => context.l10n.homeExportRecapAll,
    OverviewScope.year => context.l10n.homeExportRecapYear,
    OverviewScope.month => context.l10n.homeExportRecapMonth,
  };
  if (selectedTag == null || selectedTag.isEmpty) return base;
  return context.l10n.homeDiarySectionWithTag(base, selectedTag);
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

  final selection = ref.read(homeEntrySelectionProvider.notifier);
  var deletion = const HomeItemsDeletion(
    entryIds: <EntryId>{},
    chatIds: <String>{},
    completed: false,
  );
  var failed = false;
  try {
    deletion = await deleteHomeItems(
      ref,
      session,
      entryIds: entryIds,
      chatIds: chatIds,
      isSessionCurrent: vaultIsCurrent,
    );
  } on HomeItemsDeletionException catch (error) {
    deletion = error.deletion;
    failed = true;
    if (context.mounted && vaultIsCurrent()) {
      showAppFeedbackToast(
        context,
        userFacingErrorMessage(error.cause, l10n: context.l10n),
        tone: AppFeedbackTone.error,
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
        entryIds: deletion.entryIds,
        chatIds: deletion.chatIds,
      );
      if (deletion.entryIds.isNotEmpty) {
        ref.read(diaryRevisionProvider.notifier).bump();
      }
      if (deletion.chatIds.isNotEmpty) {
        ref.invalidate(chatDiarySessionsProvider);
      }
    }
  }
  if (!context.mounted || !vaultIsCurrent() || failed || !deletion.completed) {
    return;
  }
  selection.clear();
  showAppFeedbackToast(
    context,
    chatIds.isEmpty
        ? context.l10n.homeEntriesDeletedSuccess(count)
        : context.l10n.homeItemsDeletedSuccess(count),
    tone: AppFeedbackTone.success,
  );
}
