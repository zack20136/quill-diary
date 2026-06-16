import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/config/oauth_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('resolveServerClientId 以環境變數為最高優先序', () async {
    final String resolved = await OAuthConfig.resolveServerClientIdForTesting(
      envServerClientId: '  from-env  ',
      isAndroid: true,
      androidResolver: () async => 'from-xml',
    );

    expect(resolved, 'from-env');
  });

  test('resolveServerClientId 會在 Android 上回退到 xml 值', () async {
    final String resolved = await OAuthConfig.resolveServerClientIdForTesting(
      envServerClientId: '',
      isAndroid: true,
      androidResolver: () async => '  from-xml  ',
    );

    expect(resolved, 'from-xml');
  });

  test('resolveServerClientId 的 Android fallback 例外會回傳空字串', () async {
    final String resolved = await OAuthConfig.resolveServerClientIdForTesting(
      envServerClientId: '',
      isAndroid: true,
      androidResolver: () async => throw StateError('broken channel'),
    );

    expect(resolved, '');
  });

  test('resolveServerClientId 在非 Android 且無環境變數時回傳空字串', () async {
    final String resolved = await OAuthConfig.resolveServerClientIdForTesting(
      envServerClientId: '',
      isAndroid: false,
    );

    expect(resolved, '');
  });
}
