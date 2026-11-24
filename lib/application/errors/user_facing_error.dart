import 'package:quill_diary/application/settings/vault_transfer_capabilities.dart';
import 'package:quill_diary/application/transfer/transfer_feedback.dart';
import 'package:quill_diary/domain/attachment/asset_attachment.dart';
import 'package:quill_diary/domain/recovery/recovery_key.dart';
import 'package:quill_diary/infrastructure/database/index_database_connection_io.dart';
import 'package:quill_diary/infrastructure/drive/google_drive_error.dart';
import 'package:quill_diary/infrastructure/storage/portable/backup_archive_inspection.dart';
import 'package:quill_diary/infrastructure/storage/shared/android_saf_file_copy.dart';
import 'package:quill_diary/infrastructure/storage/tag_catalog_store.dart';
import 'package:quill_diary/l10n/l10n.dart';

String userFacingErrorMessage(
  Object error, {
  required AppLocalizations l10n,
  String? fallback,
}) {
  if (error is TagCatalogException) return l10n.tagCatalogUnavailable;
  if (error is AttachmentFormatMismatchException) {
    return l10n.editorAttachmentFormatMismatch(error.fileName);
  }
  if (error is AttachmentTooLargeException) {
    return l10n.attachmentTooLarge(error.fileName, error.limit.megabytes);
  }
  if (error is RecoveryKeyFormatException) return l10n.recoveryKeyInvalidInput;
  if (error is RecoveryKeyRotationPendingException) {
    return l10n.recoveryKeyRotationNeedsUnlock;
  }
  if (error is RecoveryKeyRotationDraftExpiredException) {
    return l10n.recoveryKeyRotationDraftExpired;
  }
  if (error is IndexCipherUnavailableException) {
    return l10n.indexCipherUnavailable;
  }
  if (error is VaultTransferBlockedException) {
    return vaultTransferBlockMessage(l10n, error.reason);
  }
  if (error is VaultBackupException) {
    return vaultBackupIssueMessage(l10n, error.issue);
  }
  if (error is GoogleDriveException) {
    return error.localizedMessage(l10n);
  }
  if (error is AndroidSafWriteException) {
    final code = error.code;
    if (code == "partial_copy") return l10n.portableExportPartialCopy;
    return code == null || code.isEmpty
        ? l10n.androidSafWriteFailed
        : l10n.androidSafWriteFailedWithCode(code);
  }
  return fallback ?? l10n.userFacingErrorDefaultMessage;
}

String vaultBackupIssueMessage(AppLocalizations l10n, VaultBackupIssue issue) {
  return switch (issue) {
    VaultBackupIssue.passed => l10n.vaultBackupIssuePassed,
    VaultBackupIssue.unsafePath => l10n.vaultBackupIssueUnsafePath,
    VaultBackupIssue.markdownExportNotBackup =>
      l10n.vaultBackupIssueMarkdownExport,
    VaultBackupIssue.missingRecovery => l10n.vaultBackupIssueMissingRecovery,
    VaultBackupIssue.missingEncryptedData =>
      l10n.vaultBackupIssueMissingEncryptedData,
    VaultBackupIssue.incomplete => l10n.vaultBackupIssueIncomplete,
    VaultBackupIssue.invalidRecoveryJson =>
      l10n.vaultBackupIssueInvalidRecoveryJson,
    VaultBackupIssue.invalidZip => l10n.vaultBackupIssueInvalidZip,
    VaultBackupIssue.missingFile => l10n.vaultBackupIssueMissingFile,
    VaultBackupIssue.invalidArchive => l10n.vaultBackupIssueInvalidArchive,
    VaultBackupIssue.invalidBackupIntegrity =>
      l10n.vaultBackupIssueInvalidBackupIntegrity,
    VaultBackupIssue.invalidBackupContent =>
      l10n.vaultBackupIssueInvalidBackupContent,
    VaultBackupIssue.recoveryKeyMismatch =>
      l10n.vaultBackupIssueRecoveryKeyMismatch,
    VaultBackupIssue.noEncryptedSample =>
      l10n.vaultBackupIssueNoEncryptedSample,
    VaultBackupIssue.recoveryInfoMissing =>
      l10n.vaultBackupIssueRecoveryInfoMissing,
    VaultBackupIssue.missingVaultPayload =>
      l10n.vaultBackupIssueMissingVaultPayload,
    VaultBackupIssue.extractionLimitExceeded =>
      l10n.vaultBackupIssueExtractionLimitExceeded,
  };
}

/// 備份檢查失敗帶的是 [VaultBackupIssue] 名稱；無法對應的名稱改用通用訊息。
String localizedBackupInspectDetail(AppLocalizations l10n, String raw) {
  final String trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return '';
  }
  for (final VaultBackupIssue issue in VaultBackupIssue.values) {
    if (issue.name == trimmed) {
      return vaultBackupIssueMessage(l10n, issue);
    }
  }
  return l10n.settingsBackupInspectUnrecognizedDetail;
}
