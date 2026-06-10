import '../../config/app_identifiers.dart';
import 'legal_disclosures.dart';

class PrivacySectionCopy {
  const PrivacySectionCopy({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;
}

/// 設定「隱私權政策」子頁文案（摘要語意對齊 docs/public/privacy-policy.md；不一致以公開網頁為準）。
abstract final class SettingsPrivacyCopy {
  static const String pageTitle = '隱私權政策';
  static const String heroTitle = '你的日記留在你的裝置上';
  static const String openInBrowserLabel = '在瀏覽器開啟完整版';
  static const String effectiveDateLabel =
      LegalDisclosures.privacyEffectiveDateLabel;

  static final String heroBody =
      'Quill Diary（${AppIdentifiers.androidPackageName}）以離線、本機加密為核心。'
      '我們不會預設收集或上傳你的日記內容。'
      '以下為摘要；完整條款（含本機資料存放與政策變更）請見底部連結。'
      '${LegalDisclosures.privacyAuthoritativeNotice}';

  static final List<PrivacySectionCopy> sections = <PrivacySectionCopy>[
    const PrivacySectionCopy(
      title: '資料留在裝置上',
      body:
          '預設不收集日記內容。標題、內文、標籤、附件、草稿、搜尋索引與復原設定'
          '皆以加密形式保存在你的裝置上，開發者不會自動收到這些資料。',
    ),
    PrivacySectionCopy(
      title: '你主動操作時',
      body:
          'Google Drive 備份：僅在你連線 Google 帳號並備份時，才會上傳加密備份檔至你的 Drive。'
          '選取圖片或檔案：透過系統選取器，不掃描整個相簿。'
          '生物辨識：僅本機解鎖，不上傳。'
          '${LegalDisclosures.billingPrivacyOneLiner}',
    ),
    const PrivacySectionCopy(
      title: '我們不會做的事',
      body:
          '無廣告、無追蹤 SDK、不出售個人資料、'
          '不要求註冊即可使用本機日記、'
          '不將日記明文上傳至開發者伺服器。',
    ),
    const PrivacySectionCopy(
      title: 'Android 權限',
      body:
          'INTERNET：Google Sign-In、Drive 備份與（若開放）Play Billing。'
          'USE_BIOMETRIC：可信裝置解鎖。'
          '不要求相機或讀取整個媒體庫的權限。',
    ),
    PrivacySectionCopy(
      title: '分享、刪除與聯絡',
      body:
          '除你主動備份至 Google Drive、自行匯出，或法律要求外，'
          '開發者不分享日記內容。'
          '你可刪除日記或附件、刪除本機或 Drive 備份、中斷 Google Drive 連線、'
          '清除 App 資料或解除安裝以移除本機資料。'
          '${LegalDisclosures.childrenPrivacyOneLiner} '
          '若對本政策有疑問，請至 GitHub Issues：${AppIdentifiers.issuesUrl}。',
    ),
  ];
}
