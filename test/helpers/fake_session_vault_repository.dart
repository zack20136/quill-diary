import 'package:quill_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/infrastructure/database/index_database_manager.dart';
import 'package:quill_diary/infrastructure/markdown/front_matter_codec.dart';
import 'package:quill_diary/infrastructure/security/app_lock_service.dart';
import 'package:quill_diary/infrastructure/security/app_unlock_mode.dart';
import 'package:quill_diary/infrastructure/security/device_key_manager.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';

import 'stub_crypto_service.dart';
import 'test_vault_path_strategy.dart';

/// Session / restore 流程用的 VaultRepository 測試替身。
class FakeSessionVaultRepository extends VaultRepository {
  FakeSessionVaultRepository({
    this.metadata,
    this.hasTrustedDevice = false,
    this.openTrustedSessionResult,
    List<Object?>? openTrustedSessionResults,
    this.resumeUnlockedSessionAfterRestoreResult,
    this.initializeError,
    this.unlockWithRecoveryKeyResult,
  }) : super(
         pathStrategy: DummyVaultPathStrategy(),
         frontMatterCodec: const FrontMatterCodec(),
         cryptoService: StubCryptoService(),
         indexDatabaseManager: IndexDatabaseManager(DummyVaultPathStrategy()),
         deviceKeyManager: const UnsupportedDeviceKeyManager(),
         appLockService: const UnsupportedAppLockService(),
       ) {
    if (openTrustedSessionResults != null) {
      _openTrustedSessionResults = List<Object?>.of(openTrustedSessionResults);
    }
  }

  final RecoveryMetadata? metadata;
  final bool hasTrustedDevice;
  final Object? openTrustedSessionResult;
  final Object? resumeUnlockedSessionAfterRestoreResult;
  final Object? initializeError;
  final Object? unlockWithRecoveryKeyResult;

  int clearTrustedDeviceAccessCalls = 0;
  int closeUnlockedResourcesCalls = 0;
  int ensureIndexReadyCalls = 0;
  int hasTrustedDeviceAccessCalls = 0;
  int openTrustedSessionCalls = 0;
  int resumeUnlockedSessionAfterRestoreCalls = 0;
  List<Object?>? _openTrustedSessionResults;
  Duration openTrustedSessionDelay = Duration.zero;

  @override
  Future<void> initialize() async {
    if (initializeError != null) {
      throw initializeError!;
    }
  }

  @override
  Future<RecoveryMetadata?> readRecoveryMetadata() async => metadata;

  @override
  Future<bool> hasTrustedDeviceAccess() async {
    hasTrustedDeviceAccessCalls++;
    return hasTrustedDevice;
  }

  @override
  Future<UnlockedVaultSession> openTrustedSession() async {
    if (openTrustedSessionDelay > Duration.zero) {
      await Future<void>.delayed(openTrustedSessionDelay);
    }
    openTrustedSessionCalls++;
    final Object? result;
    final List<Object?>? queuedResults = _openTrustedSessionResults;
    if (queuedResults != null && queuedResults.isNotEmpty) {
      result = queuedResults.removeAt(0);
    } else {
      result = openTrustedSessionResult;
    }
    if (result == null) {
      throw StateError('openTrustedSessionResult not configured');
    }
    if (result is UnlockedVaultSession) {
      return result;
    }
    throw result;
  }

  @override
  Future<UnlockedVaultSession> resumeUnlockedSessionAfterRestore(
    UnlockedVaultSession priorSession,
  ) async {
    resumeUnlockedSessionAfterRestoreCalls++;
    final Object? configured = resumeUnlockedSessionAfterRestoreResult;
    if (configured != null) {
      if (configured is UnlockedVaultSession) {
        return configured;
      }
      throw configured;
    }
    return priorSession;
  }

  @override
  Future<UnlockedVaultSession> unlockWithRecoveryKey(String recoveryKey) async {
    final Object? result = unlockWithRecoveryKeyResult;
    if (result == null) {
      throw StateError('unlockWithRecoveryKeyResult not configured');
    }
    if (result is UnlockedVaultSession) {
      return result;
    }
    throw result;
  }

  @override
  Future<void> ensureIndexReady(UnlockedVaultSession session) async {
    ensureIndexReadyCalls++;
  }

  @override
  Future<void> closeUnlockedResources() async {
    closeUnlockedResourcesCalls++;
  }

  @override
  Future<void> clearTrustedDeviceAccess() async {
    clearTrustedDeviceAccessCalls++;
  }

  @override
  Future<bool> needsKeystoreMigration(UnlockedVaultSession session) async =>
      false;

  @override
  Future<bool> needsKeystoreMigrationForVault() async => false;

  @override
  Future<UnlockedVaultSession> openTrustedSessionEnsuringKeystore() async {
    final UnlockedVaultSession session = await openTrustedSession();
    await ensureIndexReady(session);
    return session;
  }

  @override
  Future<UnlockedVaultSession> ensureKeystoreMatchesUnlockMode(
    UnlockedVaultSession session, {
    AppUnlockMode? targetMode,
  }) async {
    return session;
  }
}
