import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/security/unlocked_vault_session.dart';
import '../../shared/providers/core_providers.dart';
import '../editor/providers/editor_draft_providers.dart';
import '../editor/providers/editor_providers.dart';
import '../home/providers/home_providers.dart';
import '../session/providers/session_providers.dart';
import '../session/state/app_session_state.dart';
import '../settings/providers/settings_providers.dart';
import 'restore_prepared_context.dart';

/// 還原寫入完成後：重置依賴、建立 session、刷新索引。
Future<AppSessionState> finishRestoreSession(
  WidgetRef ref, {
  required RestorePreparedContext prepared,
  UnlockedVaultSession? livePriorSession,
}) async {
  await ref.read(appSessionProvider.notifier).beginPostRestoreStartup();
  ref.invalidate(vaultTransferServiceProvider);
  ref.invalidate(vaultArchiveIoProvider);
  ref.invalidate(vaultRepositoryProvider);
  ref.invalidate(indexDatabaseManagerProvider);
  ref.invalidate(editorDraftKeysProvider);
  ref.invalidate(recoveryMetadataProvider);
  ref.invalidate(settingsDriveConnectionProvider);
  ref.invalidate(unlockModeProvider);
  ref.read(entryIndexRevisionProvider.notifier).bump();

  try {
    final AppSessionState sessionState = await _startupRestoredSession(
      ref,
      prepared: prepared,
      livePriorSession: livePriorSession,
    );
    if (sessionState.isUnlocked && sessionState.session != null) {
      await refreshEntryIndexCaches(ref);
    }
    return sessionState;
  } finally {
    ref.read(appSessionProvider.notifier).endTrustedUnlockBootstrap();
    ref.invalidate(appStartupProvider);
    ref.invalidate(effectiveAppSessionProvider);
  }
}

Future<AppSessionState> _startupRestoredSession(
  WidgetRef ref, {
  required RestorePreparedContext prepared,
  UnlockedVaultSession? livePriorSession,
}) async {
  final String? trimmedKey = prepared.backupRecoveryKey?.trim();
  if (trimmedKey != null && trimmedKey.isNotEmpty) {
    return _unlockWithRecoveryKey(ref, trimmedKey);
  }
  if (prepared.precheck.canResumeTrustedSession(livePriorSession)) {
    return ref
        .read(appSessionProvider.notifier)
        .resumeSessionAfterRestore(livePriorSession!);
  }
  if (prepared.precheck.expectsTrustedUnlockAfterRestore) {
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
