import 'package:quill_diary/infrastructure/storage/restore_precheck.dart';

class RestorePreparedContext {
  const RestorePreparedContext({
    required this.precheck,
    this.backupRecoveryKey,
  });

  final RestorePrecheck precheck;
  final String? backupRecoveryKey;
}
