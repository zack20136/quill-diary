import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_lock_diary/domain/diary/diary_entry.dart';
import 'package:quill_lock_diary/domain/shared/value_objects.dart';
import 'package:quill_lock_diary/infrastructure/security/device_key_manager.dart';
import 'package:quill_lock_diary/infrastructure/storage/vault_repository.dart';

import '../helpers/vault_test_harness.dart';

void main() {
  late VaultTestHarness harness;

  setUp(() async {
    harness = await VaultTestHarness.create();
  });

  tearDown(() async {
    await harness.dispose();
  });

  test('setupRecoveryKey 會寫入 metadata 並建立 trusted device', () async {
    final RecoverySetupResult setup = await harness.repository.setupRecoveryKey();

    final metadata = await harness.repository.readRecoveryMetadata();
    expect(metadata, isNotNull);
    expect(metadata!.vaultId, setup.session.vaultId);
    expect(metadata.recoveryKeyVersion, 2);
    expect(metadata.recoveryEnabled, isTrue);
    expect(setup.recoveryKey, matches(RegExp(r'^[A-Z0-9]{4}(-[A-Z0-9]{4}){5}$')));
    expect(await harness.repository.hasTrustedDeviceAccess(), isTrue);
    expect(await harness.deviceKeyManager.hasTrustedKey(setup.session.vaultId), isTrue);
  });

  test('重複 setupRecoveryKey 會拒絕', () async {
    await harness.repository.setupRecoveryKey();

    expect(
      () => harness.repository.setupRecoveryKey(),
      throwsA(
        predicate<Object>(
          (Object error) =>
              error is StateError && error.message.contains('復原金鑰已存在'),
        ),
      ),
    );
  });

  test('openTrustedSession 可在關閉資源後還原 trusted session', () async {
    final RecoverySetupResult setup = await harness.repository.setupRecoveryKey();
    final String vaultId = setup.session.vaultId;

    await harness.repository.closeUnlockedResources();
    final session = await harness.repository.openTrustedSession();

    expect(session.vaultId, vaultId);
    expect(session.trustedDevice, isTrue);
    expect(session.recoveryWrapKey, isNotNull);
    expect(session.deviceSlotId, contains(vaultId));
  });

  test('clearTrustedDeviceAccess 後無法 openTrustedSession', () async {
    final RecoverySetupResult setup = await harness.repository.setupRecoveryKey();
    await harness.repository.clearTrustedDeviceAccess();

    expect(await harness.repository.hasTrustedDeviceAccess(), isFalse);
    expect(
      () => harness.repository.openTrustedSession(),
      throwsA(
        predicate<Object>(
          (Object error) => error is StateError && error.message.contains('尚未註冊'),
        ),
      ),
    );

    final WrappedRecoveryKeyRecord? record =
        await harness.deviceKeyManager.readWrappedRecoveryKey(setup.session.vaultId);
    expect(record, isNull);
  });

  test('錯誤的 Recovery Key 無法 unlockWithRecoveryKey', () async {
    final RecoverySetupResult setup = await harness.repository.setupRecoveryKey();
    final session = setup.session;

    await harness.repository.saveEntry(
      session,
      DiaryEntry(
        id: generateEntryId(),
        vaultId: session.vaultId,
        title: '驗證用',
        date: const DateOnly('2026-05-15'),
        createdAt: DateTime.parse('2026-05-15T08:00:00Z'),
        updatedAt: DateTime.parse('2026-05-15T08:00:00Z'),
        markdownBody: 'vault security verify body',
      ),
    );
    await harness.repository.closeUnlockedResources();

    expect(
      () => harness.repository.unlockWithRecoveryKey('WRON-KEY1-WRON-KEY2-WRON-KEY3'),
      throwsA(
        predicate<Object>(
          (Object error) =>
              error is SecretBoxAuthenticationError ||
              (error is StateError && error.toString().contains('復原金鑰')),
        ),
      ),
    );
  });

  test('正確的 Recovery Key 可在清除 trusted 後重新 unlock', () async {
    final RecoverySetupResult setup = await harness.repository.setupRecoveryKey();
    await harness.repository.clearTrustedDeviceAccess();
    expect(await harness.repository.hasTrustedDeviceAccess(), isFalse);

    final session = await harness.repository.unlockWithRecoveryKey(setup.recoveryKey);

    expect(session.vaultId, setup.session.vaultId);
    expect(await harness.repository.hasTrustedDeviceAccess(), isTrue);
    await harness.repository.closeUnlockedResources();
    final restored = await harness.repository.openTrustedSession();
    expect(restored.vaultId, setup.session.vaultId);
  });
}
