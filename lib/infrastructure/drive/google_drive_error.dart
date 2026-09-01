import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/utils/user_facing_error.dart';

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

final class GoogleDriveException
    implements Exception, LocalizedUserFacingError {
  const GoogleDriveException(this.code, {this.failedCount, this.totalCount});

  final GoogleDriveErrorCode code;
  final int? failedCount;
  final int? totalCount;

  @override
  String localizedMessage(AppLocalizations l10n) => switch (code) {
    GoogleDriveErrorCode.invalidBackupName => l10n.driveErrorInvalidBackupName,
    GoogleDriveErrorCode.invalidBackupFormat =>
      l10n.driveErrorInvalidBackupFormat,
    GoogleDriveErrorCode.oauthAndroidNotConfigured =>
      l10n.driveErrorOAuthAndroidNotConfigured,
    GoogleDriveErrorCode.oauthIosNotConfigured =>
      l10n.driveErrorOAuthIosNotConfigured,
    GoogleDriveErrorCode.signInRequired => l10n.driveErrorSignInRequired,
    GoogleDriveErrorCode.authorizationRequired =>
      l10n.driveErrorAuthorizationRequired,
    GoogleDriveErrorCode.oauthAdminPolicy => l10n.driveErrorOAuthAdminPolicy,
    GoogleDriveErrorCode.oauthConfiguration =>
      l10n.driveErrorOAuthConfiguration,
    GoogleDriveErrorCode.oauthCancelled => l10n.driveErrorOAuthCancelled,
    GoogleDriveErrorCode.oauthNetwork => l10n.driveErrorOAuthNetwork,
    GoogleDriveErrorCode.oauthInterrupted => l10n.driveErrorOAuthInterrupted,
    GoogleDriveErrorCode.oauthUiUnavailable =>
      l10n.driveErrorOAuthUiUnavailable,
    GoogleDriveErrorCode.oauthUserMismatch => l10n.driveErrorOAuthUserMismatch,
    GoogleDriveErrorCode.oauthUnexpected => l10n.driveErrorOAuthUnexpected,
    GoogleDriveErrorCode.invalidFileId => l10n.driveErrorInvalidFileId,
    GoogleDriveErrorCode.pruneFailed => l10n.driveErrorPruneFailed(
      failedCount ?? 0,
      totalCount ?? 0,
    ),
    GoogleDriveErrorCode.invalidDownloadPath =>
      l10n.driveErrorInvalidDownloadPath,
    GoogleDriveErrorCode.prepareUploadFailed =>
      l10n.driveErrorPrepareUploadFailed,
    GoogleDriveErrorCode.startUploadFailed => l10n.driveErrorStartUploadFailed,
    GoogleDriveErrorCode.backgroundStartNotAllowed =>
      l10n.driveErrorBackgroundStartNotAllowed,
    GoogleDriveErrorCode.uploadAlreadyActive =>
      l10n.driveErrorUploadAlreadyActive,
    GoogleDriveErrorCode.backgroundUploadUnsupported =>
      l10n.driveErrorBackgroundUploadUnsupported,
  };

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
