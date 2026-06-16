// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Quill Diary';

  @override
  String get languageNameZhTw => 'Traditional Chinese';

  @override
  String get languageNameEn => 'English';

  @override
  String get commonActionCancel => 'Cancel';

  @override
  String get commonActionDelete => 'Delete';

  @override
  String get commonActionApply => 'Apply';

  @override
  String get commonActionClose => 'Close';

  @override
  String get commonReadFailureTitle => 'Read failed';

  @override
  String get commonConfirmDeleteTitle => 'Confirm delete';

  @override
  String get commonNoTagSearchResults => 'No matching tags';

  @override
  String get commonCloseTooltip => 'Close';

  @override
  String get commonClearSearchTooltip => 'Clear search';

  @override
  String commonConfirmDeleteEntries(int count) {
    return 'Delete $count diary entries? This cannot be undone.';
  }

  @override
  String get tagAddTitle => 'Add tag';

  @override
  String get tagEditTitle => 'Edit tag';

  @override
  String get tagSaveButton => 'Save';

  @override
  String get tagNameHint => 'Tag name';

  @override
  String get tagNameRequiredMessage => 'Please enter a tag name';

  @override
  String get tagDeleteLabel => 'Delete tag';

  @override
  String get tagUnnamedPreview => 'Untitled tag';

  @override
  String get tagDefaultColorLabel => 'Default color';

  @override
  String get tagHueLabel => 'Hue';

  @override
  String get tagPreviewLabel => 'Preview';

  @override
  String tagSaveFailure(String message) {
    return 'Failed to save tag: $message';
  }

  @override
  String tagDeleteFailure(String message) {
    return 'Failed to delete tag: $message';
  }

  @override
  String get personalizationNavButtonLabel => 'Personalization';

  @override
  String get personalizationPageTitle => 'Personalization';

  @override
  String get personalizationLoadErrorMessage =>
      'Unable to load personalization settings.';

  @override
  String get personalizationTypographyResetButton => 'Reset';

  @override
  String get personalizationTypographyResetConfirmTitle =>
      'Reset diary typography?';

  @override
  String get personalizationTypographyResetConfirmBody =>
      'This resets the title and body font size, line height, and paragraph spacing to their defaults.';

  @override
  String get personalizationTypographyResetConfirmAction => 'Reset';

  @override
  String get personalizationTypographyResetSuccess =>
      'Diary typography has been reset.';

  @override
  String get personalizationLanguageSectionTitle => 'Language';

  @override
  String get personalizationLanguageSectionDescription =>
      'Choose the interface language.';

  @override
  String get personalizationLanguageComingSoonHint =>
      'Some English translations are still in progress.';

  @override
  String get personalizationSessionTimeoutSectionTitle => 'Auto lock';

  @override
  String get personalizationSessionTimeoutSectionDescription =>
      'Require verification again after the app stays in the background for a while.';

  @override
  String get personalizationSessionTimeoutUnitLabel => 'min';

  @override
  String get personalizationImageCompressSectionTitle => 'Image quality';

  @override
  String get personalizationImageCompressSectionDescription =>
      'Adjust the default compression when inserting images in the editor.';

  @override
  String get personalizationImageCompressOriginalLabel => 'Original';

  @override
  String get personalizationImageCompressStandardLabel => 'Standard';

  @override
  String get personalizationImageCompressHighLabel => 'High';

  @override
  String get personalizationAppearanceSectionTitle => 'Theme';

  @override
  String get personalizationAppearanceSectionDescription =>
      'Choose light, dark, or follow the system appearance.';

  @override
  String get personalizationAppearanceSystemLabel => 'System';

  @override
  String get personalizationAppearanceLightLabel => 'Light';

  @override
  String get personalizationAppearanceDarkLabel => 'Dark';

  @override
  String get personalizationTypographySectionTitle => 'Diary typography';

  @override
  String get personalizationTypographySectionDescription =>
      'Adjust the font size, line height, and paragraph spacing used in diary editing and preview.';

  @override
  String get personalizationTitleFontSizeLabel => 'Title font size';

  @override
  String get personalizationTitleLineHeightLabel => 'Title line height';

  @override
  String get personalizationBodyFontSizeLabel => 'Body font size';

  @override
  String get personalizationBodyLineHeightLabel => 'Body line height';

  @override
  String get personalizationBodyParagraphSpacingLabel =>
      'Body paragraph spacing';

  @override
  String get settingsPageTitle => 'Settings';

  @override
  String get settingsProgressDefault => 'Working…';

  @override
  String get personalizationImageCompressOriginalDescription =>
      'Keep the original resolution and file size with no compression. Best when you want maximum image quality and can accept a larger vault.';

  @override
  String get personalizationImageCompressStandardDescription =>
      'Resize the long edge to 1280 px with JPEG quality 70. Balanced for clarity and storage size (default).';

  @override
  String get personalizationImageCompressHighDescription =>
      'Resize the long edge to 1920 px with JPEG quality 85. Larger files, but more detail is preserved.';

  @override
  String personalizationFontSizeValue(String size) {
    return '$size pt';
  }

  @override
  String personalizationLineHeightValue(String height) {
    return '${height}x';
  }

  @override
  String personalizationParagraphSpacingValue(String spacing) {
    return '$spacing px';
  }

  @override
  String get personalizationTypographyPreviewTitleParagraph1 =>
      'A small good thing today: the sunlight landed perfectly on the desk. A moment worth keeping, so I wrote it down first.';

  @override
  String get personalizationTypographyPreviewBodyParagraph1 =>
      'Write down how you feel right now, and let words keep the memory warm. Write down how you feel right now, and let words keep the memory warm.';

  @override
  String get personalizationTypographyPreviewBodyParagraph2 =>
      'The spacing between paragraphs is also reflected in the preview. The spacing between paragraphs is also reflected in the preview.';

  @override
  String get sessionBlockedLockedTitle => 'Diary vault locked';

  @override
  String get sessionBlockedRecoveryRequiredTitle => 'Recovery key required';

  @override
  String get sessionBlockedFatalErrorTitle => 'Unable to start';

  @override
  String get sessionBlockedDefaultTitle => 'Please wait';

  @override
  String get sessionBlockedLockedSubtitle =>
      'Complete verification to continue';

  @override
  String get sessionBlockedRecoveryRequiredSubtitle =>
      'Enter the recovery key to unlock';

  @override
  String get sessionBlockedFatalErrorSubtitle =>
      'Check your setup or restart the app';

  @override
  String get editorPageTitle => 'Edit diary';

  @override
  String get editorTitleHint => 'Enter a title';

  @override
  String get editorTitleRequiredError => 'Please enter a title';

  @override
  String get editorBodyHint => 'Write here…';

  @override
  String get editorBodyEmptyPreview => 'No content yet';

  @override
  String get editorNeedsRecoveryKeyMessage =>
      'Create a recovery key before creating or editing diaries.';

  @override
  String get editorSessionLockedFallback =>
      'Unlock the diary vault again to continue.';

  @override
  String get editorSaveNeedsTitleMessage => 'Enter a title before saving';

  @override
  String get editorUnsavedDraftLabel => 'Unsaved';

  @override
  String get editorConfirmDeleteTitle => 'Confirm delete';

  @override
  String get editorConfirmDeleteBody =>
      'Delete this diary entry? This cannot be undone.';

  @override
  String get editorTagsStudioTitle => 'Tags';

  @override
  String get editorTagsStudioGuide =>
      'Create a new tag from the top right, or tap a library tag below to add it.';

  @override
  String get editorTagsStudioEmptyChosen => 'No tags applied yet';

  @override
  String get editorTagsStudioAddButton => 'Add';

  @override
  String get editorPreviewUnavailable => 'Preview unavailable';

  @override
  String get editorTagSearchHint => 'Search tags…';

  @override
  String get editorTagLibraryHint => 'Tags in library · tap to add';

  @override
  String get editorTagPoolEmpty =>
      'No more available tags in the library, or all have already been added.';

  @override
  String get editorTagAddTooltip => 'Add tag';

  @override
  String get editorTooltipCancel => 'Cancel';

  @override
  String get editorTooltipSave => 'Save';

  @override
  String get editorTooltipSaveNeedsTitle => 'Enter a title first';

  @override
  String get editorTooltipDate => 'Date';

  @override
  String get editorTooltipTime => 'Time';

  @override
  String get editorTooltipEditTags => 'Edit tags';

  @override
  String get editorTooltipUploadImages =>
      'Upload images (multiple selection supported)';

  @override
  String get editorTooltipAddAttachment => 'Add attachment';

  @override
  String get editorTooltipDelete => 'Delete';

  @override
  String get editorTooltipEdit => 'Edit';

  @override
  String get editorRestoreDraftTitle => 'Unfinished draft found';

  @override
  String get editorRestoreDraftDecline => 'Ignore';

  @override
  String get editorRestoreDraftAccept => 'Restore draft';

  @override
  String get editorUntitledDraft => 'Untitled';

  @override
  String editorRestoreDraftOverwrite(String title, String savedAt) {
    return 'Draft: $title\nLast saved: $savedAt\n\nRestoring it will replace the content you are currently viewing.';
  }

  @override
  String editorRestoreDraftPrompt(String title, String savedAt) {
    return 'Draft: $title\nLast saved: $savedAt\n\nRestore this draft?';
  }

  @override
  String get editorDiscardDraftTitle => 'Discard draft?';

  @override
  String get editorDiscardDraftBody =>
      'Your changes have not been saved as a diary entry. Discard the draft and leave?';

  @override
  String get editorDiscardDraftConfirm => 'Discard';

  @override
  String get editorGalleryDownloadTooltip => 'Download';

  @override
  String get editorGalleryDownloadFailed => 'Unable to download image';

  @override
  String editorGalleryDownloadSuccess(String path) {
    return 'Saved to $path';
  }

  @override
  String get homeUnlockingTitle => 'Unlocking';

  @override
  String get homeRetryVerification => 'Verify again';

  @override
  String get homeGoToSettings => 'Go to settings';

  @override
  String get homeNavHome => 'Home';

  @override
  String get homeNavCalendar => 'Calendar';

  @override
  String get homeNavTags => 'Tags';

  @override
  String get homeNavOverview => 'Overview';

  @override
  String get homeTooltipNewEntry => 'New diary';

  @override
  String get homeTooltipSettings => 'Settings and backup';

  @override
  String get homeTooltipExportHtml => 'Export HTML';

  @override
  String get homeTooltipDelete => 'Delete';

  @override
  String get homeTooltipAddTag => 'Add tag';

  @override
  String get homeTooltipEditTag => 'Edit tag';

  @override
  String get homeTooltipDeleteTag => 'Delete tag';

  @override
  String get homeTooltipDeselectTag => 'Clear selection';

  @override
  String get homeSelectionSelectAll => 'Select all';

  @override
  String get homeSelectionDeselectAll => 'Deselect all';

  @override
  String get homeSelectionSelectDiary => 'Select diary';

  @override
  String homeSelectionSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String get homeSearchHint => 'Search titles, content, or tags';

  @override
  String get homeEmptyDiaryTitle => 'No diary entries yet';

  @override
  String get homeEmptyDiaryMessage =>
      'Create your first diary entry to see it here.';

  @override
  String get homeNoAnalysisTitle => 'No data to analyze yet';

  @override
  String get homeNoAnalysisMessage =>
      'Write something first to see stats, tags, and scoped diary entries here.';

  @override
  String get homeExportRecapLabel => 'Export recap';

  @override
  String get homeExportRecapAll => 'Export full recap';

  @override
  String get homeExportRecapYear => 'Export yearly recap';

  @override
  String get homeExportRecapMonth => 'Export monthly recap';

  @override
  String get homePopularTagsTitle => 'Popular tags';

  @override
  String get homeScopeTitle => 'Scope';

  @override
  String get homeScopeAllLabel => 'All';

  @override
  String get homeScopeYearLabel => 'Year';

  @override
  String get homeScopeMonthLabel => 'Month';

  @override
  String get homeScopeEmptyDiary => 'No diary entries in this scope.';

  @override
  String homeScopeEmptyDiaryForTag(String tag) {
    return 'No diary entries with \"$tag\" in this scope.';
  }

  @override
  String get homeScopeEmptyTags => 'No tags in this scope.';

  @override
  String get homeUnsavedDraftLabel => 'Unsaved';

  @override
  String get homeHtmlExportLargeTitle => 'HTML file may be large';

  @override
  String get homeHtmlExportEmbeddedHint =>
      'Images are embedded into a single HTML file, which may be slower to open or harder to share.';

  @override
  String get homeHtmlExportProceed => 'Export anyway';

  @override
  String homeHtmlExportSelectionSummary(
    String entrySummary,
    String imageSummary,
  ) {
    return '$entrySummary selected, including $imageSummary.';
  }

  @override
  String homeHtmlExportImageSize(String size) {
    return 'Original image size: about $size';
  }

  @override
  String homeHtmlExportEstimatedSize(String size) {
    return 'Estimated HTML size: about $size';
  }

  @override
  String homeHtmlExportSuccess(String fileName) {
    return 'HTML exported: $fileName';
  }

  @override
  String get homeDeleteTagTitle => 'Delete tag';

  @override
  String homeDeleteTagConfirm(String label) {
    return 'Remove \"$label\" from all diary entries?';
  }

  @override
  String get homeTagSearchHint => 'Search tags…';

  @override
  String get homeNoTagsTitle => 'No tags yet';

  @override
  String get homeNoTagsMessage =>
      'Create your own tags or use the defaults. They stay in the list even if no diary entry uses them yet.';

  @override
  String get homeTagListGuide =>
      'Tap a row in the tag list to preview diary entries filtered by that tag. Tap the same row again to clear the selection.';

  @override
  String get homeTagPreviewTitle => 'Select a tag to preview diaries';

  @override
  String homeTagDeleted(String label) {
    return '\"$label\" deleted';
  }

  @override
  String homeTagRemovedFromEntries(String entrySummary, String label) {
    return 'Removed \"$label\" from $entrySummary.';
  }

  @override
  String homeTagIndexEmptyForTag(String tag) {
    return 'No indexed items found with \"$tag\".';
  }

  @override
  String homeTagRowEntryCount(String entrySummary) {
    return '$entrySummary';
  }

  @override
  String get homeTagRowTapHint => 'Tap row to preview';

  @override
  String homeDiarySectionTitleForDate(String dateLabel) {
    return 'Diary · $dateLabel';
  }

  @override
  String homeEmptyDayMessage(String dateLabel) {
    return 'No diary entries on $dateLabel.';
  }

  @override
  String get homeOverviewDataTitle => 'Data overview';

  @override
  String get homeOverviewScopeAll => 'Current scope · All diaries';

  @override
  String homeOverviewScopeYear(int year) {
    return 'Current scope · $year';
  }

  @override
  String homeOverviewScopeMonth(int year, int month) {
    return 'Current scope · $year/$month';
  }

  @override
  String get homeOverviewWritingDaysLabel => 'Writing days';

  @override
  String get homeOverviewAvgLengthLabel => 'Average length';

  @override
  String get homeOverviewAttachmentsLabel => 'Total attachments';

  @override
  String homeOverviewAttachmentCount(String attachmentSummary) {
    return '$attachmentSummary';
  }

  @override
  String homeOverviewLongestStreak(String daySummary) {
    return 'Longest streak $daySummary';
  }

  @override
  String homeOverviewEntryStats(String entrySummary, String characterSummary) {
    return '$entrySummary\n$characterSummary total';
  }

  @override
  String homeDiarySectionTag(String tag) {
    return 'Diary · $tag';
  }

  @override
  String get homeDiarySectionAll => 'Diary · All';

  @override
  String get homeDiarySectionByYear => 'Diary · By year';

  @override
  String get homeDiarySectionByMonth => 'Diary · By month';

  @override
  String homeDiarySectionWithTag(String baseTitle, String tag) {
    return '$baseTitle · $tag';
  }

  @override
  String get homeCalendarMonthFormatLabel => 'Month';

  @override
  String homeOverviewAvgLengthValue(int charactersPerEntry) {
    return '$charactersPerEntry chars / entry';
  }

  @override
  String homeOverviewAttachmentDetail(int photos, int files) {
    return 'Photos $photos · Files $files';
  }

  @override
  String homeOverviewMostEntriesInSingleDay(String entrySummary) {
    return 'Max in one day $entrySummary';
  }

  @override
  String get vaultTransferNeedsUnlockForBackup =>
      'Unlock the diary vault before backing up or exporting.';

  @override
  String get vaultTransferNeedsRecoveryKeyForBackup =>
      'Create a recovery key before backing up or exporting.';

  @override
  String get vaultTransferNeedsUnlockForRestore =>
      'Unlock the diary vault before restoring a backup.';

  @override
  String get vaultTransferLocalSectionDescriptionBackupLocked =>
      'Local backup and export require an unlocked vault and a recovery key. If you have not created one or forgot it, you can still import an external backup to restore.';

  @override
  String get vaultTransferDriveSectionDescriptionBackupLocked =>
      'Backing up to Google Drive requires an unlocked vault and a recovery key. If you have not created one or forgot it, you can still restore directly from Google Drive.';

  @override
  String get vaultTransferDriveBackupActionsLockedHint =>
      'Unlock the diary vault and create a recovery key before backing up to Google Drive.';

  @override
  String get vaultTransferRestoreUnlockFailed =>
      'The backup was restored, but unlocking with the recovery key failed. Enter the recovery key again in Security Overview.';

  @override
  String get androidSafWriteFailed =>
      'Unable to write the file to the selected folder.';

  @override
  String androidSafWriteFailedWithCode(String code) {
    return 'Unable to write the file to the selected folder ($code).';
  }

  @override
  String get defaultTagDaily => 'Daily';

  @override
  String get defaultTagMood => 'Mood';

  @override
  String get defaultTagReflection => 'Reflection';

  @override
  String get defaultTagPlanning => 'Plan';

  @override
  String get defaultTagWork => 'Work';

  @override
  String get defaultTagStudy => 'Study';

  @override
  String get defaultTagFamily => 'Family';

  @override
  String get defaultTagFriends => 'Friends';

  @override
  String get defaultTagTravel => 'Travel';

  @override
  String get defaultTagFood => 'Food';

  @override
  String get defaultTagEntertainment => 'Entertainment';

  @override
  String get defaultTagExercise => 'Exercise';

  @override
  String get defaultTagHealth => 'Health';

  @override
  String get defaultTagShopping => 'Shopping';
}
