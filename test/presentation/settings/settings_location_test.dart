import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/shared/navigation/app_routes.dart';

void main() {
  test('settingsLocation 會帶入 focus query', () {
    expect(AppRoutes.settingsLocation(), AppRoutes.settingsRoute);
    expect(
      AppRoutes.settingsLocation(focus: SettingsFocusTarget.recoveryKey),
      '/settings?focus=recoveryKey',
    );
    expect(
      AppRoutes.settingsLocation(focus: SettingsFocusTarget.externalRestore),
      '/settings?focus=externalRestore',
    );
    expect(
      SettingsFocusTarget.tryParse('externalRestore'),
      SettingsFocusTarget.externalRestore,
    );
    expect(SettingsFocusTarget.tryParse('unknown'), isNull);
  });
}
