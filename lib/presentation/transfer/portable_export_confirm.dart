import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/storage/portable/portable_export_io.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/transfer/portable_transfer_dialogs.dart';
import 'package:quill_diary/shared/presentation/app_feedback.dart';
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
    title: l10n.portableExportMarkdownTitle,
    confirmLabel: l10n.portableExportConfirmAction,
    canConfirm: () => selectedEntryIds.isNotEmpty,
    body: (BuildContext context, StateSetter setState) {
      final MarkdownExportEstimate selectedEstimate = estimate.forSelected(
        selectedEntryIds,
      );
      return PortableTransferConfirmBody(
        summaryIcon: Icons.description_outlined,
        summaryTitle: l10n.portableExportMarkdownFormatLabel,
        summaryDetails: <String>[
          l10n.portableExportEntryCount(selectedEstimate.entryCount),
          l10n.portableExportAttachmentCount(selectedEstimate.attachmentCount),
          if (selectedEstimate.firstDate != null &&
              selectedEstimate.lastDate != null)
            _exportDates(
              l10n,
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
          if (next == null || !context.mounted) return;
          setState(() {
            selectedEntryIds
              ..clear()
              ..addAll(next);
          });
        },
        options: <Widget>[
          SwitchListTile(
            secondary: const Icon(Icons.person_off_outlined),
            value: hidePersonNames,
            onChanged: (bool value) {
              setState(() => hidePersonNames = value);
            },
            title: Text(l10n.portableExportHidePersonNamesLabel),
            subtitle: Text(l10n.portableExportHidePersonNamesHint),
          ),
        ],
        notice: AppFeedbackBanner(
          icon: Icons.lock_open_outlined,
          message: l10n.portableExportPlaintextWarning,
          tone: AppFeedbackTone.warning,
        ),
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
  var externalAssets = false;
  var hidePersonNames = false;
  final Set<EntryId> selectedEntryIds = estimate.entries
      .map((HtmlExportEntrySummary e) => e.id)
      .toSet();

  final AppLocalizations l10n = context.l10n;
  final bool confirmed = await showPortableTransferConfirmDialog(
    context: context,
    title: l10n.portableExportHtmlTitle,
    confirmLabel: l10n.portableExportConfirmAction,
    canConfirm: () => selectedEntryIds.isNotEmpty,
    body: (BuildContext context, StateSetter setState) {
      final HtmlExportEstimate selectedEstimate = estimate.forSelected(
        selectedEntryIds,
      );
      final bool canExportAssets =
          includeImages && selectedEstimate.imageCount > 0;
      final int exportBytes = selectedEstimate.estimatedExportBytes(
        includeImages: includeImages,
        externalAssets: externalAssets,
      );
      final bool largeImages =
          includeImages &&
          !externalAssets &&
          selectedEstimate.exceedsImageBytes(_kHtmlExportLargeImageBytes);
      return PortableTransferConfirmBody(
        summaryIcon: Icons.code_rounded,
        summaryTitle: externalAssets
            ? l10n.portableExportHtmlAssetsLabel
            : l10n.portableExportHtmlFormatLabel,
        summaryDetails: <String>[
          if (scopeLabel != null && scopeLabel.isNotEmpty)
            l10n.portableExportScopeLabel(scopeLabel),
          l10n.portableExportEntryCount(selectedEstimate.entryCount),
          if (includeImages && selectedEstimate.imageCount > 0)
            l10n.portableExportImageCount(selectedEstimate.imageCount),
          if (selectedEstimate.firstDate != null &&
              selectedEstimate.lastDate != null)
            _exportDates(
              l10n,
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
          if (next == null || !context.mounted) return;
          setState(() {
            selectedEntryIds
              ..clear()
              ..addAll(next);
            if (estimate.forSelected(next).imageCount == 0) {
              externalAssets = false;
            }
          });
        },
        options: <Widget>[
          SwitchListTile(
            secondary: const Icon(Icons.image_outlined),
            value: includeImages,
            onChanged: (bool value) {
              setState(() {
                includeImages = value;
                if (!value) externalAssets = false;
              });
            },
            title: Text(l10n.portableExportIncludeImagesLabel),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.folder_outlined),
            value: externalAssets,
            onChanged: canExportAssets
                ? (bool value) => setState(() => externalAssets = value)
                : null,
            title: Text(l10n.portableExportHtmlAssetsLabel),
            subtitle: Text(
              canExportAssets
                  ? l10n.portableExportHtmlAssetsHint
                  : l10n.portableExportHtmlAssetsUnavailableHint,
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.person_off_outlined),
            value: hidePersonNames,
            onChanged: (bool value) {
              setState(() => hidePersonNames = value);
            },
            title: Text(l10n.portableExportHidePersonNamesLabel),
            subtitle: Text(l10n.portableExportHidePersonNamesHint),
          ),
        ],
        notice: Column(
          spacing: 8,
          children: <Widget>[
            if (largeImages)
              AppFeedbackBanner(
                icon: Icons.image_outlined,
                message:
                    '${l10n.homeHtmlExportImageSize(DisplayFormat.formatBytesForDisplay(selectedEstimate.imageBytes))}\n${l10n.homeHtmlExportEmbeddedHint}',
                tone: AppFeedbackTone.warning,
              ),
            AppFeedbackBanner(
              icon: Icons.lock_open_outlined,
              message: l10n.portableExportPlaintextWarning,
              tone: AppFeedbackTone.warning,
            ),
          ],
        ),
      );
    },
  );

  return HtmlExportConfirmResult(
    confirmed: confirmed,
    options: HtmlExportOptions(
      externalAssets: externalAssets,
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

String _exportDates(AppLocalizations l10n, String start, String end) =>
    start == end
    ? l10n.portableExportDate(start)
    : l10n.portableExportDateRange(start, end);
