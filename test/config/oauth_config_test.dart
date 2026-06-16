import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/config/oauth_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('以環境變數為最高優先序', () async {
    final String resolved = await OAuthConfig.resolveServerClientIdForTesting(
      envServerClientId: '  from-env  ',
      isAndroid: true,
      androidResolver: () async => 'from-xml',
    );

    expect(resolved, 'from-env');
  });

  test('Android 會回退到 xml 值', () async {
    final String resolved = await OAuthConfig.resolveServerClientIdForTesting(
      envServerClientId: '',
      isAndroid: true,
      androidResolver: () async => '  from-xml  ',
    );

    expect(resolved, 'from-xml');
  });

  test('Android fallback 例外時回傳空字串', () async {
    final String resolved = await OAuthConfig.resolveServerClientIdForTesting(
      envServerClientId: '',
      isAndroid: true,
      androidResolver: () async => throw StateError('broken channel'),
    );

    expect(resolved, '');
  });

  test('非 Android 且無環境變數時回傳空字串', () async {
    final String resolved = await OAuthConfig.resolveServerClientIdForTesting(
      envServerClientId: '',
      isAndroid: false,
    );

    expect(resolved, '');
  });
}
