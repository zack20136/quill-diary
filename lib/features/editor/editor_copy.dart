import '../../infrastructure/storage/user_export_paths.dart';
import '../../l10n/l10n.dart';

/// 編輯器相關的繁體中文 UI 文案。
abstract final class EditorCopy {
  static AppLocalizations _l10n(BuildContext context) => context.l10n;

  static String pageTitle(BuildContext context) => _l10n(context).editorPageTitle;
  static String titleHint(BuildContext context) => _l10n(context).editorTitleHint;
  static String titleRequiredError(BuildContext context) => _l10n(context).editorTitleRequiredError;
  static String bodyHint(BuildContext context) => _l10n(context).editorBodyHint;
  static String bodyEmptyPreview(BuildContext context) => _l10n(context).editorBodyEmptyPreview;
  static String needsRecoveryKeyMessage(BuildContext context) =>
      _l10n(context).editorNeedsRecoveryKeyMessage;
  static String sessionLockedFallback(BuildContext context) =>
      _l10n(context).editorSessionLockedFallback;
  static String saveNeedsTitleMessage(BuildContext context) =>
      _l10n(context).editorSaveNeedsTitleMessage;
  static String unsavedDraftLabel(BuildContext context) => _l10n(context).editorUnsavedDraftLabel;

  static String confirmDeleteTitle(BuildContext context) => _l10n(context).editorConfirmDeleteTitle;
  static String confirmDeleteBody(BuildContext context) => _l10n(context).editorConfirmDeleteBody;

  static String tagsStudioTitle(BuildContext context) => _l10n(context).editorTagsStudioTitle;
  static String tagsStudioGuide(BuildContext context) => _l10n(context).editorTagsStudioGuide;
  static String tagsStudioEmptyChosen(BuildContext context) =>
      _l10n(context).editorTagsStudioEmptyChosen;
  static String tagsStudioAddButton(BuildContext context) => _l10n(context).editorTagsStudioAddButton;
  static String previewUnavailable(BuildContext context) => _l10n(context).editorPreviewUnavailable;

  static String tagSearchHint(BuildContext context) => _l10n(context).editorTagSearchHint;
  static String tagLibraryHint(BuildContext context) => _l10n(context).editorTagLibraryHint;
  static String tagPoolEmpty(BuildContext context) => _l10n(context).editorTagPoolEmpty;
  static String tagAddTooltip(BuildContext context) => _l10n(context).editorTagAddTooltip;

  static String tooltipCancel(BuildContext context) => _l10n(context).editorTooltipCancel;
  static String tooltipSave(BuildContext context) => _l10n(context).editorTooltipSave;
  static String tooltipSaveNeedsTitle(BuildContext context) =>
      _l10n(context).editorTooltipSaveNeedsTitle;
  static String tooltipDate(BuildContext context) => _l10n(context).editorTooltipDate;
  static String tooltipTime(BuildContext context) => _l10n(context).editorTooltipTime;
  static String tooltipEditTags(BuildContext context) => _l10n(context).editorTooltipEditTags;
  static String tooltipUploadImages(BuildContext context) =>
      _l10n(context).editorTooltipUploadImages;
  static String tooltipAddAttachment(BuildContext context) =>
      _l10n(context).editorTooltipAddAttachment;
  static String tooltipDelete(BuildContext context) => _l10n(context).editorTooltipDelete;
  static String tooltipEdit(BuildContext context) => _l10n(context).editorTooltipEdit;

  static String restoreDraftTitle(BuildContext context) => _l10n(context).editorRestoreDraftTitle;
  static String restoreDraftDecline(BuildContext context) => _l10n(context).editorRestoreDraftDecline;
  static String restoreDraftAccept(BuildContext context) => _l10n(context).editorRestoreDraftAccept;
  static String untitledDraft(BuildContext context) => _l10n(context).editorUntitledDraft;

  static String restoreDraftOverwrite(BuildContext context, String title, String savedAt) =>
      _l10n(context).editorRestoreDraftOverwrite(title, savedAt);

  static String restoreDraftPrompt(BuildContext context, String title, String savedAt) =>
      _l10n(context).editorRestoreDraftPrompt(title, savedAt);

  static String discardDraftTitle(BuildContext context) => _l10n(context).editorDiscardDraftTitle;
  static String discardDraftBody(BuildContext context) => _l10n(context).editorDiscardDraftBody;
  static String discardDraftConfirm(BuildContext context) =>
      _l10n(context).editorDiscardDraftConfirm;

  static String galleryDownloadTooltip(BuildContext context) =>
      _l10n(context).editorGalleryDownloadTooltip;
  static String galleryDownloadFailed(BuildContext context) =>
      _l10n(context).editorGalleryDownloadFailed;
  static String galleryDownloadSuccess(BuildContext context, String fileName) =>
      _l10n(context).editorGalleryDownloadSuccess(UserExportPaths.picturesDisplayPath(fileName));
}
