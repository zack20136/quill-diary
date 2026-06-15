import '../../domain/security/unlocked_vault_session.dart';
import '../../infrastructure/storage/restore_precheck.dart';

/// 還原前完成確認與金鑰驗證後的上下文。
class RestorePreparedContext {
  const RestorePreparedContext({
    required this.precheck,
    required this.priorSession,
    this.backupRecoveryKey,
  });

  final RestorePrecheck precheck;
  final UnlockedVaultSession? priorSession;
  final String? backupRecoveryKey;
}
