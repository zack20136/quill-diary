import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/infrastructure/storage/portable/portable_import_preview.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/transfer/portable_transfer_dialogs.dart';
import 'package:quill_diary/shared/presentation/app_feedback.dart';

Future<PortableImportConfirmResult> confirmPortableImport({
  required BuildContext context,
  required PortableImportPreview preview,
}) async {
  final Set<int> selectedPreviewIndices = preview.entries
      .map((PortableImportPreviewEntry e) => e.previewIndex)
      .toSet();

  final AppLocalizations l10n = context.l10n;
  final bool confirmed = await showPortableTransferConfirmDialog(
    context: context,
    title: l10n.portableImportConfirmTitle,
    confirmLabel: l10n.portableImportConfirmAction,
    canConfirm: () => selectedPreviewIndices.isNotEmpty,
    body: (BuildContext context, StateSetter setState) {
      final PortableImportPreview selectedPreview = preview.forSelected(
        selectedPreviewIndices,
      );
      return PortableTransferConfirmBody(
        summaryIcon: Icons.file_download_outlined,
        summaryTitle: l10n.portableExportEntryCount(selectedPreview.entryCount),
        summaryDetails: <String>[
          if (preview.skippedFiles > 0)
            l10n.portableImportSkippedFilesCount(preview.skippedFiles),
          if (preview.skippedAttachments > 0)
            l10n.portableImportSkippedAttachmentsCount(
              preview.skippedAttachments,
            ),
          if (selectedPreview.likelyDuplicateCount > 0)
            l10n.portableImportLikelyDuplicateCount(
              selectedPreview.likelyDuplicateCount,
            ),
        ],
        selectedCount: selectedPreviewIndices.length,
        totalCount: preview.entryCount,
        onSelectEntries: () async {
          final Set<int>? next = await showPortableEntrySelectionDialog<int>(
            context: context,
            entries: [
              for (final entry in preview.entries)
                PortableEntryOption<int>(
                  id: entry.previewIndex,
                  title: entry.displayTitle,
                  subtitle: entry.likelyDuplicate
                      ? '${entry.date.value} · ${l10n.portableImportLikelyDuplicateMark}'
                      : entry.date.value,
                ),
            ],
            initiallySelected: selectedPreviewIndices,
          );
          if (next == null || !context.mounted) return;
          setState(() {
            selectedPreviewIndices
              ..clear()
              ..addAll(next);
          });
        },
        notice: AppFeedbackBanner(
          icon: Icons.playlist_add_rounded,
          message: l10n.portableImportAddsAsNewHint,
        ),
      );
    },
  );

  return PortableImportConfirmResult(
    confirmed: confirmed,
    selectedPreviewIndices: Set<int>.from(selectedPreviewIndices),
  );
}
