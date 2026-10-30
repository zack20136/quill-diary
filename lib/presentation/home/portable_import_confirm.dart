import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/infrastructure/storage/portable/portable_import_preview.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/home/portable_transfer_dialogs.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_shell.dart';

Future<PortableImportConfirmResult> confirmPortableImport({
  required BuildContext context,
  required PortableImportPreview preview,
}) async {
  final Set<int> selectedPreviewIndices = preview.entries
      .map((PortableImportPreviewEntry e) => e.previewIndex)
      .toSet();

  final bool? confirmed = await showAppDialog<bool>(
    context: context,
    size: AppDialogSize.standard,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          final AppLocalizations l10n = context.l10n;
          final ColorScheme cs = Theme.of(context).colorScheme;
          final PortableImportPreview selectedPreview = preview.forSelected(
            selectedPreviewIndices,
          );
          final bool canImport = selectedPreviewIndices.isNotEmpty;

          return AppDialogShell(
            title: l10n.portableImportConfirmTitle,
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  PortableTransferSummaryCard(
                    lines: <String>[
                      l10n.portableExportEntryCount(selectedPreview.entryCount),
                      if (preview.skippedFiles > 0)
                        l10n.portableImportSkippedFilesCount(
                          preview.skippedFiles,
                        ),
                      if (preview.skippedAttachments > 0)
                        l10n.portableImportSkippedAttachmentsCount(
                          preview.skippedAttachments,
                        ),
                      if (selectedPreview.likelyDuplicateCount > 0)
                        l10n.portableImportLikelyDuplicateCount(
                          selectedPreview.likelyDuplicateCount,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        final Set<int>?
                        next = await showPortableEntrySelectionDialog<int>(
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
                        if (next == null) {
                          return;
                        }
                        setState(() {
                          selectedPreviewIndices
                            ..clear()
                            ..addAll(next);
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 10,
                        ),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    l10n.portableExportSelectEntriesLabel,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    l10n.portableExportSelectEntriesSummary(
                                      selectedPreviewIndices.length,
                                      preview.entryCount,
                                    ),
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: cs.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: cs.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.portableImportAddsAsNewHint,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.commonActionCancel),
              ),
              FilledButton(
                onPressed: canImport
                    ? () => Navigator.of(dialogContext).pop(true)
                    : null,
                child: Text(l10n.portableImportConfirmAction),
              ),
            ],
          );
        },
      );
    },
  );

  return PortableImportConfirmResult(
    confirmed: confirmed == true,
    selectedPreviewIndices: Set<int>.from(selectedPreviewIndices),
  );
}
