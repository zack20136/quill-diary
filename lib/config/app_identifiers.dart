/// Stable app names and namespaces shared by Dart infrastructure code.
///
/// Changing these values can create new on-device storage, Android package,
/// OAuth, or MethodChannel identities. Treat updates as migration-affecting.
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

  /// Public privacy policy for Google Play and in-app browser link.
  static const String privacyPolicyUrl =
      'https://zack20136.github.io/quill-diary/privacy-policy';

  static const String thirdPartyNoticesUrl =
      'https://zack20136.github.io/quill-diary/third-party-notices';
}
