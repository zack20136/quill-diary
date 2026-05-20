import '../../domain/recovery/recovery_metadata.dart';

const String kInvalidBackupArchiveMessage =
    '無法讀取備份檔，請確認檔案未損壞且為有效的 .jbackup。';

/// Preview of recovery metadata inside a `.jbackup` archive.
class BackupRecoveryPreview {
  const BackupRecoveryPreview({
    required this.hasRecovery,
    this.metadata,
  });

  final bool hasRecovery;
  final RecoveryMetadata? metadata;
}

/// Result of comparing a backup with the current device before restore.
class RestorePrecheck {
  const RestorePrecheck({
    required this.preview,
    this.localVaultId,
    required this.localHasTrustedDevice,
    required this.willOverwriteLocalVault,
  });

  final BackupRecoveryPreview preview;
  final String? localVaultId;
  final bool localHasTrustedDevice;
  final bool willOverwriteLocalVault;

  bool get backupHasRecovery => preview.hasRecovery;

  String? get backupVaultId => preview.metadata?.vaultId;

  String? get backupRecoveryHint => preview.metadata?.recoveryKeyHint;

  bool get sameVaultId =>
      backupVaultId != null &&
      localVaultId != null &&
      backupVaultId == localVaultId;

  bool get expectsTrustedUnlockAfterRestore =>
      backupHasRecovery && sameVaultId && localHasTrustedDevice;

  bool get expectsRecoveryKeyAfterRestore =>
      backupHasRecovery && !expectsTrustedUnlockAfterRestore;
}

/// Builds user-facing bullet points for the restore confirmation dialog.
List<String> buildRestoreConfirmBulletPoints(RestorePrecheck precheck) {
  final List<String> bullets = <String>[
    '將以備份內容覆寫本機日記庫，現有資料無法復原。',
    '索引會在解鎖後重新建立。',
  ];

  if (!precheck.backupHasRecovery) {
    bullets.add('此備份尚未建立復原金鑰；還原後請重新建立。');
    return bullets;
  }

  if (precheck.expectsTrustedUnlockAfterRestore) {
    bullets.add('還原後會先嘗試以本機受信任裝置自動解鎖。');
    bullets.add('若驗證失敗，再輸入建立此備份時保存的復原金鑰。');
  } else if (precheck.expectsRecoveryKeyAfterRestore) {
    bullets.add('還原後需輸入建立此備份時保存的復原金鑰（非本機後來新建的另一把）。');
    if (precheck.backupRecoveryHint != null &&
        precheck.backupRecoveryHint!.isNotEmpty) {
      bullets.add('復原金鑰提示：${precheck.backupRecoveryHint}');
    }
  }

  bullets.add('首次解鎖可能需重新包裝加密檔，請保持應用程式開啟。');
  return bullets;
}
