import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../config/app_identifiers.dart';

/// Android OAuth 指紋。更新 keystore 後請同步 [GoogleDriveOAuthFingerprints.oauthSetupDocPath] 並執行 `signingReport`。
abstract final class GoogleDriveOAuthFingerprints {
  static const String androidPackageName = AppIdentifiers.androidPackageName;

  static const String releaseUploadSha1 =
      '3D:40:C1:59:06:52:4E:C5:76:2D:29:51:30:92:77:7C:54:D5:42:1C';

  static const String debugSha1 =
      'B0:B3:BC:E7:7C:68:8E:67:84:B4:B8:BB:FF:E5:A8:AE:24:6F:53:BB';

  static const String oauthSetupDocPath = 'docs/Google-Drive-OAuth-設定.md';
}

String googleDriveAndroidOAuthSha1Checklist() {
  return '請到 Google Cloud Console 確認 Android OAuth client：\n'
      '- package name：${GoogleDriveOAuthFingerprints.androidPackageName}\n'
      '- debug 安裝請加入 SHA-1：${GoogleDriveOAuthFingerprints.debugSha1}\n'
      '- release / upload keystore 安裝請加入 SHA-1：${GoogleDriveOAuthFingerprints.releaseUploadSha1}\n'
      '- 若從 Google Play 安裝，還需 Play Console → App signing 的 SHA-1（通常與 upload 不同）';
}

/// CredentialManager 常把 OAuth 設定錯誤誤報為使用者取消。
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

String _detailLine(String? detail) {
  if (detail == null || detail.isEmpty) {
    return '';
  }
  return '\n詳細資訊：$detail';
}

String _oauthMisconfigurationMessage({
  required String headline,
  required String oauthSetupDocPath,
  String? detail,
}) {
  return '$headline\n'
      '${googleDriveAndroidOAuthSha1Checklist()}\n'
      '並確認 `oauth_config.xml` 填的是 Web OAuth client id。\n'
      '詳細設定請參考 $oauthSetupDocPath。'
      '${_detailLine(detail)}';
}

String _misconfigurationHeadline(String? detail) {
  final String lowerDetail = detail?.toLowerCase() ?? '';
  if (lowerDetail.contains('account reauth failed') || lowerDetail.contains('[16]')) {
    return 'Google 帳號驗證沒有完成（Account reauth failed）。\n'
        '請確認 SHA-1 與安裝包一致；若仍失敗，請按「重新連結 Google Drive」，'
        '或到 Google 帳號移除本 App 的第三方存取權後再試。';
  }
  if (lowerDetail.contains('access_denied')) {
    return 'Google Drive 權限授權沒有完成。\n'
        '若選完帳號後沒有出現 Drive 權限頁，通常是 OAuth 設定不一致。';
  }
  return 'Google 帳號登入未完成，通常是 OAuth 設定與目前安裝包不一致。';
}

String userMessageForGoogleSignIn(
  GoogleSignInException error, {
  String oauthSetupDocPath = GoogleDriveOAuthFingerprints.oauthSetupDocPath,
}) {
  final String? detail = error.description?.trim();
  final String lowerDetail = detail?.toLowerCase() ?? '';

  if (lowerDetail.contains('admin_policy_enforced')) {
    return '這個 Google 帳號受到組織政策限制，暫時無法授權 Google Drive 給此 App。\n'
        '請改用可自行授權的個人帳號，或請管理員確認是否允許此 App 使用 Drive 權限。'
        '${_detailLine(detail)}';
  }

  if (looksLikeGoogleOAuthMisconfiguration(detail) ||
      error.code == GoogleSignInExceptionCode.clientConfigurationError ||
      error.code == GoogleSignInExceptionCode.providerConfigurationError) {
    return _oauthMisconfigurationMessage(
      headline: _misconfigurationHeadline(detail),
      oauthSetupDocPath: oauthSetupDocPath,
      detail: detail,
    );
  }

  if (error.code == GoogleSignInExceptionCode.canceled) {
    return '你已取消 Google 登入，尚未連結 Google Drive。\n'
        '若要連結，請再按一次「連結 Google Drive」。'
        '${_detailLine(detail)}';
  }
  if (error.code == GoogleSignInExceptionCode.interrupted) {
    return 'Google 登入流程被中斷，請稍後再試一次。${_detailLine(detail)}';
  }
  if (error.code == GoogleSignInExceptionCode.uiUnavailable) {
    return '目前裝置無法顯示 Google 登入畫面。\n'
        '請先確認 Google Play 服務可正常使用，再重新嘗試。'
        '${_detailLine(detail)}';
  }
  if (error.code == GoogleSignInExceptionCode.userMismatch) {
    return '目前登入中的 Google 帳號與授權帳號不一致。\n'
        '請重新連結 Google Drive，並確認選擇的是同一個帳號。'
        '${_detailLine(detail)}';
  }

  return 'Google 登入發生未預期錯誤，請稍後再試一次。\n'
      '若問題持續，請依 $oauthSetupDocPath 檢查 OAuth 與 SHA-1 設定。'
      '${_detailLine(detail)}';
}
