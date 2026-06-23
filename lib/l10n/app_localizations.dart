import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('zh'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In zh, this message translates to:
  /// **'Quill Diary'**
  String get appTitle;

  /// No description provided for @languageNameZh.
  ///
  /// In zh, this message translates to:
  /// **'繁體中文'**
  String get languageNameZh;

  /// No description provided for @languageNameEn.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get languageNameEn;

  /// No description provided for @commonActionCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get commonActionCancel;

  /// No description provided for @commonActionDelete.
  ///
  /// In zh, this message translates to:
  /// **'刪除'**
  String get commonActionDelete;

  /// No description provided for @commonActionApply.
  ///
  /// In zh, this message translates to:
  /// **'套用'**
  String get commonActionApply;

  /// No description provided for @commonActionClose.
  ///
  /// In zh, this message translates to:
  /// **'關閉'**
  String get commonActionClose;

  /// No description provided for @commonReadFailureTitle.
  ///
  /// In zh, this message translates to:
  /// **'讀取失敗'**
  String get commonReadFailureTitle;

  /// No description provided for @commonConfirmDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'確認刪除'**
  String get commonConfirmDeleteTitle;

  /// No description provided for @commonNoTagSearchResults.
  ///
  /// In zh, this message translates to:
  /// **'沒有符合的標籤'**
  String get commonNoTagSearchResults;

  /// No description provided for @commonCloseTooltip.
  ///
  /// In zh, this message translates to:
  /// **'關閉'**
  String get commonCloseTooltip;

  /// No description provided for @commonClearSearchTooltip.
  ///
  /// In zh, this message translates to:
  /// **'清除搜尋'**
  String get commonClearSearchTooltip;

  /// No description provided for @commonUnitEntries.
  ///
  /// In zh, this message translates to:
  /// **'篇'**
  String get commonUnitEntries;

  /// No description provided for @commonUnitTags.
  ///
  /// In zh, this message translates to:
  /// **'筆'**
  String get commonUnitTags;

  /// No description provided for @commonUnitImages.
  ///
  /// In zh, this message translates to:
  /// **'張'**
  String get commonUnitImages;

  /// No description provided for @commonUnitAttachments.
  ///
  /// In zh, this message translates to:
  /// **'個附件'**
  String get commonUnitAttachments;

  /// No description provided for @commonUnitDays.
  ///
  /// In zh, this message translates to:
  /// **'天'**
  String get commonUnitDays;

  /// No description provided for @commonUnitCharacters.
  ///
  /// In zh, this message translates to:
  /// **'字'**
  String get commonUnitCharacters;

  /// No description provided for @commonUnitMilliseconds.
  ///
  /// In zh, this message translates to:
  /// **'毫秒'**
  String get commonUnitMilliseconds;

  /// No description provided for @commonUnitSeconds.
  ///
  /// In zh, this message translates to:
  /// **'秒'**
  String get commonUnitSeconds;

  /// No description provided for @userFacingErrorDefaultMessage.
  ///
  /// In zh, this message translates to:
  /// **'操作失敗，請稍後再試。'**
  String get userFacingErrorDefaultMessage;

  /// No description provided for @userFacingErrorLocalPathLabel.
  ///
  /// In zh, this message translates to:
  /// **'本機路徑'**
  String get userFacingErrorLocalPathLabel;

  /// No description provided for @commonGoogleAccountLabel.
  ///
  /// In zh, this message translates to:
  /// **'{name} · {email}'**
  String commonGoogleAccountLabel(String name, String email);

  /// No description provided for @commonConfirmDeleteEntries.
  ///
  /// In zh, this message translates to:
  /// **'確定要刪除 {count} 篇日記嗎？刪除後無法復原。'**
  String commonConfirmDeleteEntries(int count);

  /// No description provided for @tagAddTitle.
  ///
  /// In zh, this message translates to:
  /// **'新增標籤'**
  String get tagAddTitle;

  /// No description provided for @tagEditTitle.
  ///
  /// In zh, this message translates to:
  /// **'編輯標籤'**
  String get tagEditTitle;

  /// No description provided for @tagSaveButton.
  ///
  /// In zh, this message translates to:
  /// **'儲存'**
  String get tagSaveButton;

  /// No description provided for @tagNameHint.
  ///
  /// In zh, this message translates to:
  /// **'標籤名稱'**
  String get tagNameHint;

  /// No description provided for @tagNameRequiredMessage.
  ///
  /// In zh, this message translates to:
  /// **'請輸入標籤名稱'**
  String get tagNameRequiredMessage;

  /// No description provided for @tagDeleteLabel.
  ///
  /// In zh, this message translates to:
  /// **'刪除標籤'**
  String get tagDeleteLabel;

  /// No description provided for @tagUnnamedPreview.
  ///
  /// In zh, this message translates to:
  /// **'未命名標籤'**
  String get tagUnnamedPreview;

  /// No description provided for @tagDefaultColorLabel.
  ///
  /// In zh, this message translates to:
  /// **'預設色'**
  String get tagDefaultColorLabel;

  /// No description provided for @tagHueLabel.
  ///
  /// In zh, this message translates to:
  /// **'色相'**
  String get tagHueLabel;

  /// No description provided for @tagPreviewLabel.
  ///
  /// In zh, this message translates to:
  /// **'預覽'**
  String get tagPreviewLabel;

  /// No description provided for @tagSaveFailure.
  ///
  /// In zh, this message translates to:
  /// **'儲存標籤失敗：{message}'**
  String tagSaveFailure(String message);

  /// No description provided for @tagDeleteFailure.
  ///
  /// In zh, this message translates to:
  /// **'刪除標籤失敗：{message}'**
  String tagDeleteFailure(String message);

  /// No description provided for @personalizationNavButtonLabel.
  ///
  /// In zh, this message translates to:
  /// **'個人化'**
  String get personalizationNavButtonLabel;

  /// No description provided for @personalizationPageTitle.
  ///
  /// In zh, this message translates to:
  /// **'個人化'**
  String get personalizationPageTitle;

  /// No description provided for @personalizationLoadErrorMessage.
  ///
  /// In zh, this message translates to:
  /// **'無法載入個人化設定。'**
  String get personalizationLoadErrorMessage;

  /// No description provided for @personalizationTypographyResetButton.
  ///
  /// In zh, this message translates to:
  /// **'還原預設'**
  String get personalizationTypographyResetButton;

  /// No description provided for @personalizationTypographyResetConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'還原日記排版預設？'**
  String get personalizationTypographyResetConfirmTitle;

  /// No description provided for @personalizationTypographyResetConfirmBody.
  ///
  /// In zh, this message translates to:
  /// **'這會把目前的標題、內文字體大小、行距與段落間距都還原成預設值。'**
  String get personalizationTypographyResetConfirmBody;

  /// No description provided for @personalizationTypographyResetConfirmAction.
  ///
  /// In zh, this message translates to:
  /// **'還原預設'**
  String get personalizationTypographyResetConfirmAction;

  /// No description provided for @personalizationTypographyResetSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已還原日記排版預設。'**
  String get personalizationTypographyResetSuccess;

  /// No description provided for @personalizationLanguageSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'語言'**
  String get personalizationLanguageSectionTitle;

  /// No description provided for @personalizationLanguageSectionDescription.
  ///
  /// In zh, this message translates to:
  /// **'選擇介面顯示語言。'**
  String get personalizationLanguageSectionDescription;

  /// No description provided for @personalizationSessionTimeoutSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'自動鎖定'**
  String get personalizationSessionTimeoutSectionTitle;

  /// No description provided for @personalizationSessionTimeoutSectionDescription.
  ///
  /// In zh, this message translates to:
  /// **'App 切到背景一段時間後，會自動要求重新驗證。'**
  String get personalizationSessionTimeoutSectionDescription;

  /// No description provided for @personalizationSessionTimeoutUnitLabel.
  ///
  /// In zh, this message translates to:
  /// **'分鐘'**
  String get personalizationSessionTimeoutUnitLabel;

  /// No description provided for @personalizationImageCompressSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'圖片品質'**
  String get personalizationImageCompressSectionTitle;

  /// No description provided for @personalizationImageCompressSectionDescription.
  ///
  /// In zh, this message translates to:
  /// **'調整編輯器插入圖片時的壓縮預設。'**
  String get personalizationImageCompressSectionDescription;

  /// No description provided for @personalizationImageCompressOriginalLabel.
  ///
  /// In zh, this message translates to:
  /// **'原圖'**
  String get personalizationImageCompressOriginalLabel;

  /// No description provided for @personalizationImageCompressStandardLabel.
  ///
  /// In zh, this message translates to:
  /// **'標準'**
  String get personalizationImageCompressStandardLabel;

  /// No description provided for @personalizationImageCompressHighLabel.
  ///
  /// In zh, this message translates to:
  /// **'高畫質'**
  String get personalizationImageCompressHighLabel;

  /// No description provided for @personalizationAppearanceSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'外觀'**
  String get personalizationAppearanceSectionTitle;

  /// No description provided for @personalizationAppearanceSectionDescription.
  ///
  /// In zh, this message translates to:
  /// **'選擇 App 使用淺色、深色或跟隨系統。'**
  String get personalizationAppearanceSectionDescription;

  /// No description provided for @personalizationAppearanceSystemLabel.
  ///
  /// In zh, this message translates to:
  /// **'跟隨系統'**
  String get personalizationAppearanceSystemLabel;

  /// No description provided for @personalizationAppearanceLightLabel.
  ///
  /// In zh, this message translates to:
  /// **'淺色'**
  String get personalizationAppearanceLightLabel;

  /// No description provided for @personalizationAppearanceDarkLabel.
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get personalizationAppearanceDarkLabel;

  /// No description provided for @personalizationTypographySectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'日記排版'**
  String get personalizationTypographySectionTitle;

  /// No description provided for @personalizationTypographySectionDescription.
  ///
  /// In zh, this message translates to:
  /// **'調整日記編輯與預覽時的字體大小、行距與段落間距。'**
  String get personalizationTypographySectionDescription;

  /// No description provided for @personalizationTitleFontSizeLabel.
  ///
  /// In zh, this message translates to:
  /// **'標題字體大小'**
  String get personalizationTitleFontSizeLabel;

  /// No description provided for @personalizationTitleLineHeightLabel.
  ///
  /// In zh, this message translates to:
  /// **'標題行距'**
  String get personalizationTitleLineHeightLabel;

  /// No description provided for @personalizationBodyFontSizeLabel.
  ///
  /// In zh, this message translates to:
  /// **'內文字體大小'**
  String get personalizationBodyFontSizeLabel;

  /// No description provided for @personalizationBodyLineHeightLabel.
  ///
  /// In zh, this message translates to:
  /// **'內文行距'**
  String get personalizationBodyLineHeightLabel;

  /// No description provided for @personalizationBodyParagraphSpacingLabel.
  ///
  /// In zh, this message translates to:
  /// **'內文段落間距'**
  String get personalizationBodyParagraphSpacingLabel;

  /// No description provided for @settingsPageTitle.
  ///
  /// In zh, this message translates to:
  /// **'設定'**
  String get settingsPageTitle;

  /// No description provided for @settingsProgressDefault.
  ///
  /// In zh, this message translates to:
  /// **'正在處理，請稍候…'**
  String get settingsProgressDefault;

  /// No description provided for @personalizationImageCompressOriginalDescription.
  ///
  /// In zh, this message translates to:
  /// **'不壓縮，保留原始解析度與檔案大小。適合需要最高畫質、可接受較大日記庫時使用。'**
  String get personalizationImageCompressOriginalDescription;

  /// No description provided for @personalizationImageCompressStandardDescription.
  ///
  /// In zh, this message translates to:
  /// **'長邊縮至 1280 px、JPEG 品質 70。在清晰度與儲存空間之間取得平衡（預設）。'**
  String get personalizationImageCompressStandardDescription;

  /// No description provided for @personalizationImageCompressHighDescription.
  ///
  /// In zh, this message translates to:
  /// **'長邊縮至 1920 px、JPEG 品質 85。檔案較大，但細節保留較多。'**
  String get personalizationImageCompressHighDescription;

  /// No description provided for @personalizationFontSizeValue.
  ///
  /// In zh, this message translates to:
  /// **'{size} 點'**
  String personalizationFontSizeValue(String size);

  /// No description provided for @personalizationLineHeightValue.
  ///
  /// In zh, this message translates to:
  /// **'{height} 倍'**
  String personalizationLineHeightValue(String height);

  /// No description provided for @personalizationParagraphSpacingValue.
  ///
  /// In zh, this message translates to:
  /// **'{spacing} 像素'**
  String personalizationParagraphSpacingValue(String spacing);

  /// No description provided for @personalizationTypographyPreviewTitleParagraph1.
  ///
  /// In zh, this message translates to:
  /// **'今日的小確幸，陽光剛好落在書桌上。值得記住的一刻，先寫下來再說。'**
  String get personalizationTypographyPreviewTitleParagraph1;

  /// No description provided for @personalizationTypographyPreviewBodyParagraph1.
  ///
  /// In zh, this message translates to:
  /// **'記錄下此刻的心情，讓文字替記憶保溫。記錄下此刻的心情，讓文字替記憶保溫。'**
  String get personalizationTypographyPreviewBodyParagraph1;

  /// No description provided for @personalizationTypographyPreviewBodyParagraph2.
  ///
  /// In zh, this message translates to:
  /// **'段落之間的間距，也會反映在預覽裡。段落之間的間距，也會反映在預覽裡。'**
  String get personalizationTypographyPreviewBodyParagraph2;

  /// No description provided for @sessionBlockedLockedTitle.
  ///
  /// In zh, this message translates to:
  /// **'日記庫已鎖定'**
  String get sessionBlockedLockedTitle;

  /// No description provided for @sessionBlockedRecoveryRequiredTitle.
  ///
  /// In zh, this message translates to:
  /// **'需要復原金鑰'**
  String get sessionBlockedRecoveryRequiredTitle;

  /// No description provided for @sessionBlockedFatalErrorTitle.
  ///
  /// In zh, this message translates to:
  /// **'無法啟動'**
  String get sessionBlockedFatalErrorTitle;

  /// No description provided for @sessionBlockedDefaultTitle.
  ///
  /// In zh, this message translates to:
  /// **'請稍候'**
  String get sessionBlockedDefaultTitle;

  /// No description provided for @sessionBlockedLockedSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'請完成驗證以繼續'**
  String get sessionBlockedLockedSubtitle;

  /// No description provided for @sessionBlockedRecoveryRequiredSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'請輸入復原金鑰解鎖'**
  String get sessionBlockedRecoveryRequiredSubtitle;

  /// No description provided for @sessionBlockedFatalErrorSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'請檢查設定或重新啟動應用程式'**
  String get sessionBlockedFatalErrorSubtitle;

  /// No description provided for @editorPageTitle.
  ///
  /// In zh, this message translates to:
  /// **'編輯日記'**
  String get editorPageTitle;

  /// No description provided for @editorTitleHint.
  ///
  /// In zh, this message translates to:
  /// **'輸入標題'**
  String get editorTitleHint;

  /// No description provided for @editorEntryRequiredError.
  ///
  /// In zh, this message translates to:
  /// **'請輸入標題或內容'**
  String get editorEntryRequiredError;

  /// No description provided for @editorBodyHint.
  ///
  /// In zh, this message translates to:
  /// **'在這裡輸入內容…'**
  String get editorBodyHint;

  /// No description provided for @editorBodyEmptyPreview.
  ///
  /// In zh, this message translates to:
  /// **'尚未輸入內容'**
  String get editorBodyEmptyPreview;

  /// No description provided for @editorNeedsRecoveryKeyMessage.
  ///
  /// In zh, this message translates to:
  /// **'請先建立復原金鑰，才能開始建立或編輯日記。'**
  String get editorNeedsRecoveryKeyMessage;

  /// No description provided for @editorSessionLockedFallback.
  ///
  /// In zh, this message translates to:
  /// **'請先重新解鎖日記庫後再繼續。'**
  String get editorSessionLockedFallback;

  /// No description provided for @editorSaveNeedsEntryMessage.
  ///
  /// In zh, this message translates to:
  /// **'請輸入標題或內容才能儲存'**
  String get editorSaveNeedsEntryMessage;

  /// No description provided for @editorUnsavedDraftLabel.
  ///
  /// In zh, this message translates to:
  /// **'未儲存'**
  String get editorUnsavedDraftLabel;

  /// No description provided for @editorConfirmDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'確認刪除'**
  String get editorConfirmDeleteTitle;

  /// No description provided for @editorConfirmDeleteBody.
  ///
  /// In zh, this message translates to:
  /// **'確定要刪除這篇日記嗎？刪除後無法復原。'**
  String get editorConfirmDeleteBody;

  /// No description provided for @editorTagsStudioTitle.
  ///
  /// In zh, this message translates to:
  /// **'標籤'**
  String get editorTagsStudioTitle;

  /// No description provided for @editorTagsStudioGuide.
  ///
  /// In zh, this message translates to:
  /// **'可從右上角建立新標籤，也可輕觸下方標籤庫中的標籤加入。'**
  String get editorTagsStudioGuide;

  /// No description provided for @editorTagsStudioEmptyChosen.
  ///
  /// In zh, this message translates to:
  /// **'尚未套用任何標籤'**
  String get editorTagsStudioEmptyChosen;

  /// No description provided for @editorTagsStudioAddButton.
  ///
  /// In zh, this message translates to:
  /// **'加入'**
  String get editorTagsStudioAddButton;

  /// No description provided for @editorPreviewUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'無法預覽'**
  String get editorPreviewUnavailable;

  /// No description provided for @editorTagSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜尋標籤…'**
  String get editorTagSearchHint;

  /// No description provided for @editorTagLibraryHint.
  ///
  /// In zh, this message translates to:
  /// **'標籤庫 · 輕觸加入'**
  String get editorTagLibraryHint;

  /// No description provided for @editorTagPoolEmpty.
  ///
  /// In zh, this message translates to:
  /// **'標籤庫中暫時沒有其他可用標籤，或已全部加入目前清單'**
  String get editorTagPoolEmpty;

  /// No description provided for @editorTagAddTooltip.
  ///
  /// In zh, this message translates to:
  /// **'新增標籤'**
  String get editorTagAddTooltip;

  /// No description provided for @editorTooltipCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get editorTooltipCancel;

  /// No description provided for @editorTooltipSave.
  ///
  /// In zh, this message translates to:
  /// **'儲存'**
  String get editorTooltipSave;

  /// No description provided for @editorTooltipSaveNeedsEntry.
  ///
  /// In zh, this message translates to:
  /// **'請先輸入標題或內容'**
  String get editorTooltipSaveNeedsEntry;

  /// No description provided for @editorTooltipDate.
  ///
  /// In zh, this message translates to:
  /// **'日期'**
  String get editorTooltipDate;

  /// No description provided for @editorTooltipTime.
  ///
  /// In zh, this message translates to:
  /// **'時間'**
  String get editorTooltipTime;

  /// No description provided for @editorTooltipEditTags.
  ///
  /// In zh, this message translates to:
  /// **'編輯標籤'**
  String get editorTooltipEditTags;

  /// No description provided for @editorTooltipUploadImages.
  ///
  /// In zh, this message translates to:
  /// **'上傳圖片（可一次選多張）'**
  String get editorTooltipUploadImages;

  /// No description provided for @editorTooltipAddAttachment.
  ///
  /// In zh, this message translates to:
  /// **'新增附件'**
  String get editorTooltipAddAttachment;

  /// No description provided for @editorTooltipDelete.
  ///
  /// In zh, this message translates to:
  /// **'刪除'**
  String get editorTooltipDelete;

  /// No description provided for @editorTooltipEdit.
  ///
  /// In zh, this message translates to:
  /// **'編輯'**
  String get editorTooltipEdit;

  /// No description provided for @editorRestoreDraftTitle.
  ///
  /// In zh, this message translates to:
  /// **'發現未完成的草稿'**
  String get editorRestoreDraftTitle;

  /// No description provided for @editorRestoreDraftDecline.
  ///
  /// In zh, this message translates to:
  /// **'不使用'**
  String get editorRestoreDraftDecline;

  /// No description provided for @editorRestoreDraftAccept.
  ///
  /// In zh, this message translates to:
  /// **'還原草稿'**
  String get editorRestoreDraftAccept;

  /// No description provided for @editorUntitledDraft.
  ///
  /// In zh, this message translates to:
  /// **'無標題'**
  String get editorUntitledDraft;

  /// No description provided for @editorRestoreDraftOverwrite.
  ///
  /// In zh, this message translates to:
  /// **'草稿：{title}\n最後儲存：{savedAt}\n\n還原後會覆蓋目前檢視中的內容。'**
  String editorRestoreDraftOverwrite(String title, String savedAt);

  /// No description provided for @editorRestoreDraftPrompt.
  ///
  /// In zh, this message translates to:
  /// **'草稿：{title}\n最後儲存：{savedAt}\n\n是否要還原這份草稿？'**
  String editorRestoreDraftPrompt(String title, String savedAt);

  /// No description provided for @editorDiscardDraftTitle.
  ///
  /// In zh, this message translates to:
  /// **'捨棄草稿？'**
  String get editorDiscardDraftTitle;

  /// No description provided for @editorDiscardDraftBody.
  ///
  /// In zh, this message translates to:
  /// **'目前的修改尚未儲存為日記，確定要捨棄草稿並離開嗎？'**
  String get editorDiscardDraftBody;

  /// No description provided for @editorDiscardDraftConfirm.
  ///
  /// In zh, this message translates to:
  /// **'捨棄'**
  String get editorDiscardDraftConfirm;

  /// No description provided for @editorGalleryDownloadTooltip.
  ///
  /// In zh, this message translates to:
  /// **'下載'**
  String get editorGalleryDownloadTooltip;

  /// No description provided for @editorGalleryDownloadFailed.
  ///
  /// In zh, this message translates to:
  /// **'無法下載圖片'**
  String get editorGalleryDownloadFailed;

  /// No description provided for @editorGalleryDownloadSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已儲存至 {path}'**
  String editorGalleryDownloadSuccess(String path);

  /// No description provided for @homeUnlockingTitle.
  ///
  /// In zh, this message translates to:
  /// **'正在解鎖'**
  String get homeUnlockingTitle;

  /// No description provided for @homeRetryVerification.
  ///
  /// In zh, this message translates to:
  /// **'重新驗證'**
  String get homeRetryVerification;

  /// No description provided for @homeGoToSettings.
  ///
  /// In zh, this message translates to:
  /// **'前往設定'**
  String get homeGoToSettings;

  /// No description provided for @homeNavHome.
  ///
  /// In zh, this message translates to:
  /// **'首頁'**
  String get homeNavHome;

  /// No description provided for @homeNavCalendar.
  ///
  /// In zh, this message translates to:
  /// **'日曆'**
  String get homeNavCalendar;

  /// No description provided for @homeNavTags.
  ///
  /// In zh, this message translates to:
  /// **'標籤'**
  String get homeNavTags;

  /// No description provided for @homeNavOverview.
  ///
  /// In zh, this message translates to:
  /// **'總覽'**
  String get homeNavOverview;

  /// No description provided for @homeTooltipNewEntry.
  ///
  /// In zh, this message translates to:
  /// **'新增日記'**
  String get homeTooltipNewEntry;

  /// No description provided for @homeTooltipSettings.
  ///
  /// In zh, this message translates to:
  /// **'設定與備份'**
  String get homeTooltipSettings;

  /// No description provided for @homeTooltipExportHtml.
  ///
  /// In zh, this message translates to:
  /// **'匯出 HTML'**
  String get homeTooltipExportHtml;

  /// No description provided for @homeTooltipDelete.
  ///
  /// In zh, this message translates to:
  /// **'刪除'**
  String get homeTooltipDelete;

  /// No description provided for @homeTooltipAddTag.
  ///
  /// In zh, this message translates to:
  /// **'新增標籤'**
  String get homeTooltipAddTag;

  /// No description provided for @homeTooltipEditTag.
  ///
  /// In zh, this message translates to:
  /// **'編輯標籤'**
  String get homeTooltipEditTag;

  /// No description provided for @homeTooltipDeleteTag.
  ///
  /// In zh, this message translates to:
  /// **'刪除標籤'**
  String get homeTooltipDeleteTag;

  /// No description provided for @homeTooltipBackToTop.
  ///
  /// In zh, this message translates to:
  /// **'返回頂部'**
  String get homeTooltipBackToTop;

  /// No description provided for @homeTooltipDeselectTag.
  ///
  /// In zh, this message translates to:
  /// **'取消選取'**
  String get homeTooltipDeselectTag;

  /// No description provided for @homeSelectionSelectAll.
  ///
  /// In zh, this message translates to:
  /// **'全選'**
  String get homeSelectionSelectAll;

  /// No description provided for @homeSelectionDeselectAll.
  ///
  /// In zh, this message translates to:
  /// **'取消全選'**
  String get homeSelectionDeselectAll;

  /// No description provided for @homeSelectionSelectDiary.
  ///
  /// In zh, this message translates to:
  /// **'選取日記'**
  String get homeSelectionSelectDiary;

  /// No description provided for @homeSelectionSelectedCount.
  ///
  /// In zh, this message translates to:
  /// **'已選 {count} 項'**
  String homeSelectionSelectedCount(int count);

  /// No description provided for @homeSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜尋標題、內文或標籤'**
  String get homeSearchHint;

  /// No description provided for @homeEmptyDiaryTitle.
  ///
  /// In zh, this message translates to:
  /// **'目前沒有日記'**
  String get homeEmptyDiaryTitle;

  /// No description provided for @homeEmptyDiaryMessage.
  ///
  /// In zh, this message translates to:
  /// **'建立第一篇日記後，就會在這裡看到您的首頁列表。'**
  String get homeEmptyDiaryMessage;

  /// No description provided for @homeNoAnalysisTitle.
  ///
  /// In zh, this message translates to:
  /// **'尚無可分析內容'**
  String get homeNoAnalysisTitle;

  /// No description provided for @homeNoAnalysisMessage.
  ///
  /// In zh, this message translates to:
  /// **'寫下一篇後，就可以在這裡看到統計、標籤與範圍內的日記。'**
  String get homeNoAnalysisMessage;

  /// No description provided for @homeExportRecapLabel.
  ///
  /// In zh, this message translates to:
  /// **'匯出回顧'**
  String get homeExportRecapLabel;

  /// No description provided for @homeExportRecapAll.
  ///
  /// In zh, this message translates to:
  /// **'匯出總回顧'**
  String get homeExportRecapAll;

  /// No description provided for @homeExportRecapYear.
  ///
  /// In zh, this message translates to:
  /// **'匯出年度回顧'**
  String get homeExportRecapYear;

  /// No description provided for @homeExportRecapMonth.
  ///
  /// In zh, this message translates to:
  /// **'匯出月份回顧'**
  String get homeExportRecapMonth;

  /// No description provided for @homePopularTagsTitle.
  ///
  /// In zh, this message translates to:
  /// **'熱門標籤'**
  String get homePopularTagsTitle;

  /// No description provided for @homeScopeTitle.
  ///
  /// In zh, this message translates to:
  /// **'範圍'**
  String get homeScopeTitle;

  /// No description provided for @homeScopeAllLabel.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get homeScopeAllLabel;

  /// No description provided for @homeScopeYearLabel.
  ///
  /// In zh, this message translates to:
  /// **'年'**
  String get homeScopeYearLabel;

  /// No description provided for @homeScopeMonthLabel.
  ///
  /// In zh, this message translates to:
  /// **'月'**
  String get homeScopeMonthLabel;

  /// No description provided for @homeScopeEmptyDiary.
  ///
  /// In zh, this message translates to:
  /// **'此範圍內沒有符合的日記。'**
  String get homeScopeEmptyDiary;

  /// No description provided for @homeScopeEmptyDiaryForTag.
  ///
  /// In zh, this message translates to:
  /// **'此範圍內沒有套用「{tag}」的日記。'**
  String homeScopeEmptyDiaryForTag(String tag);

  /// No description provided for @homeScopeEmptyTags.
  ///
  /// In zh, this message translates to:
  /// **'此範圍內沒有標籤。'**
  String get homeScopeEmptyTags;

  /// No description provided for @homeUnsavedDraftLabel.
  ///
  /// In zh, this message translates to:
  /// **'未儲存'**
  String get homeUnsavedDraftLabel;

  /// No description provided for @homeHtmlExportLargeTitle.
  ///
  /// In zh, this message translates to:
  /// **'HTML 檔案可能很大'**
  String get homeHtmlExportLargeTitle;

  /// No description provided for @homeHtmlExportEmbeddedHint.
  ///
  /// In zh, this message translates to:
  /// **'圖片會內嵌在單一 HTML 內，檔案可能較慢開啟或不易分享。'**
  String get homeHtmlExportEmbeddedHint;

  /// No description provided for @homeHtmlExportProceed.
  ///
  /// In zh, this message translates to:
  /// **'仍要匯出'**
  String get homeHtmlExportProceed;

  /// No description provided for @homeHtmlExportSelectionSummary.
  ///
  /// In zh, this message translates to:
  /// **'選取 {entrySummary}日記，包含 {imageSummary}圖片。'**
  String homeHtmlExportSelectionSummary(
    String entrySummary,
    String imageSummary,
  );

  /// No description provided for @homeHtmlExportImageSize.
  ///
  /// In zh, this message translates to:
  /// **'圖片原始大小：約 {size}'**
  String homeHtmlExportImageSize(String size);

  /// No description provided for @homeHtmlExportEstimatedSize.
  ///
  /// In zh, this message translates to:
  /// **'HTML 估算大小：約 {size}'**
  String homeHtmlExportEstimatedSize(String size);

  /// No description provided for @homeHtmlExportSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已匯出 HTML：{fileName}'**
  String homeHtmlExportSuccess(String fileName);

  /// No description provided for @homeDeleteTagTitle.
  ///
  /// In zh, this message translates to:
  /// **'刪除標籤'**
  String get homeDeleteTagTitle;

  /// No description provided for @homeDeleteTagConfirm.
  ///
  /// In zh, this message translates to:
  /// **'確定要從所有日記移除「{label}」嗎？'**
  String homeDeleteTagConfirm(String label);

  /// No description provided for @homeTagSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜尋標籤…'**
  String get homeTagSearchHint;

  /// No description provided for @homeNoTagsTitle.
  ///
  /// In zh, this message translates to:
  /// **'尚未有標籤'**
  String get homeNoTagsTitle;

  /// No description provided for @homeNoTagsMessage.
  ///
  /// In zh, this message translates to:
  /// **'可點下方按鈕建立一組預設標籤，或使用右上角的「+」自行新增；即使尚未套用到日記也會保留在清單中。'**
  String get homeNoTagsMessage;

  /// No description provided for @homeCreateDefaultTagsButton.
  ///
  /// In zh, this message translates to:
  /// **'建立預設標籤'**
  String get homeCreateDefaultTagsButton;

  /// No description provided for @homeTagsSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'標籤（{countSummary}）'**
  String homeTagsSectionTitle(String countSummary);

  /// No description provided for @homeTagListGuide.
  ///
  /// In zh, this message translates to:
  /// **'請從標籤清單中點選一列：此區會依索引篩選出套用該標籤的日記摘要（再點同一列可取消選取）。'**
  String get homeTagListGuide;

  /// No description provided for @homeTagPreviewTitle.
  ///
  /// In zh, this message translates to:
  /// **'選取標籤以預覽日記'**
  String get homeTagPreviewTitle;

  /// No description provided for @homeTagDeleted.
  ///
  /// In zh, this message translates to:
  /// **'「{label}」已刪除'**
  String homeTagDeleted(String label);

  /// No description provided for @homeTagRemovedFromEntries.
  ///
  /// In zh, this message translates to:
  /// **'已從 {entrySummary}日記移除「{label}」'**
  String homeTagRemovedFromEntries(String entrySummary, String label);

  /// No description provided for @homeTagIndexEmptyForTag.
  ///
  /// In zh, this message translates to:
  /// **'目前索引中找不到套用「{tag}」的項目。'**
  String homeTagIndexEmptyForTag(String tag);

  /// No description provided for @homeTagRowEntryCount.
  ///
  /// In zh, this message translates to:
  /// **'{entrySummary}日記'**
  String homeTagRowEntryCount(String entrySummary);

  /// No description provided for @homeTagRowTapHint.
  ///
  /// In zh, this message translates to:
  /// **'輕觸列預覽'**
  String get homeTagRowTapHint;

  /// No description provided for @homeDiarySectionTitleForDate.
  ///
  /// In zh, this message translates to:
  /// **'日記 · {dateLabel}'**
  String homeDiarySectionTitleForDate(String dateLabel);

  /// No description provided for @homeEmptyDayMessage.
  ///
  /// In zh, this message translates to:
  /// **'「{dateLabel}」這一天目前沒有日記。'**
  String homeEmptyDayMessage(String dateLabel);

  /// No description provided for @homeOverviewDataTitle.
  ///
  /// In zh, this message translates to:
  /// **'資料概覽'**
  String get homeOverviewDataTitle;

  /// No description provided for @homeOverviewScopeAll.
  ///
  /// In zh, this message translates to:
  /// **'目前範圍 · 全部日記'**
  String get homeOverviewScopeAll;

  /// No description provided for @homeOverviewScopeYear.
  ///
  /// In zh, this message translates to:
  /// **'目前範圍 · {year}年'**
  String homeOverviewScopeYear(int year);

  /// No description provided for @homeOverviewScopeMonth.
  ///
  /// In zh, this message translates to:
  /// **'目前範圍 · {year}年{month}月'**
  String homeOverviewScopeMonth(int year, int month);

  /// No description provided for @homeOverviewWritingDaysLabel.
  ///
  /// In zh, this message translates to:
  /// **'撰寫天數'**
  String get homeOverviewWritingDaysLabel;

  /// No description provided for @homeOverviewAvgLengthLabel.
  ///
  /// In zh, this message translates to:
  /// **'平均篇幅'**
  String get homeOverviewAvgLengthLabel;

  /// No description provided for @homeOverviewAttachmentsLabel.
  ///
  /// In zh, this message translates to:
  /// **'附件總數'**
  String get homeOverviewAttachmentsLabel;

  /// No description provided for @homeOverviewAttachmentCount.
  ///
  /// In zh, this message translates to:
  /// **'{attachmentSummary}'**
  String homeOverviewAttachmentCount(String attachmentSummary);

  /// No description provided for @homeOverviewLongestStreak.
  ///
  /// In zh, this message translates to:
  /// **'連續最長 {daySummary}'**
  String homeOverviewLongestStreak(String daySummary);

  /// No description provided for @homeOverviewEntryStats.
  ///
  /// In zh, this message translates to:
  /// **'共 {entrySummary}\n累計 {characterSummary}'**
  String homeOverviewEntryStats(String entrySummary, String characterSummary);

  /// No description provided for @homeDiarySectionTag.
  ///
  /// In zh, this message translates to:
  /// **'日記 · {tag}'**
  String homeDiarySectionTag(String tag);

  /// No description provided for @homeDiarySectionAll.
  ///
  /// In zh, this message translates to:
  /// **'日記 · 全部'**
  String get homeDiarySectionAll;

  /// No description provided for @homeDiarySectionByYear.
  ///
  /// In zh, this message translates to:
  /// **'日記 · 依年'**
  String get homeDiarySectionByYear;

  /// No description provided for @homeDiarySectionByMonth.
  ///
  /// In zh, this message translates to:
  /// **'日記 · 依月'**
  String get homeDiarySectionByMonth;

  /// No description provided for @homeDiarySectionWithTag.
  ///
  /// In zh, this message translates to:
  /// **'{baseTitle} · {tag}'**
  String homeDiarySectionWithTag(String baseTitle, String tag);

  /// No description provided for @homeCalendarMonthFormatLabel.
  ///
  /// In zh, this message translates to:
  /// **'月'**
  String get homeCalendarMonthFormatLabel;

  /// No description provided for @homeCalendarWeekdaySun.
  ///
  /// In zh, this message translates to:
  /// **'日'**
  String get homeCalendarWeekdaySun;

  /// No description provided for @homeCalendarWeekdayMon.
  ///
  /// In zh, this message translates to:
  /// **'一'**
  String get homeCalendarWeekdayMon;

  /// No description provided for @homeCalendarWeekdayTue.
  ///
  /// In zh, this message translates to:
  /// **'二'**
  String get homeCalendarWeekdayTue;

  /// No description provided for @homeCalendarWeekdayWed.
  ///
  /// In zh, this message translates to:
  /// **'三'**
  String get homeCalendarWeekdayWed;

  /// No description provided for @homeCalendarWeekdayThu.
  ///
  /// In zh, this message translates to:
  /// **'四'**
  String get homeCalendarWeekdayThu;

  /// No description provided for @homeCalendarWeekdayFri.
  ///
  /// In zh, this message translates to:
  /// **'五'**
  String get homeCalendarWeekdayFri;

  /// No description provided for @homeCalendarWeekdaySat.
  ///
  /// In zh, this message translates to:
  /// **'六'**
  String get homeCalendarWeekdaySat;

  /// No description provided for @sessionBackgroundTimeoutMinutes.
  ///
  /// In zh, this message translates to:
  /// **'{count} 分鐘'**
  String sessionBackgroundTimeoutMinutes(int count);

  /// No description provided for @sessionBackgroundTimeoutSeconds.
  ///
  /// In zh, this message translates to:
  /// **'{count} 秒'**
  String sessionBackgroundTimeoutSeconds(int count);

  /// No description provided for @homeOverviewAvgLengthValue.
  ///
  /// In zh, this message translates to:
  /// **'{charactersPerEntry} 字 / 篇'**
  String homeOverviewAvgLengthValue(int charactersPerEntry);

  /// No description provided for @homeOverviewAttachmentDetail.
  ///
  /// In zh, this message translates to:
  /// **'照片 {photos} · 檔案 {files}'**
  String homeOverviewAttachmentDetail(int photos, int files);

  /// No description provided for @homeOverviewMostEntriesInSingleDay.
  ///
  /// In zh, this message translates to:
  /// **'單天最多 {entrySummary}'**
  String homeOverviewMostEntriesInSingleDay(String entrySummary);

  /// No description provided for @vaultTransferNeedsUnlockForBackup.
  ///
  /// In zh, this message translates to:
  /// **'請先解鎖日記庫，才能備份或匯出。'**
  String get vaultTransferNeedsUnlockForBackup;

  /// No description provided for @vaultTransferNeedsRecoveryKeyForBackup.
  ///
  /// In zh, this message translates to:
  /// **'請先建立復原金鑰，才能備份或匯出。'**
  String get vaultTransferNeedsRecoveryKeyForBackup;

  /// No description provided for @vaultTransferNeedsUnlockForRestore.
  ///
  /// In zh, this message translates to:
  /// **'請先解鎖日記庫，才能還原備份。'**
  String get vaultTransferNeedsUnlockForRestore;

  /// No description provided for @vaultTransferLocalSectionDescriptionBackupLocked.
  ///
  /// In zh, this message translates to:
  /// **'建立本機備份與匯出需先解鎖日記庫並建立復原金鑰；尚未建立復原金鑰或忘記金鑰時，可直接匯入外部備份還原。'**
  String get vaultTransferLocalSectionDescriptionBackupLocked;

  /// No description provided for @vaultTransferDriveSectionDescriptionBackupLocked.
  ///
  /// In zh, this message translates to:
  /// **'備份到 Google Drive 需先解鎖日記庫並建立復原金鑰；尚未建立復原金鑰或忘記金鑰時，可直接從 Google Drive 還原。'**
  String get vaultTransferDriveSectionDescriptionBackupLocked;

  /// No description provided for @vaultTransferDriveBackupActionsLockedHint.
  ///
  /// In zh, this message translates to:
  /// **'請先解鎖日記庫並建立復原金鑰，才能備份到 Google Drive。'**
  String get vaultTransferDriveBackupActionsLockedHint;

  /// No description provided for @vaultTransferRestoreUnlockFailed.
  ///
  /// In zh, this message translates to:
  /// **'備份已還原，但復原金鑰解鎖失敗。請在安全總覽重新輸入復原金鑰。'**
  String get vaultTransferRestoreUnlockFailed;

  /// No description provided for @vaultTransferPickBackupFileTitle.
  ///
  /// In zh, this message translates to:
  /// **'選擇備份 ZIP'**
  String get vaultTransferPickBackupFileTitle;

  /// No description provided for @vaultTransferPickBackupDirectoryTitle.
  ///
  /// In zh, this message translates to:
  /// **'選擇匯出備份的資料夾'**
  String get vaultTransferPickBackupDirectoryTitle;

  /// No description provided for @vaultTransferPickMarkdownDirectoryTitle.
  ///
  /// In zh, this message translates to:
  /// **'選擇匯出日記的資料夾'**
  String get vaultTransferPickMarkdownDirectoryTitle;

  /// No description provided for @vaultTransferPickHtmlDirectoryTitle.
  ///
  /// In zh, this message translates to:
  /// **'選擇匯出 HTML 的資料夾'**
  String get vaultTransferPickHtmlDirectoryTitle;

  /// No description provided for @vaultTransferImportDocumentsDirectoryPrompt.
  ///
  /// In zh, this message translates to:
  /// **'選擇包含要匯入之 App Markdown 或 HTML 的資料夾'**
  String get vaultTransferImportDocumentsDirectoryPrompt;

  /// No description provided for @vaultTransferImportDocumentsFileTitle.
  ///
  /// In zh, this message translates to:
  /// **'選擇 ZIP、Markdown 或 HTML 以匯入'**
  String get vaultTransferImportDocumentsFileTitle;

  /// No description provided for @vaultTransferBackupOutsideExpectedDirectory.
  ///
  /// In zh, this message translates to:
  /// **'備份檔案不在預期目錄內'**
  String get vaultTransferBackupOutsideExpectedDirectory;

  /// No description provided for @androidSafWriteFailed.
  ///
  /// In zh, this message translates to:
  /// **'無法將檔案寫入選擇的資料夾。'**
  String get androidSafWriteFailed;

  /// No description provided for @androidSafWriteFailedWithCode.
  ///
  /// In zh, this message translates to:
  /// **'無法將檔案寫入選擇的資料夾（{code}）。'**
  String androidSafWriteFailedWithCode(String code);

  /// No description provided for @defaultTagDaily.
  ///
  /// In zh, this message translates to:
  /// **'日常'**
  String get defaultTagDaily;

  /// No description provided for @defaultTagMood.
  ///
  /// In zh, this message translates to:
  /// **'心情'**
  String get defaultTagMood;

  /// No description provided for @defaultTagTakeaways.
  ///
  /// In zh, this message translates to:
  /// **'心得'**
  String get defaultTagTakeaways;

  /// No description provided for @defaultTagNotes.
  ///
  /// In zh, this message translates to:
  /// **'筆記'**
  String get defaultTagNotes;

  /// No description provided for @defaultTagReflection.
  ///
  /// In zh, this message translates to:
  /// **'反思'**
  String get defaultTagReflection;

  /// No description provided for @defaultTagIdeas.
  ///
  /// In zh, this message translates to:
  /// **'靈感'**
  String get defaultTagIdeas;

  /// No description provided for @defaultTagPlans.
  ///
  /// In zh, this message translates to:
  /// **'計畫'**
  String get defaultTagPlans;

  /// No description provided for @defaultTagGoals.
  ///
  /// In zh, this message translates to:
  /// **'目標'**
  String get defaultTagGoals;

  /// No description provided for @defaultTagWork.
  ///
  /// In zh, this message translates to:
  /// **'工作'**
  String get defaultTagWork;

  /// No description provided for @defaultTagLearning.
  ///
  /// In zh, this message translates to:
  /// **'學習'**
  String get defaultTagLearning;

  /// No description provided for @defaultTagRelationships.
  ///
  /// In zh, this message translates to:
  /// **'人際'**
  String get defaultTagRelationships;

  /// No description provided for @defaultTagFamily.
  ///
  /// In zh, this message translates to:
  /// **'家庭'**
  String get defaultTagFamily;

  /// No description provided for @defaultTagHealth.
  ///
  /// In zh, this message translates to:
  /// **'健康'**
  String get defaultTagHealth;

  /// No description provided for @defaultTagGratitude.
  ///
  /// In zh, this message translates to:
  /// **'感謝'**
  String get defaultTagGratitude;

  /// No description provided for @settingsActionConfirm.
  ///
  /// In zh, this message translates to:
  /// **'確認還原'**
  String get settingsActionConfirm;

  /// No description provided for @settingsActionUpdate.
  ///
  /// In zh, this message translates to:
  /// **'更新'**
  String get settingsActionUpdate;

  /// No description provided for @settingsActionVerifyAndRestore.
  ///
  /// In zh, this message translates to:
  /// **'驗證並還原'**
  String get settingsActionVerifyAndRestore;

  /// No description provided for @settingsRecoveryKeyFieldLabel.
  ///
  /// In zh, this message translates to:
  /// **'復原金鑰'**
  String get settingsRecoveryKeyFieldLabel;

  /// No description provided for @settingsRecoveryKeyFieldHint.
  ///
  /// In zh, this message translates to:
  /// **'ABCD-EFGH-IJKL-MNOP-QRST-UVWX'**
  String get settingsRecoveryKeyFieldHint;

  /// No description provided for @settingsRecoveryKeyHintLine.
  ///
  /// In zh, this message translates to:
  /// **'末四碼：{hint}'**
  String settingsRecoveryKeyHintLine(String hint);

  /// No description provided for @settingsBackupPhaseCreating.
  ///
  /// In zh, this message translates to:
  /// **'正在建立備份…'**
  String get settingsBackupPhaseCreating;

  /// No description provided for @settingsBackupPhaseCopying.
  ///
  /// In zh, this message translates to:
  /// **'正在寫入備份…'**
  String get settingsBackupPhaseCopying;

  /// No description provided for @settingsBackupPhaseUploadingDrive.
  ///
  /// In zh, this message translates to:
  /// **'正在上傳到 Google Drive…'**
  String get settingsBackupPhaseUploadingDrive;

  /// No description provided for @settingsBackupPhaseDownloadingDrive.
  ///
  /// In zh, this message translates to:
  /// **'正在從 Google Drive 下載…'**
  String get settingsBackupPhaseDownloadingDrive;

  /// No description provided for @settingsBackupPhaseRestoring.
  ///
  /// In zh, this message translates to:
  /// **'正在還原備份，請勿關閉應用程式…'**
  String get settingsBackupPhaseRestoring;

  /// No description provided for @settingsBackupStartingAfterRestore.
  ///
  /// In zh, this message translates to:
  /// **'正在啟動還原後的日記庫…'**
  String get settingsBackupStartingAfterRestore;

  /// No description provided for @settingsPlatformSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'平台限制'**
  String get settingsPlatformSectionTitle;

  /// No description provided for @settingsPlatformSectionDescription.
  ///
  /// In zh, this message translates to:
  /// **'Quill Diary 目前僅支援 Android。'**
  String get settingsPlatformSectionDescription;

  /// No description provided for @settingsSecurityLockStatusPreparing.
  ///
  /// In zh, this message translates to:
  /// **'正在準備中…'**
  String get settingsSecurityLockStatusPreparing;

  /// No description provided for @settingsSecurityLockStatusUnlocked.
  ///
  /// In zh, this message translates to:
  /// **'已解鎖，可以正常使用。'**
  String get settingsSecurityLockStatusUnlocked;

  /// No description provided for @settingsSecurityLockStatusFatalError.
  ///
  /// In zh, this message translates to:
  /// **'初始化失敗，請稍後再試。'**
  String get settingsSecurityLockStatusFatalError;

  /// No description provided for @settingsSecurityLockUnlockingWaitHint.
  ///
  /// In zh, this message translates to:
  /// **'若等候過久，驗證視窗可能被擋住。可取消後改用手動驗證。'**
  String get settingsSecurityLockUnlockingWaitHint;

  /// No description provided for @settingsSecurityLockCancelUnlockButton.
  ///
  /// In zh, this message translates to:
  /// **'取消並改用手動驗證'**
  String get settingsSecurityLockCancelUnlockButton;

  /// No description provided for @settingsSecurityLockUnlockWithRecoveryButton.
  ///
  /// In zh, this message translates to:
  /// **'使用復原金鑰解鎖'**
  String get settingsSecurityLockUnlockWithRecoveryButton;

  /// No description provided for @settingsSecurityLockRecoveryUnlockHint.
  ///
  /// In zh, this message translates to:
  /// **'輸入復原金鑰以解鎖日記庫。'**
  String get settingsSecurityLockRecoveryUnlockHint;

  /// No description provided for @settingsSecurityLockRetryVerificationButton.
  ///
  /// In zh, this message translates to:
  /// **'重新驗證'**
  String get settingsSecurityLockRetryVerificationButton;

  /// No description provided for @settingsRecoveryKeyNotSetupBanner.
  ///
  /// In zh, this message translates to:
  /// **'尚未建立復原金鑰。請先建立，以便換機、備份與還原。'**
  String get settingsRecoveryKeyNotSetupBanner;

  /// No description provided for @settingsRecoveryKeySetupBanner.
  ///
  /// In zh, this message translates to:
  /// **'復原金鑰已建立，請確認已妥善保存。'**
  String get settingsRecoveryKeySetupBanner;

  /// No description provided for @settingsRecoveryKeyCreateButton.
  ///
  /// In zh, this message translates to:
  /// **'建立復原金鑰'**
  String get settingsRecoveryKeyCreateButton;

  /// No description provided for @settingsRecoveryKeyRotateButton.
  ///
  /// In zh, this message translates to:
  /// **'更新復原金鑰'**
  String get settingsRecoveryKeyRotateButton;

  /// No description provided for @settingsRecoveryKeyFactVaultLabel.
  ///
  /// In zh, this message translates to:
  /// **'日記庫'**
  String get settingsRecoveryKeyFactVaultLabel;

  /// No description provided for @settingsRecoveryKeyFactHintLabel.
  ///
  /// In zh, this message translates to:
  /// **'末四碼'**
  String get settingsRecoveryKeyFactHintLabel;

  /// No description provided for @settingsRecoveryKeyFactKdfLabel.
  ///
  /// In zh, this message translates to:
  /// **'加密方式'**
  String get settingsRecoveryKeyFactKdfLabel;

  /// No description provided for @settingsRecoveryKeySaveDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'請保存復原金鑰'**
  String get settingsRecoveryKeySaveDialogTitle;

  /// No description provided for @settingsRecoveryKeySaveNewDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'請保存新的復原金鑰'**
  String get settingsRecoveryKeySaveNewDialogTitle;

  /// No description provided for @settingsRecoveryKeyCopyButton.
  ///
  /// In zh, this message translates to:
  /// **'複製'**
  String get settingsRecoveryKeyCopyButton;

  /// No description provided for @settingsRecoveryKeyCopiedMessage.
  ///
  /// In zh, this message translates to:
  /// **'已複製到剪貼簿'**
  String get settingsRecoveryKeyCopiedMessage;

  /// No description provided for @settingsRecoveryKeyRotateDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'更新復原金鑰？'**
  String get settingsRecoveryKeyRotateDialogTitle;

  /// No description provided for @settingsRecoveryKeyRotateDialogBody.
  ///
  /// In zh, this message translates to:
  /// **'將產生全新的復原金鑰，請立即保存。\n\n既有本機或 Google Drive 備份仍須使用舊金鑰還原；更新後請重新建立備份。'**
  String get settingsRecoveryKeyRotateDialogBody;

  /// No description provided for @settingsSecurityOverviewSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'安全狀態'**
  String get settingsSecurityOverviewSectionTitle;

  /// No description provided for @settingsSecurityOverviewSectionDescription.
  ///
  /// In zh, this message translates to:
  /// **'查看復原金鑰、解鎖方式與搜尋索引是否正常。'**
  String get settingsSecurityOverviewSectionDescription;

  /// No description provided for @settingsSecurityOverviewRecoveryKeyTitle.
  ///
  /// In zh, this message translates to:
  /// **'復原金鑰'**
  String get settingsSecurityOverviewRecoveryKeyTitle;

  /// No description provided for @settingsSecurityOverviewRecoveryKeyReady.
  ///
  /// In zh, this message translates to:
  /// **'已建立，可用於換機與還原。'**
  String get settingsSecurityOverviewRecoveryKeyReady;

  /// No description provided for @settingsSecurityOverviewRecoveryKeyMissing.
  ///
  /// In zh, this message translates to:
  /// **'尚未建立，請先建立後再備份或匯出。'**
  String get settingsSecurityOverviewRecoveryKeyMissing;

  /// No description provided for @settingsSecurityOverviewUnlockStatusTitle.
  ///
  /// In zh, this message translates to:
  /// **'解鎖狀態'**
  String get settingsSecurityOverviewUnlockStatusTitle;

  /// No description provided for @settingsSecurityOverviewUnlockStatusUnlocked.
  ///
  /// In zh, this message translates to:
  /// **'日記庫目前已解鎖。'**
  String get settingsSecurityOverviewUnlockStatusUnlocked;

  /// No description provided for @settingsSecurityOverviewUnlockStatusLocked.
  ///
  /// In zh, this message translates to:
  /// **'請先解鎖，才能備份、還原或調整設定。'**
  String get settingsSecurityOverviewUnlockStatusLocked;

  /// No description provided for @settingsSecurityOverviewUnlockModeTitle.
  ///
  /// In zh, this message translates to:
  /// **'解鎖方式'**
  String get settingsSecurityOverviewUnlockModeTitle;

  /// No description provided for @settingsSecurityOverviewTrustedDeviceTitle.
  ///
  /// In zh, this message translates to:
  /// **'可信裝置'**
  String get settingsSecurityOverviewTrustedDeviceTitle;

  /// No description provided for @settingsSecurityOverviewTrustedDeviceReady.
  ///
  /// In zh, this message translates to:
  /// **'這台裝置已完成驗證，可快速解鎖。'**
  String get settingsSecurityOverviewTrustedDeviceReady;

  /// No description provided for @settingsSecurityOverviewTrustedDeviceMissing.
  ///
  /// In zh, this message translates to:
  /// **'這台裝置尚未完成驗證。'**
  String get settingsSecurityOverviewTrustedDeviceMissing;

  /// No description provided for @settingsSecurityOverviewUnlockModeNeedsRecoveryKeyMessage.
  ///
  /// In zh, this message translates to:
  /// **'建立復原金鑰後，即可設定解鎖方式。'**
  String get settingsSecurityOverviewUnlockModeNeedsRecoveryKeyMessage;

  /// No description provided for @settingsSecurityOverviewUnlockModeProtectedMessage.
  ///
  /// In zh, this message translates to:
  /// **'目前以 {unlockModeLabel} 保護此裝置。'**
  String settingsSecurityOverviewUnlockModeProtectedMessage(
    String unlockModeLabel,
  );

  /// No description provided for @settingsSecurityOverviewIndexTitle.
  ///
  /// In zh, this message translates to:
  /// **'日記庫'**
  String get settingsSecurityOverviewIndexTitle;

  /// No description provided for @settingsSecurityOverviewCreateRecoveryKeyButton.
  ///
  /// In zh, this message translates to:
  /// **'建立復原金鑰'**
  String get settingsSecurityOverviewCreateRecoveryKeyButton;

  /// No description provided for @settingsSecurityOverviewRotateRecoveryKeyButton.
  ///
  /// In zh, this message translates to:
  /// **'更新復原金鑰'**
  String get settingsSecurityOverviewRotateRecoveryKeyButton;

  /// No description provided for @settingsSecurityOverviewRepairVaultButton.
  ///
  /// In zh, this message translates to:
  /// **'修復日記庫'**
  String get settingsSecurityOverviewRepairVaultButton;

  /// No description provided for @settingsSecurityOverviewHealthLevelOk.
  ///
  /// In zh, this message translates to:
  /// **'正常'**
  String get settingsSecurityOverviewHealthLevelOk;

  /// No description provided for @settingsSecurityOverviewHealthLevelWarning.
  ///
  /// In zh, this message translates to:
  /// **'需注意'**
  String get settingsSecurityOverviewHealthLevelWarning;

  /// No description provided for @settingsSecurityOverviewHealthLevelError.
  ///
  /// In zh, this message translates to:
  /// **'錯誤'**
  String get settingsSecurityOverviewHealthLevelError;

  /// No description provided for @settingsUnlockModeFullNone.
  ///
  /// In zh, this message translates to:
  /// **'無'**
  String get settingsUnlockModeFullNone;

  /// No description provided for @settingsUnlockModeFullDeviceLock.
  ///
  /// In zh, this message translates to:
  /// **'裝置螢幕鎖'**
  String get settingsUnlockModeFullDeviceLock;

  /// No description provided for @settingsUnlockModeFullBiometric.
  ///
  /// In zh, this message translates to:
  /// **'生物驗證'**
  String get settingsUnlockModeFullBiometric;

  /// No description provided for @settingsUnlockMethodSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'解鎖方式'**
  String get settingsUnlockMethodSectionTitle;

  /// No description provided for @settingsUnlockMethodSectionDescription.
  ///
  /// In zh, this message translates to:
  /// **'App 放在背景超過 {timeoutLabel} 會自動鎖定；如果只是短時間切換 App，通常不會。鎖定後回到 App 時，請依下方方式重新驗證。'**
  String settingsUnlockMethodSectionDescription(String timeoutLabel);

  /// No description provided for @settingsUnlockMethodSegmentNone.
  ///
  /// In zh, this message translates to:
  /// **'無'**
  String get settingsUnlockMethodSegmentNone;

  /// No description provided for @settingsUnlockMethodSegmentDeviceLock.
  ///
  /// In zh, this message translates to:
  /// **'螢幕鎖'**
  String get settingsUnlockMethodSegmentDeviceLock;

  /// No description provided for @settingsUnlockMethodSegmentBiometric.
  ///
  /// In zh, this message translates to:
  /// **'生物驗證'**
  String get settingsUnlockMethodSegmentBiometric;

  /// No description provided for @settingsUnlockMethodBiometricNeedsDeviceLockHint.
  ///
  /// In zh, this message translates to:
  /// **'須已設定螢幕鎖並登錄生物辨識。\n驗證取消或失敗時，可改以螢幕鎖解鎖，不必輸入復原金鑰。'**
  String get settingsUnlockMethodBiometricNeedsDeviceLockHint;

  /// No description provided for @settingsUnlockModeChangeCancelled.
  ///
  /// In zh, this message translates to:
  /// **'已取消變更，解鎖方式維持不變。'**
  String get settingsUnlockModeChangeCancelled;

  /// No description provided for @settingsUnlockModeChangeAuthFailed.
  ///
  /// In zh, this message translates to:
  /// **'驗證失敗，解鎖方式維持不變。'**
  String get settingsUnlockModeChangeAuthFailed;

  /// No description provided for @settingsUnlockModeDescriptionNone.
  ///
  /// In zh, this message translates to:
  /// **'鎖定後不額外驗證，直接解鎖。適合尚未設定螢幕鎖的裝置，安全性較低。'**
  String get settingsUnlockModeDescriptionNone;

  /// No description provided for @settingsUnlockModeDescriptionDeviceLock.
  ///
  /// In zh, this message translates to:
  /// **'鎖定後以螢幕鎖（PIN、圖案或密碼）驗證。請先在裝置設定中建立螢幕鎖。'**
  String get settingsUnlockModeDescriptionDeviceLock;

  /// No description provided for @settingsUnlockModeDescriptionBiometric.
  ///
  /// In zh, this message translates to:
  /// **'鎖定後以指紋或臉部驗證；取消或失敗時可改以螢幕鎖，不必輸入復原金鑰。'**
  String get settingsUnlockModeDescriptionBiometric;

  /// No description provided for @settingsSessionTimeoutBackgroundLockExplanation.
  ///
  /// In zh, this message translates to:
  /// **'App 放在背景超過 {timeoutLabel} 會自動鎖定；如果只是短時間切換 App，通常不會。'**
  String settingsSessionTimeoutBackgroundLockExplanation(String timeoutLabel);

  /// No description provided for @settingsSessionTimeoutAboutBackgroundTimeoutBody.
  ///
  /// In zh, this message translates to:
  /// **'App 放在背景超過 {timeoutLabel} 會自動鎖定；如果只是短時間切換 App，通常不會。您可以在個人化頁調整成 1 / 3 / 5 / 10 分鐘。若正在備份、還原或匯入匯出，會先暫停自動鎖定；等您回來後，再依目前的解鎖方式重新驗證。'**
  String settingsSessionTimeoutAboutBackgroundTimeoutBody(String timeoutLabel);

  /// No description provided for @settingsImportExportSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'匯入與匯出'**
  String get settingsImportExportSectionTitle;

  /// No description provided for @settingsImportExportSectionDescriptionEnabled.
  ///
  /// In zh, this message translates to:
  /// **'可從其他 App 匯入日記，或將日記匯出成檔案。支援 Markdown、HTML 與 Easy Diary 備份。'**
  String get settingsImportExportSectionDescriptionEnabled;

  /// No description provided for @settingsImportExportImportNoEntriesMessage.
  ///
  /// In zh, this message translates to:
  /// **'找不到可匯入的日記，請確認檔案格式。'**
  String get settingsImportExportImportNoEntriesMessage;

  /// No description provided for @settingsImportExportImportAllSkippedMessage.
  ///
  /// In zh, this message translates to:
  /// **'所選檔案皆無法匯入（格式不符、內容空白，或 Easy Diary 加密日記）。'**
  String get settingsImportExportImportAllSkippedMessage;

  /// No description provided for @settingsImportExportFailureSelectedFilesUnreadable.
  ///
  /// In zh, this message translates to:
  /// **'所選檔案無法讀取，請改用本機檔案或重新選取。'**
  String get settingsImportExportFailureSelectedFilesUnreadable;

  /// No description provided for @settingsImportExportFailureZipNoEntries.
  ///
  /// In zh, this message translates to:
  /// **'ZIP 內找不到可匯入的 Markdown、HTML 或 Easy Diary 完整備份。'**
  String get settingsImportExportFailureZipNoEntries;

  /// No description provided for @settingsImportExportFailureEasyDiaryUnsupportedPlatform.
  ///
  /// In zh, this message translates to:
  /// **'Easy Diary 備份目前僅支援在 Android 上匯入。'**
  String get settingsImportExportFailureEasyDiaryUnsupportedPlatform;

  /// No description provided for @settingsImportExportFailureEasyDiaryRealmReadFailed.
  ///
  /// In zh, this message translates to:
  /// **'無法讀取 Easy Diary 備份，可能版本不相容。請在 Easy Diary 重新建立備份後再試。'**
  String get settingsImportExportFailureEasyDiaryRealmReadFailed;

  /// No description provided for @settingsImportExportFailureEasyDiaryEmptyBackup.
  ///
  /// In zh, this message translates to:
  /// **'Easy Diary 備份檔內沒有可匯入的日記。'**
  String get settingsImportExportFailureEasyDiaryEmptyBackup;

  /// No description provided for @settingsImportExportFailureEasyDiaryAllEncrypted.
  ///
  /// In zh, this message translates to:
  /// **'Easy Diary 備份內的日記皆為加密狀態，無法匯入。'**
  String get settingsImportExportFailureEasyDiaryAllEncrypted;

  /// No description provided for @settingsImportExportImportProgress.
  ///
  /// In zh, this message translates to:
  /// **'正在匯入日記，請稍候…'**
  String get settingsImportExportImportProgress;

  /// No description provided for @settingsImportExportExportButton.
  ///
  /// In zh, this message translates to:
  /// **'匯出日記'**
  String get settingsImportExportExportButton;

  /// No description provided for @settingsImportExportImportButton.
  ///
  /// In zh, this message translates to:
  /// **'匯入日記'**
  String get settingsImportExportImportButton;

  /// No description provided for @settingsImportExportExportProgress.
  ///
  /// In zh, this message translates to:
  /// **'正在匯出日記，整理內容與附件中…'**
  String get settingsImportExportExportProgress;

  /// No description provided for @settingsImportExportExportSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已匯出：{path}'**
  String settingsImportExportExportSuccess(String path);

  /// No description provided for @settingsImportExportImportSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已匯入 {count} 篇日記。'**
  String settingsImportExportImportSuccess(int count);

  /// No description provided for @settingsImportExportImportSuccessWithSkippedFiles.
  ///
  /// In zh, this message translates to:
  /// **'已匯入 {count} 篇日記，{skippedFiles} 個檔案無法解析。'**
  String settingsImportExportImportSuccessWithSkippedFiles(
    int count,
    int skippedFiles,
  );

  /// No description provided for @settingsImportExportImportSuccessWithSkippedAttachments.
  ///
  /// In zh, this message translates to:
  /// **'已匯入 {count} 篇日記，{skippedAttachments} 張圖片無法匯入。'**
  String settingsImportExportImportSuccessWithSkippedAttachments(
    int count,
    int skippedAttachments,
  );

  /// No description provided for @settingsImportExportImportSuccessWithSkippedFilesAndAttachments.
  ///
  /// In zh, this message translates to:
  /// **'已匯入 {count} 篇日記，{skippedFiles} 個檔案無法解析，{skippedAttachments} 張圖片無法匯入。'**
  String settingsImportExportImportSuccessWithSkippedFilesAndAttachments(
    int count,
    int skippedFiles,
    int skippedAttachments,
  );

  /// No description provided for @settingsLocalBackupSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'本機備份與還原'**
  String get settingsLocalBackupSectionTitle;

  /// No description provided for @settingsLocalBackupSectionDescriptionEnabled.
  ///
  /// In zh, this message translates to:
  /// **'建立完整備份並存於本機，還原會覆蓋目前日記。（本機最多保留 5 份）'**
  String get settingsLocalBackupSectionDescriptionEnabled;

  /// No description provided for @settingsLocalBackupCreateButton.
  ///
  /// In zh, this message translates to:
  /// **'建立本機備份'**
  String get settingsLocalBackupCreateButton;

  /// No description provided for @settingsLocalBackupRestoreButton.
  ///
  /// In zh, this message translates to:
  /// **'從本機備份還原'**
  String get settingsLocalBackupRestoreButton;

  /// No description provided for @settingsLocalBackupExportToExternalButton.
  ///
  /// In zh, this message translates to:
  /// **'匯出備份到資料夾'**
  String get settingsLocalBackupExportToExternalButton;

  /// No description provided for @settingsLocalBackupImportFromExternalButton.
  ///
  /// In zh, this message translates to:
  /// **'匯入外部備份'**
  String get settingsLocalBackupImportFromExternalButton;

  /// No description provided for @settingsLocalBackupPickDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'選擇本機備份'**
  String get settingsLocalBackupPickDialogTitle;

  /// No description provided for @settingsLocalBackupPickExternalBackupDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'選擇備份 ZIP'**
  String get settingsLocalBackupPickExternalBackupDialogTitle;

  /// No description provided for @settingsLocalBackupNoBackups.
  ///
  /// In zh, this message translates to:
  /// **'目前沒有本機備份。'**
  String get settingsLocalBackupNoBackups;

  /// No description provided for @settingsLocalBackupDeleteBackupTooltip.
  ///
  /// In zh, this message translates to:
  /// **'刪除備份'**
  String get settingsLocalBackupDeleteBackupTooltip;

  /// No description provided for @settingsLocalBackupDeleteConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'刪除本機備份？'**
  String get settingsLocalBackupDeleteConfirmTitle;

  /// No description provided for @settingsLocalBackupBackupSuccessInApp.
  ///
  /// In zh, this message translates to:
  /// **'已建立本機備份：{fileName}'**
  String settingsLocalBackupBackupSuccessInApp(String fileName);

  /// No description provided for @settingsLocalBackupBackupExportSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已匯出備份：{fileName}'**
  String settingsLocalBackupBackupExportSuccess(String fileName);

  /// No description provided for @settingsLocalBackupBackupInspectFailed.
  ///
  /// In zh, this message translates to:
  /// **'備份檢查未通過。\n{message}'**
  String settingsLocalBackupBackupInspectFailed(String message);

  /// No description provided for @settingsLocalBackupDeleteBackupSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已刪除本機備份：{fileName}'**
  String settingsLocalBackupDeleteBackupSuccess(String fileName);

  /// No description provided for @settingsLocalBackupDeleteConfirmBody.
  ///
  /// In zh, this message translates to:
  /// **'將刪除 {fileName}。此動作不會影響目前日記庫。'**
  String settingsLocalBackupDeleteConfirmBody(String fileName);

  /// No description provided for @settingsDriveBackupSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'Google Drive 備份與還原'**
  String get settingsDriveBackupSectionTitle;

  /// No description provided for @settingsDriveBackupSectionDescriptionEnabled.
  ///
  /// In zh, this message translates to:
  /// **'連結 Google 帳戶後，可上傳備份到雲端或從雲端還原，還原會覆蓋目前日記。（雲端最多保留 5 份）'**
  String get settingsDriveBackupSectionDescriptionEnabled;

  /// No description provided for @settingsDriveBackupSectionDescriptionOAuthNotConfigured.
  ///
  /// In zh, this message translates to:
  /// **'此版本尚未設定 Google 登入，暫無法使用雲端備份。'**
  String get settingsDriveBackupSectionDescriptionOAuthNotConfigured;

  /// No description provided for @settingsDriveBackupLinkButton.
  ///
  /// In zh, this message translates to:
  /// **'連結 Google 帳戶'**
  String get settingsDriveBackupLinkButton;

  /// No description provided for @settingsDriveBackupSwitchAccountButton.
  ///
  /// In zh, this message translates to:
  /// **'切換帳戶'**
  String get settingsDriveBackupSwitchAccountButton;

  /// No description provided for @settingsDriveBackupDisconnectButton.
  ///
  /// In zh, this message translates to:
  /// **'中斷連結'**
  String get settingsDriveBackupDisconnectButton;

  /// No description provided for @settingsDriveBackupUploadButton.
  ///
  /// In zh, this message translates to:
  /// **'備份到 Google Drive'**
  String get settingsDriveBackupUploadButton;

  /// No description provided for @settingsDriveBackupRestoreButton.
  ///
  /// In zh, this message translates to:
  /// **'從 Google Drive 還原'**
  String get settingsDriveBackupRestoreButton;

  /// No description provided for @settingsDriveBackupDisconnectedLabel.
  ///
  /// In zh, this message translates to:
  /// **'尚未連結 Google 帳戶'**
  String get settingsDriveBackupDisconnectedLabel;

  /// No description provided for @settingsDriveBackupFallbackAccountLabel.
  ///
  /// In zh, this message translates to:
  /// **'Google 帳戶'**
  String get settingsDriveBackupFallbackAccountLabel;

  /// No description provided for @settingsDriveBackupLinkSuccessEmpty.
  ///
  /// In zh, this message translates to:
  /// **'Google 帳戶已連結，可以開始備份或還原。'**
  String get settingsDriveBackupLinkSuccessEmpty;

  /// No description provided for @settingsDriveBackupLinkSuccess.
  ///
  /// In zh, this message translates to:
  /// **'Google 帳戶已連結：{accountLabel}'**
  String settingsDriveBackupLinkSuccess(String accountLabel);

  /// No description provided for @settingsDriveBackupSwitchAccountSuccessEmpty.
  ///
  /// In zh, this message translates to:
  /// **'已切換 Google 帳戶。'**
  String get settingsDriveBackupSwitchAccountSuccessEmpty;

  /// No description provided for @settingsDriveBackupSwitchAccountSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已切換為 {accountLabel}'**
  String settingsDriveBackupSwitchAccountSuccess(String accountLabel);

  /// No description provided for @settingsDriveBackupDisconnectSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已中斷 Google 帳戶連線，雲端備份仍會保留。'**
  String get settingsDriveBackupDisconnectSuccess;

  /// No description provided for @settingsDriveBackupDisconnectConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'中斷 Google 帳戶連線？'**
  String get settingsDriveBackupDisconnectConfirmTitle;

  /// No description provided for @settingsDriveBackupDisconnectConfirmBody.
  ///
  /// In zh, this message translates to:
  /// **'中斷後需重新連結才能備份或還原。雲端上的備份檔不會被刪除。'**
  String get settingsDriveBackupDisconnectConfirmBody;

  /// No description provided for @settingsDriveBackupUploadSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已備份到 Google Drive：{fileName}'**
  String settingsDriveBackupUploadSuccess(String fileName);

  /// No description provided for @settingsDriveBackupBackupInspectFailed.
  ///
  /// In zh, this message translates to:
  /// **'雲端備份未完成。\n{message}'**
  String settingsDriveBackupBackupInspectFailed(String message);

  /// No description provided for @settingsDriveBackupNoBackups.
  ///
  /// In zh, this message translates to:
  /// **'Google Drive 目前沒有可用備份，請先建立一份。'**
  String get settingsDriveBackupNoBackups;

  /// No description provided for @settingsDriveBackupPickDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'選擇 Google Drive 備份'**
  String get settingsDriveBackupPickDialogTitle;

  /// No description provided for @settingsDriveBackupUnknownCreatedTime.
  ///
  /// In zh, this message translates to:
  /// **'無建立時間'**
  String get settingsDriveBackupUnknownCreatedTime;

  /// No description provided for @settingsDriveBackupDeleteBackupTooltip.
  ///
  /// In zh, this message translates to:
  /// **'刪除備份'**
  String get settingsDriveBackupDeleteBackupTooltip;

  /// No description provided for @settingsDriveBackupDeleteConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'刪除 Google Drive 備份？'**
  String get settingsDriveBackupDeleteConfirmTitle;

  /// No description provided for @settingsDriveBackupDeleteBackupSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已從 Google Drive 刪除：{fileName}'**
  String settingsDriveBackupDeleteBackupSuccess(String fileName);

  /// No description provided for @settingsDriveBackupDeleteConfirmBody.
  ///
  /// In zh, this message translates to:
  /// **'將刪除 {fileName}。此動作不會影響目前日記庫。'**
  String settingsDriveBackupDeleteConfirmBody(String fileName);

  /// No description provided for @settingsDriveBackupRestoreSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已從 Google Drive 還原：{fileName}'**
  String settingsDriveBackupRestoreSuccess(String fileName);

  /// No description provided for @settingsRestoreDialogConfirmLocalTitle.
  ///
  /// In zh, this message translates to:
  /// **'還原本機備份？'**
  String get settingsRestoreDialogConfirmLocalTitle;

  /// No description provided for @settingsRestoreDialogConfirmDriveTitle.
  ///
  /// In zh, this message translates to:
  /// **'從 Google Drive 還原？'**
  String get settingsRestoreDialogConfirmDriveTitle;

  /// No description provided for @settingsRestoreDialogDriveFileLine.
  ///
  /// In zh, this message translates to:
  /// **'備份：{name}'**
  String settingsRestoreDialogDriveFileLine(String name);

  /// No description provided for @settingsRestoreDialogRecoveryKeyTitle.
  ///
  /// In zh, this message translates to:
  /// **'輸入備份復原金鑰'**
  String get settingsRestoreDialogRecoveryKeyTitle;

  /// No description provided for @settingsRestoreDialogRecoveryKeyEmptyError.
  ///
  /// In zh, this message translates to:
  /// **'請輸入復原金鑰。'**
  String get settingsRestoreDialogRecoveryKeyEmptyError;

  /// No description provided for @settingsRestoreDialogRecoveryKeyVerifyNote.
  ///
  /// In zh, this message translates to:
  /// **'金鑰正確才會開始還原；錯誤則不會覆寫本機資料。'**
  String get settingsRestoreDialogRecoveryKeyVerifyNote;

  /// No description provided for @settingsRestoreDialogSubtitleRotatedBackup.
  ///
  /// In zh, this message translates to:
  /// **'此備份在更新復原金鑰之前建立。請輸入建立該備份時保存的舊金鑰，不是目前這把新金鑰。'**
  String get settingsRestoreDialogSubtitleRotatedBackup;

  /// No description provided for @settingsRestoreDialogSubtitleSameVaultManual.
  ///
  /// In zh, this message translates to:
  /// **'本機無法自動解鎖此備份。請輸入建立此備份時保存的復原金鑰。'**
  String get settingsRestoreDialogSubtitleSameVaultManual;

  /// No description provided for @settingsRestoreDialogSubtitleOtherVault.
  ///
  /// In zh, this message translates to:
  /// **'此備份來自其他裝置。請輸入建立此備份時保存的復原金鑰。'**
  String get settingsRestoreDialogSubtitleOtherVault;

  /// No description provided for @settingsRestoreBulletOverwriteWarning.
  ///
  /// In zh, this message translates to:
  /// **'將以備份內容覆蓋本機日記，現有資料無法復原。'**
  String get settingsRestoreBulletOverwriteWarning;

  /// No description provided for @settingsRestoreBulletRebuildIndex.
  ///
  /// In zh, this message translates to:
  /// **'搜尋索引會在解鎖後重新建立。'**
  String get settingsRestoreBulletRebuildIndex;

  /// No description provided for @settingsRestoreBulletBackupWithoutRecovery.
  ///
  /// In zh, this message translates to:
  /// **'此備份尚未建立復原金鑰，還原後請重新建立。'**
  String get settingsRestoreBulletBackupWithoutRecovery;

  /// No description provided for @settingsRestoreBulletRotatedBackup.
  ///
  /// In zh, this message translates to:
  /// **'此備份在更新復原金鑰之前建立。還原後請輸入建立該備份時保存的舊復原金鑰，不是目前這把新金鑰。'**
  String get settingsRestoreBulletRotatedBackup;

  /// No description provided for @settingsRestoreBulletTrustedAutoUnlock.
  ///
  /// In zh, this message translates to:
  /// **'若備份與本機使用同一把復原金鑰，還原後通常可直接使用。'**
  String get settingsRestoreBulletTrustedAutoUnlock;

  /// No description provided for @settingsRestoreBulletTrustedAutoUnlockFallback.
  ///
  /// In zh, this message translates to:
  /// **'若無法直接解鎖，請輸入建立此備份時保存的復原金鑰。'**
  String get settingsRestoreBulletTrustedAutoUnlockFallback;

  /// No description provided for @settingsRestoreBulletRecoveryKeyAfterRestore.
  ///
  /// In zh, this message translates to:
  /// **'還原後需輸入建立此備份時保存的復原金鑰。'**
  String get settingsRestoreBulletRecoveryKeyAfterRestore;

  /// No description provided for @settingsRestoreBulletRewrapNote.
  ///
  /// In zh, this message translates to:
  /// **'還原後首次解鎖可能需要較久，請保持 App 開啟。'**
  String get settingsRestoreBulletRewrapNote;

  /// No description provided for @settingsRepairVaultReadyMessage.
  ///
  /// In zh, this message translates to:
  /// **'可隨時修復，讓日記庫與搜尋恢復正常。'**
  String get settingsRepairVaultReadyMessage;

  /// No description provided for @settingsRepairVaultLockedMessage.
  ///
  /// In zh, this message translates to:
  /// **'解鎖後可修復日記庫。'**
  String get settingsRepairVaultLockedMessage;

  /// No description provided for @settingsUnlockRequiredToChangeSettingMessage.
  ///
  /// In zh, this message translates to:
  /// **'解鎖後可調整此設定。'**
  String get settingsUnlockRequiredToChangeSettingMessage;

  /// No description provided for @settingsIndexLinkDriveProgress.
  ///
  /// In zh, this message translates to:
  /// **'正在連結 Google 帳戶…'**
  String get settingsIndexLinkDriveProgress;

  /// No description provided for @settingsIndexSwitchDriveAccountProgress.
  ///
  /// In zh, this message translates to:
  /// **'正在切換帳戶…'**
  String get settingsIndexSwitchDriveAccountProgress;

  /// No description provided for @settingsIndexDisconnectDriveProgress.
  ///
  /// In zh, this message translates to:
  /// **'正在中斷連線…'**
  String get settingsIndexDisconnectDriveProgress;

  /// No description provided for @settingsRepairVaultCompleted.
  ///
  /// In zh, this message translates to:
  /// **'最近修復完成：{entryCount} 篇日記，{finishedAt}。'**
  String settingsRepairVaultCompleted(int entryCount, String finishedAt);

  /// No description provided for @settingsRepairVaultSuccess.
  ///
  /// In zh, this message translates to:
  /// **'日記庫已修復：{entryCount} 篇日記，耗時 {duration}'**
  String settingsRepairVaultSuccess(int entryCount, String duration);

  /// No description provided for @settingsRepairVaultSuccessChanges.
  ///
  /// In zh, this message translates to:
  /// **'（搬移 {relocatedEntries} 篇、刪除 {removedDuplicates} 個重複日記檔與 {removedOrphanAssets} 個孤立附件；跳過 {skippedCorruptEntries} 個損壞檔）'**
  String settingsRepairVaultSuccessChanges(
    int relocatedEntries,
    int removedDuplicates,
    int removedOrphanAssets,
    int skippedCorruptEntries,
  );

  /// No description provided for @settingsSupportNavButtonLabel.
  ///
  /// In zh, this message translates to:
  /// **'支持'**
  String get settingsSupportNavButtonLabel;

  /// No description provided for @settingsSupportPageTitle.
  ///
  /// In zh, this message translates to:
  /// **'支持開發者'**
  String get settingsSupportPageTitle;

  /// No description provided for @settingsSupportHeroTitle.
  ///
  /// In zh, this message translates to:
  /// **'喜歡的話，歡迎支持'**
  String get settingsSupportHeroTitle;

  /// No description provided for @settingsSupportHeroBody.
  ///
  /// In zh, this message translates to:
  /// **'如果 Quill Diary 對您有幫助，您可以透過 Google Play 提供一次性支持。這不會解鎖額外功能，也不影響日記內容的存取與使用。'**
  String get settingsSupportHeroBody;

  /// No description provided for @settingsSupportHeroChipNoExtraFeatures.
  ///
  /// In zh, this message translates to:
  /// **'不解鎖額外功能'**
  String get settingsSupportHeroChipNoExtraFeatures;

  /// No description provided for @settingsSupportHeroChipRepeatablePurchase.
  ///
  /// In zh, this message translates to:
  /// **'可再次支持'**
  String get settingsSupportHeroChipRepeatablePurchase;

  /// No description provided for @settingsSupportHeroChipGooglePlayPayment.
  ///
  /// In zh, this message translates to:
  /// **'Google Play 付款'**
  String get settingsSupportHeroChipGooglePlayPayment;

  /// No description provided for @settingsSupportComplianceCardTitle.
  ///
  /// In zh, this message translates to:
  /// **'付款與資料說明'**
  String get settingsSupportComplianceCardTitle;

  /// No description provided for @settingsSupportComplianceCardBody.
  ///
  /// In zh, this message translates to:
  /// **'付款由 Google Play 處理，屬一次性支持，非訂閱或會員方案。本應用程式不保存支持紀錄，亦不讀取日記內容。'**
  String get settingsSupportComplianceCardBody;

  /// No description provided for @settingsSupportProductsSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'支持選項'**
  String get settingsSupportProductsSectionTitle;

  /// No description provided for @settingsSupportProductsSectionBody.
  ///
  /// In zh, this message translates to:
  /// **'Google Play 會依所在地區顯示金額與幣別；每個選項都可再次支持。'**
  String get settingsSupportProductsSectionBody;

  /// No description provided for @settingsSupportBuyButtonPrefix.
  ///
  /// In zh, this message translates to:
  /// **'支持'**
  String get settingsSupportBuyButtonPrefix;

  /// No description provided for @settingsSupportRecommendedTierBadge.
  ///
  /// In zh, this message translates to:
  /// **'常用'**
  String get settingsSupportRecommendedTierBadge;

  /// No description provided for @settingsSupportPendingMessage.
  ///
  /// In zh, this message translates to:
  /// **'付款處理中，請稍候。'**
  String get settingsSupportPendingMessage;

  /// No description provided for @settingsSupportThanksMessage.
  ///
  /// In zh, this message translates to:
  /// **'謝謝您的支持，這對開發很有幫助。'**
  String get settingsSupportThanksMessage;

  /// No description provided for @settingsSupportErrorMessage.
  ///
  /// In zh, this message translates to:
  /// **'付款未完成，請稍後再試。'**
  String get settingsSupportErrorMessage;

  /// No description provided for @settingsSupportBillingUnavailableMessage.
  ///
  /// In zh, this message translates to:
  /// **'目前無法使用 Google Play 購買功能，請於已安裝 Google Play 商店的 Android 裝置上操作。'**
  String get settingsSupportBillingUnavailableMessage;

  /// No description provided for @settingsSupportProductLoadErrorTitle.
  ///
  /// In zh, this message translates to:
  /// **'暫時無法載入支持選項'**
  String get settingsSupportProductLoadErrorTitle;

  /// No description provided for @settingsSupportProductLoadErrorBody.
  ///
  /// In zh, this message translates to:
  /// **'請稍後再試。'**
  String get settingsSupportProductLoadErrorBody;

  /// No description provided for @settingsSupportProductsNotReadyTitle.
  ///
  /// In zh, this message translates to:
  /// **'暫時無法顯示支持選項'**
  String get settingsSupportProductsNotReadyTitle;

  /// No description provided for @settingsSupportProductsNotReadyBody.
  ///
  /// In zh, this message translates to:
  /// **'請確認網路連線正常；若問題持續，請更新本應用程式後再試。'**
  String get settingsSupportProductsNotReadyBody;

  /// No description provided for @settingsSupportProductsQueryFailedTitle.
  ///
  /// In zh, this message translates to:
  /// **'目前無法連線至 Google Play'**
  String get settingsSupportProductsQueryFailedTitle;

  /// No description provided for @settingsSupportProductsQueryFailedBody.
  ///
  /// In zh, this message translates to:
  /// **'請確認網路連線後再試。'**
  String get settingsSupportProductsQueryFailedBody;

  /// No description provided for @settingsSupportProductsPartialMessage.
  ///
  /// In zh, this message translates to:
  /// **'部分方案暫時無法顯示，您仍可選擇其他可用金額。'**
  String get settingsSupportProductsPartialMessage;

  /// No description provided for @settingsSupportRetryLoadProductsLabel.
  ///
  /// In zh, this message translates to:
  /// **'重新載入'**
  String get settingsSupportRetryLoadProductsLabel;

  /// No description provided for @settingsSupportFooterNote.
  ///
  /// In zh, this message translates to:
  /// **'支持完全自願，請依您的需求與意願決定。'**
  String get settingsSupportFooterNote;

  /// No description provided for @settingsSupportTierSponsorCoffeeLabel.
  ///
  /// In zh, this message translates to:
  /// **'請開發者喝杯咖啡'**
  String get settingsSupportTierSponsorCoffeeLabel;

  /// No description provided for @settingsSupportTierSponsorCoffeeHint.
  ///
  /// In zh, this message translates to:
  /// **'讓 Quill Diary 持續被照顧與改進'**
  String get settingsSupportTierSponsorCoffeeHint;

  /// No description provided for @settingsSupportTierSponsorSnackLabel.
  ///
  /// In zh, this message translates to:
  /// **'請開發者吃點心'**
  String get settingsSupportTierSponsorSnackLabel;

  /// No description provided for @settingsSupportTierSponsorSnackHint.
  ///
  /// In zh, this message translates to:
  /// **'為日常改進補充一點能量'**
  String get settingsSupportTierSponsorSnackHint;

  /// No description provided for @settingsSupportTierSponsorLunchLabel.
  ///
  /// In zh, this message translates to:
  /// **'請開發者吃午餐'**
  String get settingsSupportTierSponsorLunchLabel;

  /// No description provided for @settingsSupportTierSponsorLunchHint.
  ///
  /// In zh, this message translates to:
  /// **'支持更多時間投入開發與維護'**
  String get settingsSupportTierSponsorLunchHint;

  /// No description provided for @settingsSupportTierSponsorBoostLabel.
  ///
  /// In zh, this message translates to:
  /// **'大力支持'**
  String get settingsSupportTierSponsorBoostLabel;

  /// No description provided for @settingsSupportTierSponsorBoostHint.
  ///
  /// In zh, this message translates to:
  /// **'給持續開發一份有力鼓勵'**
  String get settingsSupportTierSponsorBoostHint;

  /// No description provided for @settingsSupportTierSponsorSuperLabel.
  ///
  /// In zh, this message translates to:
  /// **'大大大大大力支持'**
  String get settingsSupportTierSponsorSuperLabel;

  /// No description provided for @settingsSupportTierSponsorSuperHint.
  ///
  /// In zh, this message translates to:
  /// **'幫助我們更安心投入長期維護與改進'**
  String get settingsSupportTierSponsorSuperHint;

  /// No description provided for @sessionStartupNeedsRecoveryKeyMessage.
  ///
  /// In zh, this message translates to:
  /// **'尚未建立復原金鑰。'**
  String get sessionStartupNeedsRecoveryKeyMessage;

  /// No description provided for @sessionStartupNeedsTrustedDeviceMessage.
  ///
  /// In zh, this message translates to:
  /// **'這台裝置尚未授權，請使用復原金鑰解鎖。'**
  String get sessionStartupNeedsTrustedDeviceMessage;

  /// No description provided for @sessionUnlockFailedMessage.
  ///
  /// In zh, this message translates to:
  /// **'解鎖失敗，請再試一次。'**
  String get sessionUnlockFailedMessage;

  /// No description provided for @sessionRecoveryUnlockSuccessMessage.
  ///
  /// In zh, this message translates to:
  /// **'已使用復原金鑰解鎖。'**
  String get sessionRecoveryUnlockSuccessMessage;

  /// No description provided for @sessionRecoverySetupSuccessMessage.
  ///
  /// In zh, this message translates to:
  /// **'復原金鑰已建立，現在可以設定解鎖方式。'**
  String get sessionRecoverySetupSuccessMessage;

  /// No description provided for @sessionAppLockedMessage.
  ///
  /// In zh, this message translates to:
  /// **'應用程式已鎖定。'**
  String get sessionAppLockedMessage;

  /// No description provided for @sessionTrustedUnlockInProgressMessage.
  ///
  /// In zh, this message translates to:
  /// **'正在以可信裝置解鎖…'**
  String get sessionTrustedUnlockInProgressMessage;

  /// No description provided for @sessionLockedRetryVerificationMessage.
  ///
  /// In zh, this message translates to:
  /// **'目前已鎖定。請重新完成裝置驗證，不必輸入復原金鑰。'**
  String get sessionLockedRetryVerificationMessage;

  /// No description provided for @sessionRecoveryKeyRotatedMessage.
  ///
  /// In zh, this message translates to:
  /// **'復原金鑰已更新，請立即保存新金鑰。'**
  String get sessionRecoveryKeyRotatedMessage;

  /// No description provided for @sessionRecoveryRequiredAfterRestoreMessage.
  ///
  /// In zh, this message translates to:
  /// **'還原後需輸入建立此備份時保存的復原金鑰。'**
  String get sessionRecoveryRequiredAfterRestoreMessage;

  /// No description provided for @sessionInvalidBackupFileMessage.
  ///
  /// In zh, this message translates to:
  /// **'無法讀取備份檔，請確認檔案未損壞且為有效的 ZIP 備份。'**
  String get sessionInvalidBackupFileMessage;

  /// No description provided for @sessionRestoreSuccessUnlockedMessage.
  ///
  /// In zh, this message translates to:
  /// **'已還原備份，可以正常使用。'**
  String get sessionRestoreSuccessUnlockedMessage;

  /// No description provided for @sessionRestoreSuccessLockedMessage.
  ///
  /// In zh, this message translates to:
  /// **'已還原備份。請完成生物驗證或螢幕鎖驗證以繼續。'**
  String get sessionRestoreSuccessLockedMessage;

  /// No description provided for @sessionRestoreSuccessRecoveryRequiredMessage.
  ///
  /// In zh, this message translates to:
  /// **'已還原備份。請輸入建立此備份時保存的復原金鑰。'**
  String get sessionRestoreSuccessRecoveryRequiredMessage;

  /// No description provided for @sessionRestoreSuccessNeedsRecoveryKeySetupMessage.
  ///
  /// In zh, this message translates to:
  /// **'已還原備份。此備份尚未建立復原金鑰，請先建立。'**
  String get sessionRestoreSuccessNeedsRecoveryKeySetupMessage;

  /// No description provided for @sessionRestoreStartupFailedMessage.
  ///
  /// In zh, this message translates to:
  /// **'已還原備份，但啟動失敗。請到設定頁重試或輸入復原金鑰。'**
  String get sessionRestoreStartupFailedMessage;

  /// No description provided for @sessionRecoveryKeyMismatchMessage.
  ///
  /// In zh, this message translates to:
  /// **'復原金鑰不正確。若為更新復原金鑰前的舊備份，請輸入建立該備份時保存的舊金鑰。'**
  String get sessionRecoveryKeyMismatchMessage;

  /// No description provided for @sessionTrustedUnlockFailedAfterRestoreMessage.
  ///
  /// In zh, this message translates to:
  /// **'還原後無法自動解鎖。請輸入建立此備份時保存的復原金鑰。'**
  String get sessionTrustedUnlockFailedAfterRestoreMessage;

  /// No description provided for @sessionIndexDatabaseUnreadableMessage.
  ///
  /// In zh, this message translates to:
  /// **'搜尋索引無法讀取，可能已損壞。請用復原金鑰重新解鎖；若仍失敗，可嘗試重新還原備份。'**
  String get sessionIndexDatabaseUnreadableMessage;

  /// No description provided for @sessionUnlockModeNeedsDeviceLockMessage.
  ///
  /// In zh, this message translates to:
  /// **'請先在裝置設定中建立螢幕鎖，才能使用此模式。'**
  String get sessionUnlockModeNeedsDeviceLockMessage;

  /// No description provided for @sessionUnlockModeChangeNeedsUnlockMessage.
  ///
  /// In zh, this message translates to:
  /// **'請先解鎖日記庫後，再變更解鎖方式。'**
  String get sessionUnlockModeChangeNeedsUnlockMessage;

  /// No description provided for @sessionBiometricNotEnrolledSwitchModeMessage.
  ///
  /// In zh, this message translates to:
  /// **'裝置尚未登錄指紋或臉部。請先到系統設定完成生物辨識設定，或改用裝置螢幕鎖。'**
  String get sessionBiometricNotEnrolledSwitchModeMessage;

  /// No description provided for @sessionUseDeviceLockToUnlockMessage.
  ///
  /// In zh, this message translates to:
  /// **'請使用裝置螢幕鎖解鎖。'**
  String get sessionUseDeviceLockToUnlockMessage;

  /// No description provided for @sessionNoneModeLockedMessage.
  ///
  /// In zh, this message translates to:
  /// **'背景逾時，正在重新解鎖日記庫…'**
  String get sessionNoneModeLockedMessage;

  /// No description provided for @sessionKeystoreMigrationMayReverifyMessage.
  ///
  /// In zh, this message translates to:
  /// **'若系統再次要求驗證，請完成以更新解鎖設定。'**
  String get sessionKeystoreMigrationMayReverifyMessage;

  /// No description provided for @sessionStartupNeedsBiometricMessage.
  ///
  /// In zh, this message translates to:
  /// **'請先完成生物驗證。'**
  String get sessionStartupNeedsBiometricMessage;

  /// No description provided for @legalPrivacyEffectiveDateLabel.
  ///
  /// In zh, this message translates to:
  /// **'生效日期：2026 年 6 月 6 日'**
  String get legalPrivacyEffectiveDateLabel;

  /// No description provided for @legalChildrenPrivacyOneLiner.
  ///
  /// In zh, this message translates to:
  /// **'本應用程式並非專為十三歲（含）以下兒童而設計，亦不故意蒐集兒童之個人資料。'**
  String get legalChildrenPrivacyOneLiner;

  /// No description provided for @legalBrandDisclaimer.
  ///
  /// In zh, this message translates to:
  /// **'Quill Diary 名稱、圖示與 Google Play 商店 listing 為作者品牌，不隨程式碼授權一併轉讓。'**
  String get legalBrandDisclaimer;

  /// No description provided for @legalBillingVaultPrivacyNote.
  ///
  /// In zh, this message translates to:
  /// **'支持流程不讀取日記庫內容。'**
  String get legalBillingVaultPrivacyNote;

  /// No description provided for @legalBillingPrivacyOneLiner.
  ///
  /// In zh, this message translates to:
  /// **'支持開發者之付款由 Google Play 處理，屬自願性一次性支持，不解鎖任何額外功能；支持流程不讀取日記庫內容。'**
  String get legalBillingPrivacyOneLiner;

  /// No description provided for @legalBillingSupportPageBody.
  ///
  /// In zh, this message translates to:
  /// **'僅透過 Google Play Billing 收款，為一次性支持、非訂閱、非會員；付款由 Google 處理，開發者不保存支持紀錄。支持流程不讀取日記庫內容。'**
  String get legalBillingSupportPageBody;

  /// No description provided for @legalExternalLinkUnavailableMessage.
  ///
  /// In zh, this message translates to:
  /// **'無法開啟瀏覽器，請稍後再試。'**
  String get legalExternalLinkUnavailableMessage;

  /// No description provided for @settingsLegalSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'法律與隱私'**
  String get settingsLegalSectionTitle;

  /// No description provided for @settingsLegalSectionDescription.
  ///
  /// In zh, this message translates to:
  /// **'可在 GitHub 查看原始碼、隱私政策與第三方聲明；有問題歡迎透過 Issues 聯絡。'**
  String get settingsLegalSectionDescription;

  /// No description provided for @settingsLegalSourceCodeTitle.
  ///
  /// In zh, this message translates to:
  /// **'GitHub 原始碼'**
  String get settingsLegalSourceCodeTitle;

  /// No description provided for @settingsLegalPrivacyPolicyTitle.
  ///
  /// In zh, this message translates to:
  /// **'隱私權政策'**
  String get settingsLegalPrivacyPolicyTitle;

  /// No description provided for @settingsLegalThirdPartyNoticesTitle.
  ///
  /// In zh, this message translates to:
  /// **'第三方聲明'**
  String get settingsLegalThirdPartyNoticesTitle;

  /// No description provided for @settingsLegalContactAuthorTitle.
  ///
  /// In zh, this message translates to:
  /// **'聯絡作者'**
  String get settingsLegalContactAuthorTitle;

  /// No description provided for @aboutPageTitle.
  ///
  /// In zh, this message translates to:
  /// **'介紹'**
  String get aboutPageTitle;

  /// No description provided for @aboutTabIntroLabel.
  ///
  /// In zh, this message translates to:
  /// **'簡介'**
  String get aboutTabIntroLabel;

  /// No description provided for @aboutTabIntroHeroTitle.
  ///
  /// In zh, this message translates to:
  /// **'把私人日記留在自己手上'**
  String get aboutTabIntroHeroTitle;

  /// No description provided for @aboutTabIntroHeroBody.
  ///
  /// In zh, this message translates to:
  /// **'Quill Diary 是為個人記錄設計的本機加密日記 App。您可以安心寫、快速找、隨時回顧，也能在需要時建立完整備份或匯出可閱讀內容；除非您主動操作，資料預設留在裝置上。'**
  String get aboutTabIntroHeroBody;

  /// No description provided for @aboutTabIntroChip0.
  ///
  /// In zh, this message translates to:
  /// **'資料留在裝置'**
  String get aboutTabIntroChip0;

  /// No description provided for @aboutTabIntroChip1.
  ///
  /// In zh, this message translates to:
  /// **'可匯出 Markdown'**
  String get aboutTabIntroChip1;

  /// No description provided for @aboutTabIntroChip2.
  ///
  /// In zh, this message translates to:
  /// **'全文搜尋'**
  String get aboutTabIntroChip2;

  /// No description provided for @aboutTabIntroChip3.
  ///
  /// In zh, this message translates to:
  /// **'完整加密備份'**
  String get aboutTabIntroChip3;

  /// No description provided for @aboutTabIntroChip4.
  ///
  /// In zh, this message translates to:
  /// **'可攜式匯出'**
  String get aboutTabIntroChip4;

  /// No description provided for @aboutTabIntroSection0Title.
  ///
  /// In zh, this message translates to:
  /// **'為什麼適合拿來寫日記'**
  String get aboutTabIntroSection0Title;

  /// No description provided for @aboutTabIntroSection0Subtitle.
  ///
  /// In zh, this message translates to:
  /// **'它不是把雲端筆記換個名字，而是把私人資料保護和日常使用一起考慮。'**
  String get aboutTabIntroSection0Subtitle;

  /// No description provided for @aboutTabIntroSection0Item0Title.
  ///
  /// In zh, this message translates to:
  /// **'本機加密保存'**
  String get aboutTabIntroSection0Item0Title;

  /// No description provided for @aboutTabIntroSection0Item0Body.
  ///
  /// In zh, this message translates to:
  /// **'正式日記、附件、草稿與搜尋索引都會留在裝置上，並受到加密或有效解鎖狀態保護。除非您主動備份或匯出，內容不會自動離開手機。'**
  String get aboutTabIntroSection0Item0Body;

  /// No description provided for @aboutTabIntroSection0Item1Title.
  ///
  /// In zh, this message translates to:
  /// **'不用註冊就能開始'**
  String get aboutTabIntroSection0Item1Title;

  /// No description provided for @aboutTabIntroSection0Item1Body.
  ///
  /// In zh, this message translates to:
  /// **'日常寫作不依賴帳戶系統或遠端伺服器。您不需要先建立帳戶，才能使用本機日記、搜尋與回顧功能。'**
  String get aboutTabIntroSection0Item1Body;

  /// No description provided for @aboutTabIntroSection0Item2Title.
  ///
  /// In zh, this message translates to:
  /// **'少收集、少干擾'**
  String get aboutTabIntroSection0Item2Title;

  /// No description provided for @aboutTabIntroSection0Item2Body.
  ///
  /// In zh, this message translates to:
  /// **'App 不內嵌廣告或追蹤 SDK，也不會把日記明文上傳到開發者控制的伺服器。您可以把它當成以隱私為前提的私人寫作空間。'**
  String get aboutTabIntroSection0Item2Body;

  /// No description provided for @aboutTabIntroSection1Title.
  ///
  /// In zh, this message translates to:
  /// **'您可以怎麼使用它'**
  String get aboutTabIntroSection1Title;

  /// No description provided for @aboutTabIntroSection1Subtitle.
  ///
  /// In zh, this message translates to:
  /// **'從當下記錄，到之後回顧整理，常用功能都圍繞個人日記情境設計。'**
  String get aboutTabIntroSection1Subtitle;

  /// No description provided for @aboutTabIntroSection1Item0Title.
  ///
  /// In zh, this message translates to:
  /// **'寫下每天想記住的內容'**
  String get aboutTabIntroSection1Item0Title;

  /// No description provided for @aboutTabIntroSection1Item0Body.
  ///
  /// In zh, this message translates to:
  /// **'支援標題、日期、標籤、圖片與一般附件。新建日記可直接開始寫，既有日記也能先看再編輯；需要時也能把內容匯出成 Markdown 或 HTML。'**
  String get aboutTabIntroSection1Item0Body;

  /// No description provided for @aboutTabIntroSection1Item1Title.
  ///
  /// In zh, this message translates to:
  /// **'用不同角度看自己的紀錄'**
  String get aboutTabIntroSection1Item1Title;

  /// No description provided for @aboutTabIntroSection1Item1Body.
  ///
  /// In zh, this message translates to:
  /// **'主畫面提供列表、日曆、標籤與總覽四種入口。您可以依時間瀏覽、按日期回看，或從標籤和統計整理自己的生活軌跡。'**
  String get aboutTabIntroSection1Item1Body;

  /// No description provided for @aboutTabIntroSection1Item2Title.
  ///
  /// In zh, this message translates to:
  /// **'找回以前寫過的內容'**
  String get aboutTabIntroSection1Item2Title;

  /// No description provided for @aboutTabIntroSection1Item2Body.
  ///
  /// In zh, this message translates to:
  /// **'解鎖後可搜尋標題、標籤與內文，適合回頭找某段經歷、某個關鍵字，或快速整理某段時間的紀錄。'**
  String get aboutTabIntroSection1Item2Body;

  /// No description provided for @aboutTabIntroSection1Item3Title.
  ///
  /// In zh, this message translates to:
  /// **'把回顧整理成可分享的形式'**
  String get aboutTabIntroSection1Item3Title;

  /// No description provided for @aboutTabIntroSection1Item3Body.
  ///
  /// In zh, this message translates to:
  /// **'您可以建立完整備份保存整個加密日記庫，也能匯出 Markdown 或 HTML，方便自己閱讀、整理或搬移內容。'**
  String get aboutTabIntroSection1Item3Body;

  /// No description provided for @aboutTabIntroSection2Title.
  ///
  /// In zh, this message translates to:
  /// **'資料掌控權在您手上'**
  String get aboutTabIntroSection2Title;

  /// No description provided for @aboutTabIntroSection2Subtitle.
  ///
  /// In zh, this message translates to:
  /// **'備份、匯出與解鎖方式各自扮演不同角色，目的是讓您能保留資料，也能理解風險邊界。'**
  String get aboutTabIntroSection2Subtitle;

  /// No description provided for @aboutTabIntroSection2Item0Title.
  ///
  /// In zh, this message translates to:
  /// **'可信裝置與復原金鑰'**
  String get aboutTabIntroSection2Item0Title;

  /// No description provided for @aboutTabIntroSection2Item0Body.
  ///
  /// In zh, this message translates to:
  /// **'日常可用螢幕鎖或生物辨識快速回到 App；換機、還原或可信狀態失效時，復原金鑰才是重新取得存取權的關鍵。'**
  String get aboutTabIntroSection2Item0Body;

  /// No description provided for @aboutTabIntroSection2Item1Title.
  ///
  /// In zh, this message translates to:
  /// **'完整備份保存的是加密日記庫'**
  String get aboutTabIntroSection2Item1Title;

  /// No description provided for @aboutTabIntroSection2Item1Body.
  ///
  /// In zh, this message translates to:
  /// **'完整備份保留的是整個加密日記庫，適合之後完整還原，不是直接打開就能閱讀的文件。'**
  String get aboutTabIntroSection2Item1Body;

  /// No description provided for @aboutTabIntroSection2Item2Title.
  ///
  /// In zh, this message translates to:
  /// **'匯出內容後要自行保護'**
  String get aboutTabIntroSection2Item2Title;

  /// No description provided for @aboutTabIntroSection2Item2Body.
  ///
  /// In zh, this message translates to:
  /// **'Markdown 與 HTML 匯出適合閱讀、整理與轉移內容，但它們屬於可讀文件，不再等同於 App 內的加密保存狀態。'**
  String get aboutTabIntroSection2Item2Body;

  /// No description provided for @aboutTabIntroSection3Title.
  ///
  /// In zh, this message translates to:
  /// **'開源與品牌'**
  String get aboutTabIntroSection3Title;

  /// No description provided for @aboutTabIntroSection3Subtitle.
  ///
  /// In zh, this message translates to:
  /// **'您可以查看原始碼與授權條件，也能清楚知道品牌使用界線。'**
  String get aboutTabIntroSection3Subtitle;

  /// No description provided for @aboutTabIntroSection3Item0Title.
  ///
  /// In zh, this message translates to:
  /// **'AGPL-3.0 開源'**
  String get aboutTabIntroSection3Item0Title;

  /// No description provided for @aboutTabIntroSection3Item0Body.
  ///
  /// In zh, this message translates to:
  /// **'原始碼以 GNU Affero General Public License v3.0 發布，讓產品行為與實作方式能被公開檢視，增加透明度與可驗證性。'**
  String get aboutTabIntroSection3Item0Body;

  /// No description provided for @aboutTabIntroSection3Item1Title.
  ///
  /// In zh, this message translates to:
  /// **'Quill Diary 品牌'**
  String get aboutTabIntroSection3Item1Title;

  /// No description provided for @aboutTabUnlockSessionLabel.
  ///
  /// In zh, this message translates to:
  /// **'解鎖與狀態'**
  String get aboutTabUnlockSessionLabel;

  /// No description provided for @aboutTabUnlockSessionHeroTitle.
  ///
  /// In zh, this message translates to:
  /// **'在方便解鎖和保護資料之間取得平衡'**
  String get aboutTabUnlockSessionHeroTitle;

  /// No description provided for @aboutTabUnlockSessionHeroBody.
  ///
  /// In zh, this message translates to:
  /// **'Quill Diary 不會要求您每次切出再回來都重新做最重的驗證，但也不會讓已解鎖狀態無限延長。這一頁說明不同解鎖方式、自動鎖定，以及什麼情況下會需要復原金鑰。'**
  String get aboutTabUnlockSessionHeroBody;

  /// No description provided for @aboutTabUnlockSessionChip0.
  ///
  /// In zh, this message translates to:
  /// **'生物辨識'**
  String get aboutTabUnlockSessionChip0;

  /// No description provided for @aboutTabUnlockSessionChip1.
  ///
  /// In zh, this message translates to:
  /// **'螢幕鎖'**
  String get aboutTabUnlockSessionChip1;

  /// No description provided for @aboutTabUnlockSessionChip2.
  ///
  /// In zh, this message translates to:
  /// **'自動鎖定'**
  String get aboutTabUnlockSessionChip2;

  /// No description provided for @aboutTabUnlockSessionChip3.
  ///
  /// In zh, this message translates to:
  /// **'復原金鑰'**
  String get aboutTabUnlockSessionChip3;

  /// No description provided for @aboutTabUnlockSessionSection0Title.
  ///
  /// In zh, this message translates to:
  /// **'解鎖方式怎麼選'**
  String get aboutTabUnlockSessionSection0Title;

  /// No description provided for @aboutTabUnlockSessionSection0Subtitle.
  ///
  /// In zh, this message translates to:
  /// **'您可以依裝置習慣與想要的保護程度，在設定頁切換不同模式。'**
  String get aboutTabUnlockSessionSection0Subtitle;

  /// No description provided for @aboutTabUnlockSessionSection0Item0Title.
  ///
  /// In zh, this message translates to:
  /// **'無'**
  String get aboutTabUnlockSessionSection0Item0Title;

  /// No description provided for @aboutTabUnlockSessionSection0Item0Body.
  ///
  /// In zh, this message translates to:
  /// **'鎖定後不額外驗證，回到 App 會直接恢復。適合尚未設定裝置螢幕鎖的情況，但保護力最低。'**
  String get aboutTabUnlockSessionSection0Item0Body;

  /// No description provided for @aboutTabUnlockSessionSection0Item1Title.
  ///
  /// In zh, this message translates to:
  /// **'裝置螢幕鎖'**
  String get aboutTabUnlockSessionSection0Item1Title;

  /// No description provided for @aboutTabUnlockSessionSection0Item1Body.
  ///
  /// In zh, this message translates to:
  /// **'回到 App 時用 PIN、圖案或密碼重新驗證。適合想保留系統層保護，又不一定使用生物辨識的人。'**
  String get aboutTabUnlockSessionSection0Item1Body;

  /// No description provided for @aboutTabUnlockSessionSection0Item2Title.
  ///
  /// In zh, this message translates to:
  /// **'生物驗證'**
  String get aboutTabUnlockSessionSection0Item2Title;

  /// No description provided for @aboutTabUnlockSessionSection0Item2Body.
  ///
  /// In zh, this message translates to:
  /// **'優先使用指紋或臉部驗證，失敗或取消時可改走螢幕鎖。這通常是日常使用最方便的方式。'**
  String get aboutTabUnlockSessionSection0Item2Body;

  /// No description provided for @aboutTabUnlockSessionSection0Item3Title.
  ///
  /// In zh, this message translates to:
  /// **'共同前提'**
  String get aboutTabUnlockSessionSection0Item3Title;

  /// No description provided for @aboutTabUnlockSessionSection0Item3Body.
  ///
  /// In zh, this message translates to:
  /// **'螢幕鎖與生物驗證模式都要求裝置先設定好螢幕鎖；要使用生物辨識，也必須先在系統中完成登錄。'**
  String get aboutTabUnlockSessionSection0Item3Body;

  /// No description provided for @aboutTabUnlockSessionSection1Title.
  ///
  /// In zh, this message translates to:
  /// **'什麼時候會重新驗證'**
  String get aboutTabUnlockSessionSection1Title;

  /// No description provided for @aboutTabUnlockSessionSection1Subtitle.
  ///
  /// In zh, this message translates to:
  /// **'只有在有效解鎖期間內，正式日記、草稿與搜尋索引才會保持可用。'**
  String get aboutTabUnlockSessionSection1Subtitle;

  /// No description provided for @aboutTabUnlockSessionSection1Item0Title.
  ///
  /// In zh, this message translates to:
  /// **'解鎖中'**
  String get aboutTabUnlockSessionSection1Item0Title;

  /// No description provided for @aboutTabUnlockSessionSection1Item0Body.
  ///
  /// In zh, this message translates to:
  /// **'解鎖後，您可以正常讀寫日記、編輯草稿、附加檔案，並使用全文搜尋。'**
  String get aboutTabUnlockSessionSection1Item0Body;

  /// No description provided for @aboutTabUnlockSessionSection1Item1Title.
  ///
  /// In zh, this message translates to:
  /// **'背景逾時'**
  String get aboutTabUnlockSessionSection1Item1Title;

  /// No description provided for @aboutTabUnlockSessionSection1Item2Title.
  ///
  /// In zh, this message translates to:
  /// **'回到 App 時'**
  String get aboutTabUnlockSessionSection1Item2Title;

  /// No description provided for @aboutTabUnlockSessionSection1Item2Body.
  ///
  /// In zh, this message translates to:
  /// **'如果只是短暫切出去再回來，通常不會立刻要求重驗。若放在背景超過時間後才回來，就會依您選擇的模式決定是否直接恢復或跳出系統驗證。'**
  String get aboutTabUnlockSessionSection1Item2Body;

  /// No description provided for @aboutTabUnlockSessionSection1Item3Title.
  ///
  /// In zh, this message translates to:
  /// **'驗證取消或失敗後'**
  String get aboutTabUnlockSessionSection1Item3Title;

  /// No description provided for @aboutTabUnlockSessionSection1Item3Body.
  ///
  /// In zh, this message translates to:
  /// **'如果這次驗證取消或沒有通過，App 會維持鎖定，不會一直反覆跳窗。您可以在方便時再手動重試。'**
  String get aboutTabUnlockSessionSection1Item3Body;

  /// No description provided for @aboutTabUnlockSessionSection2Title.
  ///
  /// In zh, this message translates to:
  /// **'為什麼還需要復原金鑰'**
  String get aboutTabUnlockSessionSection2Title;

  /// No description provided for @aboutTabUnlockSessionSection2Subtitle.
  ///
  /// In zh, this message translates to:
  /// **'可信裝置提供的是便利路徑，真正能跨裝置、跨狀態重新進入日記庫的依據仍然是復原金鑰。'**
  String get aboutTabUnlockSessionSection2Subtitle;

  /// No description provided for @aboutTabUnlockSessionSection2Item0Title.
  ///
  /// In zh, this message translates to:
  /// **'換機或重設後'**
  String get aboutTabUnlockSessionSection2Item0Title;

  /// No description provided for @aboutTabUnlockSessionSection2Item0Body.
  ///
  /// In zh, this message translates to:
  /// **'當您換手機、清除 App 資料，或要在另一台裝置上恢復日記庫時，可信裝置狀態通常不會跟著過去，這時就需要復原金鑰。'**
  String get aboutTabUnlockSessionSection2Item0Body;

  /// No description provided for @aboutTabUnlockSessionSection2Item1Title.
  ///
  /// In zh, this message translates to:
  /// **'可信狀態失效'**
  String get aboutTabUnlockSessionSection2Item1Title;

  /// No description provided for @aboutTabUnlockSessionSection2Item1Body.
  ///
  /// In zh, this message translates to:
  /// **'如果裝置上的可信狀態失效，或與目前的日記庫狀態不再對應，就不能只靠本機快速進入。'**
  String get aboutTabUnlockSessionSection2Item1Body;

  /// No description provided for @aboutTabUnlockSessionSection2Item2Title.
  ///
  /// In zh, this message translates to:
  /// **'最終存取權'**
  String get aboutTabUnlockSessionSection2Item2Title;

  /// No description provided for @aboutTabUnlockSessionSection2Item2Body.
  ///
  /// In zh, this message translates to:
  /// **'復原金鑰不是可有可無的備用功能，而是換機、還原與可信裝置失效時的必要憑證，請務必妥善保存。'**
  String get aboutTabUnlockSessionSection2Item2Body;

  /// No description provided for @aboutTabEncryptionLabel.
  ///
  /// In zh, this message translates to:
  /// **'加密與解密'**
  String get aboutTabEncryptionLabel;

  /// No description provided for @aboutTabEncryptionHeroTitle.
  ///
  /// In zh, this message translates to:
  /// **'資料預設以加密形式保存'**
  String get aboutTabEncryptionHeroTitle;

  /// No description provided for @aboutTabEncryptionHeroBody.
  ///
  /// In zh, this message translates to:
  /// **'Quill Diary 會先保護內容，再把它寫進日記庫。正式日記、附件與其他敏感資料會使用 LDJ2 格式封裝，內容以 AES-256-GCM 加密，並透過可信裝置或復原金鑰的正確路徑才能打開。'**
  String get aboutTabEncryptionHeroBody;

  /// No description provided for @aboutTabEncryptionChip0.
  ///
  /// In zh, this message translates to:
  /// **'本機加密'**
  String get aboutTabEncryptionChip0;

  /// No description provided for @aboutTabEncryptionChip1.
  ///
  /// In zh, this message translates to:
  /// **'LDJ2'**
  String get aboutTabEncryptionChip1;

  /// No description provided for @aboutTabEncryptionChip2.
  ///
  /// In zh, this message translates to:
  /// **'AES-256-GCM'**
  String get aboutTabEncryptionChip2;

  /// No description provided for @aboutTabEncryptionChip3.
  ///
  /// In zh, this message translates to:
  /// **'Argon2id'**
  String get aboutTabEncryptionChip3;

  /// No description provided for @aboutTabEncryptionChip4.
  ///
  /// In zh, this message translates to:
  /// **'可信裝置'**
  String get aboutTabEncryptionChip4;

  /// No description provided for @aboutTabEncryptionChip5.
  ///
  /// In zh, this message translates to:
  /// **'Android Keystore'**
  String get aboutTabEncryptionChip5;

  /// No description provided for @aboutTabEncryptionSection0Title.
  ///
  /// In zh, this message translates to:
  /// **'這套保護機制在幫您做什麼'**
  String get aboutTabEncryptionSection0Title;

  /// No description provided for @aboutTabEncryptionSection0Subtitle.
  ///
  /// In zh, this message translates to:
  /// **'重點不是堆術語，而是讓您知道正式資料在存放與讀取時，都有清楚而一致的保護流程。'**
  String get aboutTabEncryptionSection0Subtitle;

  /// No description provided for @aboutTabEncryptionSection0Item0Title.
  ///
  /// In zh, this message translates to:
  /// **'LDJ2 + AES-256-GCM 保護內容'**
  String get aboutTabEncryptionSection0Item0Title;

  /// No description provided for @aboutTabEncryptionSection0Item0Body.
  ///
  /// In zh, this message translates to:
  /// **'正式日記與附件會先用 LDJ2 格式封裝，再以 AES-256-GCM 加密正文。即使看到檔案本身，也不是直接就能讀懂的內容。'**
  String get aboutTabEncryptionSection0Item0Body;

  /// No description provided for @aboutTabEncryptionSection0Item1Title.
  ///
  /// In zh, this message translates to:
  /// **'被竄改時應該直接失敗'**
  String get aboutTabEncryptionSection0Item1Title;

  /// No description provided for @aboutTabEncryptionSection0Item1Body.
  ///
  /// In zh, this message translates to:
  /// **'正式資料不只加密，也帶有完整性驗證。若內容或檔案 header 被動過手腳，解密應該直接失敗，而不是悄悄回傳可疑內容。'**
  String get aboutTabEncryptionSection0Item1Body;

  /// No description provided for @aboutTabEncryptionSection0Item2Title.
  ///
  /// In zh, this message translates to:
  /// **'每個檔案都有獨立金鑰'**
  String get aboutTabEncryptionSection0Item2Title;

  /// No description provided for @aboutTabEncryptionSection0Item2Body.
  ///
  /// In zh, this message translates to:
  /// **'每個加密檔案都會先產生自己的隨機 file key，再由日記庫層的保護機制包裝。這讓不同內容不會共用同一把檔案金鑰。'**
  String get aboutTabEncryptionSection0Item2Body;

  /// No description provided for @aboutTabEncryptionSection1Title.
  ///
  /// In zh, this message translates to:
  /// **'您可以怎麼打開自己的資料'**
  String get aboutTabEncryptionSection1Title;

  /// No description provided for @aboutTabEncryptionSection1Subtitle.
  ///
  /// In zh, this message translates to:
  /// **'日常與緊急情況走的是不同入口，但最後都會回到同一套解密流程。'**
  String get aboutTabEncryptionSection1Subtitle;

  /// No description provided for @aboutTabEncryptionSection1Item0Title.
  ///
  /// In zh, this message translates to:
  /// **'可信裝置'**
  String get aboutTabEncryptionSection1Item0Title;

  /// No description provided for @aboutTabEncryptionSection1Item0Body.
  ///
  /// In zh, this message translates to:
  /// **'在同一台已建立可信狀態的裝置上，日常通常可透過螢幕鎖或生物辨識重新進入。這條路徑會由 Android Keystore 保護日記庫層的重要金鑰。'**
  String get aboutTabEncryptionSection1Item0Body;

  /// No description provided for @aboutTabEncryptionSection1Item1Title.
  ///
  /// In zh, this message translates to:
  /// **'復原金鑰'**
  String get aboutTabEncryptionSection1Item1Title;

  /// No description provided for @aboutTabEncryptionSection1Item1Body.
  ///
  /// In zh, this message translates to:
  /// **'當您換機、還原備份或本機可信狀態失效時，可以用復原金鑰重新取得進入整個日記庫的能力。復原金鑰會先經過 Argon2id 推導，再進入後續解密流程。'**
  String get aboutTabEncryptionSection1Item1Body;

  /// No description provided for @aboutTabEncryptionSection1Item2Title.
  ///
  /// In zh, this message translates to:
  /// **'先確認日記庫，再解開各檔'**
  String get aboutTabEncryptionSection1Item2Title;

  /// No description provided for @aboutTabEncryptionSection1Item2Body.
  ///
  /// In zh, this message translates to:
  /// **'流程會先確認目前的存取狀態能否正確進入日記庫，之後才解開各個檔案。這能避免用錯憑證時，把問題誤判成資料毀損。'**
  String get aboutTabEncryptionSection1Item2Body;

  /// No description provided for @aboutTabEncryptionSection2Title.
  ///
  /// In zh, this message translates to:
  /// **'使用前要知道的邊界'**
  String get aboutTabEncryptionSection2Title;

  /// No description provided for @aboutTabEncryptionSection2Subtitle.
  ///
  /// In zh, this message translates to:
  /// **'加密能保護日記庫本身，但不代表所有情境都自動安全。'**
  String get aboutTabEncryptionSection2Subtitle;

  /// No description provided for @aboutTabEncryptionSection2Item0Title.
  ///
  /// In zh, this message translates to:
  /// **'匯出後不再是同一層保護'**
  String get aboutTabEncryptionSection2Item0Title;

  /// No description provided for @aboutTabEncryptionSection2Item0Body.
  ///
  /// In zh, this message translates to:
  /// **'只要您把內容匯出成 Markdown 或 HTML，可讀文件之後的存放與分享風險，就不再由 App 內的加密機制接手。'**
  String get aboutTabEncryptionSection2Item0Body;

  /// No description provided for @aboutTabEncryptionSection2Item1Title.
  ///
  /// In zh, this message translates to:
  /// **'復原金鑰要自己保管'**
  String get aboutTabEncryptionSection2Item1Title;

  /// No description provided for @aboutTabEncryptionSection2Item1Body.
  ///
  /// In zh, this message translates to:
  /// **'復原金鑰是重新進入日記庫的重要依據。若它外洩、遺失，或您沒有妥善保存，之後可能影響資料安全或可恢復性。'**
  String get aboutTabEncryptionSection2Item1Body;

  /// No description provided for @aboutTabEncryptionSection2Item2Title.
  ///
  /// In zh, this message translates to:
  /// **'它保護的是靜態資料'**
  String get aboutTabEncryptionSection2Item2Title;

  /// No description provided for @aboutTabEncryptionSection2Item2Body.
  ///
  /// In zh, this message translates to:
  /// **'這套設計主要保護的是存放在裝置上的加密資料；若裝置本身遭到入侵、已解鎖狀態被他人取得，風險就不只取決於檔案格式本身。'**
  String get aboutTabEncryptionSection2Item2Body;

  /// No description provided for @aboutTabSearchIndexLabel.
  ///
  /// In zh, this message translates to:
  /// **'索引與搜尋'**
  String get aboutTabSearchIndexLabel;

  /// No description provided for @aboutTabSearchIndexHeroTitle.
  ///
  /// In zh, this message translates to:
  /// **'解鎖後，您可以快速找回以前寫過的內容'**
  String get aboutTabSearchIndexHeroTitle;

  /// No description provided for @aboutTabSearchIndexHeroBody.
  ///
  /// In zh, this message translates to:
  /// **'搜尋不是每次都把所有日記重新讀一遍，而是透過一份加密索引來加快查找。這份索引只在解鎖期間打開，讓搜尋體驗和資料保護可以兼顧。'**
  String get aboutTabSearchIndexHeroBody;

  /// No description provided for @aboutTabSearchIndexChip0.
  ///
  /// In zh, this message translates to:
  /// **'標題/內文搜尋'**
  String get aboutTabSearchIndexChip0;

  /// No description provided for @aboutTabSearchIndexChip1.
  ///
  /// In zh, this message translates to:
  /// **'加密索引'**
  String get aboutTabSearchIndexChip1;

  /// No description provided for @aboutTabSearchIndexChip2.
  ///
  /// In zh, this message translates to:
  /// **'解鎖期間可用'**
  String get aboutTabSearchIndexChip2;

  /// No description provided for @aboutTabSearchIndexChip3.
  ///
  /// In zh, this message translates to:
  /// **'可重建'**
  String get aboutTabSearchIndexChip3;

  /// No description provided for @aboutTabSearchIndexSection0Title.
  ///
  /// In zh, this message translates to:
  /// **'搜尋能幫您找什麼'**
  String get aboutTabSearchIndexSection0Title;

  /// No description provided for @aboutTabSearchIndexSection0Subtitle.
  ///
  /// In zh, this message translates to:
  /// **'適合在回顧、整理或想找某段經歷時，快速縮小範圍。'**
  String get aboutTabSearchIndexSection0Subtitle;

  /// No description provided for @aboutTabSearchIndexSection0Item0Title.
  ///
  /// In zh, this message translates to:
  /// **'搜尋標題、標籤與內文'**
  String get aboutTabSearchIndexSection0Item0Title;

  /// No description provided for @aboutTabSearchIndexSection0Item0Body.
  ///
  /// In zh, this message translates to:
  /// **'您可以直接查找標題、內文與標籤中的關鍵字，不需要一篇篇翻找過去寫過什麼。'**
  String get aboutTabSearchIndexSection0Item0Body;

  /// No description provided for @aboutTabSearchIndexSection0Item1Title.
  ///
  /// In zh, this message translates to:
  /// **'結果來自正式已儲存內容'**
  String get aboutTabSearchIndexSection0Item1Title;

  /// No description provided for @aboutTabSearchIndexSection0Item1Body.
  ///
  /// In zh, this message translates to:
  /// **'搜尋看到的是已正式寫入日記庫的內容，而不是暫時停在編輯器中的草稿。'**
  String get aboutTabSearchIndexSection0Item1Body;

  /// No description provided for @aboutTabSearchIndexSection0Item2Title.
  ///
  /// In zh, this message translates to:
  /// **'索引本身也受保護'**
  String get aboutTabSearchIndexSection0Item2Title;

  /// No description provided for @aboutTabSearchIndexSection0Item2Body.
  ///
  /// In zh, this message translates to:
  /// **'搜尋不是建立一份明文資料庫放在旁邊，而是使用另一份加密索引來支撐查找速度。'**
  String get aboutTabSearchIndexSection0Item2Body;

  /// No description provided for @aboutTabSearchIndexSection1Title.
  ///
  /// In zh, this message translates to:
  /// **'為什麼搜尋不會拖慢日常使用'**
  String get aboutTabSearchIndexSection1Title;

  /// No description provided for @aboutTabSearchIndexSection1Subtitle.
  ///
  /// In zh, this message translates to:
  /// **'它把查找工作交給索引層，而不是每次都逐篇掃描正式日記。'**
  String get aboutTabSearchIndexSection1Subtitle;

  /// No description provided for @aboutTabSearchIndexSection1Item0Title.
  ///
  /// In zh, this message translates to:
  /// **'以索引換速度'**
  String get aboutTabSearchIndexSection1Item0Title;

  /// No description provided for @aboutTabSearchIndexSection1Item0Body.
  ///
  /// In zh, this message translates to:
  /// **'當您輸入關鍵字時，系統會查詢索引，而不是臨時解密整個日記庫後逐篇比對。'**
  String get aboutTabSearchIndexSection1Item0Body;

  /// No description provided for @aboutTabSearchIndexSection1Item1Title.
  ///
  /// In zh, this message translates to:
  /// **'正式儲存後才更新'**
  String get aboutTabSearchIndexSection1Item1Title;

  /// No description provided for @aboutTabSearchIndexSection1Item1Body.
  ///
  /// In zh, this message translates to:
  /// **'只有正式儲存成功或匯入完成後，索引才會同步更新；這樣搜尋結果才不會混入尚未確定的草稿內容。'**
  String get aboutTabSearchIndexSection1Item1Body;

  /// No description provided for @aboutTabSearchIndexSection1Item2Title.
  ///
  /// In zh, this message translates to:
  /// **'必要時可重建'**
  String get aboutTabSearchIndexSection1Item2Title;

  /// No description provided for @aboutTabSearchIndexSection1Item2Body.
  ///
  /// In zh, this message translates to:
  /// **'索引屬於衍生資料。如果格式更新、還原備份，或目前狀態不適合沿用，系統會刪除並重新生成。'**
  String get aboutTabSearchIndexSection1Item2Body;

  /// No description provided for @aboutTabSearchIndexSection2Title.
  ///
  /// In zh, this message translates to:
  /// **'它和安全性的關係'**
  String get aboutTabSearchIndexSection2Title;

  /// No description provided for @aboutTabSearchIndexSection2Subtitle.
  ///
  /// In zh, this message translates to:
  /// **'搜尋好用，不代表要放棄保護邊界。'**
  String get aboutTabSearchIndexSection2Subtitle;

  /// No description provided for @aboutTabSearchIndexSection2Item0Title.
  ///
  /// In zh, this message translates to:
  /// **'只在解鎖期間可用'**
  String get aboutTabSearchIndexSection2Item0Title;

  /// No description provided for @aboutTabSearchIndexSection2Item0Body.
  ///
  /// In zh, this message translates to:
  /// **'搜尋索引只會在有效解鎖期間打開；App 鎖定後，索引也會跟著關閉。'**
  String get aboutTabSearchIndexSection2Item0Body;

  /// No description provided for @aboutTabSearchIndexSection2Item1Title.
  ///
  /// In zh, this message translates to:
  /// **'草稿不進搜尋'**
  String get aboutTabSearchIndexSection2Item1Title;

  /// No description provided for @aboutTabSearchIndexSection2Item1Body.
  ///
  /// In zh, this message translates to:
  /// **'編輯中的草稿不會出現在搜尋結果裡，避免把未完成內容誤當成正式紀錄。'**
  String get aboutTabSearchIndexSection2Item1Body;

  /// No description provided for @aboutTabSearchIndexSection2Item2Title.
  ///
  /// In zh, this message translates to:
  /// **'正式資料仍以日記庫為準'**
  String get aboutTabSearchIndexSection2Item2Title;

  /// No description provided for @aboutTabSearchIndexSection2Item2Body.
  ///
  /// In zh, this message translates to:
  /// **'搜尋索引的工作是幫您更快找到內容，不是取代正式日記資料本體；真正的權威來源仍然是加密日記庫。'**
  String get aboutTabSearchIndexSection2Item2Body;

  /// No description provided for @aboutTabEditorLabel.
  ///
  /// In zh, this message translates to:
  /// **'日記編輯器'**
  String get aboutTabEditorLabel;

  /// No description provided for @aboutTabEditorHeroTitle.
  ///
  /// In zh, this message translates to:
  /// **'寫作、暫存與正式保存各走自己的路'**
  String get aboutTabEditorHeroTitle;

  /// No description provided for @aboutTabEditorHeroBody.
  ///
  /// In zh, this message translates to:
  /// **'編輯器不會把「還在寫」和「已正式保存」混在一起。它會先把變更寫成加密草稿，等您確認儲存後，再更新正式日記與搜尋索引，讓寫作過程比較安心，也更容易接續。'**
  String get aboutTabEditorHeroBody;

  /// No description provided for @aboutTabEditorChip0.
  ///
  /// In zh, this message translates to:
  /// **'可匯出 Markdown'**
  String get aboutTabEditorChip0;

  /// No description provided for @aboutTabEditorChip1.
  ///
  /// In zh, this message translates to:
  /// **'圖片附件'**
  String get aboutTabEditorChip1;

  /// No description provided for @aboutTabEditorChip2.
  ///
  /// In zh, this message translates to:
  /// **'自動草稿'**
  String get aboutTabEditorChip2;

  /// No description provided for @aboutTabEditorChip3.
  ///
  /// In zh, this message translates to:
  /// **'未儲存提醒'**
  String get aboutTabEditorChip3;

  /// No description provided for @aboutTabEditorSection0Title.
  ///
  /// In zh, this message translates to:
  /// **'日常寫作功能'**
  String get aboutTabEditorSection0Title;

  /// No description provided for @aboutTabEditorSection0Subtitle.
  ///
  /// In zh, this message translates to:
  /// **'以個人記錄為核心，把常用的整理方式都放進同一個編輯流程。'**
  String get aboutTabEditorSection0Subtitle;

  /// No description provided for @aboutTabEditorSection0Item0Title.
  ///
  /// In zh, this message translates to:
  /// **'新建或修改既有日記'**
  String get aboutTabEditorSection0Item0Title;

  /// No description provided for @aboutTabEditorSection0Item0Body.
  ///
  /// In zh, this message translates to:
  /// **'新建日記會直接進入編輯模式；既有日記則可先閱讀，確定要改時再切換到編輯狀態。'**
  String get aboutTabEditorSection0Item0Body;

  /// No description provided for @aboutTabEditorSection0Item1Title.
  ///
  /// In zh, this message translates to:
  /// **'內容、標題、日期與標籤'**
  String get aboutTabEditorSection0Item1Title;

  /// No description provided for @aboutTabEditorSection0Item1Body.
  ///
  /// In zh, this message translates to:
  /// **'您可以編輯日記內容，同時整理標題、日期、時間與標籤。正式儲存時會檢查必要欄位，避免留下不完整紀錄；需要時也能把內容匯出成 Markdown。'**
  String get aboutTabEditorSection0Item1Body;

  /// No description provided for @aboutTabEditorSection0Item2Title.
  ///
  /// In zh, this message translates to:
  /// **'圖片與一般附件'**
  String get aboutTabEditorSection0Item2Title;

  /// No description provided for @aboutTabEditorSection0Item2Body.
  ///
  /// In zh, this message translates to:
  /// **'可加入多張圖片或一般檔案，並調整圖片順序。這讓日記不只是一段文字，也能保留當下的素材與脈絡。'**
  String get aboutTabEditorSection0Item2Body;

  /// No description provided for @aboutTabEditorSection1Title.
  ///
  /// In zh, this message translates to:
  /// **'草稿機制'**
  String get aboutTabEditorSection1Title;

  /// No description provided for @aboutTabEditorSection1Subtitle.
  ///
  /// In zh, this message translates to:
  /// **'草稿不是額外的小功能，而是整個寫作體驗的重要保護層。'**
  String get aboutTabEditorSection1Subtitle;

  /// No description provided for @aboutTabEditorSection1Item0Title.
  ///
  /// In zh, this message translates to:
  /// **'變更會自動保存'**
  String get aboutTabEditorSection1Item0Title;

  /// No description provided for @aboutTabEditorSection1Item0Body.
  ///
  /// In zh, this message translates to:
  /// **'進入編輯後，只要標題、日期、標籤、內文或附件有變動，就會自動寫成加密草稿，降低中斷時遺失內容的風險。'**
  String get aboutTabEditorSection1Item0Body;

  /// No description provided for @aboutTabEditorSection1Item1Title.
  ///
  /// In zh, this message translates to:
  /// **'再次開啟時可還原'**
  String get aboutTabEditorSection1Item1Title;

  /// No description provided for @aboutTabEditorSection1Item1Body.
  ///
  /// In zh, this message translates to:
  /// **'重新打開同一篇日記或未完成的新建內容時，如果本地仍保留草稿，App 會先詢問您要不要接著上次進度寫。'**
  String get aboutTabEditorSection1Item1Body;

  /// No description provided for @aboutTabEditorSection1Item2Title.
  ///
  /// In zh, this message translates to:
  /// **'正式儲存後自動清理'**
  String get aboutTabEditorSection1Item2Title;

  /// No description provided for @aboutTabEditorSection1Item2Body.
  ///
  /// In zh, this message translates to:
  /// **'當內容成功正式寫入日記庫，草稿就會被清掉；如果您取消編輯且沒有留下新變更，也不會一直堆積舊草稿。'**
  String get aboutTabEditorSection1Item2Body;

  /// No description provided for @aboutTabEditorSection2Title.
  ///
  /// In zh, this message translates to:
  /// **'和其他資料的關係'**
  String get aboutTabEditorSection2Title;

  /// No description provided for @aboutTabEditorSection2Subtitle.
  ///
  /// In zh, this message translates to:
  /// **'編輯中的內容與正式保存的內容有清楚界線，避免把兩者混為一談。'**
  String get aboutTabEditorSection2Subtitle;

  /// No description provided for @aboutTabEditorSection2Item0Title.
  ///
  /// In zh, this message translates to:
  /// **'草稿不進搜尋結果'**
  String get aboutTabEditorSection2Item0Title;

  /// No description provided for @aboutTabEditorSection2Item0Body.
  ///
  /// In zh, this message translates to:
  /// **'搜尋只看正式寫入日記庫的內容，草稿不會出現在結果中，避免未完成內容被誤認為正式紀錄。'**
  String get aboutTabEditorSection2Item0Body;

  /// No description provided for @aboutTabEditorSection2Item1Title.
  ///
  /// In zh, this message translates to:
  /// **'草稿不進完整備份'**
  String get aboutTabEditorSection2Item1Title;

  /// No description provided for @aboutTabEditorSection2Item1Body.
  ///
  /// In zh, this message translates to:
  /// **'完整備份只封裝正式日記庫，不包含 `drafts/`。這代表備份與還原的重點是正式資料，而不是尚未定稿的編輯狀態。'**
  String get aboutTabEditorSection2Item1Body;

  /// No description provided for @aboutTabEditorSection2Item2Title.
  ///
  /// In zh, this message translates to:
  /// **'未儲存提示'**
  String get aboutTabEditorSection2Item2Title;

  /// No description provided for @aboutTabEditorSection2Item2Body.
  ///
  /// In zh, this message translates to:
  /// **'如果某篇日記仍留有本地草稿，列表與檢視模式會顯示「未儲存」標記，提醒您還有內容尚未正式保存。'**
  String get aboutTabEditorSection2Item2Body;

  /// No description provided for @aboutTabBackupRestoreLabel.
  ///
  /// In zh, this message translates to:
  /// **'備份與還原'**
  String get aboutTabBackupRestoreLabel;

  /// No description provided for @aboutTabBackupRestoreHeroTitle.
  ///
  /// In zh, this message translates to:
  /// **'保留整個日記庫，或帶出可閱讀內容'**
  String get aboutTabBackupRestoreHeroTitle;

  /// No description provided for @aboutTabBackupRestoreHeroBody.
  ///
  /// In zh, this message translates to:
  /// **'備份與匯出看起來都像「把資料帶出去」，但用途完全不同。完整備份用來保留整個加密日記庫，Markdown / HTML 則是把內容變成可閱讀、可整理、可再匯入的形式。這兩條流程不能混用。'**
  String get aboutTabBackupRestoreHeroBody;

  /// No description provided for @aboutTabBackupRestoreChip0.
  ///
  /// In zh, this message translates to:
  /// **'完整加密備份'**
  String get aboutTabBackupRestoreChip0;

  /// No description provided for @aboutTabBackupRestoreChip1.
  ///
  /// In zh, this message translates to:
  /// **'Google Drive'**
  String get aboutTabBackupRestoreChip1;

  /// No description provided for @aboutTabBackupRestoreChip2.
  ///
  /// In zh, this message translates to:
  /// **'Markdown'**
  String get aboutTabBackupRestoreChip2;

  /// No description provided for @aboutTabBackupRestoreChip3.
  ///
  /// In zh, this message translates to:
  /// **'HTML'**
  String get aboutTabBackupRestoreChip3;

  /// No description provided for @aboutTabBackupRestoreSection0Title.
  ///
  /// In zh, this message translates to:
  /// **'完整備份適合什麼情境'**
  String get aboutTabBackupRestoreSection0Title;

  /// No description provided for @aboutTabBackupRestoreSection0Subtitle.
  ///
  /// In zh, this message translates to:
  /// **'如果您想保留整個正式日記庫，之後能原樣恢復，走的就是完整備份。'**
  String get aboutTabBackupRestoreSection0Subtitle;

  /// No description provided for @aboutTabBackupRestoreSection0Item0Title.
  ///
  /// In zh, this message translates to:
  /// **'保存整個加密日記庫'**
  String get aboutTabBackupRestoreSection0Item0Title;

  /// No description provided for @aboutTabBackupRestoreSection0Item0Body.
  ///
  /// In zh, this message translates to:
  /// **'`backup_*.zip` 封裝的是 `vault/` 內的正式資料，包括日記、附件、復原設定與標籤目錄；內容仍保持加密，不是明文文件。'**
  String get aboutTabBackupRestoreSection0Item0Body;

  /// No description provided for @aboutTabBackupRestoreSection0Item1Title.
  ///
  /// In zh, this message translates to:
  /// **'建立後會先檢查'**
  String get aboutTabBackupRestoreSection0Item1Title;

  /// No description provided for @aboutTabBackupRestoreSection0Item1Body.
  ///
  /// In zh, this message translates to:
  /// **'完整備份會先經過結構檢查，確認內容可用後，才交付到本機、外部資料夾或 Google Drive。'**
  String get aboutTabBackupRestoreSection0Item1Body;

  /// No description provided for @aboutTabBackupRestoreSection0Item2Title.
  ///
  /// In zh, this message translates to:
  /// **'保留份數'**
  String get aboutTabBackupRestoreSection0Item2Title;

  /// No description provided for @aboutTabBackupRestoreSection0Item2Body.
  ///
  /// In zh, this message translates to:
  /// **'本機備份與 Google Drive 都保留最新 {retainCount} 份；若您匯出到外部資料夾，則不會自動輪替或刪除舊檔。'**
  String aboutTabBackupRestoreSection0Item2Body(int retainCount);

  /// No description provided for @aboutTabBackupRestoreSection1Title.
  ///
  /// In zh, this message translates to:
  /// **'還原時會發生什麼'**
  String get aboutTabBackupRestoreSection1Title;

  /// No description provided for @aboutTabBackupRestoreSection1Subtitle.
  ///
  /// In zh, this message translates to:
  /// **'還原不是補回少掉的幾篇內容，而是把目前正式日記庫換成備份中的那一份。'**
  String get aboutTabBackupRestoreSection1Subtitle;

  /// No description provided for @aboutTabBackupRestoreSection1Item0Title.
  ///
  /// In zh, this message translates to:
  /// **'正式日記庫會被覆寫'**
  String get aboutTabBackupRestoreSection1Item0Title;

  /// No description provided for @aboutTabBackupRestoreSection1Item0Body.
  ///
  /// In zh, this message translates to:
  /// **'不論備份來源是 App 內清單還是外部 ZIP，還原流程都會用備份內容覆寫目前的 `vault/`。'**
  String get aboutTabBackupRestoreSection1Item0Body;

  /// No description provided for @aboutTabBackupRestoreSection1Item1Title.
  ///
  /// In zh, this message translates to:
  /// **'搜尋索引會重建'**
  String get aboutTabBackupRestoreSection1Item1Title;

  /// No description provided for @aboutTabBackupRestoreSection1Item1Body.
  ///
  /// In zh, this message translates to:
  /// **'還原時現有索引會被刪除，之後再依新的正式資料重建。若目前可信狀態無法直接沿用，也可能需要重新驗證。'**
  String get aboutTabBackupRestoreSection1Item1Body;

  /// No description provided for @aboutTabBackupRestoreSection1Item2Title.
  ///
  /// In zh, this message translates to:
  /// **'可能會要求復原金鑰'**
  String get aboutTabBackupRestoreSection1Item2Title;

  /// No description provided for @aboutTabBackupRestoreSection1Item2Body.
  ///
  /// In zh, this message translates to:
  /// **'如果目前裝置上的可信狀態不能直接對應到那份備份，流程就會要求輸入建立該備份時保存的復原金鑰。'**
  String get aboutTabBackupRestoreSection1Item2Body;

  /// No description provided for @aboutTabBackupRestoreSection2Title.
  ///
  /// In zh, this message translates to:
  /// **'匯入與匯出適合什麼用途'**
  String get aboutTabBackupRestoreSection2Title;

  /// No description provided for @aboutTabBackupRestoreSection2Subtitle.
  ///
  /// In zh, this message translates to:
  /// **'這條流程處理的是內容交換與閱讀，不是拿來完整覆寫整個日記庫。'**
  String get aboutTabBackupRestoreSection2Subtitle;

  /// No description provided for @aboutTabBackupRestoreSection2Item0Title.
  ///
  /// In zh, this message translates to:
  /// **'匯入'**
  String get aboutTabBackupRestoreSection2Item0Title;

  /// No description provided for @aboutTabBackupRestoreSection2Item0Body.
  ///
  /// In zh, this message translates to:
  /// **'可從 ZIP、Markdown、HTML 或資料夾匯入內容。若是 ZIP，系統會先判斷是否為支援的備份格式，再決定後續處理方式。'**
  String get aboutTabBackupRestoreSection2Item0Body;

  /// No description provided for @aboutTabBackupRestoreSection2Item1Title.
  ///
  /// In zh, this message translates to:
  /// **'匯出'**
  String get aboutTabBackupRestoreSection2Item1Title;

  /// No description provided for @aboutTabBackupRestoreSection2Item1Body.
  ///
  /// In zh, this message translates to:
  /// **'您可以在設定頁匯出 `markdown_*.zip`，也能從主畫面選取日記或在總覽匯出 `html_*.html`，把內容整理成可閱讀格式。'**
  String get aboutTabBackupRestoreSection2Item1Body;

  /// No description provided for @aboutTabBackupRestoreSection2Item2Title.
  ///
  /// In zh, this message translates to:
  /// **'它不是同步服務'**
  String get aboutTabBackupRestoreSection2Item2Title;

  /// No description provided for @aboutTabBackupRestoreSection2Item2Body.
  ///
  /// In zh, this message translates to:
  /// **'Google Drive 在這裡扮演的是可選的加密備份目的地，而不是跨裝置即時同步日記的服務。'**
  String get aboutTabBackupRestoreSection2Item2Body;

  /// No description provided for @aboutTabBackupRestoreSection3Title.
  ///
  /// In zh, this message translates to:
  /// **'使用前要知道的事'**
  String get aboutTabBackupRestoreSection3Title;

  /// No description provided for @aboutTabBackupRestoreSection3Subtitle.
  ///
  /// In zh, this message translates to:
  /// **'備份與匯出都很重要，但它們保護的對象與責任邊界並不相同。'**
  String get aboutTabBackupRestoreSection3Subtitle;

  /// No description provided for @aboutTabBackupRestoreSection3Item0Title.
  ///
  /// In zh, this message translates to:
  /// **'完整備份不包含草稿'**
  String get aboutTabBackupRestoreSection3Item0Title;

  /// No description provided for @aboutTabBackupRestoreSection3Item0Body.
  ///
  /// In zh, this message translates to:
  /// **'完整備份只處理正式日記庫，不包含 `drafts/`。如果您還在編輯中的內容尚未正式儲存，它不會被一起封裝進去。'**
  String get aboutTabBackupRestoreSection3Item0Body;

  /// No description provided for @aboutTabBackupRestoreSection3Item1Title.
  ///
  /// In zh, this message translates to:
  /// **'可讀匯出要自己保管'**
  String get aboutTabBackupRestoreSection3Item1Title;

  /// No description provided for @aboutTabBackupRestoreSection3Item1Body.
  ///
  /// In zh, this message translates to:
  /// **'Markdown 與 HTML 匯出是為了閱讀、整理與轉移內容，但它們不再是 App 內的加密格式，後續保存方式要由您自己決定。'**
  String get aboutTabBackupRestoreSection3Item1Body;

  /// No description provided for @aboutTabBackupRestoreSection3Item2Title.
  ///
  /// In zh, this message translates to:
  /// **'別把兩條流程混用'**
  String get aboutTabBackupRestoreSection3Item2Title;

  /// No description provided for @aboutTabBackupRestoreSection3Item2Body.
  ///
  /// In zh, this message translates to:
  /// **'如果您要的是之後完整恢復整個日記庫，請使用完整備份；如果您要的是把內容帶出去看或整理，才使用 Markdown / HTML 匯出。'**
  String get aboutTabBackupRestoreSection3Item2Body;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
