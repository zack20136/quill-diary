import 'package:quill_diary/application/settings/vault_transfer_capabilities.dart';
import 'package:quill_diary/infrastructure/drive/drive_backup_service.dart';
import 'package:quill_diary/infrastructure/drive/google_drive_error.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/presentation/display_format.dart';

extension DriveConnectionPresentation on DriveConnectionState {
  String? accountLabel(AppLocalizations l10n) {
    final String? trimmedName = displayName?.trim();
    final String? trimmedEmail = email?.trim();
    if (trimmedName != null && trimmedName.isNotEmpty) {
      if (trimmedEmail != null && trimmedEmail.isNotEmpty) {
        return DisplayFormat.formatGoogleAccountLabel(
          l10n,
          trimmedName,
          trimmedEmail,
        );
      }
      return trimmedName;
    }
    if (trimmedEmail != null && trimmedEmail.isNotEmpty) {
      return trimmedEmail;
    }
    return null;
  }
}

extension GoogleDriveErrorPresentation on GoogleDriveException {
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
}

String vaultTransferBlockMessage(
  AppLocalizations l10n,
  VaultTransferBlock reason,
) => switch (reason) {
  VaultTransferBlock.backupNeedsUnlock =>
    l10n.vaultTransferNeedsUnlockForBackup,
  VaultTransferBlock.backupNeedsRecoveryKey =>
    l10n.vaultTransferNeedsRecoveryKeyForBackup,
  VaultTransferBlock.portableNeedsUnlock =>
    l10n.vaultTransferNeedsUnlockForPortableTransfer,
  VaultTransferBlock.restoreNeedsUnlock =>
    l10n.vaultTransferNeedsUnlockForRestore,
};

extension VaultTransferFeedback on VaultTransferCapabilities {
  String? backupDisabledMessage(AppLocalizations l10n) =>
      backupDisabledReason == null
      ? null
      : vaultTransferBlockMessage(l10n, backupDisabledReason!);
  String? portableTransferDisabledMessage(AppLocalizations l10n) =>
      portableTransferDisabledReason == null
      ? null
      : vaultTransferBlockMessage(l10n, portableTransferDisabledReason!);
  String? restoreDisabledMessage(AppLocalizations l10n) =>
      restoreDisabledReason == null
      ? null
      : vaultTransferBlockMessage(l10n, restoreDisabledReason!);

  String? backupSectionBlockedMessage(
    AppLocalizations l10n, {
    required String fallback,
  }) {
    if (!canBackup && !canRestore) {
      return restoreDisabledMessage(l10n) ?? backupDisabledMessage(l10n);
    }
    if (!canBackup) return backupDisabledMessage(l10n) ?? fallback;
    if (!canRestore) return restoreDisabledMessage(l10n);
    return null;
  }
}
