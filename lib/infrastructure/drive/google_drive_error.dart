enum GoogleDriveErrorCode {
  invalidBackupName,
  invalidBackupFormat,
  oauthAndroidNotConfigured,
  oauthIosNotConfigured,
  signInRequired,
  authorizationRequired,
  oauthAdminPolicy,
  oauthConfiguration,
  oauthCancelled,
  oauthNetwork,
  oauthInterrupted,
  oauthUiUnavailable,
  oauthUserMismatch,
  oauthUnexpected,
  invalidFileId,
  pruneFailed,
  invalidDownloadPath,
  prepareUploadFailed,
  startUploadFailed,
  backgroundStartNotAllowed,
  uploadAlreadyActive,
  backgroundUploadUnsupported,
}

final class GoogleDriveException implements Exception {
  const GoogleDriveException(this.code, {this.failedCount, this.totalCount});

  final GoogleDriveErrorCode code;
  final int? failedCount;
  final int? totalCount;

  @override
  String toString() => 'GoogleDriveException(${code.name})';
}

GoogleDriveException? googleDriveExceptionForNativeAuthCode(String code) {
  final GoogleDriveErrorCode? errorCode = switch (code) {
    'google_drive_auth_configuration' =>
      GoogleDriveErrorCode.oauthConfiguration,
    'google_drive_auth_network' => GoogleDriveErrorCode.oauthNetwork,
    'google_drive_auth_reauth' ||
    'google_drive_scope_missing' => GoogleDriveErrorCode.authorizationRequired,
    'google_drive_auth_unavailable' => GoogleDriveErrorCode.oauthUiUnavailable,
    'google_drive_auth_cancelled' => GoogleDriveErrorCode.oauthCancelled,
    'google_drive_auth_in_progress' => GoogleDriveErrorCode.oauthInterrupted,
    'google_drive_account_missing' ||
    'google_drive_auth_failed' => GoogleDriveErrorCode.oauthUnexpected,
    _ => null,
  };
  return errorCode == null ? null : GoogleDriveException(errorCode);
}
