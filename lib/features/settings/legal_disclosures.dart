/// 法律短句與設定頁「法律與隱私」文案（完整條款見 docs/privacy-policy.md）。
abstract final class LegalDisclosures {
  static const String privacyEffectiveDateLabel = '生效日期：2026 年 6 月 6 日';

  static const String childrenPrivacyOneLiner =
      '本應用程式並非專為十三歲（含）以下兒童而設計，亦不故意蒐集兒童之個人資料。';

  static const String brandDisclaimer =
      'Quill Diary 名稱、圖示與 Google Play 商店 listing 為作者品牌，不隨程式碼授權一併轉讓。';

  static const String billingVaultPrivacyNote = '支持流程不讀取 vault 內容。';

  static const String billingPrivacyOneLiner =
      '支持開發者之付款由 Google Play 處理，屬自願性一次性支持，不解鎖任何額外功能；'
      '$billingVaultPrivacyNote';

  static const String billingSupportPageBody =
      '開放後僅透過 Google Play Billing 收款，為一次性支持、非訂閱、非會員。'
      '$billingVaultPrivacyNote';

  static const String externalLinkUnavailableMessage =
      '無法開啟瀏覽器，請稍後再試。';
}

/// 設定頁「法律與隱私」區塊列標題。
abstract final class SettingsLegalCopy {
  static const String sectionTitle = '法律與隱私';
  static const String sectionDescription =
      '可在 GitHub 查看原始碼、隱私政策與第三方聲明；'
      '有問題歡迎透過 Issues 聯絡。';

  static const String sourceCodeTitle = 'GitHub 原始碼';
  static const String privacyPolicyTitle = '隱私權政策';
  static const String thirdPartyNoticesTitle = '第三方聲明';
  static const String contactAuthorTitle = '聯絡作者';
}
