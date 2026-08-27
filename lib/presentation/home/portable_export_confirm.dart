import 'package:flutter/material.dart';

import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/storage/vault_archive_io.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/presentation/display_format.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_shell.dart';

const int _kHtmlExportLargeImageBytes = 50 * 1024 * 1024;

/// Markdown 匯出確認結果（含選項與選中篇）。
class MarkdownExportConfirmResult {
  const MarkdownExportConfirmResult({
    required this.confirmed,
    required this.options,
    required this.selectedEntryIds,
  });

  final bool confirmed;
  final MarkdownExportOptions options;
  final Set<EntryId> selectedEntryIds;
}

/// HTML 匯出確認結果（含選項與選中篇）。
class HtmlExportConfirmResult {
  const HtmlExportConfirmResult({
    required this.confirmed,
    required this.options,
    required this.selectedEntryIds,
  });

  final bool confirmed;
  final HtmlExportOptions options;
  final Set<EntryId> selectedEntryIds;
}

class _PickableExportEntry {
  const _PickableExportEntry({
    required this.id,
    required this.date,
    required this.title,
  });

  final EntryId id;
  final DateOnly date;
  final String? title;
}

Future<MarkdownExportConfirmResult> confirmMarkdownExport({
  required BuildContext context,
  required MarkdownExportEstimate estimate,
}) async {
  final bool useEnglishPersonLabels = isEnglishL10n(context.l10n);
  var hidePersonNames = false;
  final Set<EntryId> selectedEntryIds = estimate.entries
      .map((MarkdownExportEntrySummary e) => e.id)
      .toSet();

  final bool? confirmed = await showAppDialog<bool>(
    context: context,
    size: AppDialogSize.standard,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          final AppLocalizations l10n = context.l10n;
          final ColorScheme cs = Theme.of(context).colorScheme;
          final MarkdownExportEstimate selectedEstimate = estimate.forSelected(
            selectedEntryIds,
          );
          final bool canExport = selectedEntryIds.isNotEmpty;

          return AppDialogShell(
            title: l10n.portableExportConfirmTitle,
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _ExportSummaryCard(
                    lines: <String>[
                      l10n.portableExportMarkdownFormatLabel,
                      l10n.portableExportEntryCount(selectedEstimate.entryCount),
                      l10n.portableExportAttachmentCount(
                        selectedEstimate.attachmentCount,
                      ),
                      if (selectedEstimate.firstDate != null &&
                          selectedEstimate.lastDate != null)
                        l10n.portableExportDateRange(
                          selectedEstimate.firstDate!.value,
                          selectedEstimate.lastDate!.value,
                        ),
                      l10n.portableExportFileSize(
                        DisplayFormat.formatBytesForDisplay(
                          selectedEstimate.estimatedBytes,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        final Set<EntryId>? next =
                            await _showSelectEntriesDialog(
                              context: context,
                              entries: estimate.entries
                                  .map(
                                    (MarkdownExportEntrySummary e) =>
                                        _PickableExportEntry(
                                          id: e.id,
                                          date: e.date,
                                          title: e.title,
                                        ),
                                  )
                                  .toList(growable: false),
                              initiallySelected: selectedEntryIds,
                            );
                        if (next == null) {
                          return;
                        }
                        setState(() {
                          selectedEntryIds
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
                                      selectedEntryIds.length,
                                      estimate.entryCount,
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
                  const SizedBox(height: 4),
                  Divider(
                    height: 1,
                    color: cs.outlineVariant.withValues(alpha: 0.45),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: hidePersonNames,
                    onChanged: (bool value) {
                      setState(() => hidePersonNames = value);
                    },
                    title: Text(l10n.portableExportHidePersonNamesLabel),
                    subtitle: Text(l10n.portableExportHidePersonNamesHint),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.portableExportPlaintextWarning,
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
                onPressed: canExport
                    ? () => Navigator.of(dialogContext).pop(true)
                    : null,
                child: Text(l10n.portableExportConfirmAction),
              ),
            ],
          );
        },
      );
    },
  );

  return MarkdownExportConfirmResult(
    confirmed: confirmed == true,
    options: MarkdownExportOptions(
      hidePersonNames: hidePersonNames,
      useEnglishPersonLabels: useEnglishPersonLabels,
    ),
    selectedEntryIds: Set<EntryId>.from(selectedEntryIds),
  );
}

Future<HtmlExportConfirmResult> confirmHtmlExport({
  required BuildContext context,
  required HtmlExportEstimate estimate,
  String? scopeLabel,
}) async {
  final bool useEnglishPersonLabels = isEnglishL10n(context.l10n);
  var includeImages = true;
  var hidePersonNames = false;
  final Set<EntryId> selectedEntryIds = estimate.entries
      .map((HtmlExportEntrySummary e) => e.id)
      .toSet();

  final bool? confirmed = await showAppDialog<bool>(
    context: context,
    size: AppDialogSize.standard,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          final AppLocalizations l10n = context.l10n;
          final ColorScheme cs = Theme.of(context).colorScheme;
          final HtmlExportEstimate selectedEstimate = estimate.forSelected(
            selectedEntryIds,
          );
          final bool canExport = selectedEntryIds.isNotEmpty;
          final int exportBytes = selectedEstimate.estimatedExportBytes(
            includeImages: includeImages,
          );

          return AppDialogShell(
            title: l10n.portableExportConfirmTitle,
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _ExportSummaryCard(
                    lines: <String>[
                      l10n.portableExportHtmlFormatLabel,
                      if (scopeLabel != null && scopeLabel.isNotEmpty)
                        l10n.portableExportScopeLabel(scopeLabel),
                      l10n.portableExportEntryCount(selectedEstimate.entryCount),
                      if (includeImages && selectedEstimate.imageCount > 0)
                        l10n.portableExportImageCount(
                          selectedEstimate.imageCount,
                        ),
                      if (selectedEstimate.firstDate != null &&
                          selectedEstimate.lastDate != null)
                        l10n.portableExportDateRange(
                          selectedEstimate.firstDate!.value,
                          selectedEstimate.lastDate!.value,
                        ),
                      l10n.portableExportFileSize(
                        DisplayFormat.formatBytesForDisplay(exportBytes),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        final Set<EntryId>? next =
                            await _showSelectEntriesDialog(
                              context: context,
                              entries: estimate.entries
                                  .map(
                                    (HtmlExportEntrySummary e) =>
                                        _PickableExportEntry(
                                          id: e.id,
                                          date: e.date,
                                          title: e.title,
                                        ),
                                  )
                                  .toList(growable: false),
                              initiallySelected: selectedEntryIds,
                            );
                        if (next == null) {
                          return;
                        }
                        setState(() {
                          selectedEntryIds
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
                                      selectedEntryIds.length,
                                      estimate.entryCount,
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
                  const SizedBox(height: 4),
                  Divider(
                    height: 1,
                    color: cs.outlineVariant.withValues(alpha: 0.45),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: includeImages,
                    onChanged: (bool value) {
                      setState(() => includeImages = value);
                    },
                    title: Text(l10n.portableExportIncludeImagesLabel),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: hidePersonNames,
                    onChanged: (bool value) {
                      setState(() => hidePersonNames = value);
                    },
                    title: Text(l10n.portableExportHidePersonNamesLabel),
                    subtitle: Text(l10n.portableExportHidePersonNamesHint),
                  ),
                  if (includeImages &&
                      selectedEstimate.exceedsImageBytes(
                        _kHtmlExportLargeImageBytes,
                      )) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(l10n.homeHtmlExportLargeTitle),
                    const SizedBox(height: 4),
                    Text(
                      l10n.homeHtmlExportImageSize(
                        DisplayFormat.formatBytesForDisplay(
                          selectedEstimate.imageBytes,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(l10n.homeHtmlExportEmbeddedHint),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    l10n.portableExportPlaintextWarning,
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
                onPressed: canExport
                    ? () => Navigator.of(dialogContext).pop(true)
                    : null,
                child: Text(l10n.portableExportConfirmAction),
              ),
            ],
          );
        },
      );
    },
  );

  return HtmlExportConfirmResult(
    confirmed: confirmed == true,
    options: HtmlExportOptions(
      includeImages: includeImages,
      hidePersonNames: hidePersonNames,
      useEnglishPersonLabels: useEnglishPersonLabels,
    ),
    selectedEntryIds: Set<EntryId>.from(selectedEntryIds),
  );
}

Future<Set<EntryId>?> _showSelectEntriesDialog({
  required BuildContext context,
  required List<_PickableExportEntry> entries,
  required Set<EntryId> initiallySelected,
}) {
  final Set<EntryId> draft = Set<EntryId>.from(initiallySelected);

  return showAppDialog<Set<EntryId>>(
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
                              entries.map((_PickableExportEntry e) => e.id),
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
                        entries.length,
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
                      itemCount: entries.length,
                      separatorBuilder: (BuildContext context, int index) =>
                          Divider(
                            height: 1,
                            color: cs.outlineVariant.withValues(alpha: 0.35),
                          ),
                      itemBuilder: (BuildContext context, int index) {
                        final _PickableExportEntry entry = entries[index];
                        final String title =
                            (entry.title?.trim().isNotEmpty ?? false)
                            ? entry.title!.trim()
                            : l10n.editorUntitledDraft;
                        final bool selected = draft.contains(entry.id);
                        return CheckboxListTile(
                          value: selected,
                          onChanged: (bool? value) {
                            setState(() {
                              if (value == true) {
                                draft.add(entry.id);
                              } else {
                                draft.remove(entry.id);
                              }
                            });
                          },
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(entry.date.value),
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
                    ? () => Navigator.of(
                        dialogContext,
                      ).pop(Set<EntryId>.from(draft))
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

class _ExportSummaryCard extends StatelessWidget {
  const _ExportSummaryCard({required this.lines});

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
