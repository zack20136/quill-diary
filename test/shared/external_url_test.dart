import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/shared/utils/external_url.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

class _RecordingUrlLauncher extends UrlLauncherPlatform {
  String? lastUrl;
  LaunchOptions? lastOptions;
  bool launchResult = true;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    lastUrl = url;
    lastOptions = options;
    return launchResult;
  }
}

void main() {
  late _RecordingUrlLauncher launcher;
  late UrlLauncherPlatform originalInstance;

  setUp(() {
    originalInstance = UrlLauncherPlatform.instance;
    launcher = _RecordingUrlLauncher();
    UrlLauncherPlatform.instance = launcher;
  });

  tearDown(() {
    UrlLauncherPlatform.instance = originalInstance;
  });

  test('launchExternalUrl 以 externalApplication 開啟並轉傳結果', () async {
    launcher.launchResult = true;

    final bool opened = await launchExternalUrl('https://example.com/privacy');

    expect(opened, isTrue);
    expect(launcher.lastUrl, 'https://example.com/privacy');
    expect(launcher.lastOptions?.mode, PreferredLaunchMode.externalApplication);
  });

  test('launchUrl 回 false 時 launchExternalUrl 回 false', () async {
    launcher.launchResult = false;

    final bool opened = await launchExternalUrl('https://example.com/issues');

    expect(opened, isFalse);
    expect(launcher.lastUrl, 'https://example.com/issues');
  });
}
