// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get commonMoreActions => 'More actions';

  @override
  String get appTitle => 'Quill Diary';

  @override
  String get languageNameZh => '繁體中文';

  @override
  String get languageNameEn => 'English';

  @override
  String get commonActionCancel => 'Cancel';

  @override
  String get commonActionDelete => 'Delete';

  @override
  String get commonActionApply => 'Apply';

  @override
  String get commonActionConfirm => 'OK';

  @override
  String get commonActionClose => 'Close';

  @override
  String get commonReadFailureTitle => 'Read Failed';

  @override
  String get commonConfirmDeleteTitle => 'Confirm Delete';

  @override
  String get commonNoTagSearchResults => 'No Matching Tags';

  @override
  String get commonCloseTooltip => 'Close';

  @override
  String get commonClearSearchTooltip => 'Clear Search';

  @override
  String get commonUnitEntries => 'entries';

  @override
  String get commonUnitTags => 'tags';

  @override
  String get commonUnitAttachments => 'atts.';

  @override
  String get commonUnitDays => 'days';

  @override
  String get commonUnitCharacters => 'chars';

  @override
  String get commonUnitMilliseconds => 'ms';

  @override
  String get commonUnitSeconds => 'sec';

  @override
  String get commonRelativeToday => 'today';

  @override
  String get commonRelativeYesterday => 'yesterday';

  @override
  String commonRelativeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String get userFacingErrorDefaultMessage =>
      'The operation failed. Please try again later.';

  @override
  String get userFacingErrorLocalPathLabel => 'local path';

  @override
  String commonGoogleAccountLabel(String name, String email) {
    return '$name · $email';
  }

  @override
  String commonConfirmDeleteEntries(int count) {
    return 'Delete $count entries? This cannot be undone.';
  }

  @override
  String get tagAddTitle => 'Add Tag';

  @override
  String get tagEditTitle => 'Edit Tag';

  @override
  String get tagSaveButton => 'Save';

  @override
  String get tagNameHint => 'Tag Name';

  @override
  String get tagNameRequiredMessage => 'Please enter a tag name';

  @override
  String get tagDeleteLabel => 'Delete Tag';

  @override
  String get tagUnnamedPreview => 'Untitled Tag';

  @override
  String get tagDefaultColorLabel => 'Default Color';

  @override
  String get tagCustomColorLabel => 'Custom color';

  @override
  String get tagCustomColorDialogTitle => 'Pick a custom color';

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
      'Reset Entry Typography?';

  @override
  String get personalizationTypographyResetConfirmBody =>
      'This resets the title and body font size, line height, and paragraph spacing to their defaults.';

  @override
  String get personalizationTypographyResetConfirmAction => 'Reset';

  @override
  String get personalizationTypographyResetSuccess =>
      'Entry typography has been reset.';

  @override
  String get personalizationLanguageSectionTitle => 'Language';

  @override
  String get personalizationLanguageSectionDescription =>
      'Choose the interface language.';

  @override
  String get personalizationSessionTimeoutSectionTitle => 'Auto-Lock';

  @override
  String get personalizationSessionTimeoutSectionDescription =>
      'Require verification again after the app stays in the background for a while.';

  @override
  String get personalizationSessionTimeoutUnitLabel => 'min';

  @override
  String get personalizationImageCompressSectionTitle => 'Image Quality';

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
  String get personalizationAppearanceSectionTitle => 'Appearance';

  @override
  String get personalizationAppearanceSectionDescription =>
      'Choose light, dark, or system appearance.';

  @override
  String get personalizationAppearanceSystemLabel => 'System';

  @override
  String get personalizationAppearanceLightLabel => 'Light';

  @override
  String get personalizationAppearanceDarkLabel => 'Dark';

  @override
  String get personalizationTypographySectionTitle => 'Entry Typography';

  @override
  String get personalizationTypographySectionDescription =>
      'Adjust the font size, line height, and paragraph spacing used when editing and previewing entries.';

  @override
  String get personalizationTitleFontSizeLabel => 'Title Font Size';

  @override
  String get personalizationTitleLineHeightLabel => 'Title Line Height';

  @override
  String get personalizationBodyFontSizeLabel => 'Body Font Size';

  @override
  String get personalizationBodyLineHeightLabel => 'Body Line Height';

  @override
  String get personalizationBodyParagraphSpacingLabel =>
      'Body Paragraph Spacing';

  @override
  String get settingsPageTitle => 'Settings';

  @override
  String get settingsProgressDefault => 'Working…';

  @override
  String get settingsProgressWorkingTitle => 'Working';

  @override
  String get settingsProgressKeepAppOpenHint => 'Please keep the app open';

  @override
  String settingsProgressPercent(int percent) {
    return '$percent%';
  }

  @override
  String settingsProgressSemanticDeterminate(
    String title,
    String stage,
    int percent,
  ) {
    return '$title. $stage. Progress $percent%';
  }

  @override
  String settingsProgressSemanticIndeterminate(String title, String stage) {
    return '$title. $stage. Progress unavailable';
  }

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
      'Write down how you feel now and let words keep the memory warm. Write down how you feel now and let words keep the memory warm.';

  @override
  String get personalizationTypographyPreviewBodyParagraph2 =>
      'Paragraph spacing is also reflected in the preview. Paragraph spacing is also reflected in the preview.';

  @override
  String get sessionBlockedLockedTitle => 'Diary Vault Locked';

  @override
  String get sessionBlockedRecoveryRequiredTitle => 'Recovery Key Required';

  @override
  String get sessionBlockedFatalErrorTitle => 'Unable to Start';

  @override
  String get sessionBlockedDefaultTitle => 'Please Wait';

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
  String get sessionUnsupportedRuntimeMessage =>
      'Quill Diary currently supports Android only.';

  @override
  String get editorPageTitle => 'Edit Entry';

  @override
  String get editorTitleHint => 'Enter a title';

  @override
  String get editorEntryRequiredError => 'Please enter a title or body';

  @override
  String get editorBodyHint => 'Write here…';

  @override
  String get editorCheckboxDragTooltip => 'Drag to reorder';

  @override
  String get editorBodyEmptyPreview => 'No content yet';

  @override
  String get editorNeedsRecoveryKeyMessage =>
      'Create a recovery key before creating or editing entries.';

  @override
  String get editorSessionLockedFallback =>
      'Unlock the diary vault again to continue.';

  @override
  String get editorSaveNeedsEntryMessage =>
      'Enter a title or body before saving';

  @override
  String get editorUnsavedDraftLabel => 'Unsaved';

  @override
  String get editorConfirmDeleteTitle => 'Confirm Delete';

  @override
  String get editorConfirmDeleteBody =>
      'Delete this entry? This cannot be undone.';

  @override
  String get editorTagsStudioTitle => 'Tags';

  @override
  String get editorTagsStudioGuide =>
      'Create a new tag from the top right, or tap a tag from the library below to add it.';

  @override
  String get editorTagsStudioEmptyChosen => 'No tags applied yet';

  @override
  String get editorTagsStudioAddButton => 'Add';

  @override
  String get editorPreviewUnavailable => 'Preview Unavailable';

  @override
  String get editorTagSearchHint => 'Search tags…';

  @override
  String get editorTagLibraryHint => 'Tag Library · Tap to Add';

  @override
  String get editorTagPoolEmpty =>
      'No more available tags in the library, or all have already been added.';

  @override
  String get editorTagAddTooltip => 'Add Tag';

  @override
  String get editorTooltipCancel => 'Cancel';

  @override
  String get editorTooltipSave => 'Save';

  @override
  String get editorTooltipSaveNeedsEntry => 'Enter a Title or Body First';

  @override
  String get editorTooltipDate => 'Set Date';

  @override
  String get editorTooltipTime => 'Set Time';

  @override
  String get editorTooltipEditTags => 'Edit Tags';

  @override
  String get editorTooltipUploadImages => 'Upload Images';

  @override
  String get editorTooltipAddAttachment => 'Add Attachment';

  @override
  String get editorTooltipInsertCheckbox => 'Insert Task Item';

  @override
  String get editorTooltipDelete => 'Delete';

  @override
  String get editorTooltipEdit => 'Edit';

  @override
  String editorAttachmentImagesLabel(int count) {
    return 'Images $count';
  }

  @override
  String editorAttachmentFilesLabel(int count) {
    return 'Attachments $count';
  }

  @override
  String get editorAttachmentPendingLabel => 'New';

  @override
  String get editorAttachmentDragTooltip => 'Long-press and drag to reorder';

  @override
  String get editorRestoreDraftTitle => 'Unfinished Draft Found';

  @override
  String get editorRestoreDraftDecline => 'Ignore';

  @override
  String get editorRestoreDraftAccept => 'Restore Draft';

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
  String get editorDiscardDraftTitle => 'Discard Draft?';

  @override
  String get editorDiscardDraftBody =>
      'Your changes have not been saved as an entry. Discard the draft and leave?';

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
  String get homeRetryVerification => 'Verify Again';

  @override
  String get homeGoToSettings => 'Go to Settings';

  @override
  String get homeNavHome => 'Home';

  @override
  String get homeNavCalendar => 'Calendar';

  @override
  String get homeNavTags => 'Tags';

  @override
  String get homeNavPeople => 'People';

  @override
  String get homeNavOverview => 'Overview';

  @override
  String get homePopularPeopleTitle => 'Top people';

  @override
  String get peopleEmptyTitle => 'No people yet';

  @override
  String get peopleEmptyBody =>
      'After you add people, diary mentions are analyzed by name and alias. In the editor, @ inserts that person\'s chosen diary name (the main name by default, or an alias you pick).';

  @override
  String get peopleNotFoundTitle => 'Person not found';

  @override
  String get peopleNotFoundMessage =>
      'This person may have been deleted, or could not be loaded from the current data.';

  @override
  String get peopleSearchHint => 'Search name or alias';

  @override
  String get peopleSearchNoResultsTitle => 'No matching people';

  @override
  String get peopleSearchNoResultsMessage =>
      'Try different keywords, or adjust the relationship filters.';

  @override
  String get peopleCreateAction => 'Add person';

  @override
  String get peopleManageRelationshipsTooltip => 'Manage relationships';

  @override
  String get peopleManageRelationshipsTitle => 'Manage relationships';

  @override
  String get peopleManageRelationshipsGuide =>
      'Drag the handle to reorder. Tap a name to rename. New names are saved for the current language and copied to the other language.';

  @override
  String get peopleReorderRelationshipTooltip => 'Drag to reorder';

  @override
  String get peopleManageRelationshipsEmpty => 'No relationship types yet';

  @override
  String get peopleAddRelationshipHint => 'e.g. Mentor';

  @override
  String get peopleAddRelationshipAction => 'Add';

  @override
  String get peopleRenameRelationshipAction => 'Rename';

  @override
  String get peopleDeleteRelationshipAction => 'Delete';

  @override
  String get peopleRelationshipNameEmpty => 'Relationship name cannot be empty';

  @override
  String get peopleRelationshipNameDuplicate =>
      'This relationship name already exists';

  @override
  String get peopleDeleteRelationshipConfirmTitle => 'Delete relationship?';

  @override
  String peopleDeleteRelationshipConfirmBody(int count) {
    return '$count people use this relationship. Deleting it will remove it from those people.';
  }

  @override
  String get peopleSortTooltip => 'Sort by';

  @override
  String get peopleSortLastMention => 'Last mentioned';

  @override
  String get peopleSortTotalMentions => 'Mentions';

  @override
  String get peopleSortRecentMentions => 'Last 30 days';

  @override
  String get peopleSortName => 'Name';

  @override
  String get peopleFieldName => 'Name';

  @override
  String get peopleFieldColor => 'Person color';

  @override
  String get peopleColorAutomatic => 'Automatic';

  @override
  String get peopleColorCustom => 'Custom color';

  @override
  String get peopleChooseCustomColor => 'More colors';

  @override
  String peopleColorPreset(int number) {
    return 'Color $number';
  }

  @override
  String get peopleFieldAliases => 'Aliases';

  @override
  String get peopleFieldAliasesHint => 'Separate multiple aliases with commas';

  @override
  String get peopleAddAliasLabel => 'Add alias';

  @override
  String get peopleAddAliasAction => 'Add alias';

  @override
  String get peopleAliasAlreadyAdded => 'This alias has already been added';

  @override
  String peopleRemoveAliasAction(String alias) {
    return 'Remove alias “$alias”';
  }

  @override
  String get peopleFieldMentionName => '@ name to use';

  @override
  String get peopleFieldMentionNameHint =>
      'Choose which name or alias @ inserts into diary entries';

  @override
  String get peopleMentionNameUsesNameFallback => 'Name';

  @override
  String peopleExportRecapScope(String name) {
    return 'Entries related to $name';
  }

  @override
  String get peopleFieldRelationships => 'Relationships';

  @override
  String get peopleFieldRelationshipDescription => 'Relationship notes';

  @override
  String get peopleFieldNotes => 'Notes';

  @override
  String get peopleNoValue => 'None';

  @override
  String get peopleFieldFriendliness => 'Familiarity';

  @override
  String get peopleFieldBirthday => 'Birthday';

  @override
  String get peopleFieldAcquaintanceYear => 'Year met';

  @override
  String get peopleSectionBasic => 'Basic information';

  @override
  String get peopleSectionRelationship => 'Relationship';

  @override
  String get peopleSectionOther => 'Other information';

  @override
  String get peopleMentionOverviewTitle => 'Mention overview';

  @override
  String get peopleProfileDetailsTitle => 'Profile details';

  @override
  String get peopleFriendlinessLow => 'Unfamiliar';

  @override
  String get peopleFriendlinessHigh => 'Very familiar';

  @override
  String get peopleFriendlinessLevel1 => 'Unfamiliar';

  @override
  String get peopleFriendlinessLevel2 => 'Barely know';

  @override
  String get peopleFriendlinessLevel3 => 'Acquainted';

  @override
  String get peopleFriendlinessLevel4 => 'Familiar';

  @override
  String get peopleFriendlinessLevel5 => 'Very familiar';

  @override
  String peopleAnalysisProgress(int processed, int total) {
    return 'Analyzing diaries $processed/$total';
  }

  @override
  String peopleIndexPreparationProgress(int processed, int total) {
    return 'Preparing diary index $processed/$total';
  }

  @override
  String peopleFriendlinessSemantics(
    int level,
    int max,
    String low,
    String high,
  ) {
    return '$level/$max ($low–$high)';
  }

  @override
  String peopleFriendlinessValueSemantics(String label, int level, int max) {
    return '$label, $level/$max';
  }

  @override
  String get peopleCreateTitle => 'Add person';

  @override
  String get peopleEditTitle => 'Edit person';

  @override
  String get peopleDetailTitle => 'Person';

  @override
  String get peopleSaveAction => 'Save';

  @override
  String get peopleDeleteAction => 'Delete person';

  @override
  String get peopleDeleteConfirmTitle => 'Delete this person?';

  @override
  String get peopleDeleteConfirmBody =>
      'Only the people catalog and derived stats are removed. Diary content is unchanged.';

  @override
  String get peopleNameRequired => 'Name is required';

  @override
  String get peopleNameConflict =>
      'This name or alias is already used by another person';

  @override
  String get peopleDiscardChangesTitle => 'Discard person changes?';

  @override
  String get peopleDiscardChangesBody => 'Unsaved changes will be lost.';

  @override
  String get peopleDiscardChangesAction => 'Discard';

  @override
  String peopleSaveFailure(String message) {
    return 'Could not save person: $message';
  }

  @override
  String peopleDeleteFailure(String message) {
    return 'Could not delete person: $message';
  }

  @override
  String get peopleWarningConfirmTitle => 'Save anyway?';

  @override
  String get peopleWarningConfirmBody =>
      'The name is short or overlaps another person’s name prefix, which may cause false matches.';

  @override
  String get peopleRenameKeepAliasTitle => 'Keep the old name as an alias?';

  @override
  String get peopleRenameKeepAliasBody =>
      'After renaming, the old name becomes an alias so existing diary text can still match this person.';

  @override
  String get peopleRenameKeepAliasAction => 'Keep';

  @override
  String peopleMentionCount(int count) {
    return '$count mentions';
  }

  @override
  String peopleRecentMentionCount(int count) {
    return '$count in last 30 days';
  }

  @override
  String peopleLastMention(String date) {
    return 'Last mentioned $date';
  }

  @override
  String get peopleLastMentionNever => 'Not mentioned yet';

  @override
  String get peopleTotalMentionsLabel => 'Total mentions';

  @override
  String get peopleRecentMentionsLabel => 'Last 30 days';

  @override
  String get peopleLastMentionLabel => 'Last mentioned';

  @override
  String peopleMentionEntriesValue(int count) {
    return '$count entries';
  }

  @override
  String get peopleAnalysisLoading => 'Analyzing entries';

  @override
  String get peopleAnalysisRetry => 'Analyze again';

  @override
  String get peopleRelatedEntriesTitle => 'Related entries';

  @override
  String get peopleRelatedEntriesEmpty => 'No related entries';

  @override
  String get peoplePickBirthday => 'Pick birthday';

  @override
  String get peopleClearBirthday => 'Clear birthday';

  @override
  String get peopleClearAcquaintanceYear => 'Clear year met';

  @override
  String get editorMentionEmptyCatalog =>
      'No people yet. Add someone on the People tab.';

  @override
  String get editorMentionNoMatches => 'No matching people';

  @override
  String get editorMentionCreatePerson => 'Create person';

  @override
  String get homeTooltipNewEntry => 'New Entry';

  @override
  String get homeTooltipSettings => 'Settings';

  @override
  String get homeTooltipExportHtml => 'Export HTML';

  @override
  String get homeTooltipPin => 'Pin';

  @override
  String get homeTooltipUnpin => 'Unpin';

  @override
  String homePinEntriesSuccess(int count) {
    return 'Pinned $count entries';
  }

  @override
  String homeUnpinEntriesSuccess(int count) {
    return 'Unpinned $count entries';
  }

  @override
  String get homeTooltipDelete => 'Delete';

  @override
  String get homeTooltipAddTag => 'Add Tag';

  @override
  String get homeTooltipEditTag => 'Edit Tag';

  @override
  String get homeTooltipDeleteTag => 'Delete Tag';

  @override
  String get homeTooltipBackToTop => 'Back to Top';

  @override
  String get homeTooltipDeselectTag => 'Clear Selection';

  @override
  String get homeSelectionSelectAll => 'Select All';

  @override
  String get homeSelectionDeselectAll => 'Deselect All';

  @override
  String get homeSelectionSelectDiary => 'Select Entry';

  @override
  String homeSelectionSelectedCount(int count) {
    return '$count Selected';
  }

  @override
  String get homeSearchHint => 'Search titles, content, or tags';

  @override
  String homeSearchResultCount(int count) {
    return '$count results';
  }

  @override
  String get homeSearchNoResultsTitle => 'No Matching Entries';

  @override
  String get homeSearchNoResultsMessage =>
      'Try different keywords, or search titles, content, and tags.';

  @override
  String get homeEmptyDiaryTitle => 'No Entries Yet';

  @override
  String get homeEmptyDiaryMessage => 'Create your first entry to see it here.';

  @override
  String get homeNoAnalysisTitle => 'No Data to Analyze Yet';

  @override
  String get homeNoAnalysisMessage =>
      'Write something first to see stats, tags, and entries in scope here.';

  @override
  String get homeExportRecapLabel => 'Export Recap';

  @override
  String get homeExportRecapAll => 'Export Full Recap';

  @override
  String get homeExportRecapYear => 'Export Yearly Recap';

  @override
  String get homeExportRecapMonth => 'Export Monthly Recap';

  @override
  String get homePopularTagsTitle => 'Popular Tags';

  @override
  String get homeScopeTitle => 'Scope';

  @override
  String get homeScopeAllLabel => 'All';

  @override
  String get homeScopeYearLabel => 'Year';

  @override
  String get homeScopeMonthLabel => 'Month';

  @override
  String get homeScopeEmptyDiary => 'No entries in this scope.';

  @override
  String homeScopeEmptyDiaryForTag(String tag) {
    return 'No entries with \"$tag\" in this scope.';
  }

  @override
  String get homeScopeEmptyTags => 'No tags in this scope.';

  @override
  String get homeUnsavedDraftLabel => 'Unsaved';

  @override
  String get homeHtmlExportLargeTitle => 'HTML File May Be Large';

  @override
  String get homeHtmlExportEmbeddedHint =>
      'Images are embedded into a single HTML file, which may be slower to open or harder to share.';

  @override
  String get portableExportConfirmTitle => 'Confirm Export';

  @override
  String get portableExportConfirmAction => 'Export';

  @override
  String get portableExportPlaintextWarning =>
      'Exported files are plaintext. Diary text and images are no longer protected by vault encryption; anyone with the files can read them.';

  @override
  String get portableExportMarkdownFormatLabel => 'Format: Markdown ZIP';

  @override
  String get portableExportHtmlFormatLabel => 'Format: HTML';

  @override
  String portableExportEntryCount(int count) {
    return 'Entries: $count';
  }

  @override
  String portableExportImageCount(int count) {
    return 'Images: $count';
  }

  @override
  String portableExportAttachmentCount(int count) {
    return 'Attachments: $count';
  }

  @override
  String portableExportDateRange(String start, String end) {
    return 'Date range: $start – $end';
  }

  @override
  String portableExportFileSize(String size) {
    return 'File size: about $size';
  }

  @override
  String portableExportScopeLabel(String scope) {
    return 'Scope: $scope';
  }

  @override
  String get portableExportIncludeImagesLabel =>
      'Include images and attachments';

  @override
  String get portableExportHidePersonNamesLabel => 'Hide person names';

  @override
  String get portableExportHidePersonNamesHint =>
      'Replace names and aliases from your people list with Person A, Person B, and so on.';

  @override
  String get portableExportSelectEntriesLabel => 'Select entries';

  @override
  String portableExportSelectEntriesSummary(int selected, int total) {
    return '$selected of $total selected';
  }

  @override
  String get portableImportConfirmTitle => 'Confirm import';

  @override
  String get portableImportConfirmAction => 'Import';

  @override
  String portableImportLikelyDuplicateCount(int count) {
    return 'Likely already in vault: $count';
  }

  @override
  String get portableImportLikelyDuplicateMark => 'Possible duplicate';

  @override
  String portableImportSkippedFilesCount(int count) {
    return 'Unreadable files: $count';
  }

  @override
  String portableImportSkippedAttachmentsCount(int count) {
    return 'Skipped attachments: $count';
  }

  @override
  String get portableImportAddsAsNewHint =>
      'Entries are always added as new; nothing is auto-deduplicated.';

  @override
  String homeHtmlExportImageSize(String size) {
    return 'Original image size: about $size';
  }

  @override
  String homeHtmlExportSuccess(String fileName) {
    return 'HTML exported: $fileName';
  }

  @override
  String get homeDeleteTagTitle => 'Delete Tag';

  @override
  String homeDeleteTagConfirm(String label) {
    return 'Remove \"$label\" from all entries?';
  }

  @override
  String get homeTagSearchHint => 'Search tags…';

  @override
  String get homeNoTagsTitle => 'No Tags Yet';

  @override
  String get homeNoTagsMessage =>
      'Tap the button below to create default tags, or use \"+\" to add your own. Unused tags stay in the list.';

  @override
  String get homeCreateDefaultTagsButton => 'Create Default Tags';

  @override
  String get homeCreateDefaultTagsSuccess => 'Default tags created';

  @override
  String homeTagsSectionTitle(String countSummary) {
    return 'Tags ($countSummary)';
  }

  @override
  String get homeTagListGuide =>
      'Tap a row in the tag list to preview entries filtered by that tag. Tap the same row again to clear the selection.';

  @override
  String get homeTagPreviewTitle => 'Select a Tag to Preview Entries';

  @override
  String homeTagDeleted(String label) {
    return '\"$label\" deleted';
  }

  @override
  String homeTagRemovedFromEntries(String entrySummary, String label) {
    return 'Removed \"$label\" from $entrySummary.';
  }

  @override
  String homeEntriesDeletedSuccess(int count) {
    return 'Deleted $count entries';
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
  String get homeTagRowTapHint => 'Tap to preview';

  @override
  String homeDiarySectionTitleForDate(String dateLabel) {
    return 'Entries · $dateLabel';
  }

  @override
  String homeEmptyDayMessage(String dateLabel) {
    return 'No entries on $dateLabel.';
  }

  @override
  String get homeOverviewDataTitle => 'Data Overview';

  @override
  String get homeOverviewScopeAll => 'Scope · All Entries';

  @override
  String homeOverviewScopeYear(int year) {
    return 'Scope · $year';
  }

  @override
  String homeOverviewScopeMonth(int year, int month) {
    return 'Scope · $year/$month';
  }

  @override
  String get homeOverviewWritingDaysLabel => 'Days Written';

  @override
  String get homeOverviewAvgLengthLabel => 'Avg. Length';

  @override
  String get homeOverviewAttachmentsLabel => 'Attachments';

  @override
  String homeOverviewAttachmentCount(String attachmentSummary) {
    return '$attachmentSummary';
  }

  @override
  String homeOverviewLongestStreak(String daySummary) {
    return 'Streak $daySummary';
  }

  @override
  String homeOverviewEntryStats(String entrySummary, String characterSummary) {
    return '$entrySummary\n$characterSummary';
  }

  @override
  String homeDiarySectionTag(String tag) {
    return 'Entries · $tag';
  }

  @override
  String get homeDiarySectionAll => 'Entries · All';

  @override
  String get homeDiarySectionByYear => 'Entries · By Year';

  @override
  String get homeDiarySectionByMonth => 'Entries · By Month';

  @override
  String homeDiarySectionWithTag(String baseTitle, String tag) {
    return '$baseTitle · $tag';
  }

  @override
  String get homeCalendarMonthFormatLabel => 'Month';

  @override
  String get datePickerChooseDate => 'Choose date';

  @override
  String get datePickerChooseYearMonth => 'Choose year and month';

  @override
  String get datePickerChooseYear => 'Choose year';

  @override
  String get datePickerYearLabel => 'Year';

  @override
  String get datePickerMonthLabel => 'Month';

  @override
  String get datePickerDayLabel => 'Day';

  @override
  String get timePickerChooseTime => 'Choose time';

  @override
  String get timePickerHourLabel => 'Hour';

  @override
  String get timePickerMinuteLabel => 'Minute';

  @override
  String get timePickerAm => 'AM';

  @override
  String get timePickerPm => 'PM';

  @override
  String get timePickerInvalidTime => 'Enter a valid time';

  @override
  String get timePickerInputHint =>
      'Enter an hour from 1–12 and minutes from 0–59';

  @override
  String get timePickerSwitchToInput => 'Switch to number input';

  @override
  String get timePickerSwitchToDial => 'Switch to clock dial';

  @override
  String get timePickerDialSemantics => 'Time selection dial';

  @override
  String get datePickerPreviousYear => 'Previous year';

  @override
  String get datePickerNextYear => 'Next year';

  @override
  String get datePickerPreviousMonth => 'Previous month';

  @override
  String get datePickerNextMonth => 'Next month';

  @override
  String datePickerMonthOption(int month) {
    return 'Month $month';
  }

  @override
  String datePickerDayOption(int day) {
    return 'Day $day';
  }

  @override
  String get datePickerWeekdaySun => 'Sun';

  @override
  String get datePickerWeekdayMon => 'Mon';

  @override
  String get datePickerWeekdayTue => 'Tue';

  @override
  String get datePickerWeekdayWed => 'Wed';

  @override
  String get datePickerWeekdayThu => 'Thu';

  @override
  String get datePickerWeekdayFri => 'Fri';

  @override
  String get datePickerWeekdaySat => 'Sat';

  @override
  String homeCalendarEntryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries',
      one: '1 entry',
      zero: '0 entries',
    );
    return '$_temp0';
  }

  @override
  String get homeCalendarSelectedStatus => 'selected';

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
    return '$charactersPerEntry / entry';
  }

  @override
  String homeOverviewAttachmentDetail(int photos, int files) {
    return 'Pics $photos · Files $files';
  }

  @override
  String homeOverviewMostEntriesInSingleDay(String entrySummary) {
    return 'Max $entrySummary';
  }

  @override
  String get vaultTransferNeedsUnlockForBackup =>
      'Unlock the diary vault before backing up or exporting.';

  @override
  String get vaultTransferNeedsRecoveryKeyForBackup =>
      'Create a recovery key before backing up or exporting.';

  @override
  String get vaultTransferNeedsUnlockForPortableTransfer =>
      'Unlock the diary vault before importing or exporting diary files.';

  @override
  String get vaultTransferNeedsUnlockForRestore =>
      'Unlock the diary vault before restoring a backup.';

  @override
  String get vaultTransferLocalSectionDescriptionBackupLocked =>
      'Local backup/export requires an unlocked vault and a recovery key. If none exists or you forgot it, import an external backup to restore.';

  @override
  String get vaultTransferDriveSectionDescriptionBackupLocked =>
      'Google Drive backup requires an unlocked vault and a recovery key. If none exists or you forgot it, you can still restore from Google Drive.';

  @override
  String get vaultTransferDriveBackupActionsLockedHint =>
      'Unlock the diary vault and create a recovery key before backing up to Google Drive.';

  @override
  String get vaultTransferLocalBackupActionsLockedHint =>
      'Unlock the diary vault and create a recovery key before creating or exporting local backups.';

  @override
  String get vaultTransferRestoreUnlockFailed =>
      'The backup was restored, but unlocking with the recovery key failed. Enter the recovery key again in Security Overview.';

  @override
  String get vaultTransferPickBackupFileTitle => 'Choose Backup ZIP';

  @override
  String get vaultTransferPickedFileUnreadable =>
      'The selected backup could not be read. Choose another file or source.';

  @override
  String get vaultTransferPickBackupDirectoryTitle =>
      'Choose a Folder for the Backup Export';

  @override
  String get vaultTransferPickMarkdownDirectoryTitle =>
      'Choose a Folder for the Markdown Export';

  @override
  String get vaultTransferPickHtmlDirectoryTitle =>
      'Choose a Folder for the HTML Export';

  @override
  String get vaultTransferImportDocumentsDirectoryPrompt =>
      'Choose a folder containing App Markdown or HTML files to import';

  @override
  String get vaultTransferImportDocumentsFileTitle =>
      'Choose ZIP, Markdown, or HTML to Import';

  @override
  String get vaultTransferBackupOutsideExpectedDirectory =>
      'The backup file is outside the expected directory.';

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
  String get defaultTagTakeaways => 'Takeaways';

  @override
  String get defaultTagNotes => 'Notes';

  @override
  String get defaultTagReflection => 'Reflection';

  @override
  String get defaultTagIdeas => 'Ideas';

  @override
  String get defaultTagPlans => 'Plans';

  @override
  String get defaultTagGoals => 'Goals';

  @override
  String get defaultTagWork => 'Work';

  @override
  String get defaultTagLearning => 'Learning';

  @override
  String get defaultTagRelationships => 'Relationships';

  @override
  String get defaultTagFamily => 'Family';

  @override
  String get defaultTagHealth => 'Health';

  @override
  String get defaultTagGratitude => 'Gratitude';

  @override
  String get settingsActionConfirm => 'Confirm Restore';

  @override
  String get settingsActionUpdate => 'Update';

  @override
  String get settingsActionVerifyAndRestore => 'Verify and Restore';

  @override
  String get settingsRecoveryKeyFieldLabel => 'Recovery Key';

  @override
  String get settingsRecoveryKeyFieldHint => 'ABCD-EFGH-IJKL-MNOP-QRST-UVWX';

  @override
  String get settingsRecoveryKeyShowTooltip => 'Show recovery key';

  @override
  String get settingsRecoveryKeyHideTooltip => 'Hide recovery key';

  @override
  String settingsRecoveryKeyHintLine(String hint) {
    return 'Last 4: $hint';
  }

  @override
  String get settingsBackupPhaseCreating => 'Creating backup…';

  @override
  String get settingsBackupPhaseCopying => 'Writing backup…';

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
      'Cancel and Verify Manually';

  @override
  String get settingsSecurityLockUnlockWithRecoveryButton =>
      'Unlock with Recovery Key';

  @override
  String get settingsSecurityLockRecoveryUnlockHint =>
      'Enter the recovery key to unlock the diary vault.';

  @override
  String get settingsSecurityLockRetryVerificationButton => 'Verify Again';

  @override
  String get settingsRecoveryKeyNotSetupBanner =>
      'No recovery key yet. The recovery key is an important part of protecting the entire vault, so create and save one before you change devices, restore, or lose access to this device.';

  @override
  String get settingsRecoveryKeySetupBanner =>
      'Recovery key created. Make sure you have saved it securely.';

  @override
  String get settingsRecoveryKeyCreateButton => 'Create Recovery Key';

  @override
  String get settingsRecoveryKeyRotateButton => 'Update Recovery Key';

  @override
  String get settingsRecoveryKeyFactVaultLabel => 'Diary Vault';

  @override
  String get settingsRecoveryKeyFactHintLabel => 'Last 4';

  @override
  String get settingsRecoveryKeyFactKdfLabel => 'Encryption';

  @override
  String get settingsRecoveryKeySaveDialogTitle => 'Save Your Recovery Key';

  @override
  String get settingsRecoveryKeySaveNewDialogTitle =>
      'Save Your New Recovery Key';

  @override
  String get settingsRecoveryKeySaveDialogHint =>
      'Save it now. You won\'t be able to view it again after closing.';

  @override
  String get settingsRecoveryKeyCopyButton => 'Copy';

  @override
  String get settingsRecoveryKeyCopiedMessage => 'Copied to clipboard';

  @override
  String get tagColorCodeCopiedMessage => 'Color code copied';

  @override
  String get settingsRecoveryKeyRotateDialogTitle => 'Update Recovery Key?';

  @override
  String get settingsRecoveryKeyRotateDialogBody =>
      'A new recovery key will be generated—save it immediately.\n\nExisting local or Google Drive backups still require the old key to restore; create a new backup after updating.';

  @override
  String get settingsSecurityOverviewSectionTitle => 'Security Overview';

  @override
  String get settingsSecurityOverviewSectionDescription =>
      'Review recovery key status, unlock method, search index, and backup status.';

  @override
  String get settingsSecurityOverviewRecoveryKeyTitle => 'Recovery Key';

  @override
  String get settingsSecurityOverviewRecoveryKeyReady =>
      'Created and ready for device migration and restore.';

  @override
  String get settingsSecurityOverviewRecoveryKeyMissing =>
      'Not created yet. Create one before backing up or exporting.';

  @override
  String get settingsSecurityOverviewUnlockStatusTitle => 'Unlock Status';

  @override
  String get settingsSecurityOverviewUnlockStatusUnlocked =>
      'The diary vault is currently unlocked.';

  @override
  String get settingsSecurityOverviewUnlockStatusLocked =>
      'Unlock first to back up, restore, or change settings.';

  @override
  String get settingsSecurityOverviewUnlockModeTitle => 'Unlock Method';

  @override
  String get settingsSecurityOverviewTrustedDeviceTitle => 'Trusted Device';

  @override
  String get settingsSecurityOverviewTrustedDeviceReady =>
      'This device is verified and can unlock quickly.';

  @override
  String get settingsSecurityOverviewTrustedDeviceMissing =>
      'This device has not been verified yet.';

  @override
  String get settingsSecurityOverviewUnlockModeNeedsRecoveryKeyMessage =>
      'Create a recovery key first. It helps protect the entire vault, and you will need it to configure an unlock method and to regain access when you change devices, restore, or lose access to this device.';

  @override
  String settingsSecurityOverviewUnlockModeProtectedMessage(
    String unlockModeLabel,
  ) {
    return 'This device is protected with $unlockModeLabel.';
  }

  @override
  String get settingsSecurityOverviewIndexTitle => 'Vault';

  @override
  String get settingsSecurityOverviewCreateRecoveryKeyButton =>
      'Create Recovery Key';

  @override
  String get settingsSecurityOverviewRotateRecoveryKeyButton =>
      'Update Recovery Key';

  @override
  String get settingsSecurityOverviewRepairVaultButton => 'Repair Vault';

  @override
  String get settingsSecurityOverviewInspectVaultButton => 'Check Vault';

  @override
  String get settingsSecurityOverviewHealthLevelOk => 'OK';

  @override
  String get settingsSecurityOverviewHealthLevelWarning => 'Needs Attention';

  @override
  String get settingsSecurityOverviewHealthLevelError => 'Error';

  @override
  String get settingsSecurityOverviewLocalBackupTitle => 'Local backup';

  @override
  String get settingsSecurityOverviewLocalBackupNever =>
      'No local backup yet. Consider backing up soon.';

  @override
  String settingsSecurityOverviewLocalBackupLast(String time, String method) {
    return 'Last local backup: $time ($method).';
  }

  @override
  String get settingsSecurityOverviewLocalBackupStale =>
      'Your last local backup was over 30 days ago. Consider backing up soon.';

  @override
  String get settingsSecurityOverviewDriveBackupTitle => 'Google Drive backup';

  @override
  String get settingsSecurityOverviewDriveBackupNever =>
      'No Google Drive backup yet. Consider backing up soon.';

  @override
  String settingsSecurityOverviewDriveBackupLast(String time) {
    return 'Last Google Drive backup: $time.';
  }

  @override
  String settingsSecurityOverviewDriveBackupLastWithAccount(
    String time,
    String account,
  ) {
    return 'Last Google Drive backup: $time ($account).';
  }

  @override
  String get settingsSecurityOverviewDriveBackupStale =>
      'Your last Google Drive backup was over 30 days ago. Consider backing up soon.';

  @override
  String settingsSecurityOverviewBackupRecentFailure(String action) {
    return 'Latest \"$action\" attempt failed.';
  }

  @override
  String get settingsUnlockModeFullNone => 'None';

  @override
  String get settingsUnlockModeFullDeviceLock => 'Device Screen Lock';

  @override
  String get settingsUnlockModeFullBiometric => 'Biometric Verification';

  @override
  String get settingsUnlockMethodSectionTitle => 'Unlock Method';

  @override
  String settingsUnlockMethodSectionDescription(String timeoutLabel) {
    return 'The app auto-locks after staying in the background for $timeoutLabel. Brief app switches usually do not trigger a lock. When you return, verify using the unlock method set below.';
  }

  @override
  String get settingsUnlockMethodSegmentNone => 'None';

  @override
  String get settingsUnlockMethodSegmentDeviceLock => 'Screen Lock';

  @override
  String get settingsUnlockMethodSegmentBiometric => 'Biometric';

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
      'Uses fingerprint or face verification after lock; requires a screen lock and enrolled biometrics first. On cancel or failure, it falls back to screen lock.';

  @override
  String settingsSessionTimeoutBackgroundLockExplanation(String timeoutLabel) {
    return 'The app auto-locks after staying in the background for $timeoutLabel; brief app switches usually do not trigger a lock.';
  }

  @override
  String settingsSessionTimeoutAboutBackgroundTimeoutBody(String timeoutLabel) {
    return 'The app auto-locks after staying in the background for $timeoutLabel; brief app switches usually do not. You can change the timeout in Personalization. Auto-lock pauses while backup, restore, import, or export is in progress.';
  }

  @override
  String get settingsImportExportSectionTitle => 'Import & Export';

  @override
  String get settingsImportExportSectionDescriptionEnabled =>
      'Import entries from other apps or files, or export saved content as files. Supports Markdown, HTML, and Easy Diary backups.';

  @override
  String get settingsImportExportImportNoEntriesMessage =>
      'No importable entries found. Check the file format.';

  @override
  String get settingsImportExportExportNoEntriesMessage =>
      'There are no diary entries to export.';

  @override
  String get settingsImportExportPrepareProgress =>
      'Reading and parsing files…';

  @override
  String get settingsImportExportImportAllSkippedMessage =>
      'None of the selected files could be imported (unsupported format, empty content, or encrypted Easy Diary entries).';

  @override
  String get settingsImportExportFailureSelectedFilesUnreadable =>
      'The selected files could not be read. Try choosing a local file again.';

  @override
  String get settingsImportExportFailureZipNoEntries =>
      'The ZIP contains no importable Markdown, HTML, or full Easy Diary backup.';

  @override
  String get settingsImportExportFailureEasyDiaryRealmReadFailed =>
      'Unable to read the Easy Diary backup; the version may be incompatible. Create a new backup in Easy Diary and try again.';

  @override
  String get settingsImportExportFailureEasyDiaryEmptyBackup =>
      'The Easy Diary backup contains no importable entries.';

  @override
  String get settingsImportExportFailureEasyDiaryAllEncrypted =>
      'All entries in the Easy Diary backup are encrypted and cannot be imported.';

  @override
  String get settingsImportExportImportProgress => 'Importing entries…';

  @override
  String get settingsImportExportExportButton => 'Export Entries';

  @override
  String get settingsImportExportImportButton => 'Import Entries';

  @override
  String get settingsImportExportExportProgress =>
      'Exporting entries and preparing attachments…';

  @override
  String settingsImportExportExportSuccess(String path) {
    return 'Exported: $path';
  }

  @override
  String settingsImportExportImportSuccess(int count) {
    return 'Imported $count entries.';
  }

  @override
  String settingsImportExportImportSuccessWithSkippedFiles(
    int count,
    int skippedFiles,
  ) {
    return 'Imported $count entries; $skippedFiles files could not be parsed.';
  }

  @override
  String settingsImportExportImportSuccessWithSkippedAttachments(
    int count,
    int skippedAttachments,
  ) {
    return 'Imported $count entries; $skippedAttachments images could not be imported.';
  }

  @override
  String settingsImportExportImportSuccessWithSkippedFilesAndAttachments(
    int count,
    int skippedFiles,
    int skippedAttachments,
  ) {
    return 'Imported $count entries; $skippedFiles files and $skippedAttachments images could not be imported.';
  }

  @override
  String get settingsLocalBackupSectionTitle => 'Local Backup & Restore';

  @override
  String get settingsLocalBackupSectionDescriptionEnabled =>
      'Create full local backups; restoring replaces the current diary vault with the backup copy. (Keeps up to 5 local backups)';

  @override
  String get settingsLocalBackupCreateButton => 'Create Local Backup';

  @override
  String get settingsLocalBackupRestoreButton => 'Restore from Local Backup';

  @override
  String get settingsLocalBackupExportToExternalButton =>
      'Export Backup to Folder';

  @override
  String get settingsLocalBackupImportFromExternalButton =>
      'Import External Backup';

  @override
  String get settingsLocalBackupPickDialogTitle => 'Choose Local Backup';

  @override
  String get settingsLocalBackupPickExternalBackupDialogTitle =>
      'Choose Backup ZIP';

  @override
  String get settingsLocalBackupNoBackups => 'No local backups yet.';

  @override
  String get settingsLocalBackupDeleteBackupTooltip => 'Delete Backup';

  @override
  String get settingsLocalBackupDeleteConfirmTitle => 'Delete Local Backup?';

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
  String get settingsDriveBackupSectionTitle => 'Google Drive Backup & Restore';

  @override
  String get settingsDriveBackupSectionDescriptionEnabled =>
      'Link a Google Account to create Google Drive backups or restore from Google Drive backups; restoring replaces the current diary vault with the backup copy. Uploads finish in the background, so you can switch apps; do not force-stop this app. (Keeps up to 5 Google Drive backups)';

  @override
  String get settingsDriveBackupSectionDescriptionOAuthNotConfigured =>
      'Google Sign-In is not configured in this build, so Google Drive backup is unavailable.';

  @override
  String get settingsDriveBackupLinkButton => 'Link Google Account';

  @override
  String get settingsDriveBackupSwitchAccountButton => 'Switch Account';

  @override
  String get settingsDriveBackupDisconnectButton => 'Disconnect';

  @override
  String get settingsDriveBackupUploadButton => 'Back Up to Google Drive';

  @override
  String get settingsDriveBackupRestoreButton => 'Restore from Google Drive';

  @override
  String get settingsDriveBackupDisconnectedLabel =>
      'Google Account Not Linked';

  @override
  String get settingsDriveBackupConnectionErrorLabel =>
      'Could Not Read Google Connection';

  @override
  String get settingsDriveBackupConnectionRetryButton => 'Reload';

  @override
  String get settingsDriveBackupFallbackAccountLabel => 'Google Account';

  @override
  String get settingsDriveBackupLinkSuccessEmpty =>
      'Google Account linked. You can back up or restore now.';

  @override
  String settingsDriveBackupLinkSuccess(String accountLabel) {
    return 'Google Account linked: $accountLabel';
  }

  @override
  String get settingsDriveBackupSwitchAccountSuccessEmpty =>
      'Google Account switched.';

  @override
  String settingsDriveBackupSwitchAccountSuccess(String accountLabel) {
    return 'Switched to $accountLabel';
  }

  @override
  String get settingsDriveBackupDisconnectSuccess =>
      'Google Account disconnected. Cloud backups are kept.';

  @override
  String get settingsDriveBackupDisconnectConfirmTitle =>
      'Disconnect Google Account?';

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
  String get settingsDriveBackupPickDialogTitle => 'Choose Google Drive Backup';

  @override
  String get settingsDriveBackupUnknownCreatedTime => 'Unknown creation time';

  @override
  String get settingsDriveBackupDeleteBackupTooltip => 'Delete Backup';

  @override
  String get settingsDriveBackupDeleteConfirmTitle =>
      'Delete Google Drive Backup?';

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
  String get settingsBackupPhasePreparingDriveUpload =>
      'Preparing backup… Keep Quill Diary on screen until this step finishes.';

  @override
  String get driveUploadBackgroundStarted =>
      'Uploading to Google Drive in the background. You can switch apps or lock the screen; do not force-stop the app in system settings. If the upload service is stopped by the system, open the app and start a new backup.';

  @override
  String get driveUploadNotificationsDeniedHint =>
      'Without notification permission, progress and the stop action will not appear in the notification shade. Check upload status in the app.';

  @override
  String driveUploadStatusUploading(String fileName, int percent) {
    return 'Uploading in background: $fileName ($percent%)';
  }

  @override
  String driveUploadStatusStaged(String fileName) {
    return 'Preparing background upload: $fileName';
  }

  @override
  String driveUploadStatusWaitingNetwork(String fileName) {
    return 'Waiting for network to continue upload: $fileName';
  }

  @override
  String get driveUploadStatusFinalizing =>
      'Google Drive backup uploaded; finishing up…';

  @override
  String get driveUploadStatusCancelCleanup =>
      'Clearing unfinished Google Drive backup…';

  @override
  String driveUploadStatusCancelCleanupNeedsReauth(String accountEmail) {
    return 'Re-link the Google account ($accountEmail) to finish clearing the unfinished backup.';
  }

  @override
  String driveUploadStatusCancelCleanupAccountMismatch(String accountEmail) {
    return 'The signed-in Google account does not match the upload. Re-link $accountEmail to finish cleanup, or abandon it.';
  }

  @override
  String get driveUploadCancelButton => 'Cancel upload';

  @override
  String get driveUploadCancelConfirmTitle => 'Cancel Google Drive upload?';

  @override
  String get driveUploadCancelConfirmBody =>
      'This stops the current background upload and deletes the temporary backup file.';

  @override
  String get driveUploadBusyBlocksAccountActions =>
      'An upload is in progress. Finish or cancel it before changing the Google account.';

  @override
  String get driveUploadCancelCleanupBlocksAccountActions =>
      'Clearing an unfinished Google Drive backup. If authorization failed, re-link the original account or abandon cleanup.';

  @override
  String get driveUploadAbandonCancelCleanupButton => 'Abandon cleanup';

  @override
  String get driveUploadAbandonCancelCleanupConfirmTitle =>
      'Abandon unfinished backup cleanup?';

  @override
  String get driveUploadAbandonCancelCleanupConfirmBody =>
      'This unlocks the app so you can back up again or change Google accounts. Leftover files may remain in Google Drive and will not count as a successful backup.';

  @override
  String get driveUploadAbandonedFailureTitle => 'Google Drive backup failed';

  @override
  String get driveUploadAbandonedFailureBody =>
      'The previous Google Drive backup did not finish and was cancelled. Please back up again.';

  @override
  String get driveUploadAbandonedFailureConfirm => 'OK';

  @override
  String get settingsSecurityOverviewDriveUploadInProgress =>
      'Uploading to Google Drive';

  @override
  String get settingsSecurityOverviewDriveUploadPending =>
      'Google Drive upload not finished';

  @override
  String get settingsRestoreDialogConfirmLocalTitle => 'Restore Local Backup?';

  @override
  String get settingsRestoreDialogConfirmDriveTitle =>
      'Restore from Google Drive?';

  @override
  String get settingsRestoreConfirmOverwriteHeadline =>
      'Existing data will be replaced. Follow the prompts to unlock after restore.';

  @override
  String get settingsRestoreConfirmFreshVaultHeadline =>
      'The backup will create a new diary vault.';

  @override
  String get settingsRestoreConfirmOverwriteAcknowledgeCheckbox =>
      'I understand existing entries will be overwritten and cannot be recovered.';

  @override
  String get settingsRestorePrecheckSameVaultTitle => 'Same Vault';

  @override
  String get settingsRestorePrecheckSameVaultBody =>
      'This backup belongs to the same vault as this device.';

  @override
  String get settingsRestorePrecheckOtherVaultTitle =>
      'Backup from Another Device';

  @override
  String get settingsRestorePrecheckOtherVaultBody =>
      'This backup is from another device or a different vault.';

  @override
  String get settingsRestorePrecheckRotatedTitle => 'Recovery Key Rotated';

  @override
  String get settingsRestorePrecheckRotatedBody =>
      'This backup was created before the recovery key was updated. Use the old key saved with that backup.';

  @override
  String get settingsRestorePrecheckTrustedUnlockTitle => 'May Auto-Unlock';

  @override
  String get settingsRestorePrecheckTrustedUnlockBody =>
      'If the backup uses the same recovery key as this device, you can usually continue without extra steps.';

  @override
  String get settingsRestorePrecheckRecoveryKeyTitle =>
      'Recovery Key Required After Restore';

  @override
  String get settingsRestorePrecheckRecoveryKeyBody =>
      'Have the recovery key saved when this backup was created.';

  @override
  String get settingsRestorePrecheckHintTitle => 'Key Hint';

  @override
  String get settingsRestorePrecheckRebuildIndexTitle => 'Rebuild Search Index';

  @override
  String get settingsRestorePrecheckRebuildIndexBody =>
      'The search index will be rebuilt after unlock.';

  @override
  String get settingsRestorePrecheckRewrapTitle =>
      'First Unlock May Take Longer';

  @override
  String get settingsRestorePrecheckRewrapBody =>
      'The first unlock after restore may take longer. Keep the app open.';

  @override
  String settingsRestoreDialogDriveFileLine(String name) {
    return 'Backup: $name';
  }

  @override
  String get settingsRestoreDialogRecoveryKeyTitle =>
      'Enter Backup Recovery Key';

  @override
  String get settingsRestoreDialogRecoveryKeyEmptyError =>
      'Enter the recovery key.';

  @override
  String get settingsRestoreDialogRecoveryKeyVerifyNote =>
      'Restore starts only if the key is correct; a wrong key will not overwrite local data.';

  @override
  String get settingsRestoreDialogSubtitleRotatedBackup =>
      'This backup was created before the recovery key was updated. Enter the old key saved when that backup was created, not the current new key.';

  @override
  String get settingsRestoreDialogSubtitleSameVaultManual =>
      'This device cannot auto-unlock this backup. Enter the recovery key saved when it was created.';

  @override
  String get settingsRestoreDialogSubtitleOtherVault =>
      'This backup is from another device. Enter the recovery key saved when it was created.';

  @override
  String get settingsRestoreBulletOverwriteWarning =>
      'Backup contents will overwrite local entries. Current data cannot be recovered.';

  @override
  String get settingsRestoreBulletFreshVaultNote =>
      'The backup will create a new diary vault.';

  @override
  String get settingsRestoreBulletRebuildIndex =>
      'The search index will be rebuilt after unlock.';

  @override
  String get settingsRestoreBulletRotatedBackup =>
      'This backup was created before the recovery key was updated. After restore, enter the old recovery key saved with that backup, not the current new key.';

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
  String get settingsRepairVaultReadyMessage =>
      'You can check and tidy your diary anytime.';

  @override
  String get settingsRepairVaultLockedMessage => 'Unlock to check your diary.';

  @override
  String get settingsInspectVaultConfirmTitle => 'Check vault';

  @override
  String get settingsInspectVaultConfirmBody =>
      'Before checking, you can review the last repair record.';

  @override
  String get settingsInspectVaultConfirmButton => 'Start check';

  @override
  String get settingsInspectVaultPreflightCurrent => 'Current status';

  @override
  String settingsInspectVaultPreflightTime(String finishedAt) {
    return 'Time: $finishedAt';
  }

  @override
  String get settingsInspectVaultPreflightSourceInspect => 'Source: check';

  @override
  String get settingsInspectVaultPreflightSourceRepair => 'Source: repair';

  @override
  String settingsInspectVaultPreflightEntries(int count) {
    return 'Affected entries: $count';
  }

  @override
  String get settingsInspectVaultPreflightLastRepair => 'Last repair';

  @override
  String get settingsInspectVaultPreflightNoRepair =>
      'No repair has been run yet.';

  @override
  String get settingsRepairDetailCompleted => 'Completed';

  @override
  String get settingsRepairDetailGlobal => 'Global cleanup';

  @override
  String get settingsRepairDetailUnresolved => 'Still needs attention';

  @override
  String get settingsRepairDetailAggregateFallback =>
      'This record only contains aggregate data. Per-entry details will be available from the next repair.';

  @override
  String settingsRepairDetailPurgedOldQuarantine(int count) {
    return 'Old quarantined files purged: $count';
  }

  @override
  String get settingsLastRepairLogEmpty => 'No repair has been run yet.';

  @override
  String settingsLastRepairLogFinishedAt(String finishedAt) {
    return 'Last repair: $finishedAt';
  }

  @override
  String settingsLastRepairLogCheckedEntries(int entryCount) {
    return 'Checked $entryCount entries at that time.';
  }

  @override
  String settingsLastRepairLogBackupFile(String fileName) {
    return 'Pre-repair backup: $fileName';
  }

  @override
  String settingsLastRepairLogRelocatedEntries(int count) {
    return 'Entries moved to the correct location: $count';
  }

  @override
  String settingsLastRepairLogRelocatedAssets(int count) {
    return 'Attachments moved to the correct location: $count';
  }

  @override
  String settingsLastRepairLogRecoveredAttachments(int count) {
    return 'Attachments recovered from verified copies: $count';
  }

  @override
  String settingsLastRepairLogRemovedBrokenReferences(int count) {
    return 'Broken attachment references removed: $count';
  }

  @override
  String settingsLastRepairLogSplitAttachments(int count) {
    return 'Shared attachments split: $count';
  }

  @override
  String settingsLastRepairLogRemovedDuplicates(int count) {
    return 'Duplicate entry files removed: $count';
  }

  @override
  String settingsLastRepairLogRemovedOrphans(int count) {
    return 'Orphan attachments removed: $count';
  }

  @override
  String settingsLastRepairLogQuarantined(int count) {
    return 'Abnormal files quarantined: $count';
  }

  @override
  String settingsLastRepairLogPurgedBadAssets(int count) {
    return 'Damaged attachments removed: $count';
  }

  @override
  String settingsLastRepairLogUnresolved(int count) {
    return 'Still unresolved: $count entries';
  }

  @override
  String get settingsLastRepairLogNoActions =>
      'Nothing needed automatic repair at that time.';

  @override
  String get settingsRepairDetailButton => 'Details';

  @override
  String get settingsRepairDetailTitle => 'Repair details';

  @override
  String get settingsRepairDetailEmpty =>
      'No per-entry repair details to show.';

  @override
  String settingsRepairDetailGlobalOrphans(int count) {
    return 'Orphan attachments removed: $count';
  }

  @override
  String settingsRepairDetailGlobalPurgedBad(int count) {
    return 'Damaged attachments removed: $count';
  }

  @override
  String settingsRepairDetailRecoveredAttachments(int count) {
    return 'Images recovered automatically: $count';
  }

  @override
  String settingsRepairDetailRemovedMissingAttachments(int count) {
    return 'Missing image references removed: $count';
  }

  @override
  String settingsRepairDetailPurgedBadAttachments(int count) {
    return 'Damaged images removed: $count';
  }

  @override
  String settingsRepairDetailSplitAttachments(int count) {
    return 'Shared attachments split: $count';
  }

  @override
  String settingsRepairDetailRelocatedEntries(int count) {
    return 'Entry files cleaned up: $count';
  }

  @override
  String settingsRepairDetailQuarantinedItems(int count) {
    return 'Abnormal files quarantined: $count';
  }

  @override
  String settingsRepairDetailCleanupFailures(int count) {
    return 'Automatic cleanup failed: $count';
  }

  @override
  String get settingsMaintenanceProgressTitle => 'Working on your diary…';

  @override
  String get settingsInspectVaultProgressScanningEntries => 'Checking entries…';

  @override
  String get settingsInspectVaultProgressCheckingAttachments =>
      'Checking attachments…';

  @override
  String get settingsInspectVaultProgressRebuildingIndex =>
      'Refreshing search…';

  @override
  String get settingsInspectVaultProgressRebuildingPeople =>
      'Updating people data…';

  @override
  String get settingsInspectVaultResultTitle => 'Check complete';

  @override
  String get settingsInspectVaultResultClean => 'Everything looks good.';

  @override
  String settingsInspectVaultResultWarning(int count) {
    return 'Found $count entries that need attention. Repair will create and verify a local backup first, then tidy what can be fixed automatically.';
  }

  @override
  String settingsInspectVaultResultCheckedEntries(int entryCount) {
    return 'Checked $entryCount entries.';
  }

  @override
  String get settingsInspectVaultHandleLaterButton => 'Later';

  @override
  String get settingsInspectVaultRepairAfterBackupButton =>
      'Back up and repair';

  @override
  String get settingsInspectVaultUnrecognizedEntry => 'Unrecognized entry';

  @override
  String get settingsInspectVaultEntryDateUnknown => 'Unknown date';

  @override
  String get settingsInspectVaultPlannedQuarantine =>
      'Will quarantine unverifiable data';

  @override
  String get settingsInspectVaultPlannedRemoveReference =>
      'Will remove broken attachment references';

  @override
  String get settingsInspectVaultPlannedSplitAttachment =>
      'Will split shared attachments';

  @override
  String get settingsInspectVaultPlannedRelocate =>
      'Will move files back to the correct location';

  @override
  String get settingsInspectVaultPlannedDeleteDuplicate =>
      'Will clean up duplicate files';

  @override
  String get settingsInspectVaultPlannedNone => 'Needs further review';

  @override
  String get settingsRepairVaultProgressCreatingBackup =>
      'Creating pre-repair backup…';

  @override
  String get settingsRepairVaultProgressRepairingEntries =>
      'Repairing entries…';

  @override
  String get settingsRepairVaultProgressRepairingAttachments =>
      'Organizing attachments…';

  @override
  String get settingsRepairVaultProgressUpdatingSearch =>
      'Updating search data…';

  @override
  String get settingsRepairVaultProgressScanningEntries => 'Checking entries…';

  @override
  String get settingsRepairVaultProgressCheckingAttachments =>
      'Checking attachments…';

  @override
  String get settingsRepairVaultProgressRebuildingIndex => 'Refreshing search…';

  @override
  String get settingsRepairVaultProgressRebuildingPeople =>
      'Updating people data…';

  @override
  String get settingsRepairVaultProgressCleaning => 'Finishing up…';

  @override
  String get settingsRepairVaultResultTitle => 'Repair complete';

  @override
  String get settingsRepairVaultResultClean =>
      'Your diary has been repaired and is in good shape.';

  @override
  String settingsRepairVaultResultWarning(int count) {
    return 'Repair finished, but $count entries remain unresolved. You can manually salvage readable content, or permanently delete files that cannot be recovered.';
  }

  @override
  String settingsRepairVaultResultCheckedEntries(int entryCount) {
    return 'Checked $entryCount entries.';
  }

  @override
  String settingsRepairVaultResultIssueCount(String label, int count) {
    return '$label: $count';
  }

  @override
  String settingsRepairVaultResultQuarantinedCount(int count) {
    return 'Quarantined $count items.';
  }

  @override
  String settingsRepairVaultResultBackupFile(String fileName) {
    return 'Pre-repair backup: $fileName';
  }

  @override
  String get settingsRepairVaultResultMissingAttachment =>
      'Attachment is missing';

  @override
  String get settingsRepairVaultResultSalvageButton => 'Manual repair';

  @override
  String get settingsRepairVaultResultSalvageFailed =>
      'No readable content could be recovered. Permanently delete the files or restore from a backup.';

  @override
  String get settingsRepairVaultBackupFailed =>
      'Pre-repair backup failed. Repair was cancelled and live data was not changed.';

  @override
  String get settingsRepairVaultBackupCancelled =>
      'Pre-repair backup was cancelled. Repair did not run.';

  @override
  String settingsRepairVaultBackupInspectFailed(String message) {
    return 'Pre-repair backup validation failed: $message';
  }

  @override
  String get settingsRepairIssueInvalidEntryMetadata =>
      'Some entry information is incomplete';

  @override
  String get settingsRepairIssueUnreadableEntry =>
      'Some entries could not be opened';

  @override
  String get settingsRepairIssueEntryIdentityMismatch =>
      'Some entry information needs attention';

  @override
  String get settingsRepairIssueConflictingEntry =>
      'Different copies of the same entry were found';

  @override
  String get settingsRepairIssueMissingAsset => 'Some attachments are missing';

  @override
  String get settingsRepairIssueUnreadableAsset =>
      'Some attachments could not be opened';

  @override
  String get settingsRepairIssueAssetIdentityMismatch =>
      'Some attachment content looks unusual';

  @override
  String get settingsRepairIssueConflictingAsset =>
      'Different copies of the same attachment were found';

  @override
  String get settingsRepairIssueUnverifiedOrphanAsset =>
      'Some attachments could not be matched to an entry';

  @override
  String get settingsRepairIssueCleanupFailure =>
      'Some files could not be tidied';

  @override
  String get settingsUnlockRequiredToChangeSettingMessage =>
      'Unlock the diary vault to change this setting.';

  @override
  String get settingsIndexLinkDriveProgress => 'Linking Google Account…';

  @override
  String get settingsIndexSwitchDriveAccountProgress => 'Switching account…';

  @override
  String get settingsIndexDisconnectDriveProgress => 'Disconnecting…';

  @override
  String settingsInspectVaultCompleted(int entryCount, String finishedAt) {
    return 'Last check: $finishedAt. Checked $entryCount entries; no issues found.';
  }

  @override
  String settingsInspectVaultCompletedWithIssues(
    int issueCount,
    String finishedAt,
  ) {
    return 'Last check: $finishedAt. $issueCount entries need attention.';
  }

  @override
  String settingsRepairVaultCompleted(int entryCount, String finishedAt) {
    return 'Last repair: $finishedAt. Checked $entryCount entries; no issues found.';
  }

  @override
  String settingsRepairVaultCompletedWithIssues(
    int issueCount,
    String finishedAt,
  ) {
    return 'Last repair: $finishedAt. $issueCount entries need attention.';
  }

  @override
  String get settingsAbnormalEntriesPageTitle => 'Problem entries';

  @override
  String get settingsAbnormalEntriesEmpty =>
      'There are no unresolved problems.';

  @override
  String get settingsAbnormalEntriesDeleteButton => 'Delete permanently';

  @override
  String get settingsAbnormalEntriesDeleteConfirmTitle =>
      'Permanently delete these files?';

  @override
  String get settingsAbnormalEntriesDeleteConfirmBody =>
      'Related vault files for this problem will be permanently deleted and cannot be undone. Restore from a local backup first if you still need the content.';

  @override
  String get settingsAbnormalEntriesDeleteSuccess =>
      'Related files were permanently deleted.';

  @override
  String get settingsAbnormalEntriesDeleteFailed =>
      'Deletion failed. Please try again later.';

  @override
  String get settingsAbnormalEntriesAttachmentPhoto => 'Photo';

  @override
  String get settingsAbnormalEntriesAttachmentFile => 'Attachment';

  @override
  String get settingsSupportNavButtonLabel => 'Support';

  @override
  String get settingsSupportPageTitle => 'Support the Developer';

  @override
  String get settingsSupportHeroTitle => 'Support If You Like It';

  @override
  String get settingsSupportHeroBody =>
      'If Quill Diary has been helpful, you can make a one-time support purchase through Google Play. It does not unlock extra features or affect access to your entries.';

  @override
  String get settingsSupportHeroChipNoExtraFeatures => 'No Extra Features';

  @override
  String get settingsSupportHeroChipRepeatablePurchase =>
      'Support Again Anytime';

  @override
  String get settingsSupportHeroChipGooglePlayPayment => 'Google Play Payment';

  @override
  String get settingsSupportComplianceCardTitle => 'Support and Data';

  @override
  String get settingsSupportComplianceCardBody =>
      'Support payments are processed by Google Play as one-time support purchases, not subscriptions or memberships. The app does not store support records or read entry content.';

  @override
  String get settingsSupportProductsSectionTitle => 'Support Options';

  @override
  String get settingsSupportProductsSectionBody =>
      'Google Play shows the localized title, description, and price for each support option in your region.';

  @override
  String get settingsSupportBuyButtonPrefix => 'Support';

  @override
  String get settingsSupportPendingMessage => 'Processing support…';

  @override
  String get settingsSupportThanksMessage =>
      'Thank you for your support—it helps keep Quill Diary moving.';

  @override
  String get settingsSupportErrorMessage =>
      'Support did not complete. Please try again later.';

  @override
  String get settingsSupportBillingUnavailableMessage =>
      'Google Play billing is currently unavailable. Make sure Google Play services are working on this Android device.';

  @override
  String get settingsSupportProductLoadErrorTitle =>
      'Unable to Load Support Options';

  @override
  String get settingsSupportProductLoadErrorBody => 'Please try again later.';

  @override
  String get settingsSupportProductsNotReadyTitle =>
      'Support Options Are Not Ready';

  @override
  String get settingsSupportProductsNotReadyBody =>
      'Check your network connection. If the issue persists, update the app and try again.';

  @override
  String get settingsSupportProductsInitFailedTitle =>
      'Unable to Start Google Play Billing';

  @override
  String get settingsSupportProductsInitFailedBody =>
      'Make sure Google Play services are working, then try again.';

  @override
  String get settingsSupportProductsQueryFailedTitle =>
      'Cannot Connect to Google Play';

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
      'Support is completely optional. Please choose what feels right for you.';

  @override
  String get sessionStartupNeedsRecoveryKeyMessage =>
      'No recovery key has been created yet. The recovery key is an important part of protecting the entire vault, so create and save one before you change devices, restore, or lose access to this device.';

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
      'Unable to read the backup file. Make sure it is intact and a valid ZIP backup.';

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
  String get sessionRestoreStartupFailedMessage =>
      'Backup restored, but startup failed. Retry from Settings or enter the recovery key.';

  @override
  String get postRestoreOutcomeTitle => 'Restore completed';

  @override
  String get postRestoreOutcomeNextStepLocked =>
      'One more step: complete biometric or screen-lock verification.';

  @override
  String get postRestoreOutcomeNextStepRecovery =>
      'One more step: enter the recovery key saved when this backup was created.';

  @override
  String get postRestoreOutcomeSecondaryHint =>
      'The first unlock after restore may take longer while the search index rebuilds.';

  @override
  String get postRestoreOutcomePrimaryRetryVerification => 'Verify now';

  @override
  String get postRestoreOutcomePrimaryEnterRecoveryKey => 'Enter recovery key';

  @override
  String get postRestoreOutcomeUnlockFailedTitle =>
      'Could not unlock after restore';

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
  String get sessionNoneModeLockedMessage =>
      'Session timed out in background. Restoring access…';

  @override
  String get sessionKeystoreMigrationMayReverifyMessage =>
      'Complete verification again if prompted to update unlock settings.';

  @override
  String get sessionStartupNeedsBiometricMessage =>
      'Complete biometric verification first.';

  @override
  String get legalPrivacyEffectiveDateLabel =>
      'Effective date: August 27, 2026';

  @override
  String get legalChildrenPrivacyOneLiner =>
      'This app is not designed for children aged 13 or under and does not knowingly collect children\'s personal data.';

  @override
  String get legalBrandDisclaimer =>
      'The Quill Diary name, icon, and Google Play Store listing are author branding and are not transferred with the code license.';

  @override
  String get legalBillingVaultPrivacyNote =>
      'The support flow does not read diary vault content.';

  @override
  String get legalBillingPrivacyOneLiner =>
      'Support payments are processed by Google Play as one-time purchases and unlock no extra features. The support flow does not read diary vault content.';

  @override
  String get legalBillingSupportPageBody =>
      'Support is offered only through Google Play Billing as one-time support purchases, not subscriptions or memberships. Google processes payments; the developer does not store support records. The support flow does not read diary vault content.';

  @override
  String get legalExternalLinkUnavailableMessage =>
      'Unable to open the browser. Please try again later.';

  @override
  String get settingsLegalSectionTitle => 'Legal & Privacy';

  @override
  String get settingsLegalSectionDescription =>
      'View source code, privacy policy, and third-party notices on GitHub; open an Issue if you have questions.';

  @override
  String get settingsLegalSourceCodeTitle => 'GitHub Source Code';

  @override
  String get settingsLegalPrivacyPolicyTitle => 'Privacy Policy';

  @override
  String get settingsLegalThirdPartyNoticesTitle => 'Third-Party Notices';

  @override
  String get settingsLegalContactAuthorTitle => 'Contact Author';

  @override
  String get aboutPageTitle => 'About';

  @override
  String get aboutTabIntroLabel => 'Intro';

  @override
  String get aboutTabIntroHeroTitle =>
      'Keep Your Private Diary in Your Own Hands';

  @override
  String get aboutTabIntroHeroBody =>
      'Quill Diary is a local, encrypted app for personal journaling with no account required. Create and safely store a recovery key to start writing, backing up, and exporting. Your data stays on your device unless you choose otherwise.';

  @override
  String get aboutTabIntroChip0 => 'Data Stays on Device';

  @override
  String get aboutTabIntroChip1 => 'Markdown / HTML';

  @override
  String get aboutTabIntroChip2 => 'Full-Text Search';

  @override
  String get aboutTabIntroChip3 => 'Full Backup';

  @override
  String get aboutTabIntroChip4 => 'Portable Export';

  @override
  String get aboutTabIntroSection0Title => 'Why It Works Well for Journaling';

  @override
  String get aboutTabIntroSection0Subtitle =>
      'Data storage and everyday features are both designed around private personal journaling.';

  @override
  String get aboutTabIntroSection0Item0Title => 'Encrypted Local Storage';

  @override
  String get aboutTabIntroSection0Item0Body =>
      'Entries, attachments, people, drafts, and the search index stay encrypted on your device by default. Recovery settings and a small amount of supporting metadata are not separately encrypted, but remain in private app storage.';

  @override
  String get aboutTabIntroSection0Item1Title => 'Start without Signing Up';

  @override
  String get aboutTabIntroSection0Item1Body =>
      'No Quill Diary account is required. Set up a recovery key to start reading and writing. A Google account is needed only if you use Google Drive.';

  @override
  String get aboutTabIntroSection0Item2Title =>
      'Less Collection, Less Distraction';

  @override
  String get aboutTabIntroSection0Item2Body =>
      'The app has no ads or tracking SDKs and does not upload plaintext entry content to developer-controlled servers. Treat it as a private writing space built around privacy.';

  @override
  String get aboutTabIntroSection1Title => 'How You Can Use It';

  @override
  String get aboutTabIntroSection1Subtitle =>
      'From capturing the moment to reviewing later, common features are designed around personal journaling.';

  @override
  String get aboutTabIntroSection1Item0Title =>
      'Write What You Want to Remember';

  @override
  String get aboutTabIntroSection1Item0Body =>
      'Supports titles, dates, tags, images, and general attachments. Start writing a new entry immediately or read before editing an existing one. Export to Markdown or HTML when needed.';

  @override
  String get aboutTabIntroSection1Item1Title =>
      'View Your Entries from Different Angles';

  @override
  String get aboutTabIntroSection1Item1Body =>
      'The home screen offers list, calendar, tag, people, and overview views. Browse by time, revisit by date, or organize your life through tags, people, and stats.';

  @override
  String get aboutTabIntroSection1Item2Title => 'Find What You Wrote Before';

  @override
  String get aboutTabIntroSection1Item2Body =>
      'After unlock, search titles, tags, and body text to revisit a memory, find a keyword, or quickly review a period of time.';

  @override
  String get aboutTabIntroSection1Item3Title =>
      'Backups and Exports Serve Different Purposes';

  @override
  String get aboutTabIntroSection1Item3Body =>
      'Full backups restore the whole vault. Markdown and HTML are for reading, organizing, or moving content. Google Drive is an optional full-backup location, not real-time sync.';

  @override
  String get aboutTabIntroSection2Title => 'You Stay in Control of Your Data';

  @override
  String get aboutTabIntroSection2Subtitle =>
      'Backup, export, and unlock methods play different roles so you can keep your data and understand the risk boundaries.';

  @override
  String get aboutTabIntroSection2Item0Title =>
      'Trusted Device and Recovery Key';

  @override
  String get aboutTabIntroSection2Item0Body =>
      'Use screen lock or biometrics for everyday access. When you change devices, restore, or lose trusted status, the recovery key is the key to regaining access.';

  @override
  String get aboutTabIntroSection2Item1Title =>
      'Full Backups Restore the Vault';

  @override
  String get aboutTabIntroSection2Item1Body =>
      'Entries, attachments, and people stay encrypted in a full backup, but the ZIP container and some recovery, tag, and pinned-item metadata are not separately encrypted. It is for full restore, not direct reading.';

  @override
  String get aboutTabIntroSection2Item2Title =>
      'Protect Exported Content Yourself';

  @override
  String get aboutTabIntroSection2Item2Body =>
      'Markdown and HTML exports are good for reading, organizing, and moving content, but they are readable documents and are no longer protected like in-app encrypted storage.';

  @override
  String get aboutTabIntroSection3Title => 'Open Source and Branding';

  @override
  String get aboutTabIntroSection3Subtitle =>
      'Review the source code and license terms, and understand branding boundaries clearly.';

  @override
  String get aboutTabIntroSection3Item0Title =>
      'Open Source Under AGPL-3.0-or-later';

  @override
  String get aboutTabIntroSection3Item0Body =>
      'Source code is released under AGPL-3.0-or-later for public review. Android is currently the only supported platform.';

  @override
  String get aboutTabIntroSection3Item1Title => 'Quill Diary Branding';

  @override
  String get aboutTabUnlockSessionLabel => 'Unlock & Security';

  @override
  String get aboutTabUnlockSessionHeroTitle =>
      'Convenient Access without Relaxing Protection';

  @override
  String get aboutTabUnlockSessionHeroBody =>
      'Choose no extra verification, device screen lock, or biometrics. Background timeout and the reason for locking determine when you verify again. Device changes, restores, or lost trusted status may require the recovery key.';

  @override
  String get aboutTabUnlockSessionChip0 => 'Biometrics';

  @override
  String get aboutTabUnlockSessionChip1 => 'Screen Lock';

  @override
  String get aboutTabUnlockSessionChip2 => 'Auto-Lock';

  @override
  String get aboutTabUnlockSessionChip3 => 'Recovery Key';

  @override
  String get aboutTabUnlockSessionSection0Title => 'Choosing an Unlock Method';

  @override
  String get aboutTabUnlockSessionSection0Subtitle =>
      'Choose the unlock method in Settings based on your device habits and desired protection level.';

  @override
  String get aboutTabUnlockSessionSection0Item0Title => 'None';

  @override
  String get aboutTabUnlockSessionSection0Item0Body =>
      'After a background-timeout lock, access resumes without system verification. After manual lock, you still need to tap Re-verify. This is convenient but offers the least protection.';

  @override
  String get aboutTabUnlockSessionSection0Item1Title => 'Device Screen Lock';

  @override
  String get aboutTabUnlockSessionSection0Item1Body =>
      'Re-verify with PIN, pattern, or password when returning to the app. Good if you want system-level protection without relying on biometrics.';

  @override
  String get aboutTabUnlockSessionSection0Item2Title => 'Biometrics';

  @override
  String get aboutTabUnlockSessionSection0Item2Body =>
      'Prefer fingerprint or face verification. Depending on the device and system prompt, screen lock may be offered as a fallback. This is usually the most convenient daily option.';

  @override
  String get aboutTabUnlockSessionSection0Item3Title => 'Shared Requirements';

  @override
  String get aboutTabUnlockSessionSection0Item3Body =>
      'Screen lock and biometric modes require a device screen lock first. Biometrics must also be enrolled in system settings.';

  @override
  String get aboutTabUnlockSessionSection1Title =>
      'When Re-Verification Happens';

  @override
  String get aboutTabUnlockSessionSection1Subtitle =>
      'Entries, drafts, attachments, and search data are available only during a valid unlocked session.';

  @override
  String get aboutTabUnlockSessionSection1Item0Title =>
      'During a Valid Unlocked Session';

  @override
  String get aboutTabUnlockSessionSection1Item0Body =>
      'Once unlocked, you can read and write entries, edit drafts, add attachments, and search. Until a recovery key is created, diary content remains unavailable even if the home screen is visible.';

  @override
  String get aboutTabUnlockSessionSection1Item1Title => 'Background Timeout';

  @override
  String get aboutTabUnlockSessionSection1Item2Title =>
      'When Returning to the App';

  @override
  String get aboutTabUnlockSessionSection1Item2Body =>
      'A brief app switch usually does not trigger immediate re-verification. After a longer background stay, your chosen mode decides whether to verify again. Locking only pauses access; it does not delete your entries.';

  @override
  String get aboutTabUnlockSessionSection1Item3Title =>
      'After Cancelled or Failed Verification';

  @override
  String get aboutTabUnlockSessionSection1Item3Body =>
      'If verification is cancelled or unsuccessful, the app stays locked and stops retrying automatically. Tap Re-verify when you want to try again.';

  @override
  String get aboutTabUnlockSessionSection1Item4Title => 'After Manual Lock';

  @override
  String get aboutTabUnlockSessionSection1Item4Body =>
      'After manual lock from Settings, return to the app and tap Re-verify. It will not unlock automatically.';

  @override
  String get aboutTabUnlockSessionSection2Title =>
      'Why a Recovery Key Is Still Needed';

  @override
  String get aboutTabUnlockSessionSection2Subtitle =>
      'Screen lock and biometrics simplify daily access. Device changes, restores, or lost trusted status may still require the recovery key.';

  @override
  String get aboutTabUnlockSessionSection2Item0Title =>
      'After Device Change or Reset';

  @override
  String get aboutTabUnlockSessionSection2Item0Body =>
      'When you change phones, clear app data, or restore on another device, trusted device status usually does not carry over. The recovery key is required then.';

  @override
  String get aboutTabUnlockSessionSection2Item1Title =>
      'Trusted Status Expires';

  @override
  String get aboutTabUnlockSessionSection2Item1Body =>
      'If trusted status expires or no longer matches the vault, local quick access is not enough. Use the recovery key instead.';

  @override
  String get aboutTabUnlockSessionSection2Item2Title => 'Store It Safely';

  @override
  String get aboutTabUnlockSessionSection2Item2Body =>
      'The recovery key is an important way to regain access after changing devices, restoring, or losing trusted status. If it is lost, the vault may be unrecoverable, so keep a separate copy in a safe place.';

  @override
  String get aboutTabEncryptionLabel => 'Data Encryption';

  @override
  String get aboutTabEncryptionHeroTitle =>
      'Data Is Stored Encrypted by Default';

  @override
  String get aboutTabEncryptionHeroBody =>
      'Entries, attachments, people, and drafts use the LDJ2 format with AES-256-GCM encryption, while the search index is encrypted separately. The app can read or write this content only during a valid unlocked session.';

  @override
  String get aboutTabEncryptionChip0 => 'Local Encryption';

  @override
  String get aboutTabEncryptionChip1 => 'Encrypted Files';

  @override
  String get aboutTabEncryptionChip2 => 'Content Encryption';

  @override
  String get aboutTabEncryptionChip3 => 'Key Protection';

  @override
  String get aboutTabEncryptionChip4 => 'Trusted Device';

  @override
  String get aboutTabEncryptionChip5 => 'Device Secure Storage';

  @override
  String get aboutTabEncryptionSection0Title =>
      'What This Protection Does for You';

  @override
  String get aboutTabEncryptionSection0Subtitle =>
      'Content is encrypted before it is stored and opened through the current valid unlocked session when needed.';

  @override
  String get aboutTabEncryptionSection0Item0Title =>
      'Encrypted Sensitive Content';

  @override
  String get aboutTabEncryptionSection0Item0Body =>
      'Saved entries, attachments, people, and drafts use AES-256-GCM encryption. Even with the files, their contents cannot be read directly.';

  @override
  String get aboutTabEncryptionSection0Item1Title =>
      'Stop When Tampering Is Detected';

  @override
  String get aboutTabEncryptionSection0Item1Body =>
      'Encrypted files are integrity-checked. If their contents or headers are modified, decryption fails instead of treating unverifiable data as normal content.';

  @override
  String get aboutTabEncryptionSection0Item2Title =>
      'Different Files Use Different Keys';

  @override
  String get aboutTabEncryptionSection0Item2Body =>
      'Each encrypted file uses an independently generated key instead of sharing one file key across all content.';

  @override
  String get aboutTabEncryptionSection1Title => 'How You Open Your Own Data';

  @override
  String get aboutTabEncryptionSection1Subtitle =>
      'Everyday and emergency paths differ, but both end in the same decryption flow.';

  @override
  String get aboutTabEncryptionSection1Item0Title => 'Trusted Device';

  @override
  String get aboutTabEncryptionSection1Item0Body =>
      'Daily access usually goes through screen lock or biometrics. Vault keys are protected by built-in device security.';

  @override
  String get aboutTabEncryptionSection1Item1Title => 'Recovery Key';

  @override
  String get aboutTabEncryptionSection1Item1Body =>
      'When you change devices, restore a backup, or lose local trusted status, the recovery key can restore access to the vault.';

  @override
  String get aboutTabEncryptionSection1Item2Title =>
      'Verify the Vault First, Then Open Each File';

  @override
  String get aboutTabEncryptionSection1Item2Body =>
      'The app confirms that you can enter the vault before opening its files, avoiding a wrong key being mistaken for damaged data.';

  @override
  String get aboutTabEncryptionSection2Title => 'Boundaries to Understand';

  @override
  String get aboutTabEncryptionSection2Subtitle =>
      'Content files are encrypted, but recovery and supporting metadata, readable exports, and unlocked use have different risks.';

  @override
  String get aboutTabEncryptionSection2Item0Title =>
      'Exports Use a Different Protection Layer';

  @override
  String get aboutTabEncryptionSection2Item0Body =>
      'Once you export to Markdown or HTML, storage and sharing risks for readable documents are no longer handled by in-app encryption.';

  @override
  String get aboutTabEncryptionSection2Item1Title =>
      'Keep Your Recovery Key Safe';

  @override
  String get aboutTabEncryptionSection2Item1Body =>
      'The recovery key is essential for re-entering the vault. If it leaks, is lost, or is not stored safely, security and recoverability may be affected.';

  @override
  String get aboutTabEncryptionSection2Item2Title =>
      'Protect the Device While Unlocked';

  @override
  String get aboutTabEncryptionSection2Item2Body =>
      'Encryption mainly protects stored data. Someone with access to an unlocked app or compromised device may still read content that is currently available.';

  @override
  String get aboutTabSearchIndexLabel => 'Search';

  @override
  String get aboutTabSearchIndexHeroTitle =>
      'Find Past Entries Quickly After Unlock';

  @override
  String get aboutTabSearchIndexHeroBody =>
      'The app uses encrypted search data for faster lookup instead of reading every entry each time. Search is available only while the vault is unlocked.';

  @override
  String get aboutTabSearchIndexChip0 => 'Title/Body Search';

  @override
  String get aboutTabSearchIndexChip1 => 'Encrypted Index';

  @override
  String get aboutTabSearchIndexChip2 => 'Available While Unlocked';

  @override
  String get aboutTabSearchIndexChip3 => 'Rebuildable';

  @override
  String get aboutTabSearchIndexSection0Title => 'What Search Helps You Find';

  @override
  String get aboutTabSearchIndexSection0Subtitle =>
      'Useful when reviewing, organizing, or narrowing down a memory quickly.';

  @override
  String get aboutTabSearchIndexSection0Item0Title =>
      'Search Titles, Tags, and Body Text';

  @override
  String get aboutTabSearchIndexSection0Item0Body =>
      'Search keywords in titles, body text, and tags without scrolling through every entry.';

  @override
  String get aboutTabSearchIndexSection0Item1Title =>
      'Results Come from Saved Entries';

  @override
  String get aboutTabSearchIndexSection0Item1Body =>
      'Search shows content already saved to the vault, not drafts still in the editor.';

  @override
  String get aboutTabSearchIndexSection0Item2Title =>
      'The Index Itself Is Protected';

  @override
  String get aboutTabSearchIndexSection0Item2Body =>
      'The search index file is encrypted at rest. The app opens and queries its search data only after the vault is unlocked.';

  @override
  String get aboutTabSearchIndexSection1Title =>
      'How the Index Speeds Up Search';

  @override
  String get aboutTabSearchIndexSection1Subtitle =>
      'Lookup work goes to the index layer instead of scanning every saved entry each time.';

  @override
  String get aboutTabSearchIndexSection1Item0Title => 'Index for Speed';

  @override
  String get aboutTabSearchIndexSection1Item0Body =>
      'When you enter a keyword, the app queries the search index instead of decrypting the entire vault entry by entry.';

  @override
  String get aboutTabSearchIndexSection1Item1Title => 'Updates Only After Save';

  @override
  String get aboutTabSearchIndexSection1Item1Body =>
      'The index updates only after a successful save or import, so results do not mix in drafts.';

  @override
  String get aboutTabSearchIndexSection1Item2Title =>
      'Can Be Rebuilt When Needed';

  @override
  String get aboutTabSearchIndexSection1Item2Body =>
      'The search index is rebuildable derived data. The app rebuilds it after format changes, backup restore, or whenever the existing index cannot be reused.';

  @override
  String get aboutTabSearchIndexSection2Title => 'How It Relates to Security';

  @override
  String get aboutTabSearchIndexSection2Subtitle =>
      'Useful search does not mean giving up protection boundaries.';

  @override
  String get aboutTabSearchIndexSection2Item0Title =>
      'Available Only While Unlocked';

  @override
  String get aboutTabSearchIndexSection2Item0Body =>
      'The index is built, updated, and used only while unlocked; it closes when the app locks.';

  @override
  String get aboutTabSearchIndexSection2Item1Title =>
      'Drafts Are Not Searchable';

  @override
  String get aboutTabSearchIndexSection2Item1Body =>
      'Drafts in progress do not appear in search results, avoiding unfinished content being treated as final records.';

  @override
  String get aboutTabSearchIndexSection2Item2Title =>
      'The Vault Remains the Source of Truth';

  @override
  String get aboutTabSearchIndexSection2Item2Body =>
      'The search index only helps you find content quickly. Saved entries in the encrypted vault remain the source of truth.';

  @override
  String get aboutTabEditorLabel => 'Writing';

  @override
  String get aboutTabEditorHeroTitle => 'Write Safely, Then Save When Ready';

  @override
  String get aboutTabEditorHeroBody =>
      'Edits are first kept as encrypted drafts. After you confirm save, the app writes the saved entry and updates search data, making it easier to continue after an interruption.';

  @override
  String get aboutTabEditorChip0 => 'Markdown Editing';

  @override
  String get aboutTabEditorChip1 => 'Image Attachments';

  @override
  String get aboutTabEditorChip2 => 'Auto Drafts';

  @override
  String get aboutTabEditorChip3 => 'Unsaved Reminders';

  @override
  String get aboutTabEditorSection0Title => 'Everyday Writing Features';

  @override
  String get aboutTabEditorSection0Subtitle =>
      'Built around personal records, with common organization tools split into clearer parts of the same editing flow.';

  @override
  String get aboutTabEditorSection0Item0Title =>
      'Create or Edit Existing Entries';

  @override
  String get aboutTabEditorSection0Item0Body =>
      'New entries open directly in edit mode. Existing ones can be read first and edited when you decide to change them.';

  @override
  String get aboutTabEditorSection0Item1Title => 'Content, Title, and Date';

  @override
  String get aboutTabEditorSection0Item1Body =>
      'Edit the title, date, time, and body. Saving requires at least a title or body so the diary does not accumulate blank entries.';

  @override
  String get aboutTabEditorSection0Item2Title => 'Tags';

  @override
  String get aboutTabEditorSection0Item2Body =>
      'Create, select, and organize tags, and use colors to distinguish them. Browse from the Tags view later or search the tag text directly.';

  @override
  String get aboutTabEditorSection0Item3Title => 'Task Lists';

  @override
  String get aboutTabEditorSection0Item3Body =>
      'Add task lists within your writing, check items, and continue editing normally. Checkboxes also remain interactive in preview.';

  @override
  String get aboutTabEditorSection0Item4Title =>
      'Images and General Attachments';

  @override
  String get aboutTabEditorSection0Item4Body =>
      'Add multiple images or general files and reorder images. Entries can preserve more than text by keeping context and materials from the moment.';

  @override
  String get aboutTabEditorSection1Title => 'Draft System';

  @override
  String get aboutTabEditorSection1Subtitle =>
      'Automatic drafts reduce the risk of losing changes when writing is interrupted.';

  @override
  String get aboutTabEditorSection1Item0Title => 'Changes Are Auto-Saved';

  @override
  String get aboutTabEditorSection1Item0Body =>
      'After entering edit mode, changes auto-save as encrypted drafts to reduce loss if interrupted.';

  @override
  String get aboutTabEditorSection1Item1Title => 'Restore When Reopening';

  @override
  String get aboutTabEditorSection1Item1Body =>
      'When reopening the same entry or unfinished new content, if a local draft remains, the app asks whether to continue where you left off.';

  @override
  String get aboutTabEditorSection1Item2Title => 'Auto Cleanup After Save';

  @override
  String get aboutTabEditorSection1Item2Body =>
      'After content is saved to the vault, drafts are cleared. If you cancel editing without new changes, old drafts do not pile up.';

  @override
  String get aboutTabEditorSection2Title => 'Relationship to Other Data';

  @override
  String get aboutTabEditorSection2Subtitle =>
      'Content being edited and saved content have clear boundaries so they are not mixed up.';

  @override
  String get aboutTabEditorSection2Item0Title =>
      'Drafts Are Excluded from Search';

  @override
  String get aboutTabEditorSection2Item0Body =>
      'Search only covers content saved to the vault. Drafts do not appear in results, so unfinished content is not mistaken for final records.';

  @override
  String get aboutTabEditorSection2Item1Title =>
      'Drafts Are Excluded from Full Backup';

  @override
  String get aboutTabEditorSection2Item1Body =>
      'Full backups include only the main vault, not local drafts that have not been formally saved. Import and export flows do not treat those drafts as final data either.';

  @override
  String get aboutTabEditorSection2Item2Title => 'Unsaved Indicator';

  @override
  String get aboutTabEditorSection2Item2Body =>
      'If an entry still has a local draft, list and view modes show an unsaved marker reminding you that the content has not been saved yet.';

  @override
  String get aboutTabPeopleLabel => 'People';

  @override
  String get aboutTabPeopleHeroTitle =>
      'Organize the Important People in Your Diary';

  @override
  String get aboutTabPeopleHeroBody =>
      'Create profiles for important people in your life. The app finds their names and aliases in saved entries so you can revisit related records.';

  @override
  String get aboutTabPeopleChip0 => 'Names & Aliases';

  @override
  String get aboutTabPeopleChip1 => 'Relationships & Notes';

  @override
  String get aboutTabPeopleChip2 => 'Mention Insights';

  @override
  String get aboutTabPeopleChip3 => 'Quick @ Insert';

  @override
  String get aboutTabPeopleSection0Title => 'Create and Organize People';

  @override
  String get aboutTabPeopleSection0Subtitle =>
      'Keep the details that help identify each person and describe your relationship.';

  @override
  String get aboutTabPeopleSection0Item0Title => 'Names and Aliases';

  @override
  String get aboutTabPeopleSection0Item0Body =>
      'Create a person with their main name and add nicknames or other names. When renaming someone, keep the old name as an alias so past entries can still be recognized.';

  @override
  String get aboutTabPeopleSection0Item1Title =>
      'Relationships and Familiarity';

  @override
  String get aboutTabPeopleSection0Item1Body =>
      'Record one or more relationships, add a description and familiarity level, then use a color and notes as helpful reminders.';

  @override
  String get aboutTabPeopleSection0Item2Title => 'Birthday and Year Met';

  @override
  String get aboutTabPeopleSection0Item2Body =>
      'Optionally record the month and day of a birthday and the year you met to preserve important moments in the relationship.';

  @override
  String get aboutTabPeopleSection1Title => 'Revisit Your Shared Stories';

  @override
  String get aboutTabPeopleSection1Subtitle =>
      'When you use People, the app updates rebuildable mention insights from names and aliases so related records are easier to review.';

  @override
  String get aboutTabPeopleSection1Item0Title => 'Recognize Names and Aliases';

  @override
  String get aboutTabPeopleSection1Item0Body =>
      'The app matches a person\'s main name and aliases against titles and content in encrypted search data instead of decrypting the entire vault entry by entry each time.';

  @override
  String get aboutTabPeopleSection1Item1Title => 'Review Mentions and Entries';

  @override
  String get aboutTabPeopleSection1Item1Body =>
      'A person\'s page shows total mentions, mentions in the past 30 days, the latest mention, and related entries. The people list can also be sorted using these details.';

  @override
  String get aboutTabPeopleSection1Item2Title => 'Insert a Name Quickly with @';

  @override
  String get aboutTabPeopleSection1Item2Body =>
      'Type @ in the entry editor to choose a person and insert their chosen diary name (the main name by default, or an alias you pick). It remains ordinary text and does not turn the entry into a special format.';

  @override
  String get aboutTabPeopleSection2Title => 'Good to Know';

  @override
  String get aboutTabPeopleSection2Subtitle =>
      'People helps organize your diary without replacing or rewriting saved content.';

  @override
  String get aboutTabPeopleSection2Item0Title => 'Insights Use Saved Entries';

  @override
  String get aboutTabPeopleSection2Item0Body =>
      'Mention insights use saved entries only; drafts appear after they are saved. The derived insights are excluded from full backups and can be rebuilt after restore.';

  @override
  String get aboutTabPeopleSection2Item1Title =>
      'Deleting a Person Keeps Your Entries';

  @override
  String get aboutTabPeopleSection2Item1Body =>
      'Deleting a person removes their profile and related insights, while the original entry text and content remain unchanged.';

  @override
  String get aboutTabPeopleSection2Item2Title => 'Clearer Names Match Better';

  @override
  String get aboutTabPeopleSection2Item2Body =>
      'Very short or overlapping names and aliases can cause incorrect matches. More specific names help keep mention insights accurate.';

  @override
  String get aboutTabBackupRestoreLabel => 'Backup & Restore';

  @override
  String get aboutTabBackupRestoreHeroTitle =>
      'Keep the Whole Vault or Export Readable Content';

  @override
  String get aboutTabBackupRestoreHeroBody =>
      'Full backup preserves and restores the whole vault. Markdown and HTML exports turn saved content into readable, organizable documents. Their formats and purposes differ, so neither replaces the other.';

  @override
  String get aboutTabBackupRestoreChip0 => 'Full Backup';

  @override
  String get aboutTabBackupRestoreChip1 => 'Google Drive';

  @override
  String get aboutTabBackupRestoreChip2 => 'Markdown';

  @override
  String get aboutTabBackupRestoreChip3 => 'HTML';

  @override
  String get aboutTabBackupRestoreSection0Title => 'When to Use Full Backup';

  @override
  String get aboutTabBackupRestoreSection0Subtitle =>
      'If you want to preserve the entire main vault and restore it later as-is, use full backup.';

  @override
  String get aboutTabBackupRestoreSection0Item0Title =>
      'Preserve the Complete Vault';

  @override
  String get aboutTabBackupRestoreSection0Item0Body =>
      'A full backup includes entries, attachments, people, and recovery settings. Entry content stays encrypted, but the backup container, recovery metadata, and any tag catalog or pinned-item IDs are not separately encrypted.';

  @override
  String get aboutTabBackupRestoreSection0Item1Title =>
      'Verified After Creation';

  @override
  String get aboutTabBackupRestoreSection0Item1Body =>
      'Full backups are structurally verified before delivery to local storage, external folders, or Google Drive.';

  @override
  String get aboutTabBackupRestoreSection0Item2Title => 'Retention Count';

  @override
  String aboutTabBackupRestoreSection0Item2Body(int retainCount) {
    return 'Local backups and Google Drive keep the latest $retainCount copies. Exports to external folders are not automatically rotated or deleted.';
  }

  @override
  String get aboutTabBackupRestoreSection1Title =>
      'What Happens During Restore';

  @override
  String get aboutTabBackupRestoreSection1Subtitle =>
      'Restore does not patch missing entries. It replaces the current main vault with the backup copy.';

  @override
  String get aboutTabBackupRestoreSection1Item0Title =>
      'The Main Vault Is Overwritten';

  @override
  String get aboutTabBackupRestoreSection1Item0Body =>
      'Whether the backup comes from the in-app list, an external ZIP, or Google Drive, restore replaces the current saved vault with the backup contents.';

  @override
  String get aboutTabBackupRestoreSection1Item1Title =>
      'The Search Index Is Rebuilt';

  @override
  String get aboutTabBackupRestoreSection1Item1Body =>
      'Search data is rebuilt after restore, and you may need to verify again. On the same device with a valid unlocked session, you may sometimes continue directly.';

  @override
  String get aboutTabBackupRestoreSection1Item2Title =>
      'Recovery Key May Be Required';

  @override
  String get aboutTabBackupRestoreSection1Item2Body =>
      'If trusted status on this device cannot directly match that backup, the flow asks for the recovery key saved when the backup was created.';

  @override
  String get aboutTabBackupRestoreSection2Title => 'When Import and Export Fit';

  @override
  String get aboutTabBackupRestoreSection2Subtitle =>
      'This flow handles content exchange and reading, not fully restoring the entire vault.';

  @override
  String get aboutTabBackupRestoreSection2Item0Title => 'Import';

  @override
  String get aboutTabBackupRestoreSection2Item0Body =>
      'Import Entries handles Markdown, HTML, folders, supported portable ZIP files, and Easy Diary backups. Quill Diary full-backup ZIP files must use Import External Backup instead; the two flows are not interchangeable.';

  @override
  String get aboutTabBackupRestoreSection2Item1Title => 'Export';

  @override
  String get aboutTabBackupRestoreSection2Item1Body =>
      'Export Markdown from Settings, or export HTML from the home screen or Overview, for reading, organizing, or moving saved content.';

  @override
  String get aboutTabBackupRestoreSection2Item2Title => 'Not a Sync Service';

  @override
  String get aboutTabBackupRestoreSection2Item2Body =>
      'Google Drive is a manually operated full-backup location, not cross-device real-time sync. Upload can continue in the background after handoff; if interrupted before remote verification, create the backup again.';

  @override
  String get aboutTabBackupRestoreSection3Title => 'Things to Know Before Use';

  @override
  String get aboutTabBackupRestoreSection3Subtitle =>
      'Backup and export both matter, but they protect different things with different responsibility boundaries.';

  @override
  String get aboutTabBackupRestoreSection3Item0Title =>
      'Full Backup Excludes Drafts';

  @override
  String get aboutTabBackupRestoreSection3Item0Body =>
      'Full backup does not include local drafts still being edited. Restoring a backup also clears all drafts and pending attachments on this device.';

  @override
  String get aboutTabBackupRestoreSection3Item1Title =>
      'Protect Readable Exports Yourself';

  @override
  String get aboutTabBackupRestoreSection3Item1Body =>
      'Markdown and HTML exports are for reading, organizing, and moving content, but they are no longer in-app encrypted formats. You decide how to store them afterward.';

  @override
  String get aboutTabBackupRestoreSection3Item2Title =>
      'Do Not Mix the Two Flows';

  @override
  String get aboutTabBackupRestoreSection3Item2Body =>
      'Use full backup if you want to restore the entire vault later. Use Markdown or HTML export if you want to read or organize content outside the app.';
}
