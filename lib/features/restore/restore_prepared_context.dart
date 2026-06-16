import '../../infrastructure/storage/restore_precheck.dart';

/// 還原前完成確認與金鑰驗證後的上下文。
class RestorePreparedContext {
  const RestorePreparedContext({
    required this.precheck,
    this.backupRecoveryKey,
  });

  final RestorePrecheck precheck;
  final String? backupRecoveryKey;
}
