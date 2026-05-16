import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Google Sign-In 在 Android 上須提供 [GoogleSignIn.initialize] 的 `serverClientId`
///（也就是網頁應用程式 OAuth Client ID）。
///
/// 優先順序：
/// 1. 建置參數 `--dart-define=GOOGLE_SERVER_CLIENT_ID=...`
/// 2. Android：`android/.../res/values/oauth_config.xml` 的 `oauth_request_id_token`
class OAuthConfig {
  OAuthConfig._();

  static const MethodChannel _androidOAuthChannel = MethodChannel(
    'quill_lock_diary/oauth_config',
  );

  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '',
  );

  static Future<String> resolveServerClientId() async {
    final String fromEnv = googleServerClientId.trim();
    if (fromEnv.isNotEmpty) {
      return fromEnv;
    }
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final String? fromXml =
            await _androidOAuthChannel.invokeMethod<String>('getServerClientId');
        return fromXml?.trim() ?? '';
      } on Object catch (error, stackTrace) {
        FlutterError.dumpErrorToConsole(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'OAuthConfig.resolveServerClientId',
          ),
        );
        return '';
      }
    }
    return '';
  }
}
