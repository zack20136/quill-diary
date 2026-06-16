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
    Locale('zh', 'TW'),
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In zh_TW, this message translates to:
  /// **'Quill Diary'**
  String get appTitle;

  /// No description provided for @languageNameZhTw.
  ///
  /// In zh_TW, this message translates to:
  /// **'繁體中文'**
  String get languageNameZhTw;

  /// No description provided for @languageNameEn.
  ///
  /// In zh_TW, this message translates to:
  /// **'English'**
  String get languageNameEn;

  /// No description provided for @commonActionCancel.
  ///
  /// In zh_TW, this message translates to:
  /// **'取消'**
  String get commonActionCancel;

  /// No description provided for @commonActionDelete.
  ///
  /// In zh_TW, this message translates to:
  /// **'刪除'**
  String get commonActionDelete;

  /// No description provided for @commonActionApply.
  ///
  /// In zh_TW, this message translates to:
  /// **'套用'**
  String get commonActionApply;

  /// No description provided for @commonActionClose.
  ///
  /// In zh_TW, this message translates to:
  /// **'關閉'**
  String get commonActionClose;

  /// No description provided for @commonReadFailureTitle.
  ///
  /// In zh_TW, this message translates to:
  /// **'讀取失敗'**
  String get commonReadFailureTitle;

  /// No description provided for @commonConfirmDeleteTitle.
  ///
  /// In zh_TW, this message translates to:
  /// **'確認刪除'**
  String get commonConfirmDeleteTitle;

  /// No description provided for @commonNoTagSearchResults.
  ///
  /// In zh_TW, this message translates to:
  /// **'沒有符合的標籤'**
  String get commonNoTagSearchResults;

  /// No description provided for @commonCloseTooltip.
  ///
  /// In zh_TW, this message translates to:
  /// **'關閉'**
  String get commonCloseTooltip;

  /// No description provided for @commonClearSearchTooltip.
  ///
  /// In zh_TW, this message translates to:
  /// **'清除搜尋'**
  String get commonClearSearchTooltip;

  /// No description provided for @commonConfirmDeleteEntries.
  ///
  /// In zh_TW, this message translates to:
  /// **'確定要刪除 {count} 篇日記嗎？刪除後無法復原。'**
  String commonConfirmDeleteEntries(int count);

  /// No description provided for @tagAddTitle.
  ///
  /// In zh_TW, this message translates to:
  /// **'新增標籤'**
  String get tagAddTitle;

  /// No description provided for @tagEditTitle.
  ///
  /// In zh_TW, this message translates to:
  /// **'編輯標籤'**
  String get tagEditTitle;

  /// No description provided for @tagSaveButton.
  ///
  /// In zh_TW, this message translates to:
  /// **'儲存'**
  String get tagSaveButton;

  /// No description provided for @tagNameHint.
  ///
  /// In zh_TW, this message translates to:
  /// **'標籤名稱'**
  String get tagNameHint;

  /// No description provided for @tagNameRequiredMessage.
  ///
  /// In zh_TW, this message translates to:
  /// **'請輸入標籤名稱'**
  String get tagNameRequiredMessage;

  /// No description provided for @tagDeleteLabel.
  ///
  /// In zh_TW, this message translates to:
  /// **'刪除標籤'**
  String get tagDeleteLabel;

  /// No description provided for @tagUnnamedPreview.
  ///
  /// In zh_TW, this message translates to:
  /// **'未命名標籤'**
  String get tagUnnamedPreview;

  /// No description provided for @tagDefaultColorLabel.
  ///
  /// In zh_TW, this message translates to:
  /// **'預設色'**
  String get tagDefaultColorLabel;

  /// No description provided for @tagHueLabel.
  ///
  /// In zh_TW, this message translates to:
  /// **'色相'**
  String get tagHueLabel;

  /// No description provided for @tagPreviewLabel.
  ///
  /// In zh_TW, this message translates to:
  /// **'預覽'**
  String get tagPreviewLabel;

  /// No description provided for @tagSaveFailure.
  ///
  /// In zh_TW, this message translates to:
  /// **'儲存標籤失敗：{message}'**
  String tagSaveFailure(String message);

  /// No description provided for @tagDeleteFailure.
  ///
  /// In zh_TW, this message translates to:
  /// **'刪除標籤失敗：{message}'**
  String tagDeleteFailure(String message);

  /// No description provided for @personalizationNavButtonLabel.
  ///
  /// In zh_TW, this message translates to:
  /// **'個人化'**
  String get personalizationNavButtonLabel;

  /// No description provided for @personalizationPageTitle.
  ///
  /// In zh_TW, this message translates to:
  /// **'個人化'**
  String get personalizationPageTitle;

  /// No description provided for @personalizationLoadErrorMessage.
  ///
  /// In zh_TW, this message translates to:
  /// **'無法載入個人化設定。'**
  String get personalizationLoadErrorMessage;

  /// No description provided for @personalizationTypographyResetButton.
  ///
  /// In zh_TW, this message translates to:
  /// **'還原預設'**
  String get personalizationTypographyResetButton;

  /// No description provided for @personalizationTypographyResetConfirmTitle.
  ///
  /// In zh_TW, this message translates to:
  /// **'還原日記排版預設？'**
  String get personalizationTypographyResetConfirmTitle;

  /// No description provided for @personalizationTypographyResetConfirmBody.
  ///
  /// In zh_TW, this message translates to:
  /// **'這會把目前的標題、內文字體大小、行距與段落間距都還原成預設值。'**
  String get personalizationTypographyResetConfirmBody;

  /// No description provided for @personalizationTypographyResetConfirmAction.
  ///
  /// In zh_TW, this message translates to:
  /// **'還原預設'**
  String get personalizationTypographyResetConfirmAction;

  /// No description provided for @personalizationTypographyResetSuccess.
  ///
  /// In zh_TW, this message translates to:
  /// **'已還原日記排版預設。'**
  String get personalizationTypographyResetSuccess;

  /// No description provided for @personalizationLanguageSectionTitle.
  ///
  /// In zh_TW, this message translates to:
  /// **'語言'**
  String get personalizationLanguageSectionTitle;

  /// No description provided for @personalizationLanguageSectionDescription.
  ///
  /// In zh_TW, this message translates to:
  /// **'選擇介面顯示語言。'**
  String get personalizationLanguageSectionDescription;

  /// No description provided for @personalizationLanguageComingSoonHint.
  ///
  /// In zh_TW, this message translates to:
  /// **'部分英文翻譯仍在補完中。'**
  String get personalizationLanguageComingSoonHint;

  /// No description provided for @personalizationSessionTimeoutSectionTitle.
  ///
  /// In zh_TW, this message translates to:
  /// **'自動鎖定'**
  String get personalizationSessionTimeoutSectionTitle;

  /// No description provided for @personalizationSessionTimeoutSectionDescription.
  ///
  /// In zh_TW, this message translates to:
  /// **'App 切到背景一段時間後，會自動要求重新驗證。'**
  String get personalizationSessionTimeoutSectionDescription;

  /// No description provided for @personalizationSessionTimeoutUnitLabel.
  ///
  /// In zh_TW, this message translates to:
  /// **'分鐘'**
  String get personalizationSessionTimeoutUnitLabel;

  /// No description provided for @personalizationImageCompressSectionTitle.
  ///
  /// In zh_TW, this message translates to:
  /// **'圖片品質'**
  String get personalizationImageCompressSectionTitle;

  /// No description provided for @personalizationImageCompressSectionDescription.
  ///
  /// In zh_TW, this message translates to:
  /// **'調整編輯器插入圖片時的壓縮預設。'**
  String get personalizationImageCompressSectionDescription;

  /// No description provided for @personalizationImageCompressOriginalLabel.
  ///
  /// In zh_TW, this message translates to:
  /// **'原圖'**
  String get personalizationImageCompressOriginalLabel;

  /// No description provided for @personalizationImageCompressStandardLabel.
  ///
  /// In zh_TW, this message translates to:
  /// **'標準'**
  String get personalizationImageCompressStandardLabel;

  /// No description provided for @personalizationImageCompressHighLabel.
  ///
  /// In zh_TW, this message translates to:
  /// **'高畫質'**
  String get personalizationImageCompressHighLabel;

  /// No description provided for @personalizationAppearanceSectionTitle.
  ///
  /// In zh_TW, this message translates to:
  /// **'主題顏色'**
  String get personalizationAppearanceSectionTitle;

  /// No description provided for @personalizationAppearanceSectionDescription.
  ///
  /// In zh_TW, this message translates to:
  /// **'選擇 App 使用的淺色、深色或跟隨系統外觀。'**
  String get personalizationAppearanceSectionDescription;

  /// No description provided for @personalizationAppearanceSystemLabel.
  ///
  /// In zh_TW, this message translates to:
  /// **'跟隨系統'**
  String get personalizationAppearanceSystemLabel;

  /// No description provided for @personalizationAppearanceLightLabel.
  ///
  /// In zh_TW, this message translates to:
  /// **'淺色'**
  String get personalizationAppearanceLightLabel;

  /// No description provided for @personalizationAppearanceDarkLabel.
  ///
  /// In zh_TW, this message translates to:
  /// **'深色'**
  String get personalizationAppearanceDarkLabel;

  /// No description provided for @personalizationTypographySectionTitle.
  ///
  /// In zh_TW, this message translates to:
  /// **'日記排版'**
  String get personalizationTypographySectionTitle;

  /// No description provided for @personalizationTypographySectionDescription.
  ///
  /// In zh_TW, this message translates to:
  /// **'調整日記編輯與預覽時的字體大小、行距與段落間距。'**
  String get personalizationTypographySectionDescription;

  /// No description provided for @personalizationTitleFontSizeLabel.
  ///
  /// In zh_TW, this message translates to:
  /// **'標題字體大小'**
  String get personalizationTitleFontSizeLabel;

  /// No description provided for @personalizationTitleLineHeightLabel.
  ///
  /// In zh_TW, this message translates to:
  /// **'標題行距'**
  String get personalizationTitleLineHeightLabel;

  /// No description provided for @personalizationBodyFontSizeLabel.
  ///
  /// In zh_TW, this message translates to:
  /// **'內文字體大小'**
  String get personalizationBodyFontSizeLabel;

  /// No description provided for @personalizationBodyLineHeightLabel.
  ///
  /// In zh_TW, this message translates to:
  /// **'內文行距'**
  String get personalizationBodyLineHeightLabel;

  /// No description provided for @personalizationBodyParagraphSpacingLabel.
  ///
  /// In zh_TW, this message translates to:
  /// **'內文段落間距'**
  String get personalizationBodyParagraphSpacingLabel;

  /// No description provided for @settingsPageTitle.
  ///
  /// In zh_TW, this message translates to:
  /// **'設定'**
  String get settingsPageTitle;

  /// No description provided for @settingsProgressDefault.
  ///
  /// In zh_TW, this message translates to:
  /// **'正在處理，請稍候…'**
  String get settingsProgressDefault;

  /// No description provided for @personalizationImageCompressOriginalDescription.
  ///
  /// In zh_TW, this message translates to:
  /// **'不壓縮，保留原始解析度與檔案大小。適合需要最高畫質、可接受較大日記庫時使用。'**
  String get personalizationImageCompressOriginalDescription;

  /// No description provided for @personalizationImageCompressStandardDescription.
  ///
  /// In zh_TW, this message translates to:
  /// **'長邊縮至 1280 px、JPEG 品質 70。在清晰度與儲存空間之間取得平衡（預設）。'**
  String get personalizationImageCompressStandardDescription;

  /// No description provided for @personalizationImageCompressHighDescription.
  ///
  /// In zh_TW, this message translates to:
  /// **'長邊縮至 1920 px、JPEG 品質 85。檔案較大，但細節保留較多。'**
  String get personalizationImageCompressHighDescription;

  /// No description provided for @personalizationFontSizeValue.
  ///
  /// In zh_TW, this message translates to:
  /// **'{size} 點'**
  String personalizationFontSizeValue(String size);

  /// No description provided for @personalizationLineHeightValue.
  ///
  /// In zh_TW, this message translates to:
  /// **'{height} 倍'**
  String personalizationLineHeightValue(String height);

  /// No description provided for @personalizationParagraphSpacingValue.
  ///
  /// In zh_TW, this message translates to:
  /// **'{spacing} 像素'**
  String personalizationParagraphSpacingValue(String spacing);

  /// No description provided for @personalizationTypographyPreviewTitleParagraph1.
  ///
  /// In zh_TW, this message translates to:
  /// **'今日的小確幸，陽光剛好落在書桌上。值得記住的一刻，先寫下來再說。'**
  String get personalizationTypographyPreviewTitleParagraph1;

  /// No description provided for @personalizationTypographyPreviewBodyParagraph1.
  ///
  /// In zh_TW, this message translates to:
  /// **'記錄下此刻的心情，讓文字替記憶保溫。記錄下此刻的心情，讓文字替記憶保溫。'**
  String get personalizationTypographyPreviewBodyParagraph1;

  /// No description provided for @personalizationTypographyPreviewBodyParagraph2.
  ///
  /// In zh_TW, this message translates to:
  /// **'段落之間的間距，也會反映在預覽裡。段落之間的間距，也會反映在預覽裡。'**
  String get personalizationTypographyPreviewBodyParagraph2;

  /// No description provided for @sessionBlockedLockedTitle.
  ///
  /// In zh_TW, this message translates to:
  /// **'日記庫已鎖定'**
  String get sessionBlockedLockedTitle;

  /// No description provided for @sessionBlockedRecoveryRequiredTitle.
  ///
  /// In zh_TW, this message translates to:
  /// **'需要復原金鑰'**
  String get sessionBlockedRecoveryRequiredTitle;

  /// No description provided for @sessionBlockedFatalErrorTitle.
  ///
  /// In zh_TW, this message translates to:
  /// **'無法啟動'**
  String get sessionBlockedFatalErrorTitle;

  /// No description provided for @sessionBlockedDefaultTitle.
  ///
  /// In zh_TW, this message translates to:
  /// **'請稍候'**
  String get sessionBlockedDefaultTitle;

  /// No description provided for @sessionBlockedLockedSubtitle.
  ///
  /// In zh_TW, this message translates to:
  /// **'請完成驗證以繼續'**
  String get sessionBlockedLockedSubtitle;

  /// No description provided for @sessionBlockedRecoveryRequiredSubtitle.
  ///
  /// In zh_TW, this message translates to:
  /// **'請輸入復原金鑰解鎖'**
  String get sessionBlockedRecoveryRequiredSubtitle;

  /// No description provided for @sessionBlockedFatalErrorSubtitle.
  ///
  /// In zh_TW, this message translates to:
  /// **'請檢查設定或重新啟動應用程式'**
  String get sessionBlockedFatalErrorSubtitle;

  /// No description provided for @editorPageTitle.
  ///
  /// In zh_TW, this message translates to:
  /// **'編輯日記'**
  String get editorPageTitle;

  /// No description provided for @editorTitleHint.
  ///
  /// In zh_TW, this message translates to:
  /// **'輸入標題'**
  String get editorTitleHint;

  /// No description provided for @editorTitleRequiredError.
  ///
  /// In zh_TW, this message translates to:
  /// **'請輸入標題'**
  String get editorTitleRequiredError;

  /// No description provided for @editorBodyHint.
  ///
  /// In zh_TW, this message translates to:
  /// **'在這裡輸入內容…'**
  String get editorBodyHint;

  /// No description provided for @editorBodyEmptyPreview.
  ///
  /// In zh_TW, this message translates to:
  /// **'尚未輸入內容'**
  String get editorBodyEmptyPreview;

  /// No description provided for @editorNeedsRecoveryKeyMessage.
  ///
  /// In zh_TW, this message translates to:
  /// **'請先建立復原金鑰，才能開始建立或編輯日記。'**
  String get editorNeedsRecoveryKeyMessage;

  /// No description provided for @editorSessionLockedFallback.
  ///
  /// In zh_TW, this message translates to:
  /// **'請先重新解鎖日記庫後再繼續。'**
  String get editorSessionLockedFallback;

  /// No description provided for @editorSaveNeedsTitleMessage.
  ///
  /// In zh_TW, this message translates to:
  /// **'請輸入標題才能儲存'**
  String get editorSaveNeedsTitleMessage;

  /// No description provided for @editorUnsavedDraftLabel.
  ///
  /// In zh_TW, this message translates to:
  /// **'未儲存'**
  String get editorUnsavedDraftLabel;

  /// No description provided for @editorConfirmDeleteTitle.
  ///
  /// In zh_TW, this message translates to:
  /// **'確認刪除'**
  String get editorConfirmDeleteTitle;

  /// No description provided for @editorConfirmDeleteBody.
  ///
  /// In zh_TW, this message translates to:
  /// **'確定要刪除這篇日記嗎？刪除後無法復原。'**
  String get editorConfirmDeleteBody;

  /// No description provided for @editorTagsStudioTitle.
  ///
  /// In zh_TW, this message translates to:
  /// **'標籤'**
  String get editorTagsStudioTitle;

  /// No description provided for @editorTagsStudioGuide.
  ///
  /// In zh_TW, this message translates to:
  /// **'右上角可建立新標籤；下方為文庫標籤，輕觸加入。'**
  String get editorTagsStudioGuide;

  /// No description provided for @editorTagsStudioEmptyChosen.
  ///
  /// In zh_TW, this message translates to:
  /// **'尚未套用任何標籤'**
  String get editorTagsStudioEmptyChosen;

  /// No description provided for @editorTagsStudioAddButton.
  ///
  /// In zh_TW, this message translates to:
  /// **'加入'**
  String get editorTagsStudioAddButton;

  /// No description provided for @editorPreviewUnavailable.
  ///
  /// In zh_TW, this message translates to:
  /// **'無法預覽'**
  String get editorPreviewUnavailable;

  /// No description provided for @editorTagSearchHint.
  ///
  /// In zh_TW, this message translates to:
  /// **'搜尋標籤…'**
  String get editorTagSearchHint;

  /// No description provided for @editorTagLibraryHint.
  ///
  /// In zh_TW, this message translates to:
  /// **'文庫裡的標籤 · 輕觸加入'**
  String get editorTagLibraryHint;

  /// No description provided for @editorTagPoolEmpty.
  ///
  /// In zh_TW, this message translates to:
  /// **'文庫裡暫時沒有其他可用標籤，或已全部加入目前清單'**
  String get editorTagPoolEmpty;

  /// No description provided for @editorTagAddTooltip.
  ///
  /// In zh_TW, this message translates to:
  /// **'新增標籤'**
  String get editorTagAddTooltip;

  /// No description provided for @editorTooltipCancel.
  ///
  /// In zh_TW, this message translates to:
  /// **'取消'**
  String get editorTooltipCancel;

  /// No description provided for @editorTooltipSave.
  ///
  /// In zh_TW, this message translates to:
  /// **'儲存'**
  String get editorTooltipSave;

  /// No description provided for @editorTooltipSaveNeedsTitle.
  ///
  /// In zh_TW, this message translates to:
  /// **'請先輸入標題'**
  String get editorTooltipSaveNeedsTitle;

  /// No description provided for @editorTooltipDate.
  ///
  /// In zh_TW, this message translates to:
  /// **'日期'**
  String get editorTooltipDate;

  /// No description provided for @editorTooltipTime.
  ///
  /// In zh_TW, this message translates to:
  /// **'時間'**
  String get editorTooltipTime;

  /// No description provided for @editorTooltipEditTags.
  ///
  /// In zh_TW, this message translates to:
  /// **'編輯標籤'**
  String get editorTooltipEditTags;

  /// No description provided for @editorTooltipUploadImages.
  ///
  /// In zh_TW, this message translates to:
  /// **'上傳圖片（可一次選多張）'**
  String get editorTooltipUploadImages;

  /// No description provided for @editorTooltipAddAttachment.
  ///
  /// In zh_TW, this message translates to:
  /// **'新增附件'**
  String get editorTooltipAddAttachment;

  /// No description provided for @editorTooltipDelete.
  ///
  /// In zh_TW, this message translates to:
  /// **'刪除'**
  String get editorTooltipDelete;

  /// No description provided for @editorTooltipEdit.
  ///
  /// In zh_TW, this message translates to:
  /// **'編輯'**
  String get editorTooltipEdit;

  /// No description provided for @editorRestoreDraftTitle.
  ///
  /// In zh_TW, this message translates to:
  /// **'發現未完成的草稿'**
  String get editorRestoreDraftTitle;

  /// No description provided for @editorRestoreDraftDecline.
  ///
  /// In zh_TW, this message translates to:
  /// **'不使用'**
  String get editorRestoreDraftDecline;

  /// No description provided for @editorRestoreDraftAccept.
  ///
  /// In zh_TW, this message translates to:
  /// **'還原草稿'**
  String get editorRestoreDraftAccept;

  /// No description provided for @editorUntitledDraft.
  ///
  /// In zh_TW, this message translates to:
  /// **'無標題'**
  String get editorUntitledDraft;

  /// No description provided for @editorRestoreDraftOverwrite.
  ///
  /// In zh_TW, this message translates to:
  /// **'草稿：{title}\n最後儲存：{savedAt}\n\n還原後會覆蓋目前檢視中的內容。'**
  String editorRestoreDraftOverwrite(String title, String savedAt);

  /// No description provided for @editorRestoreDraftPrompt.
  ///
  /// In zh_TW, this message translates to:
  /// **'草稿：{title}\n最後儲存：{savedAt}\n\n是否要還原這份草稿？'**
  String editorRestoreDraftPrompt(String title, String savedAt);

  /// No description provided for @editorDiscardDraftTitle.
  ///
  /// In zh_TW, this message translates to:
  /// **'捨棄草稿？'**
  String get editorDiscardDraftTitle;

  /// No description provided for @editorDiscardDraftBody.
  ///
  /// In zh_TW, this message translates to:
  /// **'目前的修改尚未儲存為日記，確定要捨棄草稿並離開嗎？'**
  String get editorDiscardDraftBody;

  /// No description provided for @editorDiscardDraftConfirm.
  ///
  /// In zh_TW, this message translates to:
  /// **'捨棄'**
  String get editorDiscardDraftConfirm;

  /// No description provided for @editorGalleryDownloadTooltip.
  ///
  /// In zh_TW, this message translates to:
  /// **'下載'**
  String get editorGalleryDownloadTooltip;

  /// No description provided for @editorGalleryDownloadFailed.
  ///
  /// In zh_TW, this message translates to:
  /// **'無法下載圖片'**
  String get editorGalleryDownloadFailed;

  /// No description provided for @editorGalleryDownloadSuccess.
  ///
  /// In zh_TW, this message translates to:
  /// **'已儲存至 {path}'**
  String editorGalleryDownloadSuccess(String path);

  /// No description provided for @homeUnlockingTitle.
  ///
  /// In zh_TW, this message translates to:
  /// **'正在解鎖'**
  String get homeUnlockingTitle;

  /// No description provided for @homeRetryVerification.
  ///
  /// In zh_TW, this message translates to:
  /// **'重新驗證'**
  String get homeRetryVerification;

  /// No description provided for @homeGoToSettings.
  ///
  /// In zh_TW, this message translates to:
  /// **'前往設定'**
  String get homeGoToSettings;

  /// No description provided for @homeNavHome.
  ///
  /// In zh_TW, this message translates to:
  /// **'首頁'**
  String get homeNavHome;

  /// No description provided for @homeNavCalendar.
  ///
  /// In zh_TW, this message translates to:
  /// **'日曆'**
  String get homeNavCalendar;

  /// No description provided for @homeNavTags.
  ///
  /// In zh_TW, this message translates to:
  /// **'標籤'**
  String get homeNavTags;

  /// No description provided for @homeNavOverview.
  ///
  /// In zh_TW, this message translates to:
  /// **'總覽'**
  String get homeNavOverview;

  /// No description provided for @homeTooltipNewEntry.
  ///
  /// In zh_TW, this message translates to:
  /// **'新增日記'**
  String get homeTooltipNewEntry;

  /// No description provided for @homeTooltipSettings.
  ///
  /// In zh_TW, this message translates to:
  /// **'設定與備份'**
  String get homeTooltipSettings;

  /// No description provided for @homeTooltipExportHtml.
  ///
  /// In zh_TW, this message translates to:
  /// **'匯出 HTML'**
  String get homeTooltipExportHtml;

  /// No description provided for @homeTooltipDelete.
  ///
  /// In zh_TW, this message translates to:
  /// **'刪除'**
  String get homeTooltipDelete;

  /// No description provided for @homeTooltipAddTag.
  ///
  /// In zh_TW, this message translates to:
  /// **'新增標籤'**
  String get homeTooltipAddTag;

  /// No description provided for @homeTooltipEditTag.
  ///
  /// In zh_TW, this message translates to:
  /// **'編輯標籤'**
  String get homeTooltipEditTag;

  /// No description provided for @homeTooltipDeleteTag.
  ///
  /// In zh_TW, this message translates to:
  /// **'刪除標籤'**
  String get homeTooltipDeleteTag;

  /// No description provided for @homeTooltipDeselectTag.
  ///
  /// In zh_TW, this message translates to:
  /// **'取消選取'**
  String get homeTooltipDeselectTag;

  /// No description provided for @homeSelectionSelectAll.
  ///
  /// In zh_TW, this message translates to:
  /// **'全選'**
  String get homeSelectionSelectAll;

  /// No description provided for @homeSelectionDeselectAll.
  ///
  /// In zh_TW, this message translates to:
  /// **'取消全選'**
  String get homeSelectionDeselectAll;

  /// No description provided for @homeSelectionSelectDiary.
  ///
  /// In zh_TW, this message translates to:
  /// **'選取日記'**
  String get homeSelectionSelectDiary;

  /// No description provided for @homeSelectionSelectedCount.
  ///
  /// In zh_TW, this message translates to:
  /// **'已選 {count} 項'**
  String homeSelectionSelectedCount(int count);

  /// No description provided for @homeSearchHint.
  ///
  /// In zh_TW, this message translates to:
  /// **'搜尋標題、內文或標籤'**
  String get homeSearchHint;

  /// No description provided for @homeEmptyDiaryTitle.
  ///
  /// In zh_TW, this message translates to:
  /// **'目前沒有日記'**
  String get homeEmptyDiaryTitle;

  /// No description provided for @homeEmptyDiaryMessage.
  ///
  /// In zh_TW, this message translates to:
  /// **'建立第一篇日記後，就會在這裡看到你的首頁列表。'**
  String get homeEmptyDiaryMessage;

  /// No description provided for @homeNoAnalysisTitle.
  ///
  /// In zh_TW, this message translates to:
  /// **'尚無可分析內容'**
  String get homeNoAnalysisTitle;

  /// No description provided for @homeNoAnalysisMessage.
  ///
  /// In zh_TW, this message translates to:
  /// **'寫下一篇後，就可以在這裡看到統計、標籤與範圍內的日記。'**
  String get homeNoAnalysisMessage;

  /// No description provided for @homeExportRecapLabel.
  ///
  /// In zh_TW, this message translates to:
  /// **'匯出回顧'**
  String get homeExportRecapLabel;

  /// No description provided for @homeExportRecapAll.
  ///
  /// In zh_TW, this message translates to:
  /// **'匯出總回顧'**
  String get homeExportRecapAll;

  /// No description provided for @homeExportRecapYear.
  ///
  /// In zh_TW, this message translates to:
  /// **'匯出年度回顧'**
  String get homeExportRecapYear;

  /// No description provided for @homeExportRecapMonth.
  ///
  /// In zh_TW, this message translates to:
  /// **'匯出月份回顧'**
  String get homeExportRecapMonth;

  /// No description provided for @homePopularTagsTitle.
  ///
  /// In zh_TW, this message translates to:
  /// **'熱門標籤'**
  String get homePopularTagsTitle;

  /// No description provided for @homeScopeTitle.
  ///
  /// In zh_TW, this message translates to:
  /// **'範圍'**
  String get homeScopeTitle;

  /// No description provided for @homeScopeAllLabel.
  ///
  /// In zh_TW, this message translates to:
  /// **'全部'**
  String get homeScopeAllLabel;

  /// No description provided for @homeScopeYearLabel.
  ///
  /// In zh_TW, this message translates to:
  /// **'年'**
  String get homeScopeYearLabel;

  /// No description provided for @homeScopeMonthLabel.
  ///
  /// In zh_TW, this message translates to:
  /// **'月'**
  String get homeScopeMonthLabel;

  /// No description provided for @homeScopeEmptyDiary.
  ///
  /// In zh_TW, this message translates to:
  /// **'此範圍內沒有符合的日記。'**
  String get homeScopeEmptyDiary;

  /// No description provided for @homeScopeEmptyDiaryForTag.
  ///
  /// In zh_TW, this message translates to:
  /// **'此範圍內沒有套用「{tag}」的日記。'**
  String homeScopeEmptyDiaryForTag(String tag);

  /// No description provided for @homeScopeEmptyTags.
  ///
  /// In zh_TW, this message translates to:
  /// **'此範圍內沒有標籤。'**
  String get homeScopeEmptyTags;

  /// No description provided for @homeUnsavedDraftLabel.
  ///
  /// In zh_TW, this message translates to:
  /// **'未儲存'**
  String get homeUnsavedDraftLabel;

  /// No description provided for @homeHtmlExportLargeTitle.
  ///
  /// In zh_TW, this message translates to:
  /// **'HTML 檔案可能很大'**
  String get homeHtmlExportLargeTitle;

  /// No description provided for @homeHtmlExportEmbeddedHint.
  ///
  /// In zh_TW, this message translates to:
  /// **'圖片會內嵌在單一 HTML 內，檔案可能較慢開啟或不易分享。'**
  String get homeHtmlExportEmbeddedHint;

  /// No description provided for @homeHtmlExportProceed.
  ///
  /// In zh_TW, this message translates to:
  /// **'仍要匯出'**
  String get homeHtmlExportProceed;

  /// No description provided for @homeHtmlExportSelectionSummary.
  ///
  /// In zh_TW, this message translates to:
  /// **'選取 {entrySummary}日記，包含 {imageSummary}圖片。'**
  String homeHtmlExportSelectionSummary(
    String entrySummary,
    String imageSummary,
  );

  /// No description provided for @homeHtmlExportImageSize.
  ///
  /// In zh_TW, this message translates to:
  /// **'圖片原始大小：約 {size}'**
  String homeHtmlExportImageSize(String size);

  /// No description provided for @homeHtmlExportEstimatedSize.
  ///
  /// In zh_TW, this message translates to:
  /// **'HTML 估算大小：約 {size}'**
  String homeHtmlExportEstimatedSize(String size);

  /// No description provided for @homeHtmlExportSuccess.
  ///
  /// In zh_TW, this message translates to:
  /// **'已匯出 HTML：{fileName}'**
  String homeHtmlExportSuccess(String fileName);

  /// No description provided for @homeDeleteTagTitle.
  ///
  /// In zh_TW, this message translates to:
  /// **'刪除標籤'**
  String get homeDeleteTagTitle;

  /// No description provided for @homeDeleteTagConfirm.
  ///
  /// In zh_TW, this message translates to:
  /// **'確定要從所有日記移除「{label}」嗎？'**
  String homeDeleteTagConfirm(String label);

  /// No description provided for @homeTagSearchHint.
  ///
  /// In zh_TW, this message translates to:
  /// **'搜尋標籤…'**
  String get homeTagSearchHint;

  /// No description provided for @homeNoTagsTitle.
  ///
  /// In zh_TW, this message translates to:
  /// **'尚未有標籤'**
  String get homeNoTagsTitle;

  /// No description provided for @homeNoTagsMessage.
  ///
  /// In zh_TW, this message translates to:
  /// **'可先建立標籤或使用預設標籤；即使尚未套用到日記也會保留在清單中。'**
  String get homeNoTagsMessage;

  /// No description provided for @homeTagListGuide.
  ///
  /// In zh_TW, this message translates to:
  /// **'請從標籤清單中點選一列：此區會依索引篩選出套用該標籤的日記摘要（再點同一列可取消選取）。'**
  String get homeTagListGuide;

  /// No description provided for @homeTagPreviewTitle.
  ///
  /// In zh_TW, this message translates to:
  /// **'選取標籤以預覽日記'**
  String get homeTagPreviewTitle;

  /// No description provided for @homeTagDeleted.
  ///
  /// In zh_TW, this message translates to:
  /// **'「{label}」已刪除'**
  String homeTagDeleted(String label);

  /// No description provided for @homeTagRemovedFromEntries.
  ///
  /// In zh_TW, this message translates to:
  /// **'已從 {entrySummary}日記移除「{label}」'**
  String homeTagRemovedFromEntries(String entrySummary, String label);

  /// No description provided for @homeTagIndexEmptyForTag.
  ///
  /// In zh_TW, this message translates to:
  /// **'目前索引中找不到套用「{tag}」的項目。'**
  String homeTagIndexEmptyForTag(String tag);

  /// No description provided for @homeTagRowEntryCount.
  ///
  /// In zh_TW, this message translates to:
  /// **'{entrySummary}日記'**
  String homeTagRowEntryCount(String entrySummary);

  /// No description provided for @homeTagRowTapHint.
  ///
  /// In zh_TW, this message translates to:
  /// **'輕觸列預覽'**
  String get homeTagRowTapHint;

  /// No description provided for @homeDiarySectionTitleForDate.
  ///
  /// In zh_TW, this message translates to:
  /// **'日記 · {dateLabel}'**
  String homeDiarySectionTitleForDate(String dateLabel);

  /// No description provided for @homeEmptyDayMessage.
  ///
  /// In zh_TW, this message translates to:
  /// **'「{dateLabel}」這一天目前沒有日記。'**
  String homeEmptyDayMessage(String dateLabel);

  /// No description provided for @homeOverviewDataTitle.
  ///
  /// In zh_TW, this message translates to:
  /// **'資料概覽'**
  String get homeOverviewDataTitle;

  /// No description provided for @homeOverviewScopeAll.
  ///
  /// In zh_TW, this message translates to:
  /// **'目前範圍 · 全部日記'**
  String get homeOverviewScopeAll;

  /// No description provided for @homeOverviewScopeYear.
  ///
  /// In zh_TW, this message translates to:
  /// **'目前範圍 · {year}年'**
  String homeOverviewScopeYear(int year);

  /// No description provided for @homeOverviewScopeMonth.
  ///
  /// In zh_TW, this message translates to:
  /// **'目前範圍 · {year}年{month}月'**
  String homeOverviewScopeMonth(int year, int month);

  /// No description provided for @homeOverviewWritingDaysLabel.
  ///
  /// In zh_TW, this message translates to:
  /// **'撰寫天數'**
  String get homeOverviewWritingDaysLabel;

  /// No description provided for @homeOverviewAvgLengthLabel.
  ///
  /// In zh_TW, this message translates to:
  /// **'平均篇幅'**
  String get homeOverviewAvgLengthLabel;

  /// No description provided for @homeOverviewAttachmentsLabel.
  ///
  /// In zh_TW, this message translates to:
  /// **'附件總數'**
  String get homeOverviewAttachmentsLabel;

  /// No description provided for @homeOverviewAttachmentCount.
  ///
  /// In zh_TW, this message translates to:
  /// **'{attachmentSummary}'**
  String homeOverviewAttachmentCount(String attachmentSummary);

  /// No description provided for @homeOverviewLongestStreak.
  ///
  /// In zh_TW, this message translates to:
  /// **'連續最長 {daySummary}'**
  String homeOverviewLongestStreak(String daySummary);

  /// No description provided for @homeOverviewEntryStats.
  ///
  /// In zh_TW, this message translates to:
  /// **'共 {entrySummary}\n累計 {characterSummary}'**
  String homeOverviewEntryStats(String entrySummary, String characterSummary);

  /// No description provided for @homeDiarySectionTag.
  ///
  /// In zh_TW, this message translates to:
  /// **'日記 · {tag}'**
  String homeDiarySectionTag(String tag);

  /// No description provided for @homeDiarySectionAll.
  ///
  /// In zh_TW, this message translates to:
  /// **'日記 · 全部'**
  String get homeDiarySectionAll;

  /// No description provided for @homeDiarySectionByYear.
  ///
  /// In zh_TW, this message translates to:
  /// **'日記 · 依年'**
  String get homeDiarySectionByYear;

  /// No description provided for @homeDiarySectionByMonth.
  ///
  /// In zh_TW, this message translates to:
  /// **'日記 · 依月'**
  String get homeDiarySectionByMonth;

  /// No description provided for @homeDiarySectionWithTag.
  ///
  /// In zh_TW, this message translates to:
  /// **'{baseTitle} · {tag}'**
  String homeDiarySectionWithTag(String baseTitle, String tag);

  /// No description provided for @homeCalendarMonthFormatLabel.
  ///
  /// In zh_TW, this message translates to:
  /// **'月'**
  String get homeCalendarMonthFormatLabel;

  /// No description provided for @homeOverviewAvgLengthValue.
  ///
  /// In zh_TW, this message translates to:
  /// **'{charactersPerEntry} 字 / 篇'**
  String homeOverviewAvgLengthValue(int charactersPerEntry);

  /// No description provided for @homeOverviewAttachmentDetail.
  ///
  /// In zh_TW, this message translates to:
  /// **'照片 {photos} · 檔案 {files}'**
  String homeOverviewAttachmentDetail(int photos, int files);

  /// No description provided for @homeOverviewMostEntriesInSingleDay.
  ///
  /// In zh_TW, this message translates to:
  /// **'單天最多 {entrySummary}'**
  String homeOverviewMostEntriesInSingleDay(String entrySummary);

  /// No description provided for @vaultTransferNeedsUnlockForBackup.
  ///
  /// In zh_TW, this message translates to:
  /// **'請先解鎖日記庫，才能備份或匯出。'**
  String get vaultTransferNeedsUnlockForBackup;

  /// No description provided for @vaultTransferNeedsRecoveryKeyForBackup.
  ///
  /// In zh_TW, this message translates to:
  /// **'請先建立復原金鑰，才能備份或匯出。'**
  String get vaultTransferNeedsRecoveryKeyForBackup;

  /// No description provided for @vaultTransferNeedsUnlockForRestore.
  ///
  /// In zh_TW, this message translates to:
  /// **'請先解鎖日記庫，才能還原備份。'**
  String get vaultTransferNeedsUnlockForRestore;

  /// No description provided for @vaultTransferLocalSectionDescriptionBackupLocked.
  ///
  /// In zh_TW, this message translates to:
  /// **'建立本機備份與匯出需先解鎖日記庫並建立復原金鑰；尚未建立復原金鑰或忘記金鑰時，可直接匯入外部備份還原。'**
  String get vaultTransferLocalSectionDescriptionBackupLocked;

  /// No description provided for @vaultTransferDriveSectionDescriptionBackupLocked.
  ///
  /// In zh_TW, this message translates to:
  /// **'備份到 Google Drive 需先解鎖日記庫並建立復原金鑰；尚未建立復原金鑰或忘記金鑰時，可直接從 Google Drive 還原。'**
  String get vaultTransferDriveSectionDescriptionBackupLocked;

  /// No description provided for @vaultTransferDriveBackupActionsLockedHint.
  ///
  /// In zh_TW, this message translates to:
  /// **'請先解鎖日記庫並建立復原金鑰，才能備份到 Google Drive。'**
  String get vaultTransferDriveBackupActionsLockedHint;

  /// No description provided for @vaultTransferRestoreUnlockFailed.
  ///
  /// In zh_TW, this message translates to:
  /// **'備份已還原，但復原金鑰解鎖失敗。請在安全總覽重新輸入復原金鑰。'**
  String get vaultTransferRestoreUnlockFailed;

  /// No description provided for @androidSafWriteFailed.
  ///
  /// In zh_TW, this message translates to:
  /// **'無法將檔案寫入選擇的資料夾。'**
  String get androidSafWriteFailed;

  /// No description provided for @androidSafWriteFailedWithCode.
  ///
  /// In zh_TW, this message translates to:
  /// **'無法將檔案寫入選擇的資料夾（{code}）。'**
  String androidSafWriteFailedWithCode(String code);

  /// No description provided for @defaultTagDaily.
  ///
  /// In zh_TW, this message translates to:
  /// **'日常'**
  String get defaultTagDaily;

  /// No description provided for @defaultTagMood.
  ///
  /// In zh_TW, this message translates to:
  /// **'心情'**
  String get defaultTagMood;

  /// No description provided for @defaultTagReflection.
  ///
  /// In zh_TW, this message translates to:
  /// **'反思'**
  String get defaultTagReflection;

  /// No description provided for @defaultTagPlanning.
  ///
  /// In zh_TW, this message translates to:
  /// **'計畫'**
  String get defaultTagPlanning;

  /// No description provided for @defaultTagWork.
  ///
  /// In zh_TW, this message translates to:
  /// **'工作'**
  String get defaultTagWork;

  /// No description provided for @defaultTagStudy.
  ///
  /// In zh_TW, this message translates to:
  /// **'學習'**
  String get defaultTagStudy;

  /// No description provided for @defaultTagFamily.
  ///
  /// In zh_TW, this message translates to:
  /// **'家庭'**
  String get defaultTagFamily;

  /// No description provided for @defaultTagFriends.
  ///
  /// In zh_TW, this message translates to:
  /// **'朋友'**
  String get defaultTagFriends;

  /// No description provided for @defaultTagTravel.
  ///
  /// In zh_TW, this message translates to:
  /// **'旅遊'**
  String get defaultTagTravel;

  /// No description provided for @defaultTagFood.
  ///
  /// In zh_TW, this message translates to:
  /// **'美食'**
  String get defaultTagFood;

  /// No description provided for @defaultTagEntertainment.
  ///
  /// In zh_TW, this message translates to:
  /// **'娛樂'**
  String get defaultTagEntertainment;

  /// No description provided for @defaultTagExercise.
  ///
  /// In zh_TW, this message translates to:
  /// **'運動'**
  String get defaultTagExercise;

  /// No description provided for @defaultTagHealth.
  ///
  /// In zh_TW, this message translates to:
  /// **'健康'**
  String get defaultTagHealth;

  /// No description provided for @defaultTagShopping.
  ///
  /// In zh_TW, this message translates to:
  /// **'購物'**
  String get defaultTagShopping;
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
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.countryCode) {
          case 'TW':
            return AppLocalizationsZhTw();
        }
        break;
      }
  }

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
