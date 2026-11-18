import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/application/session/app_session_controller.dart';
import 'package:quill_diary/application/session/session_providers.dart';
import 'package:quill_diary/application/session/session_state.dart';
import 'package:quill_diary/application/settings/settings_providers.dart';
import 'package:quill_diary/application/vault/vault_providers.dart';
import 'package:quill_diary/domain/recovery/kdf_descriptor.dart';
import 'package:quill_diary/domain/recovery/recovery_key_identity.dart';
import 'package:quill_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/infrastructure/storage/backup_status_store.dart';

import '../../helpers/session/fake_session_vault_repository.dart';

class _BackupSession extends AppSessionController {
  @override
  AppSessionState build() =>
      const AppSessionState(status: AppLockStatus.locked);

  void setSession(UnlockedVaultSession session) {
    state = AppSessionState(status: AppLockStatus.unlocked, session: session);
  }
}

class _BackupRepository extends FakeSessionVaultRepository {
  _BackupRepository(RecoveryMetadata metadata) : super(metadata: metadata);

  Completer<void>? mutationQueued;

  @override
  Future<T> runVaultMutation<T>(Future<T> Function() operation) {
    final queued = mutationQueued;
    mutationQueued = null;
    queued?.complete();
    return super.runVaultMutation(operation);
  }
}

void main() {
  test('輪替提醒僅在已解鎖時對帳，備份完成後刷新為已備份', () async {
    final directory = await Directory.systemTemp.createTemp('backup_provider_');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/backup_status.json');
    final store = BackupStatusStore(storageFile: file);
    final metadata = RecoveryMetadata(
      vaultId: 'vault',
      recoveryEnabled: true,
      recoveryKeyVersion: 1,
      recoveryKeyHint: '0123',
      createdAt: DateTime.utc(2026),
      kdf: KdfDescriptor.argon2idRecovery(saltBytes: List.filled(16, 4)),
    );
    final active = await RecoveryKeyIdentity.fromMetadata(metadata);
    final previous = RecoveryKeyIdentity(
      vaultId: 'vault',
      kdfFingerprint: 'a' * 64,
    );
    await store.setBackupRequirement(previous);
    await store.beginRecoveryRotation(previous, active);
    final beforeUnlock = await file.readAsString();
    final repository = _BackupRepository(metadata);
    final container = ProviderContainer(
      overrides: [
        appSessionProvider.overrideWith(_BackupSession.new),
        backupStatusStoreProvider.overrideWithValue(store),
        vaultRepositoryProvider.overrideWithValue(repository),
        recoveryMetadataProvider.overrideWithValue(AsyncData(metadata)),
      ],
    );
    addTearDown(container.dispose);
    expect(
      (await container.read(backupStatusProvider.future))
          .requiredBackupIdentity,
      previous,
    );
    expect(await file.readAsString(), beforeUnlock);
    final release = Completer<void>();
    addTearDown(() {
      if (!release.isCompleted) release.complete();
    });
    final started = Completer<void>();
    final mutation = repository.runVaultMutation(() async {
      started.complete();
      await release.future;
    });
    await started.future;
    final queued = repository.mutationQueued = Completer<void>();
    (container.read(appSessionProvider.notifier) as _BackupSession).setSession(
      const UnlockedVaultSession(vaultId: 'vault', trustedDevice: true),
    );
    final requirement = container.read(recoveryBackupRequiredProvider.future);
    await queued.future.timeout(const Duration(seconds: 5));
    expect(await file.readAsString(), beforeUnlock);
    release.complete();
    await mutation;
    expect(await requirement, isTrue);
    expect((await store.read()).requiredBackupIdentity, active);
    await store.recordExternalExportSuccess(
      identity: active,
      purpose: VaultBackupPurpose.normal,
    );
    container.invalidate(backupStatusProvider);
    expect(
      await container.read(recoveryBackupRequiredProvider.future),
      isFalse,
    );
  });
}
