import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/storage/vault_archive_io.dart';
import 'package:quill_diary/infrastructure/storage/storage_providers.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/presentation/app_feedback.dart';
import 'package:quill_diary/shared/presentation/display_format.dart';
import 'package:quill_diary/shared/utils/user_facing_error.dart';
import 'package:quill_diary/application/home/home_browse_state.dart';
import 'package:quill_diary/application/home/home_entry_query_providers.dart';
import 'package:quill_diary/application/session/providers/session_providers.dart';
import 'package:quill_diary/application/session/state/app_session_state.dart';
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

Future<void> deleteSelectedHomeEntries(
  BuildContext context,
  WidgetRef ref,
  AppSessionState sessionState,
  Set<EntryId> selectedIds,
) async {
  final UnlockedVaultSession? session = sessionState.session;
  if (session == null || selectedIds.isEmpty) {
    return;
  }

  final bool? confirmed = await confirmDeleteHomeEntries(
    context,
    selectedIds.length,
  );
  if (confirmed != true || !context.mounted) {
    return;
  }

  for (final EntryId id in selectedIds) {
    await ref.read(vaultEntryStoreProvider).deleteEntry(session, id);
  }

  ref.read(homeEntrySelectionProvider.notifier).clear();
  if (!context.mounted) {
    return;
  }
  refreshHomeIndexCaches(ref);
  showAppFeedbackToast(
    context,
    context.l10n.homeEntriesDeletedSuccess(selectedIds.length),
    tone: AppFeedbackTone.success,
  );
}
