import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/security/unlocked_vault_session.dart';
import '../../infrastructure/storage/restore_precheck.dart';
import '../../shared/providers/core_providers.dart';
import '../editor/providers/editor_providers.dart';
import '../home/providers/home_providers.dart';
import '../session/providers/session_providers.dart';
import '../session/state/app_session_state.dart';
import '../settings/providers/settings_providers.dart';

/// 還原寫入完成後：重置依賴、建立 session、刷新索引。
Future<AppSessionState> finishRestoreSession(
  WidgetRef ref, {
  required RestorePrecheck precheck,
  String? backupRecoveryKey,
  UnlockedVaultSession? priorSession,
}) async {
  await resetRepositoriesAfterRestore(ref);

  try {
    final AppSessionState sessionState = await _startupRestoredSession(
      ref,
      precheck: precheck,
      backupRecoveryKey: backupRecoveryKey,
      priorSession: priorSession,
    );
    if (sessionState.isUnlocked && sessionState.session != null) {
      await refreshEntryIndexCaches(ref);
    }
    return sessionState;
  } finally {
    ref.invalidate(appStartupProvider);
    ref.invalidate(effectiveAppSessionProvider);
  }
}

Future<void> resetRepositoriesAfterRestore(WidgetRef ref) async {
  await ref.read(appSessionProvider.notifier).beginPostRestoreStartup();
  ref.invalidate(vaultTransferServiceProvider);
  ref.invalidate(vaultArchiveIoProvider);
  ref.invalidate(vaultRepositoryProvider);
  ref.invalidate(indexDatabaseManagerProvider);
  ref.invalidate(recoveryMetadataProvider);
  ref.invalidate(settingsDriveConnectionProvider);
  ref.invalidate(unlockModeProvider);
  ref.read(entryIndexRevisionProvider.notifier).bump();
}

Future<AppSessionState> _startupRestoredSession(
  WidgetRef ref, {
  required RestorePrecheck precheck,
  String? backupRecoveryKey,
  UnlockedVaultSession? priorSession,
}) async {
  final String? trimmedKey = backupRecoveryKey?.trim();
  if (trimmedKey != null && trimmedKey.isNotEmpty) {
    return _unlockWithRecoveryKey(ref, trimmedKey);
  }
  if (precheck.canResumeTrustedSession(priorSession)) {
    return ref
        .read(appSessionProvider.notifier)
        .resumeSessionAfterRestore(priorSession!);
  }
  if (precheck.expectsTrustedUnlockAfterRestore) {
    return ref
        .read(appSessionProvider.notifier)
        .enterRecoveryRequiredAfterRestore();
  }
  return ref.read(appSessionProvider.notifier).bootstrapAfterRestore();
}

Future<AppSessionState> _unlockWithRecoveryKey(
  WidgetRef ref,
  String recoveryKey,
) async {
  try {
    await ref.read(appSessionProvider.notifier).unlockWithRecovery(recoveryKey);
  } catch (_) {
    // unlockWithRecovery 已更新 session 狀態。
  }
  return ref.read(appSessionProvider);
}
