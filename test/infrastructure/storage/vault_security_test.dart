import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/diary/diary_entry.dart';
import 'package:quill_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/crypto/crypto_service.dart';
import 'package:quill_diary/infrastructure/security/device_key_manager.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';
import 'package:quill_diary/infrastructure/storage/vault_state_keys.dart';

import '../../helpers/vault/fake_device_key_manager.dart';
import '../../helpers/vault/manifest_write_test_crypto_service.dart';
import '../../helpers/vault/vault_test_harness.dart';

void main() {
  late VaultTestHarness harness;

  setUp(() async {
    harness = await VaultTestHarness.create();
  });

  tearDown(() async {
    await harness.dispose();
  });

  for (final corruptInfo in [false, true]) {
    test('裝置${corruptInfo ? '槽位資訊' : '包裝記錄'}損壞仍可用正確復原金鑰重建且保留日記', () async {
      final setup = await harness.repository.setupRecoveryKey();
      final entryId = await harness.saveSimpleEntry(
        setup,
        markdownBody: '保留的正式日記',
      );
      harness.deviceKeyManager.rejectStoredRecord = !corruptInfo;
      harness.deviceKeyManager.rejectStoredDeviceInfo = corruptInfo;
      await expectLater(
        harness.repository.openTrustedSession(),
        throwsA(isA<DeviceKeyUnsupportedFormatException>()),
      );
      final recovered = await harness.repository.unlockWithRecoveryKey(
        setup.recoveryKey,
      );
      expect(
        (await harness.repository.loadEntry(recovered, entryId))!.markdownBody,
        '保留的正式日記',
      );
      expect(harness.deviceKeyManager.rejectStoredRecord, isFalse);
      expect(harness.deviceKeyManager.rejectStoredDeviceInfo, isFalse);
    });
  }

  test('錯誤 session 金鑰的新輪替不寫 pending 或進行中旗標', () async {
    final setup = await harness.repository.setupRecoveryKey();
    final before = (await harness.repository.readRecoveryMetadata())!.toJson();
    await expectLater(
      harness.repository.rotateRecoveryKey(
        setup.session.copyWith(recoveryWrapKey: List.filled(32, 0)),
      ),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
    expect(
      File(await harness.pathStrategy.recoveryRotationPendingPath())
          .existsSync(),
      isFalse,
    );
    expect(
      await harness.indexDatabaseManager.requireOpen().getAppValue(
        kRewrapInProgressKey,
      ),
      isNot('true'),
    );
    expect((await harness.repository.readRecoveryMetadata())!.toJson(), before);
  });

  for (final invalid in ['identity', 'contentType', 'vault']) {
    test('輪替 pending 的 $invalid 不符時保留現場，不當作 stale 清除', () async {
      final setup = await harness.repository.setupRecoveryKey();
      final metadata = (await harness.repository.readRecoveryMetadata())!;
      final crypto = LocalCryptoService();
      final encrypted = await crypto.encryptBytes(
        documentId: invalid == 'identity'
            ? 'other'
            : 'recovery_rotation_pending',
        vaultId: invalid == 'vault' ? generateVaultId() : metadata.vaultId,
        plaintextBytes: utf8.encode(
          jsonEncode({
            'old_metadata': metadata.toJson(),
            'new_metadata': metadata.toJson(),
            'new_recovery_key': setup.recoveryKey,
          }),
        ),
        contentType: invalid == 'contentType'
            ? 'application/json'
            : 'application/vnd.quill-diary.recovery-rotation',
        recoveryWrapKey: setup.session.recoveryWrapKey!,
        recoverySlotKdf: metadata.kdf,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final file = File(
        await harness.pathStrategy.recoveryRotationPendingPath(),
      );
      final bytes = encrypted.toFileBytes();
      await file.writeAsBytes(bytes);
      await expectLater(
        harness.repository.unlockWithRecoveryKey(setup.recoveryKey),
        throwsFormatException,
      );
      expect(await file.readAsBytes(), bytes);
      expect(
        (await harness.repository.readRecoveryMetadata())!.toJson(),
        metadata.toJson(),
      );
      expect(
        await harness.indexDatabaseManager.requireOpen().getAppValue(
          kRewrapInProgressKey,
        ),
        isNot('true'),
      );
    });
  }

  group('setupRecoveryKey', () {
    test('會寫入 metadata 並建立 trusted device', () async {
      final RecoverySetupResult setup = await harness.repository
          .setupRecoveryKey();

      final metadata = await harness.repository.readRecoveryMetadata();
      expect(metadata, isNotNull);
      expect(metadata!.vaultId, setup.session.vaultId);
      expect(metadata.recoveryKeyVersion, 1);
      expect(metadata.recoveryEnabled, isTrue);
      expect(
        setup.recoveryKey,
        matches(RegExp(r'^[A-Z0-9]{4}(-[A-Z0-9]{4}){5}$')),
      );
      expect(await harness.repository.hasTrustedDeviceAccess(), isTrue);
      expect(
        await harness.deviceKeyManager.hasTrustedKey(setup.session.vaultId),
        isTrue,
      );
    });

    test('重複設定會被拒絕', () async {
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
  });

  group('openTrustedSession', () {
    test('關閉資源後仍可還原 trusted session', () async {
      final RecoverySetupResult setup = await harness.repository
          .setupRecoveryKey();
      final String vaultId = setup.session.vaultId;

      await harness.repository.closeUnlockedResources();
      final session = await harness.repository.openTrustedSession();

      expect(session.vaultId, vaultId);
      expect(session.trustedDevice, isTrue);
      expect(session.recoveryWrapKey, isNotNull);
      expect(session.deviceSlotId, contains(vaultId));
    });
  });

  group('clearTrustedDeviceAccess', () {
    test('清除後無法再開啟 trusted session', () async {
      final RecoverySetupResult setup = await harness.repository
          .setupRecoveryKey();
      await harness.repository.clearTrustedDeviceAccess();

      expect(await harness.repository.hasTrustedDeviceAccess(), isFalse);
      expect(
        () => harness.repository.openTrustedSession(),
        throwsA(
          isA<TrustedSessionException>().having(
            (TrustedSessionException error) => error.failure,
            'failure',
            TrustedSessionFailure.deviceNotRegistered,
          ),
        ),
      );

      final WrappedRecoveryKeyRecord? record = await harness.deviceKeyManager
          .readWrappedRecoveryKey(setup.session.vaultId);
      expect(record, isNull);
    });
  });

  group('unlockWithRecoveryKey', () {
    test('錯誤的復原金鑰無法解鎖', () async {
      final RecoverySetupResult setup = await harness.repository
          .setupRecoveryKey();
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
        () => harness.repository.unlockWithRecoveryKey(
          'WRON-KEY1-WRON-KEY2-WRON-KEY3',
        ),
        throwsA(
          predicate<Object>(
            (Object error) =>
                error is SecretBoxAuthenticationError ||
                (error is StateError && error.toString().contains('復原金鑰')),
          ),
        ),
      );
    });

    test('正確金鑰可在清除 trusted 後重新解鎖', () async {
      final RecoverySetupResult setup = await harness.repository
          .setupRecoveryKey();
      await harness.repository.clearTrustedDeviceAccess();
      expect(await harness.repository.hasTrustedDeviceAccess(), isFalse);

      final session = await harness.repository.unlockWithRecoveryKey(
        setup.recoveryKey,
      );

      expect(session.vaultId, setup.session.vaultId);
      expect(await harness.repository.hasTrustedDeviceAccess(), isTrue);
      await harness.repository.closeUnlockedResources();
      final restored = await harness.repository.openTrustedSession();
      expect(restored.vaultId, setup.session.vaultId);
    });
  });

  group('rotateRecoveryKey', () {
    test('會產生新金鑰並更新 metadata，trusted 仍可解鎖', () async {
      final RecoverySetupResult setup = await harness.repository
          .setupRecoveryKey();
      final String oldKey = setup.recoveryKey;
      final UnlockedVaultSession session = setup.session;

      await harness.repository.saveEntry(
        session,
        DiaryEntry(
          id: generateEntryId(),
          vaultId: session.vaultId,
          title: '輪替前',
          date: const DateOnly('2026-05-15'),
          createdAt: DateTime.parse('2026-05-15T08:00:00Z'),
          updatedAt: DateTime.parse('2026-05-15T08:00:00Z'),
          markdownBody: 'before rotate body',
        ),
      );

      final RecoverySetupResult rotated = await harness.repository
          .rotateRecoveryKey(session);
      expect(rotated.recoveryKey, isNot(equals(oldKey)));

      final RecoveryMetadata? metadata = await harness.repository
          .readRecoveryMetadata();
      expect(
        metadata?.recoveryKeyHint,
        rotated.recoveryKey.substring(rotated.recoveryKey.length - 4),
      );
      expect(
        rotated.session.recoveryWrapKey,
        isNot(setup.session.recoveryWrapKey),
      );
    });

    test('中斷後會回復至原 Recovery Key 並保留日記', () async {
      await harness.dispose();
      final crypto = ManifestWriteTestCryptoService();
      harness = await VaultTestHarness.create(cryptoService: crypto);
      final RecoverySetupResult setup = await harness.repository
          .setupRecoveryKey();
      final String entryId = await harness.saveSimpleEntry(
        setup,
        title: '輪替中斷',
      );

      crypto.failRotationAfterEncryptedFiles = 1;
      await expectLater(
        harness.repository.rotateRecoveryKey(setup.session),
        throwsStateError,
      );

      crypto.failRotationAfterEncryptedFiles = null;
      await expectLater(
        harness.repository.unlockWithRecoveryKey(
          'WRON-KEY1-WRON-KEY2-WRON-KEY3',
        ),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
      await harness.repository.closeUnlockedResources();
      final UnlockedVaultSession recovered = await harness.repository
          .openTrustedSession();

      expect(
        (await harness.repository.loadEntry(recovered, entryId))?.title,
        '輪替中斷',
      );
      expect(
        (await harness.repository.readRecoveryMetadata())?.recoveryKeyHint,
        setup.recoveryKey.substring(setup.recoveryKey.length - 4),
      );
    });

    test('metadata 已更新但裝置金鑰寫入失敗時會回復原 Recovery Key', () async {
      await harness.dispose();
      final deviceKeyManager = CancellingDeviceKeyManager();
      harness = await VaultTestHarness.create(
        deviceKeyManager: deviceKeyManager,
      );
      final RecoverySetupResult setup = await harness.repository
          .setupRecoveryKey();
      final String entryId = await harness.saveSimpleEntry(
        setup,
        title: 'metadata 已切換',
      );

      deviceKeyManager.cancelWrap = true;
      await expectLater(
        harness.repository.rotateRecoveryKey(setup.session),
        throwsStateError,
      );

      deviceKeyManager.cancelWrap = false;
      await expectLater(
        harness.repository.unlockWithRecoveryKey(
          'WRON-KEY1-WRON-KEY2-WRON-KEY3',
        ),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
      await harness.repository.closeUnlockedResources();
      final UnlockedVaultSession recovered = await harness.repository
          .openTrustedSession();

      expect(
        (await harness.repository.loadEntry(recovered, entryId))?.title,
        'metadata 已切換',
      );
      expect(
        (await harness.repository.readRecoveryMetadata())?.recoveryKeyHint,
        setup.recoveryKey.substring(setup.recoveryKey.length - 4),
      );
    });
  });
}
