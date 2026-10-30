import 'package:flutter/foundation.dart';
import 'package:quill_diary/application/settings/vault_transfer_capabilities.dart';
import 'package:quill_diary/application/transfer/transfer_feedback.dart';
import 'package:quill_diary/infrastructure/drive/google_drive_error.dart';
import 'package:quill_diary/infrastructure/storage/portable/backup_archive_inspection.dart';
import 'package:quill_diary/infrastructure/storage/shared/android_saf_file_copy.dart';
import 'package:quill_diary/l10n/l10n.dart';

String userFacingErrorMessage(
  Object error, {
  required AppLocalizations l10n,
  String? fallback,
}) {
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
    return code == null || code.isEmpty
        ? l10n.androidSafWriteFailed
        : l10n.androidSafWriteFailedWithCode(code);
  }
  debugPrint('Unclassified user-facing error: $error');
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
    VaultBackupIssue.recoveryKeyMismatch =>
      l10n.vaultBackupIssueRecoveryKeyMismatch,
    VaultBackupIssue.noEncryptedSample =>
      l10n.vaultBackupIssueNoEncryptedSample,
    VaultBackupIssue.recoveryInfoMissing =>
      l10n.vaultBackupIssueRecoveryInfoMissing,
    VaultBackupIssue.missingVaultPayload =>
      l10n.vaultBackupIssueMissingVaultPayload,
  };
}

/// 備份檢查失敗會把 [VaultBackupIssue] 名稱存進狀態；舊紀錄仍可能是中文句子。
String localizedBackupPersistDetail(AppLocalizations l10n, String raw) {
  for (final VaultBackupIssue issue in VaultBackupIssue.values) {
    if (issue.name == raw) {
      return vaultBackupIssueMessage(l10n, issue);
    }
  }
  return raw;
}
