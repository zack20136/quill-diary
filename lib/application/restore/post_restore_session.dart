import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:quill_diary/application/session/providers/session_providers.dart';
import 'package:quill_diary/application/session/session_route_snapshot.dart';
import 'package:quill_diary/application/session/state/app_session_state.dart';
import 'package:quill_diary/application/editor/editor_draft_providers.dart';
import 'package:quill_diary/application/home/home_entry_query_providers.dart';
import 'package:quill_diary/application/settings/settings_providers.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/infrastructure/database/database_providers.dart';
import 'package:quill_diary/infrastructure/storage/storage_providers.dart';

import 'restore_prepared_context.dart';

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

  AppSessionState sessionState = const AppSessionState(
    status: AppLockStatus.uninitialized,
  );
  final bool resumeTrustedSessionAfterRestore = prepared.precheck
      .canResumeTrustedSession(livePriorSession);
  try {
    sessionState = await _startupRestoredSession(
      ref,
      prepared: prepared,
      livePriorSession: livePriorSession,
    );
    if (sessionState.isUnlocked && sessionState.session != null) {
      final bool usedRecoveryKey =
          prepared.backupRecoveryKey?.trim().isNotEmpty == true;
      if (!usedRecoveryKey && !resumeTrustedSessionAfterRestore) {
        await ref
            .read(vaultRepositoryProvider)
            .rebuildIndex(sessionState.session!);
      }
    }
    return sessionState;
  } finally {
    ref.read(sessionRouteSnapshotProvider.notifier).clear();
    ref.read(appSessionProvider.notifier).endTrustedUnlockBootstrap();
    if (sessionState.isUnlocked && sessionState.session != null) {
      refreshEntryIndexCaches(ref);
    }
    ref.invalidate(sessionStartupProvider);
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
    // unlockWithRecovery 失敗時會自行更新 session 狀態。
  }
  return ref.read(appSessionProvider);
}
