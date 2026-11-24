import 'package:quill_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';

/// 完整日記庫備份 zip 內復原中繼資料的預覽。
///
/// 可進入還原流程時一定具備可解析的 [metadata]；缺少或無效時應在
/// [prepareRestorePreview] 等上游驗證階段直接失敗。
class BackupRecoveryPreview {
  const BackupRecoveryPreview({required this.metadata, this.backupId});

  final RecoveryMetadata metadata;
  final String? backupId;
}

typedef VerifiedBackupKey = ({
  BackupRecoveryPreview preview,
  List<int> wrapKey,
  String recoveryKey,
});

/// 還原前比對備份與目前裝置的結果。
class RestorePrecheck {
  const RestorePrecheck({
    required this.preview,
    this.localMetadata,
    required this.localHasTrustedDevice,
    required this.willOverwriteLocalVault,
  });

  final BackupRecoveryPreview preview;
  final RecoveryMetadata? localMetadata;
  final bool localHasTrustedDevice;
  final bool willOverwriteLocalVault;

  String get backupVaultId => preview.metadata.vaultId;

  String get backupRecoveryHint => preview.metadata.recoveryKeyHint;

  bool get sameVaultId => backupVaultId == localMetadata?.vaultId;

  /// 同一日記庫但本機曾更新過復原金鑰（舊備份需舊金鑰）。
  bool get recoveryKeyRotatedSinceBackup =>
      sameVaultId &&
      localMetadata?.hasSameRecoveryGenerationAs(preview.metadata) == false;

  /// 同一日記庫還原後能否沿用還原前已解鎖 session（免再次裝置驗證）。
  bool canResumeTrustedSession(UnlockedVaultSession? priorSession) =>
      localHasTrustedDevice &&
      localMetadata?.hasSameRecoveryGenerationAs(preview.metadata) == true &&
      priorSession?.canUseRecovery == true &&
      priorSession!.vaultId == backupVaultId;
}
