import 'package:flutter/material.dart';

import 'package:quill_diary/infrastructure/storage/vault_archive_io.dart';
import 'package:quill_diary/l10n/l10n.dart';
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
                  _ImportSummaryCard(
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
                        final Set<int>? next = await _showSelectImportEntriesDialog(
                          context: context,
                          preview: preview,
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
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleSmall,
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
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
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

Future<Set<int>?> _showSelectImportEntriesDialog({
  required BuildContext context,
  required PortableImportPreview preview,
  required Set<int> initiallySelected,
}) {
  final Set<int> draft = Set<int>.from(initiallySelected);

  return showAppDialog<Set<int>>(
    context: context,
    size: AppDialogSize.standard,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          final AppLocalizations l10n = context.l10n;
          final ColorScheme cs = Theme.of(context).colorScheme;
          final bool canConfirm = draft.isNotEmpty;

          return AppDialogShell(
            title: l10n.portableExportSelectEntriesLabel,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    TextButton(
                      onPressed: () {
                        setState(() {
                          draft
                            ..clear()
                            ..addAll(
                              preview.entries.map(
                                (PortableImportPreviewEntry e) =>
                                    e.previewIndex,
                              ),
                            );
                        });
                      },
                      child: Text(l10n.homeSelectionSelectAll),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(draft.clear);
                      },
                      child: Text(l10n.homeSelectionDeselectAll),
                    ),
                    const Spacer(),
                    Text(
                      l10n.portableExportSelectEntriesSummary(
                        draft.length,
                        preview.entryCount,
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.45,
                  ),
                  child: Material(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(12),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: preview.entries.length,
                      separatorBuilder: (BuildContext context, int index) =>
                          Divider(
                            height: 1,
                            color: cs.outlineVariant.withValues(alpha: 0.35),
                          ),
                      itemBuilder: (BuildContext context, int index) {
                        final PortableImportPreviewEntry entry =
                            preview.entries[index];
                        final String title = entry.displayTitle.trim().isNotEmpty
                            ? entry.displayTitle.trim()
                            : l10n.editorUntitledDraft;
                        final bool selected = draft.contains(entry.previewIndex);
                        return CheckboxListTile(
                          value: selected,
                          onChanged: (bool? value) {
                            setState(() {
                              if (value == true) {
                                draft.add(entry.previewIndex);
                              } else {
                                draft.remove(entry.previewIndex);
                              }
                            });
                          },
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            entry.likelyDuplicate
                                ? '${entry.date.value} · ${l10n.portableImportLikelyDuplicateMark}'
                                : entry.date.value,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(l10n.commonActionCancel),
              ),
              FilledButton(
                onPressed: canConfirm
                    ? () =>
                          Navigator.of(dialogContext).pop(Set<int>.from(draft))
                    : null,
                child: Text(l10n.commonActionConfirm),
              ),
            ],
          );
        },
      );
    },
  );
}

class _ImportSummaryCard extends StatelessWidget {
  const _ImportSummaryCard({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (var index = 0; index < lines.length; index++) ...<Widget>[
              if (index > 0) const SizedBox(height: 4),
              Text(lines[index]),
            ],
          ],
        ),
      ),
    );
  }
}
