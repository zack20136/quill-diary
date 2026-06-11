import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/security/unlocked_vault_session.dart';
import '../../domain/shared/value_objects.dart';
import '../../infrastructure/storage/vault_archive_io.dart';
import '../../infrastructure/storage/vault_repository.dart';
import '../../shared/copy/common_copy.dart';
import '../../shared/presentation/display_format.dart';
import '../../shared/providers/core_providers.dart';
import '../../shared/utils/user_facing_error.dart';
import '../session/providers/session_providers.dart';
import '../session/state/app_session_state.dart';
import 'home_copy.dart';
import 'providers/home_providers.dart';
import 'state/home_state.dart';
import 'widgets/home_selection_toolbar.dart';

const int kHtmlExportImageWarningThresholdBytes = 50 * 1024 * 1024;

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
  Set<EntryId> selectedIds,
) async {
  if (selectedIds.isEmpty) {
    return;
  }

  final Set<EntryId> exportIds = Set<EntryId>.from(selectedIds);
  final transferService = ref.read(vaultTransferServiceProvider);
  try {
    final HtmlExportEstimate estimate =
        await transferService.estimateSelectedHtmlExport(exportIds);
    if (!context.mounted) {
      return;
    }
    if (estimate.exceedsImageBytes(kHtmlExportImageWarningThresholdBytes)) {
      final bool confirmed = await confirmLargeHtmlExport(context, estimate);
      if (!confirmed || !context.mounted) {
        return;
      }
    }

    final String? savedPath = await ref
        .read(appSessionProvider.notifier)
        .runSensitiveTask((UnlockedVaultSession activeSession) {
      return transferService.exportHtmlToDirectory(activeSession, exportIds);
    });
    if (savedPath == null || !context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          HomeCopy.htmlExportSuccess(
            DisplayFormat.formatSavedFileNameForDisplay(savedPath),
          ),
        ),
      ),
    );
  } on StateError catch (error) {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(userFacingErrorMessage(error))),
    );
  } catch (error) {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(userFacingErrorMessage(error))),
    );
  }
}

String overviewExportLabel(MemoryScope scope) {
  return switch (scope) {
    MemoryScope.all => HomeCopy.exportRecapAll,
    MemoryScope.year => HomeCopy.exportRecapYear,
    MemoryScope.month => HomeCopy.exportRecapMonth,
  };
}

Future<bool> confirmLargeHtmlExport(
  BuildContext context,
  HtmlExportEstimate estimate,
) async {
  return await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: const Text(HomeCopy.htmlExportLargeTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(HomeCopy.htmlExportSelectionSummary(
                estimate.entryCount,
                estimate.imageCount,
              )),
              const SizedBox(height: 8),
              Text(HomeCopy.htmlExportImageSize(
                DisplayFormat.formatBytesForDisplay(estimate.imageBytes),
              )),
              Text(HomeCopy.htmlExportEstimatedSize(
                DisplayFormat.formatBytesForDisplay(estimate.estimatedHtmlBytes),
              )),
              const SizedBox(height: 12),
              const Text(HomeCopy.htmlExportEmbeddedHint),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text(CommonCopy.actionCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(HomeCopy.htmlExportProceed),
            ),
          ],
        ),
      ) ??
      false;
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

  final bool? confirmed = await confirmDeleteHomeEntries(context, selectedIds.length);
  if (confirmed != true || !context.mounted) {
    return;
  }

  final VaultRepository repository = ref.read(vaultRepositoryProvider);
  for (final EntryId id in selectedIds) {
    await repository.deleteEntry(session, id);
  }

  ref.read(homeEntrySelectionProvider.notifier).clear();
  if (!context.mounted) {
    return;
  }
  await refreshHomeIndexCaches(ref);
}
