import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/storage/portable/portable_export_io.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/transfer/portable_transfer_dialogs.dart';
import 'package:quill_diary/shared/presentation/display_format.dart';

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

Future<MarkdownExportConfirmResult> confirmMarkdownExport({
  required BuildContext context,
  required MarkdownExportEstimate estimate,
}) async {
  final bool useEnglishPersonLabels = isEnglishL10n(context.l10n);
  var hidePersonNames = false;
  final Set<EntryId> selectedEntryIds = estimate.entries
      .map((MarkdownExportEntrySummary e) => e.id)
      .toSet();

  final AppLocalizations l10n = context.l10n;
  final bool confirmed = await showPortableTransferConfirmDialog(
    context: context,
    title: l10n.portableExportConfirmTitle,
    confirmLabel: l10n.portableExportConfirmAction,
    canConfirm: () => selectedEntryIds.isNotEmpty,
    body: (BuildContext context, StateSetter setState) {
      final MarkdownExportEstimate selectedEstimate = estimate.forSelected(
        selectedEntryIds,
      );
      return PortableTransferConfirmBody(
        summaryLines: <String>[
          l10n.portableExportMarkdownFormatLabel,
          l10n.portableExportEntryCount(selectedEstimate.entryCount),
          l10n.portableExportAttachmentCount(selectedEstimate.attachmentCount),
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
        selectedCount: selectedEntryIds.length,
        totalCount: estimate.entryCount,
        onSelectEntries: () async {
          final Set<EntryId>? next =
              await showPortableEntrySelectionDialog<EntryId>(
                context: context,
                entries: estimate.entries
                    .map(
                      (MarkdownExportEntrySummary e) =>
                          PortableEntryOption<EntryId>(
                            id: e.id,
                            subtitle: e.date.value,
                            title: e.title,
                          ),
                    )
                    .toList(growable: false),
                initiallySelected: selectedEntryIds,
              );
          if (next == null) return;
          setState(() {
            selectedEntryIds
              ..clear()
              ..addAll(next);
          });
        },
        options: <Widget>[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: hidePersonNames,
            onChanged: (bool value) {
              setState(() => hidePersonNames = value);
            },
            title: Text(l10n.portableExportHidePersonNamesLabel),
            subtitle: Text(l10n.portableExportHidePersonNamesHint),
          ),
        ],
        footer: l10n.portableExportPlaintextWarning,
      );
    },
  );

  return MarkdownExportConfirmResult(
    confirmed: confirmed,
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

  final AppLocalizations l10n = context.l10n;
  final bool confirmed = await showPortableTransferConfirmDialog(
    context: context,
    title: l10n.portableExportConfirmTitle,
    confirmLabel: l10n.portableExportConfirmAction,
    canConfirm: () => selectedEntryIds.isNotEmpty,
    body: (BuildContext context, StateSetter setState) {
      final HtmlExportEstimate selectedEstimate = estimate.forSelected(
        selectedEntryIds,
      );
      final int exportBytes = selectedEstimate.estimatedExportBytes(
        includeImages: includeImages,
      );
      final bool largeImages =
          includeImages &&
          selectedEstimate.exceedsImageBytes(_kHtmlExportLargeImageBytes);
      return PortableTransferConfirmBody(
        summaryLines: <String>[
          l10n.portableExportHtmlFormatLabel,
          if (scopeLabel != null && scopeLabel.isNotEmpty)
            l10n.portableExportScopeLabel(scopeLabel),
          l10n.portableExportEntryCount(selectedEstimate.entryCount),
          if (includeImages && selectedEstimate.imageCount > 0)
            l10n.portableExportImageCount(selectedEstimate.imageCount),
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
        selectedCount: selectedEntryIds.length,
        totalCount: estimate.entryCount,
        onSelectEntries: () async {
          final Set<EntryId>? next =
              await showPortableEntrySelectionDialog<EntryId>(
                context: context,
                entries: estimate.entries
                    .map(
                      (HtmlExportEntrySummary e) =>
                          PortableEntryOption<EntryId>(
                            id: e.id,
                            subtitle: e.date.value,
                            title: e.title,
                          ),
                    )
                    .toList(growable: false),
                initiallySelected: selectedEntryIds,
              );
          if (next == null) return;
          setState(() {
            selectedEntryIds
              ..clear()
              ..addAll(next);
          });
        },
        options: <Widget>[
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
        ],
        notice: largeImages
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
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
              )
            : null,
        footer: l10n.portableExportPlaintextWarning,
      );
    },
  );

  return HtmlExportConfirmResult(
    confirmed: confirmed,
    options: HtmlExportOptions(
      includeImages: includeImages,
      hidePersonNames: hidePersonNames,
      useEnglishPersonLabels: useEnglishPersonLabels,
      documentTitle: l10n.portableExportHtmlDocumentTitle,
      untitledEntryTitle: l10n.editorUntitledDraft,
      unembeddedAttachmentsHeading:
          l10n.portableExportUnembeddedAttachmentsHeading,
      htmlLang: useEnglishPersonLabels ? 'en' : 'zh-Hant',
    ),
    selectedEntryIds: Set<EntryId>.from(selectedEntryIds),
  );
}
