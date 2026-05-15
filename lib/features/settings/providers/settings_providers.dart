import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/recovery/recovery_metadata.dart';
import '../../../infrastructure/database/index_database.dart';
import '../../../shared/providers/core_providers.dart';
import '../../session/providers/session_providers.dart';

final recoveryMetadataProvider = FutureProvider<RecoveryMetadata?>((Ref ref) async {
  if (!ref.watch(supportedPlatformProvider)) {
    return null;
  }
  await ref.watch(appStartupProvider.future);
  return ref.read(vaultRepositoryProvider).readRecoveryMetadata();
});

final backupHistoryProvider = FutureProvider<List<BackupHistoryRecord>>((Ref ref) async {
  if (!ref.watch(supportedPlatformProvider)) {
    return const <BackupHistoryRecord>[];
  }
  await ref.watch(appStartupProvider.future);
  return ref.read(indexDatabaseProvider).listBackups();
});
