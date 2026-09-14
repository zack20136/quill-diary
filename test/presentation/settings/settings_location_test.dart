import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/app/router.dart';

void main() {
  test('settingsLocation 會帶入 focus query', () {
    expect(AppRouter.settingsLocation(), AppRouter.settingsRoute);
    expect(
      AppRouter.settingsLocation(focus: SettingsFocusTarget.recoveryKey),
      '/settings?focus=recoveryKey',
    );
    expect(
      AppRouter.settingsLocation(focus: SettingsFocusTarget.externalRestore),
      '/settings?focus=externalRestore',
    );
    expect(
      SettingsFocusTarget.tryParse('externalRestore'),
      SettingsFocusTarget.externalRestore,
    );
    expect(SettingsFocusTarget.tryParse('unknown'), isNull);
  });
}
