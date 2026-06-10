/// 設定頁與子頁共用的法律短句（非完整條款；完整文字見 docs/）。
abstract final class LegalDisclosures {
  static const String privacyEffectiveDateLabel = '生效日期：2026 年 6 月 6 日';

  static const String privacyAuthoritativeNotice =
      '若摘要與公開網頁版不一致，以公開網頁版為準。';

  static const String childrenPrivacyOneLiner =
      '本 App 並非專為 13 歲以下兒童設計，也不故意收集兒童個人資料。';

  static const String agplSourceCodeSubtitle =
      'AGPL-3.0；完整源碼可於 GitHub 取得';

  static const String brandDisclaimer =
      'Quill Diary 名稱、圖示與 Google Play 商店 listing 為作者品牌，不隨程式碼授權一併轉讓。';

  static const String billingVaultPrivacyNote = '支持流程不讀取 vault 內容。';

  static const String billingPrivacyOneLiner =
      '付款由 Google Play 處理，為自願一次性支持，不解鎖任何額外功能；'
      '$billingVaultPrivacyNote';

  static const String billingSupportPageBody =
      '開放後僅透過 Google Play Billing 收款，為一次性支持、非訂閱、非會員。'
      '$billingVaultPrivacyNote';

  static const String externalLinkUnavailableMessage =
      '無法開啟連結，請稍後再試。';
}
