import 'legal_disclosures.dart';

/// 設定頁「法律與隱私」區塊文案。
abstract final class SettingsLegalCopy {
  static const String sectionTitle = '法律與隱私';
  static const String sectionDescription =
      '隱私、開源授權、依存套件與第三方聲明。';

  static const String sourceCodeTitle = '原始碼';
  static const String sourceCodeSubtitle =
      LegalDisclosures.agplSourceCodeSubtitle;
  static const String dependencyLicensesTitle = '依存套件授權';
  static const String thirdPartyNoticesTitle = '第三方聲明';
}
