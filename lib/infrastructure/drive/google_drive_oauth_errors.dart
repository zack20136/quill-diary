import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:quill_diary/app/app_identifiers.dart';
import 'package:quill_diary/infrastructure/drive/google_drive_error.dart';

/// Android OAuth 指紋。更新 keystore 後請同步 [GoogleDriveOAuthFingerprints.oauthSetupDocPath] 並執行 `signingReport`。
abstract final class GoogleDriveOAuthFingerprints {
  static const String androidPackageName = AppIdentifiers.androidPackageName;

  static const String releaseUploadSha1 =
      '3D:40:C1:59:06:52:4E:C5:76:2D:29:51:30:92:77:7C:54:D5:42:1C';

  static const String debugSha1 =
      'B0:B3:BC:E7:7C:68:8E:67:84:B4:B8:BB:FF:E5:A8:AE:24:6F:53:BB';

  static const String oauthSetupDocPath =
      'docs/開發/google/Google-Drive-OAuth-設定.md';
}

/// 憑證管理員常把 OAuth 設定錯誤誤報為使用者取消。
@visibleForTesting
bool looksLikeGoogleOAuthMisconfiguration(String? detail) {
  final String lowerDetail = detail?.toLowerCase() ?? '';
  return lowerDetail.contains('activity is cancelled by the user') ||
      lowerDetail.contains('account reauth failed') ||
      lowerDetail.contains('account auth failed') ||
      lowerDetail.contains('access_denied') ||
      lowerDetail.contains('no credential') ||
      lowerDetail.contains('developer_error') ||
      lowerDetail.contains('[10]') ||
      lowerDetail.contains('[16]');
}

GoogleDriveException googleDriveExceptionForSignIn(
  GoogleSignInException error,
) {
  final String? detail = error.description?.trim();
  final String lowerDetail = detail?.toLowerCase() ?? '';
  debugPrint(
    'Google Drive sign-in failed: code=${error.code.name}, detail=$detail',
  );

  if (lowerDetail.contains('admin_policy_enforced')) {
    return const GoogleDriveException(GoogleDriveErrorCode.oauthAdminPolicy);
  }

  if (looksLikeGoogleOAuthMisconfiguration(detail) ||
      error.code == GoogleSignInExceptionCode.clientConfigurationError ||
      error.code == GoogleSignInExceptionCode.providerConfigurationError) {
    return const GoogleDriveException(GoogleDriveErrorCode.oauthConfiguration);
  }

  if (error.code == GoogleSignInExceptionCode.canceled) {
    return const GoogleDriveException(GoogleDriveErrorCode.oauthCancelled);
  }
  if (error.code == GoogleSignInExceptionCode.interrupted) {
    return const GoogleDriveException(GoogleDriveErrorCode.oauthInterrupted);
  }
  if (error.code == GoogleSignInExceptionCode.uiUnavailable) {
    return const GoogleDriveException(GoogleDriveErrorCode.oauthUiUnavailable);
  }
  if (error.code == GoogleSignInExceptionCode.userMismatch) {
    return const GoogleDriveException(GoogleDriveErrorCode.oauthUserMismatch);
  }

  return const GoogleDriveException(GoogleDriveErrorCode.oauthUnexpected);
}
