import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/preferences/personalization_preferences.dart';
import 'package:quill_diary/l10n/l10n.dart';

void main() {
  test('中文裝置語系對應繁中，其餘對應英文', () {
    expect(appLanguageFromDeviceLocale(const Locale('zh')), AppLanguage.zh);
    expect(
      appLanguageFromDeviceLocale(const Locale('zh', 'TW')),
      AppLanguage.zh,
    );
    expect(
      appLanguageFromDeviceLocale(const Locale('en', 'US')),
      AppLanguage.en,
    );
    expect(appLanguageFromDeviceLocale(const Locale('ja')), AppLanguage.en);
  });
}
