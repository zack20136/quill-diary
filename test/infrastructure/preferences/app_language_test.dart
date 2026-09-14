import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/infrastructure/preferences/personalization_preferences.dart';

void main() {
  test('中文裝置語系對應繁中，其餘對應英文', () {
    expect(AppLanguage.fromDeviceLocale(const Locale('zh')), AppLanguage.zh);
    expect(
      AppLanguage.fromDeviceLocale(const Locale('zh', 'TW')),
      AppLanguage.zh,
    );
    expect(
      AppLanguage.fromDeviceLocale(const Locale('en', 'US')),
      AppLanguage.en,
    );
    expect(AppLanguage.fromDeviceLocale(const Locale('ja')), AppLanguage.en);
  });
}
