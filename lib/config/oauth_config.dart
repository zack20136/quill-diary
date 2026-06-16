import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app_identifiers.dart';

/// Google Sign-In 在 Android 上須提供 [GoogleSignIn.initialize] 的 `serverClientId`
///（也就是網頁應用程式 OAuth Client ID）。
///
/// 優先順序：
/// 1. 建置參數 `--dart-define=GOOGLE_SERVER_CLIENT_ID=...`
/// 2. Android：`android/.../res/values/oauth_config.xml` 的 `oauth_request_id_token`
class OAuthConfig {
  OAuthConfig._();

  static const MethodChannel _androidOAuthChannel = MethodChannel(
    AppIdentifiers.oauthChannel,
  );

  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '',
  );

  static const String googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue: '',
  );

  /// iOS 端是否已提供 Google Drive OAuth Client ID。
  static bool get isIosGoogleDriveConfigured {
    if (kIsWeb || !Platform.isIOS) {
      return false;
    }
    return googleIosClientId.trim().isNotEmpty;
  }

  static Future<String> resolveServerClientId() async {
    return resolveServerClientIdForTesting(
      envServerClientId: googleServerClientId,
      isAndroid: !kIsWeb && Platform.isAndroid,
      androidResolver: () =>
          _androidOAuthChannel.invokeMethod<String>('getServerClientId'),
    );
  }

  /// 測試用注入點：保留 production 邏輯，但允許替換 Android 來源與平台判斷。
  @visibleForTesting
  static Future<String> resolveServerClientIdForTesting({
    required String envServerClientId,
    bool isAndroid = false,
    Future<String?> Function()? androidResolver,
  }) async {
    final String fromEnv = envServerClientId.trim();
    if (fromEnv.isNotEmpty) {
      return fromEnv;
    }
    if (isAndroid) {
      try {
        final Future<String?> Function() resolver =
            androidResolver ??
                () => _androidOAuthChannel.invokeMethod<String>('getServerClientId');
        final String? fromXml = await resolver();
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
