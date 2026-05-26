import 'package:quill_lock_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_lock_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_lock_diary/domain/shared/value_objects.dart';
import 'package:quill_lock_diary/infrastructure/database/index_database.dart';
import 'package:quill_lock_diary/infrastructure/database/index_database_manager.dart';
import 'package:quill_lock_diary/infrastructure/markdown/front_matter_codec.dart';
import 'package:quill_lock_diary/infrastructure/security/app_lock_service.dart';
import 'package:quill_lock_diary/infrastructure/security/device_key_manager.dart';
import 'package:quill_lock_diary/infrastructure/storage/vault_repository.dart';

import 'stub_crypto_service.dart';
import 'test_vault_path_strategy.dart';

class FakeVaultRepository extends VaultRepository {
  FakeVaultRepository({
    this.metadata,
    this.hasTrustedDevice = false,
    this.openTrustedSessionResult,
    this.initializeError,
    this.unlockWithRecoveryKeyResult,
    this.entryIndexRecords = const <EntryIndexRecord>[],
  }) : super(
          pathStrategy: DummyVaultPathStrategy(),
          frontMatterCodec: const FrontMatterCodec(),
          cryptoService: StubCryptoService(),
          indexDatabaseManager: IndexDatabaseManager(DummyVaultPathStrategy()),
          deviceKeyManager: const UnsupportedDeviceKeyManager(),
          appLockService: const UnsupportedAppLockService(),
        );

  final RecoveryMetadata? metadata;
  final bool hasTrustedDevice;
  final Object? openTrustedSessionResult;
  final Object? initializeError;
  final Object? unlockWithRecoveryKeyResult;
  final List<EntryIndexRecord> entryIndexRecords;

  int clearTrustedDeviceAccessCalls = 0;
  int closeUnlockedResourcesCalls = 0;
  int ensureIndexReadyCalls = 0;
  int listEntriesCalls = 0;
  int openTrustedSessionCalls = 0;
  final List<String?> listEntriesSearchQueries = <String?>[];
  final List<DateOnly?> listEntriesDates = <DateOnly?>[];

  @override
  Future<void> initialize() async {
    if (initializeError != null) {
      throw initializeError!;
    }
  }

  @override
  Future<RecoveryMetadata?> readRecoveryMetadata() async => metadata;

  @override
  Future<bool> hasTrustedDeviceAccess() async => hasTrustedDevice;

  @override
  Future<UnlockedVaultSession> openTrustedSession() async {
    openTrustedSessionCalls++;
    final Object? result = openTrustedSessionResult;
    if (result == null) {
      throw StateError('openTrustedSessionResult not configured');
    }
    if (result is UnlockedVaultSession) {
      return result;
    }
    throw result;
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
  Future<List<EntryIndexRecord>> listEntries({
    String? searchQuery,
    DateOnly? date,
    bool includeDeleted = false,
  }) async {
    listEntriesCalls++;
    listEntriesSearchQueries.add(searchQuery);
    listEntriesDates.add(date);
    Iterable<EntryIndexRecord> results = entryIndexRecords;
    if (!includeDeleted) {
      results = results.where((EntryIndexRecord entry) => !entry.isDeleted);
    }
    if (date != null) {
      results = results.where(
        (EntryIndexRecord entry) => entry.date.value == date.value,
      );
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final String normalized = normalizeText(searchQuery);
      results = results.where((EntryIndexRecord entry) {
        return normalizeText(entry.title ?? '').contains(normalized) ||
            normalizeText(entry.previewText).contains(normalized) ||
            entry.tags.any(
              (String tag) => normalizeText(tag).contains(normalized),
            );
      });
    }
    return results.toList();
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
  Future<UnlockedVaultSession> ensureKeystoreMatchesUnlockMode(
    UnlockedVaultSession session,
  ) async {
    return session;
  }
}
