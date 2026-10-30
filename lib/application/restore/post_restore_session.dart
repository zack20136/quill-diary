import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_diary/application/diary/diary_entry_providers.dart';
import 'package:quill_diary/application/editor/editor_draft_providers.dart';
import 'package:quill_diary/application/people/people_providers.dart';
import 'package:quill_diary/application/restore/restore_backup_flow.dart';
import 'package:quill_diary/application/session/session_providers.dart';
import 'package:quill_diary/application/session/session_route_snapshot.dart';
import 'package:quill_diary/application/session/session_state.dart';
import 'package:quill_diary/application/settings/settings_providers.dart';
import 'package:quill_diary/application/transfer/vault_backup_providers.dart';
import 'package:quill_diary/application/vault/vault_providers.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';

Future<AppSessionState> finishRestoreSession(
  Ref ref, {
  required RestorePreparedContext prepared,
  UnlockedVaultSession? livePriorSession,
}) async {
  await ref.read(appSessionProvider.notifier).beginPostRestoreStartup();
  ref.invalidate(vaultBackupIoProvider);
  ref.invalidate(portableExportIoProvider);
  ref.invalidate(portableImportIoProvider);
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
      ref.read(diaryRevisionProvider.notifier).bump();
      ref.invalidate(peopleCatalogProvider);
    }
    ref.invalidate(sessionStartupProvider);
    ref.invalidate(effectiveAppSessionProvider);
  }
}

Future<AppSessionState> _startupRestoredSession(
  Ref ref, {
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
  Ref ref,
  String recoveryKey,
) async {
  try {
    await ref.read(appSessionProvider.notifier).unlockWithRecovery(recoveryKey);
  } catch (_) {
    // unlockWithRecovery 失敗時會自行更新 session 狀態。
  }
  return ref.read(appSessionProvider);
}
