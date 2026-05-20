import '../../domain/recovery/recovery_metadata.dart';

const String kInvalidBackupArchiveMessage =
    '無法讀取備份檔，請確認檔案未損壞且為有效的 .jbackup。';

const String kBackupRecoveryKeyMismatchMessage =
    '復原金鑰與此備份不相符。請輸入建立該備份時保存的復原金鑰。';

const String kBackupNoEncryptedSampleMessage =
    '備份內找不到可驗證的加密日記檔，無法確認復原金鑰。';

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
    this.localRecoverySaltBase64,
    required this.localHasTrustedDevice,
    required this.willOverwriteLocalVault,
  });

  final BackupRecoveryPreview preview;
  final String? localVaultId;
  final String? localRecoverySaltBase64;
  final bool localHasTrustedDevice;
  final bool willOverwriteLocalVault;

  bool get backupHasRecovery => preview.hasRecovery;

  String? get backupVaultId => preview.metadata?.vaultId;

  String? get backupRecoveryHint => preview.metadata?.recoveryKeyHint;

  bool get sameVaultId =>
      backupVaultId != null &&
      localVaultId != null &&
      backupVaultId == localVaultId;

  String? get backupRecoverySaltBase64 => preview.metadata?.kdf.saltBase64;

  /// 備份與本機目前的復原金鑰為同一代（未輪替過）。
  bool get sameRecoveryGeneration =>
      backupRecoverySaltBase64 != null &&
      localRecoverySaltBase64 != null &&
      backupRecoverySaltBase64 == localRecoverySaltBase64;

  /// 同 vault 但本機曾更新過復原金鑰（舊備份需舊金鑰）。
  bool get recoveryKeyRotatedSinceBackup =>
      backupHasRecovery &&
      sameVaultId &&
      localHasTrustedDevice &&
      localRecoverySaltBase64 != null &&
      backupRecoverySaltBase64 != null &&
      !sameRecoveryGeneration;

  bool get expectsTrustedUnlockAfterRestore =>
      backupHasRecovery && sameVaultId && localHasTrustedDevice && sameRecoveryGeneration;

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

  if (precheck.recoveryKeyRotatedSinceBackup) {
    bullets.add(
      '此備份在「更新復原金鑰」之前建立；還原後請輸入建立該備份時保存的舊復原金鑰（不是目前這把新金鑰）。',
    );
    if (precheck.backupRecoveryHint != null &&
        precheck.backupRecoveryHint!.isNotEmpty) {
      bullets.add('備份金鑰提示：${precheck.backupRecoveryHint}');
    }
  } else if (precheck.expectsTrustedUnlockAfterRestore) {
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
