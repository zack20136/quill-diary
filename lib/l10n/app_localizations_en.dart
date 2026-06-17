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
  String get languageNameZh => '中文';

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
  String get commonUnitEntries => 'entries';

  @override
  String get commonUnitImages => 'images';

  @override
  String get commonUnitAttachments => 'attachments';

  @override
  String get commonUnitDays => 'days';

  @override
  String get commonUnitCharacters => 'chars';

  @override
  String get commonUnitMilliseconds => 'ms';

  @override
  String get commonUnitSeconds => 'sec';

  @override
  String commonGoogleAccountLabel(String name, String email) {
    return '$name · $email';
  }

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
  String get personalizationNavButtonLabel => 'Personalize';

  @override
  String get personalizationPageTitle => 'Personalize';

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
      'Write down how you feel now and let words keep the memory warm.';

  @override
  String get personalizationTypographyPreviewBodyParagraph2 =>
      'Paragraph spacing is reflected in the preview.';

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
  String get homeExportRecapLabel => 'Export';

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
  String get homeCalendarWeekdaySun => 'Sun';

  @override
  String get homeCalendarWeekdayMon => 'Mon';

  @override
  String get homeCalendarWeekdayTue => 'Tue';

  @override
  String get homeCalendarWeekdayWed => 'Wed';

  @override
  String get homeCalendarWeekdayThu => 'Thu';

  @override
  String get homeCalendarWeekdayFri => 'Fri';

  @override
  String get homeCalendarWeekdaySat => 'Sat';

  @override
  String sessionBackgroundTimeoutMinutes(int count) {
    return '$count minutes';
  }

  @override
  String sessionBackgroundTimeoutSeconds(int count) {
    return '$count seconds';
  }

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
      'Local backup/export require an unlocked vault and a recovery key. If none exists or you forgot it, import an external backup to restore.';

  @override
  String get vaultTransferDriveSectionDescriptionBackupLocked =>
      'Google Drive backup requires an unlocked vault and a recovery key. If none exists or you forgot it, you can still restore from Google Drive.';

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

  @override
  String get settingsActionConfirm => 'Confirm restore';

  @override
  String get settingsActionUpdate => 'Update';

  @override
  String get settingsActionVerifyAndRestore => 'Verify and restore';

  @override
  String get settingsRecoveryKeyFieldLabel => 'Recovery key';

  @override
  String get settingsRecoveryKeyFieldHint => 'ABCD-EFGH-IJKL-MNOP-QRST-UVWX';

  @override
  String settingsRecoveryKeyHintLine(String hint) {
    return 'Last four digits: $hint';
  }

  @override
  String get settingsBackupPhaseCreating => 'Creating backup…';

  @override
  String get settingsBackupPhaseCopying => 'Writing backup…';

  @override
  String get settingsBackupPhaseUploadingDrive => 'Uploading to Google Drive…';

  @override
  String get settingsBackupPhaseDownloadingDrive =>
      'Downloading from Google Drive…';

  @override
  String get settingsBackupPhaseRestoring =>
      'Restoring backup. Please keep the app open…';

  @override
  String get settingsBackupStartingAfterRestore =>
      'Starting the restored diary vault…';

  @override
  String get settingsPlatformSectionTitle => 'Platform limitation';

  @override
  String get settingsPlatformSectionDescription =>
      'Quill Diary currently supports Android only.';

  @override
  String get settingsSecurityLockStatusPreparing => 'Preparing…';

  @override
  String get settingsSecurityLockStatusUnlocked =>
      'Unlocked. Everything is ready to use.';

  @override
  String get settingsSecurityLockStatusFatalError =>
      'Initialization failed. Please try again later.';

  @override
  String get settingsSecurityLockUnlockingWaitHint =>
      'If it takes too long, the verification prompt may be hidden. Cancel and verify manually instead.';

  @override
  String get settingsSecurityLockCancelUnlockButton =>
      'Cancel and verify manually';

  @override
  String get settingsSecurityLockUnlockWithRecoveryButton =>
      'Unlock with recovery key';

  @override
  String get settingsSecurityLockRecoveryUnlockHint =>
      'Enter the recovery key to unlock the diary vault.';

  @override
  String get settingsSecurityLockRetryVerificationButton => 'Verify again';

  @override
  String get settingsRecoveryKeyNotSetupBanner =>
      'No recovery key yet. Create one for device migration, backup, and restore.';

  @override
  String get settingsRecoveryKeySetupBanner =>
      'Recovery key created. Make sure you have saved it securely.';

  @override
  String get settingsRecoveryKeyCreateButton => 'Create recovery key';

  @override
  String get settingsRecoveryKeyRotateButton => 'Rotate recovery key';

  @override
  String get settingsRecoveryKeyFactVaultLabel => 'Diary vault';

  @override
  String get settingsRecoveryKeyFactHintLabel => 'Last four digits';

  @override
  String get settingsRecoveryKeyFactKdfLabel => 'Encryption';

  @override
  String get settingsRecoveryKeySaveDialogTitle => 'Save your recovery key';

  @override
  String get settingsRecoveryKeySaveNewDialogTitle =>
      'Save your new recovery key';

  @override
  String get settingsRecoveryKeyCopyButton => 'Copy';

  @override
  String get settingsRecoveryKeyCopiedMessage => 'Copied to clipboard';

  @override
  String get settingsRecoveryKeyRotateDialogTitle => 'Rotate recovery key?';

  @override
  String get settingsRecoveryKeyRotateDialogBody =>
      'A new recovery key will be generated—save it immediately. Existing backups still require the old key to restore; create a new backup after rotating.';

  @override
  String get settingsSecurityOverviewSectionTitle => 'Security overview';

  @override
  String get settingsSecurityOverviewSectionDescription =>
      'Review recovery key status, unlock method, and search index health.';

  @override
  String get settingsSecurityOverviewRecoveryKeyTitle => 'Recovery key';

  @override
  String get settingsSecurityOverviewRecoveryKeyReady =>
      'Created and ready for device migration and restore.';

  @override
  String get settingsSecurityOverviewRecoveryKeyMissing =>
      'Not created yet. Create one before backing up or exporting.';

  @override
  String get settingsSecurityOverviewUnlockStatusTitle => 'Unlock status';

  @override
  String get settingsSecurityOverviewUnlockStatusUnlocked =>
      'The diary vault is currently unlocked.';

  @override
  String get settingsSecurityOverviewUnlockStatusLocked =>
      'Unlock first to back up, restore, or change settings.';

  @override
  String get settingsSecurityOverviewUnlockModeTitle => 'Unlock method';

  @override
  String get settingsSecurityOverviewTrustedDeviceTitle => 'Trusted device';

  @override
  String get settingsSecurityOverviewTrustedDeviceReady =>
      'This device is verified and can unlock quickly.';

  @override
  String get settingsSecurityOverviewTrustedDeviceMissing =>
      'This device has not been verified yet.';

  @override
  String get settingsSecurityOverviewUnlockModeNeedsRecoveryKeyMessage =>
      'Create a recovery key before configuring an unlock method.';

  @override
  String settingsSecurityOverviewUnlockModeProtectedMessage(
    String unlockModeLabel,
  ) {
    return 'This device is protected with $unlockModeLabel.';
  }

  @override
  String get settingsSecurityOverviewIndexTitle => 'Search index';

  @override
  String get settingsSecurityOverviewCreateRecoveryKeyButton =>
      'Create recovery key';

  @override
  String get settingsSecurityOverviewRotateRecoveryKeyButton =>
      'Rotate recovery key';

  @override
  String get settingsSecurityOverviewRebuildIndexButton => 'Rebuild index';

  @override
  String get settingsSecurityOverviewHealthLevelOk => 'OK';

  @override
  String get settingsSecurityOverviewHealthLevelWarning => 'Needs attention';

  @override
  String get settingsSecurityOverviewHealthLevelError => 'Error';

  @override
  String get settingsUnlockModeFullNone => 'None';

  @override
  String get settingsUnlockModeFullDeviceLock => 'Device screen lock';

  @override
  String get settingsUnlockModeFullBiometric => 'Biometric verification';

  @override
  String get settingsUnlockMethodSectionTitle => 'Unlock method';

  @override
  String settingsUnlockMethodSectionDescription(String timeoutLabel) {
    return 'The app locks after $timeoutLabel. Brief app switches usually do not trigger a lock. When you return, verify using the method below.';
  }

  @override
  String get settingsUnlockMethodNeedsRecoveryKeyBanner =>
      'Create a recovery key before configuring an unlock method.';

  @override
  String get settingsUnlockMethodSegmentNone => 'None';

  @override
  String get settingsUnlockMethodSegmentDeviceLock => 'Screen lock';

  @override
  String get settingsUnlockMethodSegmentBiometric => 'Biometric';

  @override
  String get settingsUnlockMethodBiometricNeedsDeviceLockHint =>
      'Requires a screen lock and enrolled biometrics. If verification is cancelled or fails, use the screen lock instead of the recovery key.';

  @override
  String get settingsUnlockModeChangeCancelled =>
      'Change cancelled. Unlock method unchanged.';

  @override
  String get settingsUnlockModeChangeAuthFailed =>
      'Verification failed. Unlock method unchanged.';

  @override
  String get settingsUnlockModeDescriptionNone =>
      'No extra verification after lock; unlocks immediately. Suitable for devices without a screen lock, but less secure.';

  @override
  String get settingsUnlockModeDescriptionDeviceLock =>
      'Requires screen lock verification (PIN, pattern, or password) after lock. Set up a screen lock in device settings first.';

  @override
  String get settingsUnlockModeDescriptionBiometric =>
      'Uses fingerprint or face verification after lock; on cancel/failure it falls back to screen lock.';

  @override
  String settingsSessionTimeoutBackgroundLockExplanation(String timeoutLabel) {
    return 'The app locks after $timeoutLabel; brief app switches usually do not trigger a lock.';
  }

  @override
  String settingsSessionTimeoutAboutBackgroundTimeoutBody(String timeoutLabel) {
    return 'The app locks after $timeoutLabel. Change this to 1/3/5/10 minutes in Personalization. Auto-lock pauses during backup, restore, or import/export; when returning, verify with your chosen unlock method.';
  }

  @override
  String get settingsImportExportSectionTitle => 'Import and export';

  @override
  String get settingsImportExportSectionDescriptionEnabled =>
      'Import diaries from other apps or export them as files. Supports Markdown, HTML, and Easy Diary backups.';

  @override
  String get settingsImportExportImportNoEntriesMessage =>
      'No importable diaries found. Check the file format.';

  @override
  String get settingsImportExportImportAllSkippedMessage =>
      'None of the selected files could be imported (unsupported format, empty content, or encrypted Easy Diary entries).';

  @override
  String get settingsImportExportFailureZipNoEntries =>
      'The zip contains no importable Markdown, HTML, or full Easy Diary backup.';

  @override
  String get settingsImportExportFailureEasyDiaryUnsupportedPlatform =>
      'Easy Diary backups can currently be imported on Android only.';

  @override
  String get settingsImportExportFailureEasyDiaryRealmReadFailed =>
      'Unable to read the Easy Diary backup; the version may be incompatible. Create a new backup in Easy Diary and try again.';

  @override
  String get settingsImportExportFailureEasyDiaryEmptyBackup =>
      'The Easy Diary backup contains no importable diaries.';

  @override
  String get settingsImportExportFailureEasyDiaryAllEncrypted =>
      'All diaries in the Easy Diary backup are encrypted and cannot be imported.';

  @override
  String get settingsImportExportImportProgress => 'Importing diaries…';

  @override
  String get settingsImportExportExportButton => 'Export diaries';

  @override
  String get settingsImportExportImportButton => 'Import diaries';

  @override
  String get settingsImportExportExportProgress =>
      'Exporting diaries and preparing attachments…';

  @override
  String settingsImportExportExportSuccess(String path) {
    return 'Exported: $path';
  }

  @override
  String settingsImportExportImportSuccess(int count) {
    return 'Imported $count diary entries.';
  }

  @override
  String settingsImportExportImportSuccessWithSkippedFiles(
    int count,
    int skippedFiles,
  ) {
    return 'Imported $count diary entries; $skippedFiles files could not be parsed.';
  }

  @override
  String settingsImportExportImportSuccessWithSkippedAttachments(
    int count,
    int skippedAttachments,
  ) {
    return 'Imported $count diary entries; $skippedAttachments images could not be imported.';
  }

  @override
  String settingsImportExportImportSuccessWithSkippedFilesAndAttachments(
    int count,
    int skippedFiles,
    int skippedAttachments,
  ) {
    return 'Imported $count diary entries; $skippedFiles files and $skippedAttachments images could not be imported.';
  }

  @override
  String get settingsLocalBackupSectionTitle => 'Local backup and restore';

  @override
  String get settingsLocalBackupSectionDescriptionEnabled =>
      'Create full backups stored on this device; restore overwrites current diaries. (Keeps up to 5 local backups)';

  @override
  String get settingsLocalBackupCreateButton => 'Create local backup';

  @override
  String get settingsLocalBackupRestoreButton => 'Restore from local backup';

  @override
  String get settingsLocalBackupExportToExternalButton =>
      'Export backup to folder';

  @override
  String get settingsLocalBackupImportFromExternalButton =>
      'Import external backup';

  @override
  String get settingsLocalBackupPickDialogTitle => 'Choose local backup';

  @override
  String get settingsLocalBackupPickExternalBackupDialogTitle =>
      'Choose backup zip';

  @override
  String get settingsLocalBackupNoBackups => 'No local backups yet.';

  @override
  String get settingsLocalBackupDeleteBackupTooltip => 'Delete backup';

  @override
  String get settingsLocalBackupDeleteConfirmTitle => 'Delete local backup?';

  @override
  String settingsLocalBackupBackupSuccessInApp(String fileName) {
    return 'Local backup created: $fileName';
  }

  @override
  String settingsLocalBackupBackupExportSuccess(String fileName) {
    return 'Backup exported: $fileName';
  }

  @override
  String settingsLocalBackupBackupInspectFailed(String message) {
    return 'Backup verification failed.\n$message';
  }

  @override
  String settingsLocalBackupDeleteBackupSuccess(String fileName) {
    return 'Local backup deleted: $fileName';
  }

  @override
  String settingsLocalBackupDeleteConfirmBody(String fileName) {
    return 'Delete $fileName? This will not affect your current diary vault.';
  }

  @override
  String get settingsDriveBackupSectionTitle =>
      'Google Drive backup and restore';

  @override
  String get settingsDriveBackupSectionDescriptionEnabled =>
      'Link a Google account to upload backups or restore from the cloud; restores overwrite current diaries. (Keeps up to 5 cloud backups)';

  @override
  String get settingsDriveBackupSectionDescriptionOAuthNotConfigured =>
      'Google sign-in is not configured in this build, so cloud backup is unavailable.';

  @override
  String get settingsDriveBackupLinkButton => 'Link Google account';

  @override
  String get settingsDriveBackupSwitchAccountButton => 'Switch account';

  @override
  String get settingsDriveBackupDisconnectButton => 'Disconnect';

  @override
  String get settingsDriveBackupUploadButton => 'Back up to Google Drive';

  @override
  String get settingsDriveBackupRestoreButton => 'Restore from Google Drive';

  @override
  String get settingsDriveBackupDisconnectedLabel =>
      'Google account not linked';

  @override
  String get settingsDriveBackupFallbackAccountLabel => 'Google account';

  @override
  String get settingsDriveBackupLinkSuccessEmpty =>
      'Google account linked. You can back up or restore now.';

  @override
  String settingsDriveBackupLinkSuccess(String accountLabel) {
    return 'Google account linked: $accountLabel';
  }

  @override
  String get settingsDriveBackupSwitchAccountSuccessEmpty =>
      'Google account switched.';

  @override
  String settingsDriveBackupSwitchAccountSuccess(String accountLabel) {
    return 'Switched to $accountLabel';
  }

  @override
  String get settingsDriveBackupDisconnectSuccess =>
      'Google account disconnected. Cloud backups are kept.';

  @override
  String get settingsDriveBackupDisconnectConfirmTitle =>
      'Disconnect Google account?';

  @override
  String get settingsDriveBackupDisconnectConfirmBody =>
      'You must link again to back up or restore. Backups on Google Drive are not deleted.';

  @override
  String settingsDriveBackupUploadSuccess(String fileName) {
    return 'Backed up to Google Drive: $fileName';
  }

  @override
  String settingsDriveBackupBackupInspectFailed(String message) {
    return 'Cloud backup did not complete.\n$message';
  }

  @override
  String get settingsDriveBackupNoBackups =>
      'No backups on Google Drive yet. Create one first.';

  @override
  String get settingsDriveBackupPickDialogTitle => 'Choose Google Drive backup';

  @override
  String get settingsDriveBackupUnknownCreatedTime => 'Unknown creation time';

  @override
  String get settingsDriveBackupDeleteBackupTooltip => 'Delete backup';

  @override
  String get settingsDriveBackupDeleteConfirmTitle =>
      'Delete Google Drive backup?';

  @override
  String settingsDriveBackupDeleteBackupSuccess(String fileName) {
    return 'Deleted from Google Drive: $fileName';
  }

  @override
  String settingsDriveBackupDeleteConfirmBody(String fileName) {
    return 'Delete $fileName? This will not affect your current diary vault.';
  }

  @override
  String settingsDriveBackupRestoreSuccess(String fileName) {
    return 'Restored from Google Drive: $fileName';
  }

  @override
  String get settingsRestoreDialogConfirmLocalTitle => 'Restore local backup?';

  @override
  String get settingsRestoreDialogConfirmDriveTitle =>
      'Restore from Google Drive?';

  @override
  String settingsRestoreDialogDriveFileLine(String name) {
    return 'Backup: $name';
  }

  @override
  String get settingsRestoreDialogRecoveryKeyTitle =>
      'Enter backup recovery key';

  @override
  String get settingsRestoreDialogRecoveryKeyEmptyError =>
      'Enter the recovery key.';

  @override
  String get settingsRestoreDialogRecoveryKeyVerifyNote =>
      'Restore starts only if the key is correct; a wrong key will not overwrite local data.';

  @override
  String get settingsRestoreDialogSubtitleRotatedBackup =>
      'This backup was created before the recovery key was rotated. Enter the old key saved with that backup.';

  @override
  String get settingsRestoreDialogSubtitleSameVaultManual =>
      'This device cannot auto-unlock this backup. Enter the recovery key saved when it was created.';

  @override
  String get settingsRestoreDialogSubtitleOtherVault =>
      'This backup is from another device. Enter the recovery key saved when it was created.';

  @override
  String get settingsRestoreBulletOverwriteWarning =>
      'Backup contents will overwrite local diaries. Current data cannot be recovered.';

  @override
  String get settingsRestoreBulletRebuildIndex =>
      'The search index will be rebuilt after unlock.';

  @override
  String get settingsRestoreBulletBackupWithoutRecovery =>
      'This backup has no recovery key. Create one after restore.';

  @override
  String get settingsRestoreBulletRotatedBackup =>
      'This backup was created before the recovery key rotation. After restore, enter the old recovery key saved with that backup.';

  @override
  String get settingsRestoreBulletTrustedAutoUnlock =>
      'If the backup uses the same recovery key as this device, you can usually continue without extra steps.';

  @override
  String get settingsRestoreBulletTrustedAutoUnlockFallback =>
      'If auto-unlock fails, enter the recovery key saved when this backup was created.';

  @override
  String get settingsRestoreBulletRecoveryKeyAfterRestore =>
      'After restore, enter the recovery key saved when this backup was created.';

  @override
  String get settingsRestoreBulletRewrapNote =>
      'The first unlock after restore may take longer. Keep the app open.';

  @override
  String get settingsIndexReadyMessage =>
      'You can rebuild anytime to restore search.';

  @override
  String get settingsIndexLockedMessage =>
      'Unlock to rebuild the search index.';

  @override
  String get settingsIndexLinkDriveProgress => 'Linking Google account…';

  @override
  String get settingsIndexSwitchDriveAccountProgress => 'Switching account…';

  @override
  String get settingsIndexDisconnectDriveProgress => 'Disconnecting…';

  @override
  String settingsIndexRebuildCompleted(int entryCount, String finishedAt) {
    return 'Last rebuild: $entryCount diary entries, $finishedAt.';
  }

  @override
  String settingsIndexRebuildSuccess(int entryCount, String duration) {
    return 'Search index rebuilt: $entryCount diary entries in $duration';
  }

  @override
  String get settingsSupportNavButtonLabel => 'Support';

  @override
  String get settingsSupportPageTitle => 'Support';

  @override
  String get settingsSupportHeroTitle => 'Voluntary support';

  @override
  String get settingsSupportHeroBody =>
      'Make a one-time support purchase through Google Play. It does not unlock extra features or affect diary access.';

  @override
  String get settingsSupportHeroChipNoExtraFeatures => 'No extra features';

  @override
  String get settingsSupportHeroChipRepeatablePurchase => 'Repeatable purchase';

  @override
  String get settingsSupportHeroChipGooglePlayPayment => 'Google Play payment';

  @override
  String get settingsSupportComplianceCardTitle => 'Payment and data';

  @override
  String get settingsSupportComplianceCardBody =>
      'Payments are processed by Google Play as one-time support purchases, not subscriptions. The app does not store support records or read diary content.';

  @override
  String get settingsSupportProductsSectionTitle => 'Support options';

  @override
  String get settingsSupportProductsSectionBody =>
      'Google Play shows the amount and currency based on your region. Every option can be purchased more than once.';

  @override
  String get settingsSupportBuyButtonPrefix => 'Support';

  @override
  String get settingsSupportRecommendedTierBadge => 'Popular';

  @override
  String get settingsSupportPendingMessage => 'Processing payment…';

  @override
  String get settingsSupportThanksMessage => 'Thank you for your support.';

  @override
  String get settingsSupportErrorMessage =>
      'Payment did not complete. Please try again later.';

  @override
  String get settingsSupportBillingUnavailableMessage =>
      'Google Play billing is currently unavailable. Use an Android device with the Google Play Store installed.';

  @override
  String get settingsSupportProductLoadErrorTitle =>
      'Unable to load support options';

  @override
  String get settingsSupportProductLoadErrorBody => 'Please try again later.';

  @override
  String get settingsSupportProductsNotReadyTitle =>
      'Support options are not ready';

  @override
  String get settingsSupportProductsNotReadyBody =>
      'Check your network connection. If the issue persists, update the app and try again.';

  @override
  String get settingsSupportProductsQueryFailedTitle =>
      'Cannot connect to Google Play';

  @override
  String get settingsSupportProductsQueryFailedBody =>
      'Check your network connection and try again.';

  @override
  String get settingsSupportProductsPartialMessage =>
      'Some options are temporarily unavailable. You can still choose from the remaining ones.';

  @override
  String get settingsSupportRetryLoadProductsLabel => 'Reload';

  @override
  String get settingsSupportFooterNote =>
      'Whether to support the project is entirely up to you.';

  @override
  String get settingsSupportTierSponsorCoffeeLabel =>
      'Buy the developer a coffee';

  @override
  String get settingsSupportTierSponsorCoffeeHint =>
      'Support ongoing Quill Diary development and maintenance';

  @override
  String get settingsSupportTierSponsorSnackLabel =>
      'Buy the developer a snack';

  @override
  String get settingsSupportTierSponsorSnackHint =>
      'Help Quill Diary keep improving steadily';

  @override
  String get settingsSupportTierSponsorLunchLabel => 'Buy the developer lunch';

  @override
  String get settingsSupportTierSponsorLunchHint =>
      'Help Quill Diary keep getting better';

  @override
  String get settingsSupportTierSponsorBoostLabel => 'Strong support';

  @override
  String get settingsSupportTierSponsorBoostHint =>
      'Support continuous development, maintenance, and improvement';

  @override
  String get settingsSupportTierSponsorSuperLabel => 'Super strong support';

  @override
  String get settingsSupportTierSponsorSuperHint =>
      'Help us invest in long-term development with more confidence';

  @override
  String get sessionStartupNeedsRecoveryKeyMessage =>
      'No recovery key has been created yet.';

  @override
  String get sessionStartupNeedsTrustedDeviceMessage =>
      'This device is not authorized yet. Unlock it with the recovery key.';

  @override
  String get sessionUnlockFailedMessage => 'Unlock failed. Please try again.';

  @override
  String get sessionRecoveryUnlockSuccessMessage =>
      'Unlocked with the recovery key.';

  @override
  String get sessionRecoverySetupSuccessMessage =>
      'Recovery key created. You can now configure an unlock method.';

  @override
  String get sessionAppLockedMessage => 'The app is locked.';

  @override
  String get sessionTrustedUnlockInProgressMessage =>
      'Unlocking with trusted device…';

  @override
  String get sessionLockedRetryVerificationMessage =>
      'The app is locked. Complete device verification again. No recovery key is required.';

  @override
  String get sessionRecoveryKeyRotatedMessage =>
      'Recovery key updated. Save the new key now.';

  @override
  String get sessionRecoveryRequiredAfterRestoreMessage =>
      'After restore, enter the recovery key saved when this backup was created.';

  @override
  String get sessionInvalidBackupFileMessage =>
      'Unable to read the backup file. Make sure it is intact and a valid zip backup.';

  @override
  String get sessionRestoreSuccessUnlockedMessage =>
      'Backup restored. Everything is ready to use.';

  @override
  String get sessionRestoreSuccessLockedMessage =>
      'Backup restored. Complete biometric or device-lock verification to continue.';

  @override
  String get sessionRestoreSuccessRecoveryRequiredMessage =>
      'Backup restored. Enter the recovery key saved when this backup was created.';

  @override
  String get sessionRestoreSuccessNeedsRecoveryKeySetupMessage =>
      'Backup restored. This backup does not have a recovery key yet. Create one first.';

  @override
  String get sessionRestoreStartupFailedMessage =>
      'Backup restored, but startup failed. Retry from Settings or enter the recovery key.';

  @override
  String get sessionRecoveryKeyMismatchMessage =>
      'The recovery key is incorrect. If this backup predates a key rotation, enter the old key saved with that backup.';

  @override
  String get sessionTrustedUnlockFailedAfterRestoreMessage =>
      'Automatic unlock failed after restore. Enter the recovery key saved for this backup.';

  @override
  String get sessionIndexDatabaseUnreadableMessage =>
      'The search index cannot be read and may be corrupted. Unlock with the recovery key or try restoring the backup.';

  @override
  String get sessionUnlockModeNeedsDeviceLockMessage =>
      'Set up a screen lock in device settings before using this mode.';

  @override
  String get sessionUnlockModeChangeNeedsUnlockMessage =>
      'Unlock the diary vault before changing the unlock method.';

  @override
  String get sessionBiometricNotEnrolledSwitchModeMessage =>
      'No fingerprint or face enrolled on this device. Set up biometrics in system settings, or use device screen lock instead.';

  @override
  String get sessionUseDeviceLockToUnlockMessage =>
      'Unlock with device screen lock.';

  @override
  String get sessionStartupNeedsBiometricMessage =>
      'Complete biometric verification first.';

  @override
  String get legalPrivacyEffectiveDateLabel => 'Effective date: June 6, 2026';

  @override
  String get legalChildrenPrivacyOneLiner =>
      'This app is not designed for children aged 13 or under and does not knowingly collect children\'s personal data.';

  @override
  String get legalBrandDisclaimer =>
      'The Quill Diary name, icon, and Google Play listing are author branding and are not transferred with the code license.';

  @override
  String get legalBillingVaultPrivacyNote =>
      'The support flow does not read vault contents.';

  @override
  String get legalBillingPrivacyOneLiner =>
      'Support payments are processed by Google Play as one-time purchases and unlock no extra features. The support flow does not read vault contents.';

  @override
  String get legalBillingSupportPageBody =>
      'Payments are collected only through Google Play Billing as one-time support purchases. Google processes payments; the developer does not store support records. The support flow does not read vault contents.';

  @override
  String get legalExternalLinkUnavailableMessage =>
      'Unable to open the browser. Please try again later.';

  @override
  String get settingsLegalSectionTitle => 'Legal and privacy';

  @override
  String get settingsLegalSectionDescription =>
      'View source code, privacy policy, and third-party notices on GitHub; contact us via Issues if you have questions.';

  @override
  String get settingsLegalSourceCodeTitle => 'GitHub source code';

  @override
  String get settingsLegalPrivacyPolicyTitle => 'Privacy policy';

  @override
  String get settingsLegalThirdPartyNoticesTitle => 'Third-party notices';

  @override
  String get settingsLegalContactAuthorTitle => 'Contact author';

  @override
  String get aboutPageTitle => 'About';

  @override
  String get aboutTabIntroLabel => 'Overview';

  @override
  String get aboutTabIntroHeroTitle =>
      'Keep your private diary in your own hands';

  @override
  String get aboutTabIntroHeroBody =>
      'Quill Diary is a local, encrypted diary app for personal journaling. Your data stays on your device by default; create backups or exports when needed.';

  @override
  String get aboutTabIntroChip0 => 'Data stays on device';

  @override
  String get aboutTabIntroChip1 => 'Markdown export';

  @override
  String get aboutTabIntroChip2 => 'Full-text search';

  @override
  String get aboutTabIntroChip3 => 'Full encrypted backup';

  @override
  String get aboutTabIntroChip4 => 'Portable export';

  @override
  String get aboutTabIntroSection0Title => 'Why it works well for journaling';

  @override
  String get aboutTabIntroSection0Subtitle =>
      'It is not just cloud notes with a new name. Privacy protection and everyday use are designed together.';

  @override
  String get aboutTabIntroSection0Item0Title => 'Encrypted local storage';

  @override
  String get aboutTabIntroSection0Item0Body =>
      'Entries, attachments, drafts, and the search index stay on your device under encryption or session protection. Nothing leaves the phone unless you back up or export.';

  @override
  String get aboutTabIntroSection0Item1Title => 'Start without signing up';

  @override
  String get aboutTabIntroSection0Item1Body =>
      'Daily writing works without accounts or remote servers. Use local diaries, search, and review without creating an account.';

  @override
  String get aboutTabIntroSection0Item2Title =>
      'Less collection, less distraction';

  @override
  String get aboutTabIntroSection0Item2Body =>
      'The app has no ads or tracking SDKs and does not upload diary plaintext to developer servers. Treat it as a private writing space focused on privacy.';

  @override
  String get aboutTabIntroSection1Title => 'How you can use it';

  @override
  String get aboutTabIntroSection1Subtitle =>
      'From capturing the moment to reviewing later, common features are designed around personal journaling.';

  @override
  String get aboutTabIntroSection1Item0Title =>
      'Write what you want to remember';

  @override
  String get aboutTabIntroSection1Item0Body =>
      'Supports titles, dates, tags, images, and general attachments. Start writing a new entry immediately or read before editing an existing one. Export to Markdown or HTML when needed.';

  @override
  String get aboutTabIntroSection1Item1Title =>
      'View your records from different angles';

  @override
  String get aboutTabIntroSection1Item1Body =>
      'The home screen offers list, calendar, tag, and overview views. Browse by time, revisit by date, or organize your life through tags and stats.';

  @override
  String get aboutTabIntroSection1Item2Title => 'Find what you wrote before';

  @override
  String get aboutTabIntroSection1Item2Body =>
      'After unlock, search titles, tags, and body text to revisit a memory, find a keyword, or quickly review a period of time.';

  @override
  String get aboutTabIntroSection1Item3Title =>
      'Turn reviews into shareable formats';

  @override
  String get aboutTabIntroSection1Item3Body =>
      'Create a full backup of the encrypted diary vault or export Markdown or HTML for reading, organizing, or moving content.';

  @override
  String get aboutTabIntroSection2Title => 'You stay in control of your data';

  @override
  String get aboutTabIntroSection2Subtitle =>
      'Backup, export, and unlock methods play different roles so you can keep your data and understand the risk boundaries.';

  @override
  String get aboutTabIntroSection2Item0Title =>
      'Trusted device and recovery key';

  @override
  String get aboutTabIntroSection2Item0Body =>
      'Use screen lock or biometrics for everyday access. When you change devices, restore, or lose trusted status, the recovery key is what restores access.';

  @override
  String get aboutTabIntroSection2Item1Title =>
      'Full backups preserve the encrypted vault';

  @override
  String get aboutTabIntroSection2Item1Body =>
      'A full backup preserves the entire encrypted vault for complete restore later. It is not a document you can open and read directly.';

  @override
  String get aboutTabIntroSection2Item2Title =>
      'Protect exported content yourself';

  @override
  String get aboutTabIntroSection2Item2Body =>
      'Markdown and HTML exports are good for reading, organizing, and moving content, but they are readable documents and no longer carry the same in-app encryption.';

  @override
  String get aboutTabIntroSection3Title => 'Open source and branding';

  @override
  String get aboutTabIntroSection3Subtitle =>
      'Review the source code and license terms, and understand branding boundaries clearly.';

  @override
  String get aboutTabIntroSection3Item0Title => 'Open source under AGPL-3.0';

  @override
  String get aboutTabIntroSection3Item0Body =>
      'Source code is released under GNU Affero General Public License v3.0, so product behavior and implementation can be publicly reviewed for transparency.';

  @override
  String get aboutTabIntroSection3Item1Title => 'Quill Diary branding';

  @override
  String get aboutTabUnlockSessionLabel => 'Unlock and session';

  @override
  String get aboutTabUnlockSessionHeroTitle =>
      'Balance convenience and data protection';

  @override
  String get aboutTabUnlockSessionHeroBody =>
      'Quill Diary does not make you repeat the heaviest verification every time you switch away and back, but it also does not leave an unlocked session open forever. This page explains unlock methods, auto-lock, and when a recovery key is required.';

  @override
  String get aboutTabUnlockSessionChip0 => 'Biometrics';

  @override
  String get aboutTabUnlockSessionChip1 => 'Screen lock';

  @override
  String get aboutTabUnlockSessionChip2 => 'Auto-lock';

  @override
  String get aboutTabUnlockSessionChip3 => 'Recovery key';

  @override
  String get aboutTabUnlockSessionSection0Title => 'Choosing an unlock method';

  @override
  String get aboutTabUnlockSessionSection0Subtitle =>
      'Switch modes in Settings based on your device habits and desired protection level.';

  @override
  String get aboutTabUnlockSessionSection0Item0Title => 'None';

  @override
  String get aboutTabUnlockSessionSection0Item0Body =>
      'No extra verification after lock; the app resumes immediately. Suitable when no device screen lock is set, but offers the least protection.';

  @override
  String get aboutTabUnlockSessionSection0Item1Title => 'Device screen lock';

  @override
  String get aboutTabUnlockSessionSection0Item1Body =>
      'Re-verify with PIN, pattern, or password when returning to the app. Good if you want system-level protection without relying on biometrics.';

  @override
  String get aboutTabUnlockSessionSection0Item2Title =>
      'Biometric verification';

  @override
  String get aboutTabUnlockSessionSection0Item2Body =>
      'Prefer fingerprint or face verification, with screen lock as fallback on cancel or failure. Usually the most convenient option for daily use.';

  @override
  String get aboutTabUnlockSessionSection0Item3Title => 'Shared requirements';

  @override
  String get aboutTabUnlockSessionSection0Item3Body =>
      'Screen lock and biometric modes require a device screen lock first. Biometrics must also be enrolled in system settings.';

  @override
  String get aboutTabUnlockSessionSection1Title =>
      'When re-verification happens';

  @override
  String get aboutTabUnlockSessionSection1Subtitle =>
      'Diary entries, drafts, and the search index stay available only during a valid unlocked session.';

  @override
  String get aboutTabUnlockSessionSection1Item0Title => 'While unlocked';

  @override
  String get aboutTabUnlockSessionSection1Item0Body =>
      'While unlocked, you can read and write diaries, edit drafts, attach files, and use full-text search.';

  @override
  String get aboutTabUnlockSessionSection1Item1Title => 'Background timeout';

  @override
  String get aboutTabUnlockSessionSection1Item2Title =>
      'When returning to the app';

  @override
  String get aboutTabUnlockSessionSection1Item2Body =>
      'A brief app switch usually does not trigger immediate re-verification. If the app stayed in the background longer than the timeout, your chosen mode decides whether it resumes directly or asks for system verification.';

  @override
  String get aboutTabUnlockSessionSection1Item3Title =>
      'After cancelled or failed verification';

  @override
  String get aboutTabUnlockSessionSection1Item3Body =>
      'If verification is cancelled or fails, the app stays locked without repeatedly prompting. Retry manually when convenient.';

  @override
  String get aboutTabUnlockSessionSection2Title =>
      'Why a recovery key is still needed';

  @override
  String get aboutTabUnlockSessionSection2Subtitle =>
      'Trusted devices offer convenience, but the recovery key is what truly restores access across devices and states.';

  @override
  String get aboutTabUnlockSessionSection2Item0Title =>
      'After device change or reset';

  @override
  String get aboutTabUnlockSessionSection2Item0Body =>
      'When you change phones, clear app data, or restore on another device, trusted device status usually does not carry over. The recovery key is required then.';

  @override
  String get aboutTabUnlockSessionSection2Item1Title =>
      'When trusted status expires';

  @override
  String get aboutTabUnlockSessionSection2Item1Body =>
      'If trusted status on the device expires or no longer matches the current vault state, local quick access alone is not enough.';

  @override
  String get aboutTabUnlockSessionSection2Item2Title =>
      'Ultimate access credential';

  @override
  String get aboutTabUnlockSessionSection2Item2Body =>
      'The recovery key is not optional backup trivia. It is the required credential when changing devices, restoring, or losing trusted status. Keep it safe.';

  @override
  String get aboutTabEncryptionLabel => 'Encryption and decryption';

  @override
  String get aboutTabEncryptionHeroTitle =>
      'Data is stored encrypted by default';

  @override
  String get aboutTabEncryptionHeroBody =>
      'Quill Diary protects content before writing it into the diary vault. Entries, attachments, and other sensitive data use the LDJ2 format with AES-256-GCM encryption. Only the correct trusted-device or recovery-key path can open them.';

  @override
  String get aboutTabEncryptionChip0 => 'Local encryption';

  @override
  String get aboutTabEncryptionChip1 => 'LDJ2';

  @override
  String get aboutTabEncryptionChip2 => 'AES-256-GCM';

  @override
  String get aboutTabEncryptionChip3 => 'Argon2id';

  @override
  String get aboutTabEncryptionChip4 => 'Trusted device';

  @override
  String get aboutTabEncryptionChip5 => 'Android Keystore';

  @override
  String get aboutTabEncryptionSection0Title =>
      'What this protection does for you';

  @override
  String get aboutTabEncryptionSection0Subtitle =>
      'The point is not jargon. It is knowing that stored and read data follows a clear, consistent protection flow.';

  @override
  String get aboutTabEncryptionSection0Item0Title =>
      'LDJ2 + AES-256-GCM content protection';

  @override
  String get aboutTabEncryptionSection0Item0Body =>
      'Diary entries and attachments are wrapped in LDJ2 and encrypted with AES-256-GCM. Even if you see the file itself, the content is not directly readable.';

  @override
  String get aboutTabEncryptionSection0Item1Title =>
      'Tampering should fail immediately';

  @override
  String get aboutTabEncryptionSection0Item1Body =>
      'Stored data is encrypted and integrity-checked. If content or file headers are tampered with, decryption should fail instead of silently returning suspicious data.';

  @override
  String get aboutTabEncryptionSection0Item2Title =>
      'Each file has its own key';

  @override
  String get aboutTabEncryptionSection0Item2Body =>
      'Each encrypted file gets its own random file key, then vault-level protection wraps it. Different content does not share the same file key.';

  @override
  String get aboutTabEncryptionSection1Title => 'How you open your own data';

  @override
  String get aboutTabEncryptionSection1Subtitle =>
      'Everyday and emergency paths differ, but both end in the same decryption flow.';

  @override
  String get aboutTabEncryptionSection1Item0Title => 'Trusted device';

  @override
  String get aboutTabEncryptionSection1Item0Body =>
      'On a device with trusted status, daily access usually goes through screen lock or biometrics. Android Keystore protects important vault-layer keys on this path.';

  @override
  String get aboutTabEncryptionSection1Item1Title => 'Recovery key';

  @override
  String get aboutTabEncryptionSection1Item1Body =>
      'When you change devices, restore a backup, or lose local trusted status, the recovery key restores access to the entire vault after Argon2id derivation.';

  @override
  String get aboutTabEncryptionSection1Item2Title =>
      'Verify the vault first, then open each file';

  @override
  String get aboutTabEncryptionSection1Item2Body =>
      'The flow confirms current access can enter the vault correctly before opening individual files. This avoids mistaking wrong credentials for data corruption.';

  @override
  String get aboutTabEncryptionSection2Title => 'Boundaries to understand';

  @override
  String get aboutTabEncryptionSection2Subtitle =>
      'Encryption protects the vault itself, but not every situation is automatically safe.';

  @override
  String get aboutTabEncryptionSection2Item0Title =>
      'Exports are no longer the same protection layer';

  @override
  String get aboutTabEncryptionSection2Item0Body =>
      'Once you export to Markdown or HTML, storage and sharing risks for readable documents are no longer handled by in-app encryption.';

  @override
  String get aboutTabEncryptionSection2Item1Title =>
      'Keep your recovery key safe';

  @override
  String get aboutTabEncryptionSection2Item1Body =>
      'The recovery key is essential for re-entering the vault. If it leaks, is lost, or is not stored safely, security and recoverability may be affected.';

  @override
  String get aboutTabEncryptionSection2Item2Title => 'It protects data at rest';

  @override
  String get aboutTabEncryptionSection2Item2Body =>
      'This design mainly protects encrypted data stored on the device. If the device is compromised or someone obtains an unlocked session, risk depends on more than file format alone.';

  @override
  String get aboutTabSearchIndexLabel => 'Index and search';

  @override
  String get aboutTabSearchIndexHeroTitle =>
      'Find what you wrote quickly after unlock';

  @override
  String get aboutTabSearchIndexHeroBody =>
      'Search does not reread every diary entry each time. It uses an encrypted index for faster lookup. The index opens only while unlocked so search and protection can coexist.';

  @override
  String get aboutTabSearchIndexChip0 => 'Title/body search';

  @override
  String get aboutTabSearchIndexChip1 => 'Encrypted index';

  @override
  String get aboutTabSearchIndexChip2 => 'Available while unlocked';

  @override
  String get aboutTabSearchIndexChip3 => 'Rebuildable';

  @override
  String get aboutTabSearchIndexSection0Title => 'What search helps you find';

  @override
  String get aboutTabSearchIndexSection0Subtitle =>
      'Useful when reviewing, organizing, or narrowing down a memory quickly.';

  @override
  String get aboutTabSearchIndexSection0Item0Title =>
      'Search titles, tags, and body text';

  @override
  String get aboutTabSearchIndexSection0Item0Body =>
      'Search keywords in titles, body text, and tags without scrolling through every entry.';

  @override
  String get aboutTabSearchIndexSection0Item1Title =>
      'Results come from saved entries';

  @override
  String get aboutTabSearchIndexSection0Item1Body =>
      'Search shows content formally saved to the vault, not drafts still in the editor.';

  @override
  String get aboutTabSearchIndexSection0Item2Title =>
      'The index itself is protected';

  @override
  String get aboutTabSearchIndexSection0Item2Body =>
      'Search does not build a plaintext database on the side. It uses a separate encrypted index for speed.';

  @override
  String get aboutTabSearchIndexSection1Title =>
      'Why search does not slow daily use';

  @override
  String get aboutTabSearchIndexSection1Subtitle =>
      'Lookup work goes to the index layer instead of scanning every saved entry each time.';

  @override
  String get aboutTabSearchIndexSection1Item0Title => 'Index for speed';

  @override
  String get aboutTabSearchIndexSection1Item0Body =>
      'When you type a keyword, the system queries the index instead of decrypting the whole vault entry by entry.';

  @override
  String get aboutTabSearchIndexSection1Item1Title =>
      'Updates only after formal save';

  @override
  String get aboutTabSearchIndexSection1Item1Body =>
      'The index updates only after a successful save or import so results do not mix in uncertain drafts.';

  @override
  String get aboutTabSearchIndexSection1Item2Title =>
      'Can be rebuilt when needed';

  @override
  String get aboutTabSearchIndexSection1Item2Body =>
      'The index is derived data. After format updates, backup restore, or incompatible state, it is deleted and rebuilt.';

  @override
  String get aboutTabSearchIndexSection2Title => 'How it relates to security';

  @override
  String get aboutTabSearchIndexSection2Subtitle =>
      'Useful search does not mean giving up protection boundaries.';

  @override
  String get aboutTabSearchIndexSection2Item0Title =>
      'Available only while unlocked';

  @override
  String get aboutTabSearchIndexSection2Item0Body =>
      'The search index opens only during a valid unlocked session and closes when the app locks.';

  @override
  String get aboutTabSearchIndexSection2Item1Title =>
      'Drafts are not searchable';

  @override
  String get aboutTabSearchIndexSection2Item1Body =>
      'Drafts in progress do not appear in search results, avoiding unfinished content being treated as final records.';

  @override
  String get aboutTabSearchIndexSection2Item2Title =>
      'The vault remains the source of truth';

  @override
  String get aboutTabSearchIndexSection2Item2Body =>
      'The search index helps you find content faster. It does not replace the vault, which remains the authoritative source.';

  @override
  String get aboutTabEditorLabel => 'Diary editor';

  @override
  String get aboutTabEditorHeroTitle =>
      'Writing, drafts, and formal saves follow separate paths';

  @override
  String get aboutTabEditorHeroBody =>
      'The editor does not mix still writing with formally saved content. Changes go into encrypted drafts first, then update the saved entry and search index after you confirm save, making writing safer and easier to resume.';

  @override
  String get aboutTabEditorChip0 => 'Markdown export';

  @override
  String get aboutTabEditorChip1 => 'Image attachments';

  @override
  String get aboutTabEditorChip2 => 'Auto drafts';

  @override
  String get aboutTabEditorChip3 => 'Unsaved reminders';

  @override
  String get aboutTabEditorSection0Title => 'Everyday writing features';

  @override
  String get aboutTabEditorSection0Subtitle =>
      'Built around personal records, with common organization tools in one editing flow.';

  @override
  String get aboutTabEditorSection0Item0Title =>
      'Create or edit existing entries';

  @override
  String get aboutTabEditorSection0Item0Body =>
      'New entries open directly in edit mode. Existing ones can be read first and edited when you decide to change them.';

  @override
  String get aboutTabEditorSection0Item1Title =>
      'Content, title, date, and tags';

  @override
  String get aboutTabEditorSection0Item1Body =>
      'Edit diary content while organizing title, date, time, and tags. Formal save checks required fields to avoid incomplete records. Export to Markdown when needed.';

  @override
  String get aboutTabEditorSection0Item2Title =>
      'Images and general attachments';

  @override
  String get aboutTabEditorSection0Item2Body =>
      'Add multiple images or general files and reorder images. Diaries can preserve more than text by keeping context and materials from the moment.';

  @override
  String get aboutTabEditorSection1Title => 'Draft mechanism';

  @override
  String get aboutTabEditorSection1Subtitle =>
      'Drafts are not a minor extra. They are an important protection layer in the writing experience.';

  @override
  String get aboutTabEditorSection1Item0Title => 'Changes auto-save';

  @override
  String get aboutTabEditorSection1Item0Body =>
      'After entering edit mode, changes to title, date, tags, body, or attachments auto-save as encrypted drafts to reduce loss if interrupted.';

  @override
  String get aboutTabEditorSection1Item1Title => 'Restore when reopening';

  @override
  String get aboutTabEditorSection1Item1Body =>
      'When reopening the same entry or unfinished new content, if a local draft remains, the app asks whether to continue where you left off.';

  @override
  String get aboutTabEditorSection1Item2Title =>
      'Auto cleanup after formal save';

  @override
  String get aboutTabEditorSection1Item2Body =>
      'After content is formally saved to the vault, drafts are cleared. If you cancel editing without new changes, old drafts do not pile up.';

  @override
  String get aboutTabEditorSection2Title => 'Relationship to other data';

  @override
  String get aboutTabEditorSection2Subtitle =>
      'Content being edited and formally saved content have clear boundaries.';

  @override
  String get aboutTabEditorSection2Item0Title =>
      'Drafts are excluded from search';

  @override
  String get aboutTabEditorSection2Item0Body =>
      'Search only covers formally saved vault content. Drafts do not appear in results.';

  @override
  String get aboutTabEditorSection2Item1Title =>
      'Drafts are excluded from full backup';

  @override
  String get aboutTabEditorSection2Item1Body =>
      'Full backups wrap only the formal vault, not `drafts/`. Backup and restore focus on saved data, not unfinished editing state.';

  @override
  String get aboutTabEditorSection2Item2Title => 'Unsaved indicator';

  @override
  String get aboutTabEditorSection2Item2Body =>
      'If an entry still has a local draft, list and view modes show an unsaved marker reminding you that content is not formally saved yet.';

  @override
  String get aboutTabBackupRestoreLabel => 'Backup and restore';

  @override
  String get aboutTabBackupRestoreHeroTitle =>
      'Keep the whole vault or export readable content';

  @override
  String get aboutTabBackupRestoreHeroBody =>
      'Backup and export both move data out, but for different purposes. Full backup preserves the entire encrypted vault. Markdown and HTML turn content into readable, organizable, re-importable formats. Do not mix the two flows.';

  @override
  String get aboutTabBackupRestoreChip0 => 'Full encrypted backup';

  @override
  String get aboutTabBackupRestoreChip1 => 'Google Drive';

  @override
  String get aboutTabBackupRestoreChip2 => 'Markdown';

  @override
  String get aboutTabBackupRestoreChip3 => 'HTML';

  @override
  String get aboutTabBackupRestoreSection0Title => 'When full backup fits';

  @override
  String get aboutTabBackupRestoreSection0Subtitle =>
      'If you want to preserve the entire formal vault and restore it later as-is, use full backup.';

  @override
  String get aboutTabBackupRestoreSection0Item0Title =>
      'Preserve the entire encrypted vault';

  @override
  String get aboutTabBackupRestoreSection0Item0Body =>
      '`backup_*.zip` wraps formal data in `vault/`, including entries, attachments, recovery settings, and tag directories. Content stays encrypted, not plaintext.';

  @override
  String get aboutTabBackupRestoreSection0Item1Title =>
      'Verified after creation';

  @override
  String get aboutTabBackupRestoreSection0Item1Body =>
      'Full backups are structurally verified before delivery to local storage, external folders, or Google Drive.';

  @override
  String get aboutTabBackupRestoreSection0Item2Title => 'Retention count';

  @override
  String aboutTabBackupRestoreSection0Item2Body(int retainCount) {
    return 'Local backups and Google Drive keep the latest $retainCount copies. Exports to external folders are not automatically rotated or deleted.';
  }

  @override
  String get aboutTabBackupRestoreSection1Title =>
      'What happens during restore';

  @override
  String get aboutTabBackupRestoreSection1Subtitle =>
      'Restore does not patch missing entries. It replaces the current formal vault with the backup copy.';

  @override
  String get aboutTabBackupRestoreSection1Item0Title =>
      'The formal vault is overwritten';

  @override
  String get aboutTabBackupRestoreSection1Item0Body =>
      'Whether from the in-app list or an external zip, restore overwrites the current `vault/` with backup contents.';

  @override
  String get aboutTabBackupRestoreSection1Item1Title =>
      'The search index is rebuilt';

  @override
  String get aboutTabBackupRestoreSection1Item1Body =>
      'During restore, the existing index is deleted and rebuilt from the new formal data. Re-verification may be required if trusted status cannot carry over.';

  @override
  String get aboutTabBackupRestoreSection1Item2Title =>
      'Recovery key may be required';

  @override
  String get aboutTabBackupRestoreSection1Item2Body =>
      'If trusted status on this device cannot directly match that backup, the flow asks for the recovery key saved when the backup was created.';

  @override
  String get aboutTabBackupRestoreSection2Title => 'When import and export fit';

  @override
  String get aboutTabBackupRestoreSection2Subtitle =>
      'This flow handles content exchange and reading, not replacing the entire vault.';

  @override
  String get aboutTabBackupRestoreSection2Item0Title => 'Import';

  @override
  String get aboutTabBackupRestoreSection2Item0Body =>
      'Import from zip, Markdown, HTML, or folders. For zip files, the system first checks whether the backup format is supported.';

  @override
  String get aboutTabBackupRestoreSection2Item1Title => 'Export';

  @override
  String get aboutTabBackupRestoreSection2Item1Body =>
      'Export `markdown_*.zip` from Settings, or export `html_*.html` from selected entries or overview on the home screen for readable formats.';

  @override
  String get aboutTabBackupRestoreSection2Item2Title =>
      'It is not a sync service';

  @override
  String get aboutTabBackupRestoreSection2Item2Body =>
      'Google Drive here is an optional encrypted backup destination, not a cross-device real-time diary sync service.';

  @override
  String get aboutTabBackupRestoreSection3Title => 'Things to know before use';

  @override
  String get aboutTabBackupRestoreSection3Subtitle =>
      'Backup and export both matter, but they protect different things with different responsibility boundaries.';

  @override
  String get aboutTabBackupRestoreSection3Item0Title =>
      'Full backup excludes drafts';

  @override
  String get aboutTabBackupRestoreSection3Item0Body =>
      'Full backup covers only the formal vault, not `drafts/`. Content still being edited and not formally saved is not included.';

  @override
  String get aboutTabBackupRestoreSection3Item1Title =>
      'Protect readable exports yourself';

  @override
  String get aboutTabBackupRestoreSection3Item1Body =>
      'Markdown and HTML exports are for reading, organizing, and moving content, but they are no longer in-app encrypted formats. You decide how to store them afterward.';

  @override
  String get aboutTabBackupRestoreSection3Item2Title =>
      'Do not mix the two flows';

  @override
  String get aboutTabBackupRestoreSection3Item2Body =>
      'Use full backup if you want to restore the entire vault later. Use Markdown or HTML export if you want to read or organize content outside the app.';
}
