/// Dart 基礎設施程式碼共用的穩定應用名稱與命名空間。
///
/// 變更這些值可能產生新的本機儲存、Android 套件、
/// OAuth 或 MethodChannel 身份；更新應視為影響遷移。
abstract final class AppIdentifiers {
  static const String displayName = 'Quill Diary';
  static const String dartPackageName = 'quill_diary';
  static const String androidPackageName = 'zack20136.com.quill_diary';

  static const String appStorageDirectory = 'quill_diary';
  static const String downloadsExportDirectory = 'quill-diary';
  static const String secureStorageNamespace = 'quill_diary_device';

  static const String oauthChannel = 'quill_diary/oauth_config';
  static const String deviceKeyChannel = 'quill_diary/device_key_bridge';
  static const String easyDiaryRealmChannel = 'quill_diary/easy_diary_realm';

  static const String indexKeyDerivationInfo = 'quill_diary:index:v1';

  static const String sourceRepositoryUrl =
      'https://github.com/zack20136/quill-diary';
  static const String issuesUrl = '$sourceRepositoryUrl/issues';

  /// GitHub 渲染的法律文件（亦適用於 Google Play Console）。
  static const String privacyPolicyUrl =
      '$sourceRepositoryUrl/blob/main/docs/privacy-policy.md';

  static const String thirdPartyNoticesUrl =
      '$sourceRepositoryUrl/blob/main/docs/third-party-notices.md';
}
