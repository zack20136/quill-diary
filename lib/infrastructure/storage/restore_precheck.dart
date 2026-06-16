import '../../domain/recovery/recovery_metadata.dart';
import '../../domain/security/unlocked_vault_session.dart';

const String kInvalidBackupArchiveMessage = '無法讀取備份檔，請確認檔案未損壞且為有效的 zip 備份。';

const String kBackupRecoveryKeyMismatchMessage =
    '復原金鑰與此備份不相符。請輸入建立該備份時保存的復原金鑰。';

const String kBackupNoEncryptedSampleMessage = '備份內找不到可驗證的加密日記檔，無法確認復原金鑰。';

/// 完整 vault 備份 zip 內復原中繼資料的預覽。
class BackupRecoveryPreview {
  const BackupRecoveryPreview({required this.hasRecovery, this.metadata});

  final bool hasRecovery;
  final RecoveryMetadata? metadata;
}

/// 還原前比對備份與目前裝置的結果。
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
      localRecoverySaltBase64 != null &&
      backupRecoverySaltBase64 != null &&
      !sameRecoveryGeneration;

  bool get expectsTrustedUnlockAfterRestore =>
      backupHasRecovery &&
      sameVaultId &&
      localHasTrustedDevice &&
      sameRecoveryGeneration;

  bool get expectsRecoveryKeyAfterRestore =>
      backupHasRecovery && !expectsTrustedUnlockAfterRestore;

  /// 同 vault 還原後能否沿用還原前已解鎖 session（免再次裝置驗證）。
  bool canResumeTrustedSession(UnlockedVaultSession? priorSession) =>
      expectsTrustedUnlockAfterRestore &&
      priorSession?.canUseRecovery == true &&
      priorSession!.vaultId == backupVaultId;
}
