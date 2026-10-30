import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:quill_diary/domain/attachment/asset_attachment.dart';
import 'package:quill_diary/domain/diary/diary_entry.dart';
import 'package:quill_diary/domain/diary/diary_entry_summary.dart';
import 'package:quill_diary/domain/people/person.dart';
import 'package:quill_diary/domain/people/relationship_type.dart';
import 'package:quill_diary/domain/recovery/kdf_descriptor.dart';
import 'package:quill_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/domain/tag/tag.dart';
import 'package:quill_diary/infrastructure/crypto/crypto_service.dart';
import 'package:quill_diary/infrastructure/database/index_database.dart';
import 'package:quill_diary/infrastructure/database/index_database_manager.dart';
import 'package:quill_diary/infrastructure/markdown/front_matter_codec.dart';
import 'package:quill_diary/infrastructure/markdown/visible_text_from_markdown.dart';
import 'package:quill_diary/infrastructure/security/app_lock_service.dart';
import 'package:quill_diary/infrastructure/security/app_unlock_mode.dart';
import 'package:quill_diary/infrastructure/security/device_key_manager.dart';
import 'package:quill_diary/infrastructure/security/keystore_unlock_policy.dart';
import 'package:quill_diary/infrastructure/security/unlock_mode_policy.dart';
import 'package:quill_diary/infrastructure/storage/pinned_entries_store.dart';
import 'package:quill_diary/infrastructure/storage/portable/backup_archive_inspection.dart';
import 'package:quill_diary/infrastructure/storage/shared/media_type_utils.dart';
import 'package:quill_diary/infrastructure/storage/shared/vault_file_ops.dart';
import 'package:quill_diary/infrastructure/storage/tag_styles_store.dart';
import 'package:quill_diary/infrastructure/storage/vault_maintenance_models.dart';
import 'package:quill_diary/infrastructure/storage/vault_path_strategy.dart';
import 'package:quill_diary/infrastructure/storage/vault_people_service.dart';
import 'package:quill_diary/infrastructure/storage/vault_repair_file_operations.dart';
import 'package:quill_diary/infrastructure/storage/vault_repair_service.dart';
import 'package:quill_diary/infrastructure/storage/vault_salvage_models.dart';
import 'package:quill_diary/infrastructure/storage/vault_state_keys.dart';
import 'package:quill_diary/shared/data_versions.dart';

/// 同流程建立新 Recovery Key 並完成可信裝置存取時回傳的結果。
class RecoverySetupResult {
  const RecoverySetupResult({required this.recoveryKey, required this.session});

  final String recoveryKey;
  final UnlockedVaultSession session;
}

enum TrustedSessionFailure {
  recoveryKeyMissing,
  deviceNotRegistered,
  dataUnusable,
}

class TrustedSessionException implements Exception {
  const TrustedSessionException(this.failure);

  final TrustedSessionFailure failure;
}

class VaultRepository {
  VaultRepository({
    required this._pathStrategy,
    required this._frontMatterCodec,
    required this._cryptoService,
    required this._indexDatabaseManager,
    required this._deviceKeyManager,
    required this._appLockService,
    this._repairFileOperations = const VaultRepairFileOperations(),
  });

  final VaultPathStrategy _pathStrategy;
  final FrontMatterCodec _frontMatterCodec;
  final CryptoService _cryptoService;
  final IndexDatabaseManager _indexDatabaseManager;
  final DeviceKeyManager _deviceKeyManager;
  final AppLockService _appLockService;
  final VaultRepairFileOperations _repairFileOperations;

  late final VaultPeopleService _people = VaultPeopleService(
    pathStrategy: _pathStrategy,
    cryptoService: _cryptoService,
    indexDatabaseManager: _indexDatabaseManager,
    requireMetadataForSession: _requireMetadataForSession,
  );
  late final VaultRepairService _repair = VaultRepairService(
    pathStrategy: _pathStrategy,
    cryptoService: _cryptoService,
    frontMatterCodec: _frontMatterCodec,
    indexDatabaseManager: _indexDatabaseManager,
    people: _people,
    requireMetadataForSession: _requireMetadataForSession,
    writeManifest: _writeEncryptedManifest,
    copyChatFiles: _copyChatFilesBesideEntry,
    repairFileOperations: _repairFileOperations,
  );

  Future<void> _mutationTail = Future<void>.value();

  RecoveryMetadata? _cachedRecoveryMetadata;

  Stream<PeopleAnalyticsProgress> get peopleAnalyticsProgress =>
      _people.peopleAnalyticsProgress;

  @visibleForTesting
  PeopleAnalyticsDebugMetrics get peopleAnalyticsDebugMetrics =>
      _people.peopleAnalyticsDebugMetrics;

  Future<void> initialize() async {
    await _pathStrategy.ensureBaseDirectories();
    _cachedRecoveryMetadata = await readRecoveryMetadata();
  }

  Future<bool> hasTrustedDeviceAccess() async {
    final RecoveryMetadata? metadata = await readRecoveryMetadata();
    if (metadata == null) {
      return false;
    }
    return _deviceKeyManager.hasTrustedKey(metadata.vaultId);
  }

  Future<bool> hasVault() async {
    return await readRecoveryMetadata() != null;
  }

  Future<UnlockedVaultSession> openTrustedSession() async {
    final RecoveryMetadata metadata =
        await readRecoveryMetadata() ??
        (throw const TrustedSessionException(
          TrustedSessionFailure.recoveryKeyMissing,
        ));
    if (!await _deviceKeyManager.hasTrustedKey(metadata.vaultId)) {
      throw const TrustedSessionException(
        TrustedSessionFailure.deviceNotRegistered,
      );
    }

    final WrappedRecoveryKeyRecord record =
        await _deviceKeyManager.readWrappedRecoveryKey(metadata.vaultId) ??
        (throw const TrustedSessionException(
          TrustedSessionFailure.dataUnusable,
        ));
    final TrustedDeviceInfo deviceInfo =
        await _deviceKeyManager.readDeviceInfo(metadata.vaultId) ??
        (throw const TrustedSessionException(
          TrustedSessionFailure.dataUnusable,
        ));
    if (record.slotId != deviceInfo.slotId) {
      await _deviceKeyManager.clearTrustedKey(metadata.vaultId);
      throw const TrustedSessionException(TrustedSessionFailure.dataUnusable);
    }

    final List<int> recoveryWrapKey;
    try {
      recoveryWrapKey = await _deviceKeyManager.unwrapWithDeviceKey(
        vaultId: metadata.vaultId,
        slotId: record.slotId,
        nonceBase64: record.nonceBase64,
        ciphertextBase64: record.ciphertextBase64,
      );
    } on DeviceKeyException {
      rethrow;
    } on Object catch (_, stackTrace) {
      await _deviceKeyManager.clearTrustedKey(metadata.vaultId);
      Error.throwWithStackTrace(
        const TrustedSessionException(TrustedSessionFailure.dataUnusable),
        stackTrace,
      );
    }

    await _verifyRecoveryKey(metadata, recoveryWrapKey);

    return _openVerifiedTrustedSession(
      metadata: metadata,
      recoveryWrapKey: recoveryWrapKey,
      trustedDevice: true,
      deviceSlotId: deviceInfo.slotId,
    );
  }

  /// 在 unwrap 前比對 Keystore 與解鎖模式是否一致（不需 [UnlockedVaultSession]）。
  Future<bool> needsKeystoreMigrationForVault() async {
    final RecoveryMetadata? metadata = await readRecoveryMetadata();
    if (metadata == null) {
      return false;
    }
    final WrappedRecoveryKeyRecord? wrappedRecord = await _deviceKeyManager
        .readWrappedRecoveryKey(metadata.vaultId);
    if (wrappedRecord == null) {
      return true;
    }
    final KeystoreAuthKind expected = await _requireCurrentKeystoreAuthKind();
    final UnlockedVaultSession probe = UnlockedVaultSession(
      vaultId: metadata.vaultId,
      trustedDevice: true,
      recoveryWrapKey: const <int>[],
      deviceSlotId: wrappedRecord.slotId,
    );
    String? syncedSuffix;
    try {
      syncedSuffix = await _requireOpenIndex().getAppValue(
        kKeystoreWrapModeKey,
      );
    } on StateError {
      return !keystoreSlotsMatchExpected(
        session: probe,
        expected: expected,
        wrappedRecord: wrappedRecord,
      );
    }
    return !trustedProtectionMatches(
      session: probe,
      expected: expected,
      syncedSuffix: syncedSuffix,
      wrappedRecord: wrappedRecord,
    );
  }

  /// 可信裝置解鎖並同步 Keystore、準備索引。
  Future<UnlockedVaultSession> openTrustedSessionEnsuringKeystore() async {
    final RecoveryMetadata metadata =
        await readRecoveryMetadata() ??
        (throw const TrustedSessionException(
          TrustedSessionFailure.recoveryKeyMissing,
        ));
    final WrappedRecoveryKeyRecord record =
        await _deviceKeyManager.readWrappedRecoveryKey(metadata.vaultId) ??
        (throw const TrustedSessionException(
          TrustedSessionFailure.dataUnusable,
        ));
    final KeystoreAuthKind expected = await _requireCurrentKeystoreAuthKind();
    final UnlockedVaultSession probe = UnlockedVaultSession(
      vaultId: metadata.vaultId,
      trustedDevice: true,
      recoveryWrapKey: const <int>[],
      deviceSlotId: record.slotId,
    );

    final UnlockedVaultSession session;
    if (keystoreSlotsMatchExpected(
      session: probe,
      expected: expected,
      wrappedRecord: record,
    )) {
      session = await openTrustedSession();
      await ensureKeystoreMatchesUnlockMode(session);
    } else {
      session = await _openTrustedSessionViaRewrap(
        metadata: metadata,
        record: record,
        expected: expected,
      );
    }
    await ensureIndexReady(session);
    return session;
  }

  /// 槽位與解鎖模式不一致時，以單次原生驗證完成 unwrap + re-wrap。
  Future<UnlockedVaultSession> _openTrustedSessionViaRewrap({
    required RecoveryMetadata metadata,
    required WrappedRecoveryKeyRecord record,
    required KeystoreAuthKind expected,
  }) async {
    final RewrapTrustedRecoveryKeyResult rewrap = await _deviceKeyManager
        .rewrapTrustedRecoveryKey(
          vaultId: metadata.vaultId,
          sourceSlotId: record.slotId,
          nonceBase64: record.nonceBase64,
          ciphertextBase64: record.ciphertextBase64,
          targetAuthKind: expected,
        );
    await _deviceKeyManager.storeWrappedRecoveryKey(
      vaultId: metadata.vaultId,
      record: WrappedRecoveryKeyRecord(
        slotId: rewrap.payload.slotId,
        nonceBase64: rewrap.payload.nonceBase64,
        ciphertextBase64: rewrap.payload.ciphertextBase64,
        wrappedAt: DateTime.now(),
        formatVersion: DataVersions.wrappedRecoveryKey,
        platform: rewrap.payload.platform,
      ),
    );
    await _deviceKeyManager.purgeInactiveDeviceKeys(
      metadata.vaultId,
      activeAuthKind: expected,
    );
    await _verifyRecoveryKey(metadata, rewrap.recoveryWrapKey);
    final UnlockedVaultSession session = await _openVerifiedTrustedSession(
      metadata: metadata,
      recoveryWrapKey: rewrap.recoveryWrapKey,
      trustedDevice: true,
      deviceSlotId: rewrap.payload.slotId,
    );
    await _openIndexForSession(session);
    await _requireOpenIndex().setAppValue(
      kKeystoreWrapModeKey,
      expected.storageSuffix,
    );
    return session;
  }

  /// 還原同 vault 後沿用還原前 session 的包裝金鑰，不再觸發裝置驗證。
  Future<UnlockedVaultSession> resumeUnlockedSessionAfterRestore(
    UnlockedVaultSession priorSession,
  ) async {
    final RecoveryMetadata metadata =
        await readRecoveryMetadata() ??
        (throw const TrustedSessionException(
          TrustedSessionFailure.recoveryKeyMissing,
        ));
    if (priorSession.vaultId != metadata.vaultId) {
      throw const TrustedSessionException(TrustedSessionFailure.dataUnusable);
    }

    final List<int> recoveryWrapKey = requireRecoveryWrapKey(priorSession);
    await _verifyRecoveryKey(metadata, recoveryWrapKey);

    return _openVerifiedTrustedSession(
      metadata: metadata,
      recoveryWrapKey: recoveryWrapKey,
      trustedDevice: priorSession.trustedDevice,
      deviceSlotId: priorSession.deviceSlotId,
    );
  }

  Future<UnlockedVaultSession> _openVerifiedTrustedSession({
    required RecoveryMetadata metadata,
    required List<int> recoveryWrapKey,
    required bool trustedDevice,
    DeviceSlotId? deviceSlotId,
  }) async {
    final UnlockedVaultSession session = UnlockedVaultSession(
      vaultId: metadata.vaultId,
      trustedDevice: trustedDevice,
      recoveryWrapKey: recoveryWrapKey,
      deviceSlotId: deviceSlotId,
    );
    await _openIndexForSession(session);
    try {
      await _resumeRewrapIfNeeded(session, metadata);
    } on Object catch (_, stackTrace) {
      Error.throwWithStackTrace(
        StateError('日記庫重新包裝未完成，下次啟動會自動繼續。若問題持續，請檢查加密檔是否毀損。'),
        stackTrace,
      );
    }
    return session;
  }

  /// 在從備份還原並覆寫 vault 目錄後呼叫，避免仍沿用記憶體內舊的復原中繼資料。
  void clearRecoveryMetadataCache() {
    _cachedRecoveryMetadata = null;
  }

  Future<RecoveryMetadata?> readRecoveryMetadata() async {
    if (_cachedRecoveryMetadata != null) {
      return _cachedRecoveryMetadata;
    }

    final File file = File(await _pathStrategy.recoveryMetadataPath());
    if (!file.existsSync()) {
      return null;
    }

    final Object? decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Recovery metadata 格式不正確。');
    }

    _cachedRecoveryMetadata = RecoveryMetadata.fromJson(decoded);
    return _cachedRecoveryMetadata;
  }

  Future<RecoverySetupResult> setupRecoveryKey() async {
    if (await readRecoveryMetadata() != null) {
      throw StateError('復原金鑰已存在。');
    }

    final String recoveryKey = _generateRecoveryKey();
    final KdfDescriptor recoveryKdf = KdfDescriptor.argon2idRecovery(
      saltBytes: List<int>.generate(16, (_) => Random.secure().nextInt(256)),
    );
    final List<int> recoveryWrapKey = await _cryptoService
        .deriveRecoveryWrapKey(recoveryKey: recoveryKey, kdf: recoveryKdf);

    final RecoveryMetadata metadata = RecoveryMetadata(
      vaultId: generateVaultId(),
      recoveryEnabled: true,
      recoveryKeyVersion: DataVersions.initialRecoveryKey,
      recoveryKeyHint: recoveryKey.substring(recoveryKey.length - 4),
      createdAt: DateTime.now(),
      kdf: recoveryKdf,
    );

    final KeystoreAuthKind authKind = await _requireCurrentKeystoreAuthKind();
    final TrustedDeviceInfo deviceInfo = await _deviceKeyManager
        .ensureDeviceKey(metadata.vaultId, authKind: authKind);

    final File file = File(await _pathStrategy.recoveryMetadataPath());
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(metadata.toJson()),
      flush: true,
    );
    _cachedRecoveryMetadata = metadata;

    await _storeWrappedRecoveryKey(
      vaultId: metadata.vaultId,
      recoveryWrapKey: recoveryWrapKey,
      authKind: authKind,
    );

    final UnlockedVaultSession session = UnlockedVaultSession(
      vaultId: metadata.vaultId,
      trustedDevice: true,
      recoveryWrapKey: recoveryWrapKey,
      deviceSlotId: deviceInfo.slotId,
    );
    await _openIndexForSession(session);
    await _writeEncryptedManifest(session, metadata);
    await _requireOpenIndex().setAppValue(
      kKeystoreWrapModeKey,
      authKind.storageSuffix,
    );

    return RecoverySetupResult(recoveryKey: recoveryKey, session: session);
  }

  /// 輪替復原金鑰：先重加密 vault，最後才更新 [recovery.json]。
  Future<RecoverySetupResult> rotateRecoveryKey(UnlockedVaultSession session) =>
      runVaultMutation(() => _rotateRecoveryKey(session));

  Future<RecoverySetupResult> _rotateRecoveryKey(
    UnlockedVaultSession session,
  ) async {
    final RecoveryMetadata oldMetadata = await _requireMetadataForSession(
      session,
    );
    final List<int> oldWrapKey = requireRecoveryWrapKey(session);
    final KeystoreAuthKind authKind = await _requireCurrentKeystoreAuthKind();

    await _openIndexForSession(session);
    await _setRewrapState(inProgress: true);
    try {
      final String recoveryKey = _generateRecoveryKey();
      final KdfDescriptor newKdf = KdfDescriptor.argon2idRecovery(
        saltBytes: List<int>.generate(16, (_) => Random.secure().nextInt(256)),
      );
      final List<int> newWrapKey = await _cryptoService.deriveRecoveryWrapKey(
        recoveryKey: recoveryKey,
        kdf: newKdf,
      );
      final RecoveryMetadata newMetadata = RecoveryMetadata(
        vaultId: oldMetadata.vaultId,
        recoveryEnabled: true,
        recoveryKeyVersion: oldMetadata.recoveryKeyVersion,
        recoveryKeyHint: recoveryKey.substring(recoveryKey.length - 4),
        createdAt: DateTime.now(),
        kdf: newKdf,
      );

      await _rewrapVaultRecoveryKey(
        vaultId: session.vaultId,
        oldRecoveryWrapKey: oldWrapKey,
        newRecoveryWrapKey: newWrapKey,
        newMetadata: newMetadata,
      );

      final File file = File(await _pathStrategy.recoveryMetadataPath());
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(newMetadata.toJson()),
        flush: true,
      );
      _cachedRecoveryMetadata = newMetadata;

      UnlockedVaultSession updatedSession = session.copyWith(
        recoveryWrapKey: newWrapKey,
      );
      await _storeWrappedRecoveryKey(
        vaultId: oldMetadata.vaultId,
        recoveryWrapKey: newWrapKey,
        authKind: authKind,
      );
      updatedSession = await ensureKeystoreMatchesUnlockMode(updatedSession);
      await _repair.inspectVaultWithReport(updatedSession);
      await _setRewrapState(inProgress: false);

      return RecoverySetupResult(
        recoveryKey: recoveryKey,
        session: updatedSession,
      );
    } catch (_, stackTrace) {
      Error.throwWithStackTrace(
        StateError('復原金鑰輪替失敗，已保留進行中旗標以便下次自動續跑。'),
        stackTrace,
      );
    }
  }

  /// 還原前驗證復原金鑰能否解密備份內的加密檔（不寫入本機 vault）。
  Future<void> verifyRecoveryKeyAgainstBackupBytes({
    required RecoveryMetadata metadata,
    required String recoveryKey,
    required List<int> encryptedDocumentBytes,
  }) async {
    final List<int> recoveryWrapKey = await _cryptoService
        .deriveRecoveryWrapKey(recoveryKey: recoveryKey, kdf: metadata.kdf);
    final ParsedEncryptedDocument parsed = _cryptoService.parseFileBytes(
      encryptedDocumentBytes,
    );
    try {
      await _cryptoService.decryptBytes(
        headerBytes: parsed.headerBytes,
        ciphertextBytes: parsed.ciphertextBytes,
        context: DecryptionContext.recovery(
          recoveryWrapKey: recoveryWrapKey,
          vaultId: metadata.vaultId,
        ),
      );
    } on SecretBoxAuthenticationError {
      throw const VaultBackupException(VaultBackupIssue.recoveryKeyMismatch);
    }
  }

  Future<UnlockedVaultSession> unlockWithRecoveryKey(String recoveryKey) async {
    final RecoveryMetadata metadata =
        await readRecoveryMetadata() ??
        (throw StateError('找不到 Recovery metadata。'));
    final List<int> recoveryWrapKey = await _cryptoService
        .deriveRecoveryWrapKey(recoveryKey: recoveryKey, kdf: metadata.kdf);
    await _verifyRecoveryKey(metadata, recoveryWrapKey);

    final AppUnlockMode unlockMode = await _appLockService.getUnlockMode();
    final UnlockModeCapabilityFailure? wrapFailure =
        await precheckUnlockModeChange(
          appLock: _appLockService,
          mode: unlockMode,
        );
    if (wrapFailure != null) {
      throw UnlockModeCapabilityException(wrapFailure);
    }
    final KeystoreAuthKind authKind = keystoreAuthFor(unlockMode);
    final TrustedDeviceInfo deviceInfo = await _deviceKeyManager
        .ensureDeviceKey(metadata.vaultId, authKind: authKind);

    final UnlockedVaultSession session = UnlockedVaultSession(
      vaultId: metadata.vaultId,
      trustedDevice: true,
      recoveryWrapKey: recoveryWrapKey,
      deviceSlotId: deviceInfo.slotId,
    );

    await _openIndexForSession(session);
    await _setRewrapState(inProgress: true);
    try {
      await _rewrapVaultForTrustedDevice(session, metadata);
    } on Object catch (_, stackTrace) {
      Error.throwWithStackTrace(
        StateError('日記庫重新包裝失敗，已保留進行中旗標以便下次自動續跑。'),
        stackTrace,
      );
    }

    await _storeWrappedRecoveryKey(
      vaultId: metadata.vaultId,
      recoveryWrapKey: recoveryWrapKey,
      authKind: authKind,
    );
    await _requireOpenIndex().setAppValue(
      kKeystoreWrapModeKey,
      authKind.storageSuffix,
    );
    await rebuildIndex(session);
    await _setRewrapState(inProgress: false);
    return session;
  }

  Future<List<DiaryEntrySummary>> listEntries({
    String? searchQuery,
    DateOnly? date,
  }) {
    return _requireOpenIndex().listEntries(
      searchQuery: searchQuery,
      date: date,
    );
  }

  Future<List<DiaryEntrySummary>> listEntriesForMonth(DateTime month) {
    return _requireOpenIndex().listEntriesForMonth(month);
  }

  Future<List<DiaryEntrySummary>> listEntriesForDateRange({
    required DateOnly firstDate,
    required DateOnly lastDate,
  }) {
    return _requireOpenIndex().listEntriesForDateRange(
      firstDate: firstDate,
      lastDate: lastDate,
    );
  }

  Future<({DateOnly earliest, DateOnly latest})?> entryDateBounds() {
    return _requireOpenIndex().entryDateBounds();
  }

  Future<DiaryEntry?> loadEntry(
    UnlockedVaultSession session,
    EntryId entryId,
  ) async {
    final DiaryEntrySummary? indexRecord = await _requireOpenIndex()
        .getEntryById(entryId);
    if (indexRecord == null) {
      return null;
    }

    final File file = File(indexRecord.filePath);
    if (!file.existsSync()) {
      return null;
    }

    final ParsedEncryptedDocument parsed = _cryptoService.parseFileBytes(
      await file.readAsBytes(),
    );
    final String markdown = await _cryptoService.decryptMarkdown(
      headerBytes: parsed.headerBytes,
      ciphertextBytes: parsed.ciphertextBytes,
      context: vaultDecryptionContext(session),
    );
    final DiaryEntry entry = _frontMatterCodec
        .decode(markdown)
        .copyWith(vaultId: indexRecord.vaultId);
    return _entryWithIndexedAttachmentIds(entry);
  }

  Future<DiaryEntry> _entryWithIndexedAttachmentIds(DiaryEntry entry) async {
    final List<AssetAttachment> attachments = await _requireOpenIndex()
        .attachmentsForEntry(entry.id);
    if (attachments.isEmpty) {
      return entry;
    }

    final List<AssetId> indexedIds = attachments
        .map((AssetAttachment attachment) => attachment.id)
        .toList(growable: false);
    if (listEquals(entry.attachmentIds, indexedIds)) {
      return entry;
    }

    return entry.copyWith(attachmentIds: indexedIds);
  }

  Future<List<AssetAttachment>> loadAttachments(EntryId entryId) {
    return _requireOpenIndex().attachmentsForEntry(entryId);
  }

  Future<List<TagCatalogItem>> listTagCatalog() {
    return TagStylesStore(_pathStrategy).read();
  }

  Future<Set<EntryId>> listPinnedEntryIds() {
    return PinnedEntriesStore(_pathStrategy).readIds();
  }

  Future<void> setEntriesPinned(
    Iterable<EntryId> entryIds, {
    required bool pinned,
  }) {
    return PinnedEntriesStore(_pathStrategy)
        .setPinnedMany(entryIds, pinned: pinned);
  }

  Future<void> upsertTagCatalogItem(
    String label, {
    int? accentArgb,
    bool? accentIsCustom,
  }) async {
    final String displayLabel = label.trim().replaceAll(RegExp(r'\s+'), ' ');
    final String normalized = normalizeText(displayLabel);
    if (normalized.isEmpty) {
      throw ArgumentError.value(label, 'label', '標籤名稱不可為空白');
    }

    final List<TagCatalogItem> catalog = await listTagCatalog();
    final List<TagCatalogItem> merged = TagStylesStore.merge(
      catalog,
      <TagCatalogItem>[
        TagCatalogItem(
          label: displayLabel,
          accentArgb: accentArgb,
          accentIsCustom: accentIsCustom,
        ),
      ],
    );
    await _persistTagCatalogToVault(merged);
    final TagCatalogItem saved = merged.firstWhere(
      (TagCatalogItem item) => item.normalized == normalized,
    );
    if (saved.accentArgb != null) {
      await _requireOpenIndex().upsertTagAccentArgb(
        saved.label,
        saved.accentArgb!,
      );
    }
  }

  Future<void> ensureTagCatalogLabels(Iterable<String> labels) =>
      TagStylesStore(_pathStrategy).ensureLabels(labels);

  Future<void> deleteTagCatalogItem(String label) async {
    final String normalized = normalizeText(label);
    if (normalized.isEmpty) {
      return;
    }
    final List<TagCatalogItem> catalog = await listTagCatalog();
    final List<TagCatalogItem> next = catalog
        .where((TagCatalogItem item) => item.normalized != normalized)
        .toList(growable: false);
    await _persistTagCatalogToVault(next);
    await _requireOpenIndex().deleteTagAccentArgb(label);
  }

  Future<void> upsertTagAccentArgb(
    String tag,
    int accentArgb, {
    bool? accentIsCustom,
  }) async {
    await upsertTagCatalogItem(
      tag,
      accentArgb: accentArgb,
      accentIsCustom: accentIsCustom,
    );
  }

  Future<void> deleteTagAccentArgb(String tag) async {
    await deleteTagCatalogItem(tag);
  }

  /// 重新命名標籤並同步更新 catalog、索引與所有日記條目。
  /// 若 [toLabel] 的正規化鍵已存在，會合併到該標籤。
  Future<int> renameTagCatalogItem(
    UnlockedVaultSession session, {
    required String fromLabel,
    required String toLabel,
    int? accentArgb,
    bool? accentIsCustom,
  }) async {
    final String fromDisplay = fromLabel.trim().replaceAll(RegExp(r'\s+'), ' ');
    final String toDisplay = toLabel.trim().replaceAll(RegExp(r'\s+'), ' ');
    final String fromNorm = normalizeText(fromDisplay);
    final String toNorm = normalizeText(toDisplay);
    if (fromNorm.isEmpty || toNorm.isEmpty) {
      throw ArgumentError.value(toLabel, 'toLabel', '標籤名稱不可為空白');
    }

    final List<TagCatalogItem> catalog = await listTagCatalog();
    int? resolvedAccent = accentArgb;
    bool? resolvedIsCustom = accentIsCustom;
    for (final TagCatalogItem item in catalog) {
      if (item.normalized == fromNorm) {
        resolvedAccent ??= item.accentArgb;
        resolvedIsCustom ??= item.accentIsCustom;
      }
    }

    final int updatedCount = fromNorm != toNorm || fromDisplay != toDisplay
        ? await _rewriteTagInAllEntries(
            session,
            fromNorm: fromNorm,
            toDisplay: toDisplay,
          )
        : 0;

    final List<TagCatalogItem> base = catalog
        .where((TagCatalogItem item) => item.normalized != fromNorm)
        .toList(growable: false);
    final List<TagCatalogItem> merged = TagStylesStore.merge(
      base,
      <TagCatalogItem>[
        TagCatalogItem(
          label: toDisplay,
          accentArgb: resolvedAccent,
          accentIsCustom: resolvedIsCustom,
        ),
      ],
    );
    await _persistTagCatalogToVault(merged);

    final IndexDatabase indexDb = _requireOpenIndex();
    if (fromNorm != toNorm) {
      await indexDb.deleteTagAccentArgb(fromDisplay);
    }
    if (resolvedAccent != null) {
      await indexDb.upsertTagAccentArgb(toDisplay, resolvedAccent);
    }

    return updatedCount;
  }

  Future<int> _rewriteTagInAllEntries(
    UnlockedVaultSession session, {
    required String fromNorm,
    required String toDisplay,
  }) async {
    final String toNorm = normalizeText(toDisplay);
    final List<DiaryEntrySummary> records = await listEntries();
    int updatedCount = 0;
    for (final DiaryEntrySummary record in records) {
      if (!record.tags.any((String t) => normalizeText(t) == fromNorm)) {
        continue;
      }

      final DiaryEntry? entry = await loadEntry(session, record.id);
      if (entry == null) {
        continue;
      }

      final List<String> nextTags = <String>[];
      final Set<String> seenNorm = <String>{};
      for (final String tag in entry.tags) {
        final String norm = normalizeText(tag);
        if (norm == fromNorm) {
          if (seenNorm.add(toNorm)) {
            nextTags.add(toDisplay);
          }
          continue;
        }
        if (seenNorm.add(norm)) {
          nextTags.add(tag);
        }
      }

      if (listEquals(entry.tags, nextTags)) {
        continue;
      }

      await saveEntry(session, entry.copyWith(tags: nextTags));
      updatedCount++;
    }
    return updatedCount;
  }

  /// 從所有日記條目移除 [tag]，並清除已儲存的強調色。
  Future<int> removeTagFromAllEntries(
    UnlockedVaultSession session,
    String tag,
  ) async {
    final String normalized = normalizeText(tag);
    if (normalized.isEmpty) {
      return 0;
    }

    final List<DiaryEntrySummary> records = await listEntries();
    int updatedCount = 0;
    for (final DiaryEntrySummary record in records) {
      final bool hasTag = record.tags.any(
        (String t) => normalizeText(t) == normalized,
      );
      if (!hasTag) {
        continue;
      }

      final DiaryEntry? entry = await loadEntry(session, record.id);
      if (entry == null) {
        continue;
      }

      final List<String> nextTags = entry.tags
          .where((String t) => normalizeText(t) != normalized)
          .toList(growable: false);
      if (nextTags.length == entry.tags.length) {
        continue;
      }

      await saveEntry(session, entry.copyWith(tags: nextTags));
      updatedCount++;
    }

    await deleteTagCatalogItem(tag);
    return updatedCount;
  }

  Future<void> _persistTagCatalogToVault(List<TagCatalogItem> catalog) {
    return TagStylesStore(_pathStrategy).write(catalog);
  }

  Future<void> _applyTagCatalogFromVaultToIndex() =>
      TagStylesStore(_pathStrategy).applyToIndex(_requireOpenIndex());

  /// 重建或還原後保持 vault 檔案與索引同步。
  Future<void> syncTagStylesBetweenVaultAndIndex() async {
    await _applyTagCatalogFromVaultToIndex();
  }

  Future<bool> canSalvageFindings(
    UnlockedVaultSession session,
    List<VaultFinding> findings,
  ) => _repair.canSalvageFindings(session, findings);

  Future<VaultSalvageDraft?> tryCreateSalvageDraft(
    UnlockedVaultSession session, {
    required List<VaultFinding> findings,
  }) => _repair.tryCreateSalvageDraft(session, findings: findings);

  Future<DiaryEntry> saveEntry(
    UnlockedVaultSession session,
    DiaryEntry draft, {
    List<PendingAttachment> pendingAttachments = const <PendingAttachment>[],
    List<VaultFinding> retireFindingsAfterSave = const <VaultFinding>[],
  }) => runVaultMutation(() async {
    final DiaryEntry saved = await _saveEntry(
      session,
      draft,
      pendingAttachments: pendingAttachments,
    );
    if (retireFindingsAfterSave.isNotEmpty) {
      await _repair.permanentlyDeleteAbnormalFindings(
        session,
        findings: retireFindingsAfterSave,
        salvaged: true,
      );
    }
    return saved;
  });

  Future<DiaryEntry> _saveEntry(
    UnlockedVaultSession session,
    DiaryEntry draft, {
    required List<PendingAttachment> pendingAttachments,
  }) async {
    final RecoveryMetadata metadata = await _requireMetadataForSession(session);
    final List<int> recoveryWrapKey = requireRecoveryWrapKey(session);
    final IndexDatabase indexDb = _requireOpenIndex();
    final DiaryEntrySummary? previousRecord = await indexDb.getEntryById(
      draft.id,
    );
    final DateOnly previousDate = previousRecord?.date ?? draft.date;
    final List<AssetAttachment> existingFromDb = await indexDb
        .attachmentsForEntry(draft.id);
    final Set<AssetId> keepExistingIds = draft.attachmentIds.toSet();
    final Map<AssetId, AssetAttachment> existingById =
        <AssetId, AssetAttachment>{
          for (final AssetAttachment attachment in existingFromDb)
            attachment.id: attachment,
        };
    final Set<AssetId> pendingIds = <AssetId>{};
    for (final PendingAttachment pending in pendingAttachments) {
      if (pending.assetId.trim().isEmpty) {
        throw ArgumentError('暫存附件 ID 不可為空白');
      }
      if (!pendingIds.add(pending.assetId)) {
        throw ArgumentError('暫存附件 ID 不可重複：${pending.assetId}');
      }
      if (existingById.containsKey(pending.assetId)) {
        throw ArgumentError('暫存附件 ID 不可與既有附件重複：${pending.assetId}');
      }
    }
    final Set<AssetId> seenKeptIds = <AssetId>{};
    final List<AssetAttachment> existingKept = <AssetAttachment>[];
    for (final AssetId id in draft.attachmentIds) {
      if (!seenKeptIds.add(id)) {
        continue;
      }
      final AssetAttachment? attachment = existingById[id];
      if (attachment != null) {
        existingKept.add(attachment);
      }
    }
    final List<AssetAttachment> removedAttachments = existingFromDb
        .where((AssetAttachment a) => !keepExistingIds.contains(a.id))
        .toList(growable: false);
    final Set<String> obsoletePathsAfterSave = <String>{};
    for (final AssetAttachment attachment in removedAttachments) {
      obsoletePathsAfterSave.add(
        await _pathStrategy.attachmentAbsolutePath(
          date: previousDate,
          attachment: attachment,
        ),
      );
    }

    final List<AssetAttachment> newAttachments = await _storePendingAttachments(
      entry: draft,
      pendingAttachments: pendingAttachments,
      recoveryWrapKey: recoveryWrapKey,
      recoverySlotKdf: metadata.kdf,
      vaultId: metadata.vaultId,
    );

    final Map<AssetId, AssetAttachment> availableById =
        <AssetId, AssetAttachment>{
          for (final AssetAttachment attachment in existingKept)
            attachment.id: attachment,
          for (final AssetAttachment attachment in newAttachments)
            attachment.id: attachment,
        };
    final Set<AssetId> seenOrderedIds = <AssetId>{};
    final List<AssetAttachment> allAttachments = <AssetAttachment>[];
    for (final AssetId id in draft.attachmentIds) {
      final AssetAttachment? attachment = availableById[id];
      if (attachment != null && seenOrderedIds.add(id)) {
        allAttachments.add(attachment);
      }
    }
    // 匯入流程不一定預先知道新附件 ID，未列入順序的新附件依輸入順序附加。
    for (final AssetAttachment attachment in newAttachments) {
      if (seenOrderedIds.add(attachment.id)) {
        allAttachments.add(attachment);
      }
    }
    final List<AssetAttachment> orderedAttachments = allAttachments;
    final DiaryEntry normalized = draft.copyWith(
      vaultId: metadata.vaultId,
      attachmentIds: orderedAttachments
          .map((AssetAttachment asset) => asset.id)
          .toList(),
      updatedAt: DateTime.now(),
    );

    if (previousRecord != null && previousRecord.date != normalized.date) {
      for (final AssetAttachment attachment in existingKept) {
        final String oldPath = await _pathStrategy.attachmentAbsolutePath(
          date: previousRecord.date,
          attachment: attachment,
        );
        final bool copied = await _copyAssetFileIfNeeded(
          date: normalized.date,
          attachment: attachment,
          currentPath: oldPath,
        );
        if (copied) {
          obsoletePathsAfterSave.add(oldPath);
        }
      }
    }

    final String markdown = _frontMatterCodec.encode(
      normalized,
      attachments: orderedAttachments,
    );
    final EncryptionResult encryption = await _cryptoService.encryptMarkdown(
      documentId: normalized.id,
      vaultId: metadata.vaultId,
      markdown: markdown,
      recoveryWrapKey: recoveryWrapKey,
      recoverySlotKdf: metadata.kdf,
      createdAt: normalized.createdAt,
      updatedAt: normalized.updatedAt,
    );

    final String filePath = await _pathStrategy.entryAbsolutePath(
      date: normalized.date,
      entryId: normalized.id,
    );
    final Uint8List fileBytes = encryption.toFileBytes();
    await atomicWriteBytes(File(filePath), fileBytes);
    if (previousRecord != null && previousRecord.filePath != filePath) {
      obsoletePathsAfterSave.add(previousRecord.filePath);
      obsoletePathsAfterSave.addAll(
        await _copyChatFilesBesideEntry(
          fromEntryPath: previousRecord.filePath,
          toEntryPath: filePath,
          session: session,
        ),
      );
    }

    final EntrySearchFields searchFields = entrySearchFields(normalized);

    await indexDb.upsertEntry(
      entry: normalized,
      filePath: filePath,
      previewText: searchFields.previewText,
      previewMarkdown: searchFields.previewMarkdown,
      titleSearchText: searchFields.titleSearchText,
      bodySearchText: searchFields.bodySearchText,
      bodyVisibleText: searchFields.bodyVisibleText,
      contentHash: await hashVaultText(markdown),
      encryptedFileSize: fileBytes.lengthInBytes,
      encryptedModifiedAt: DateTime.now(),
    );
    await indexDb.replaceAttachments(
      normalized.id,
      orderedAttachments,
      <AssetId, String>{
        for (final AssetAttachment attachment in orderedAttachments)
          attachment.id: await _pathStrategy.attachmentAbsolutePath(
            date: normalized.date,
            attachment: attachment,
          ),
      },
    );
    await _writeEncryptedManifest(session, metadata);
    await ensureTagCatalogLabels(normalized.tags);
    await _deleteObsoleteFilesAfterSave(obsoletePathsAfterSave);
    return normalized;
  }

  Future<void> deleteEntry(UnlockedVaultSession session, EntryId entryId) =>
      runVaultMutation(() => _deleteEntry(session, entryId));

  Future<void> _deleteEntry(
    UnlockedVaultSession session,
    EntryId entryId,
  ) async {
    final IndexDatabase indexDb = _requireOpenIndex();
    final DiaryEntrySummary? record = await indexDb.getEntryById(entryId);
    if (record == null) {
      return;
    }

    final List<AssetAttachment> attachments = await indexDb.attachmentsForEntry(
      entryId,
    );
    await _deleteEntryFilesOnDisk(record: record, attachments: attachments);
    await indexDb.removeEntry(entryId);
    await PinnedEntriesStore(_pathStrategy).remove(entryId);

    final RecoveryMetadata metadata = await _requireMetadataForSession(session);
    await _writeEncryptedManifest(session, metadata);
  }

  Future<List<DiaryEntrySummary>> searchEntries(String query) {
    return _requireOpenIndex().searchEntries(query);
  }

  Future<VaultRepairSummary?> readLastRepairSummary() =>
      _repair.readLastRepairSummary();

  Future<VaultInspectSummary?> readLastInspectSummary() =>
      _repair.readLastInspectSummary();

  /// 永久刪除異常 finding 對應的正式檔案，並從最近檢查／修復摘要移除這些項。
  ///
  /// 回傳成功刪除的檔案數。僅允許刪除 vault 內 `entries/`、`assets/` 路徑。
  Future<int> permanentlyDeleteAbnormalFindings(
    UnlockedVaultSession session, {
    required List<VaultFinding> findings,
  }) {
    return runVaultMutation(
      () => _repair.permanentlyDeleteAbnormalFindings(
        session,
        findings: findings,
      ),
    );
  }

  Future<void> rebuildIndex(UnlockedVaultSession session) =>
      runVaultMutation(() async {
        await _repair.inspectVaultWithReport(session);
      });

  Future<VaultInspectReport> inspectVaultWithReport(
    UnlockedVaultSession session, {
    VaultRepairProgressCallback? onProgress,
  }) => runVaultMutation(
    () => _repair.inspectVaultWithReport(session, onProgress: onProgress),
  );

  Future<VaultRepairReport> repairVaultWithReport(
    UnlockedVaultSession session, {
    VaultRepairProgressCallback? onProgress,
    String? backupFileName,
  }) => runVaultMutation(
    () => _repair.repairVaultWithReport(
      session,
      onProgress: onProgress,
      backupFileName: backupFileName,
    ),
  );

  Future<bool> _copyAssetFileIfNeeded({
    required DateOnly date,
    required AssetAttachment attachment,
    required String currentPath,
  }) async {
    final String newPath = await _pathStrategy.attachmentAbsolutePath(
      date: date,
      attachment: attachment,
    );
    if (p.normalize(currentPath) == p.normalize(newPath)) {
      return false;
    }
    final File oldFile = File(currentPath);
    if (!oldFile.existsSync()) {
      return false;
    }
    await File(newPath).parent.create(recursive: true);
    await oldFile.copy(newPath);
    return true;
  }

  /// 讀取並解密 vault 資產（磁碟上的 `.enc`）供記憶體內預覽，例如列表縮圖。
  Future<Uint8List?> readDecryptedAssetBytes(
    UnlockedVaultSession session,
    String encryptedAbsolutePath, {
    int maxEncryptedFileBytes = 32 << 20,
  }) async {
    final String trimmed = encryptedAbsolutePath.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final File file = File(trimmed);
    if (!file.existsSync()) {
      return null;
    }
    final int encLength = await file.length();
    if (encLength > maxEncryptedFileBytes) {
      return null;
    }
    try {
      final ParsedEncryptedDocument parsed = _cryptoService.parseFileBytes(
        await file.readAsBytes(),
      );
      final List<int> plain = await _cryptoService.decryptBytes(
        headerBytes: parsed.headerBytes,
        ciphertextBytes: parsed.ciphertextBytes,
        context: vaultDecryptionContext(session),
      );
      return Uint8List.fromList(plain);
    } on Object {
      return null;
    }
  }

  /// 僅在 catalog 為空時寫入預設標籤；已存在則 no-op。需 index 已開啟。
  Future<bool> seedDefaultTagCatalogIfEmpty(
    List<TagCatalogItem> defaultCatalog,
  ) async {
    final List<TagCatalogItem> existing = await listTagCatalog();
    if (existing.isNotEmpty) {
      return false;
    }
    await _persistTagCatalogToVault(defaultCatalog);
    final IndexDatabase indexDb = _requireOpenIndex();
    for (final TagCatalogItem item in defaultCatalog) {
      if (item.accentArgb == null) {
        continue;
      }
      await indexDb.upsertTagAccentArgb(item.label, item.accentArgb!);
    }
    return true;
  }

  Future<void> validateRecoverySession(UnlockedVaultSession session) async {
    await _verifyRecoveryKey(
      await _requireMetadataForSession(session),
      requireRecoveryWrapKey(session),
    );
  }

  Future<RecoveryMetadata> _requireMetadataForSession(
    UnlockedVaultSession session,
  ) async {
    final RecoveryMetadata metadata =
        await readRecoveryMetadata() ??
        (throw StateError('找不到 Recovery metadata。'));
    if (metadata.vaultId != session.vaultId) {
      throw StateError('目前 session 與 vault 資料不一致。');
    }
    return metadata;
  }

  Future<void> _verifyRecoveryDecryptFile(
    File file,
    DecryptionContext recoveryContext,
  ) async {
    final ParsedEncryptedDocument parsed = _cryptoService.parseFileBytes(
      await file.readAsBytes(),
    );
    await _cryptoService.decryptBytes(
      headerBytes: parsed.headerBytes,
      ciphertextBytes: parsed.ciphertextBytes,
      context: recoveryContext,
    );
  }

  /// 優先試 `entries/**/*.md.enc`，其餘 `entries|assets/**/*.enc`，不含 manifest。
  Future<List<File>> _encryptedFilesForRecoveryVerification() async {
    final Directory vaultRoot = await _pathStrategy.vaultRootDirectory();
    final String manifestPath = await _pathStrategy.manifestPath();
    final List<File> entryEncrypted = <File>[];
    final List<File> otherEncrypted = <File>[];

    if (!vaultRoot.existsSync()) {
      return const <File>[];
    }

    final File peopleCatalog = File(await _pathStrategy.peopleCatalogPath());
    final List<File> preferred = <File>[
      if (peopleCatalog.existsSync()) peopleCatalog,
    ];

    await for (final FileSystemEntity entity in vaultRoot.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) {
        continue;
      }
      if (!_isUnderVaultContentSubdir(entity.path, vaultRoot.path)) {
        continue;
      }
      if (entity.path == manifestPath ||
          !entity.path.toLowerCase().endsWith('.enc')) {
        continue;
      }
      final String lowered = entity.path.toLowerCase();
      if (lowered.endsWith('.md.enc')) {
        entryEncrypted.add(entity);
      } else {
        otherEncrypted.add(entity);
      }
    }

    int pathSort(File a, File b) => a.path.compareTo(b.path);
    entryEncrypted.sort(pathSort);
    otherEncrypted.sort(pathSort);

    return <File>[...preferred, ...entryEncrypted, ...otherEncrypted];
  }

  bool _isUnderVaultContentSubdir(String absolutePath, String vaultRootPath) {
    final String relative = p.relative(absolutePath, from: vaultRootPath);
    if (relative.startsWith('..')) {
      return false;
    }
    return relative.startsWith('entries${p.separator}') ||
        relative.startsWith('assets${p.separator}');
  }

  Future<void> _verifyRecoveryKey(
    RecoveryMetadata metadata,
    List<int> recoveryWrapKey,
  ) async {
    final File manifest = File(await _pathStrategy.manifestPath());
    final DecryptionContext recoveryContext = DecryptionContext.recovery(
      recoveryWrapKey: recoveryWrapKey,
      vaultId: metadata.vaultId,
    );

    if (manifest.existsSync()) {
      await _verifyRecoveryDecryptFile(manifest, recoveryContext);
      return;
    }

    final List<File> fallbackTargets =
        await _encryptedFilesForRecoveryVerification();
    if (fallbackTargets.isEmpty) {
      return;
    }

    Object? parseProblem;
    Object? verificationProblem;
    bool sawAuthFailure = false;
    bool sawParsableEncryptedFile = false;
    for (final File file in fallbackTargets) {
      late final ParsedEncryptedDocument parsed;
      try {
        parsed = _cryptoService.parseFileBytes(await file.readAsBytes());
      } on Object catch (parseErr) {
        parseProblem ??= parseErr;
        continue;
      }

      sawParsableEncryptedFile = true;
      try {
        await _cryptoService.decryptBytes(
          headerBytes: parsed.headerBytes,
          ciphertextBytes: parsed.ciphertextBytes,
          context: recoveryContext,
        );
        return;
      } on SecretBoxAuthenticationError {
        sawAuthFailure = true;
      } on Object catch (decryptErr) {
        verificationProblem ??= decryptErr;
      }
    }

    if (verificationProblem != null) {
      throw StateError(
        '無法用現有加密檔驗證復原金鑰（至少一個檔案疑似毀損或格式異常）。'
        ' 最近一次驗證問題：$verificationProblem',
      );
    }

    if (sawParsableEncryptedFile && sawAuthFailure) {
      throw SecretBoxAuthenticationError();
    }

    throw StateError(
      '無法解析或驗證任何加密檔'
      '${parseProblem == null ? '' : '（最近一次格式錯誤：$parseProblem）'}',
    );
  }

  Future<void> _writeEncryptedManifest(
    UnlockedVaultSession session,
    RecoveryMetadata metadata,
  ) async {
    final List<DiaryEntrySummary> entries = await listEntries();
    final int assetCount = await _requireOpenIndex().countAttachments();
    final Map<String, Object?> manifest = <String, Object?>{
      'vault_id': metadata.vaultId,
      'entry_count': entries.length,
      'asset_count': assetCount,
      'oldest_entry_date': entries.isEmpty ? null : entries.last.date.value,
      'newest_entry_date': entries.isEmpty ? null : entries.first.date.value,
    };

    final EncryptionResult encryption = await _cryptoService.encryptBytes(
      documentId: 'manifest',
      vaultId: metadata.vaultId,
      plaintextBytes: utf8.encode(jsonEncode(manifest)),
      contentType: 'application/json',
      recoveryWrapKey: requireRecoveryWrapKey(session),
      recoverySlotKdf: metadata.kdf,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await atomicWriteBytes(
      File(await _pathStrategy.manifestPath()),
      encryption.toFileBytes(),
    );
  }

  Future<List<AssetAttachment>> _storePendingAttachments({
    required DiaryEntry entry,
    required List<PendingAttachment> pendingAttachments,
    required List<int> recoveryWrapKey,
    required KdfDescriptor recoverySlotKdf,
    required String vaultId,
  }) async {
    final List<AssetAttachment> results = <AssetAttachment>[];
    for (final PendingAttachment pending in pendingAttachments) {
      final AssetId assetId = pending.assetId;
      final String originalFilename = p.basename(
        pending.originalFilename.trim(),
      );
      final String extension = p
          .extension(originalFilename)
          .replaceFirst('.', '');
      final String safeFilename = originalFilename.isEmpty
          ? (extension.isEmpty ? assetId : '$assetId.$extension')
          : originalFilename;
      final List<int> sourceBytes = pending.bytes != null
          ? pending.bytes!
          : await File(pending.sourcePath!).readAsBytes();
      if (!contentTypeMatchesExtension(pending.mimeType, extension) ||
          !attachmentContentMatchesMimeType(sourceBytes, pending.mimeType)) {
        throw ArgumentError.value(
          originalFilename,
          'pendingAttachments',
          '附件內容、MIME 與副檔名不一致。',
        );
      }
      final DateTime createdAt = DateTime.now();
      final EncryptionResult encrypted = await _cryptoService.encryptBytes(
        documentId: assetId,
        vaultId: vaultId,
        plaintextBytes: sourceBytes,
        contentType: pending.mimeType,
        recoveryWrapKey: recoveryWrapKey,
        recoverySlotKdf: recoverySlotKdf,
        createdAt: createdAt,
        updatedAt: createdAt,
      );
      final String assetPath = await _pathStrategy.assetAbsolutePath(
        date: entry.date,
        assetId: assetId,
        extension: extension.isEmpty ? 'bin' : extension,
      );
      await atomicWriteBytes(File(assetPath), encrypted.toFileBytes());
      results.add(
        AssetAttachment(
          id: assetId,
          entryId: entry.id,
          mimeType: pending.mimeType,
          originalFilename: originalFilename.isEmpty ? null : originalFilename,
          safeFilename: safeFilename,
          byteSize: sourceBytes.length,
          createdAt: createdAt,
          sha256: await hashVaultBytes(sourceBytes),
        ),
      );
    }
    return results;
  }

  Future<void> _rewrapVaultRecoveryKey({
    required VaultId vaultId,
    required List<int> oldRecoveryWrapKey,
    required List<int> newRecoveryWrapKey,
    required RecoveryMetadata newMetadata,
  }) async {
    final List<File> files = await _allEncryptedFiles();
    for (final File file in files) {
      final ParsedEncryptedDocument parsed = _cryptoService.parseFileBytes(
        await file.readAsBytes(),
      );
      final List<int> plaintextBytes = await _cryptoService.decryptBytes(
        headerBytes: parsed.headerBytes,
        ciphertextBytes: parsed.ciphertextBytes,
        context: DecryptionContext.recovery(
          recoveryWrapKey: oldRecoveryWrapKey,
          vaultId: vaultId,
        ),
      );
      final EncryptionResult encryption = await _cryptoService.encryptBytes(
        documentId: parsed.header.fileId,
        vaultId: parsed.header.vaultId,
        plaintextBytes: plaintextBytes,
        contentType: parsed.header.contentType,
        recoveryWrapKey: newRecoveryWrapKey,
        recoverySlotKdf: newMetadata.kdf,
        createdAt: parsed.header.createdAt,
        updatedAt: DateTime.now(),
      );
      await atomicWriteBytes(file, encryption.toFileBytes());
    }
  }

  Future<void> _rewrapVaultForTrustedDevice(
    UnlockedVaultSession session,
    RecoveryMetadata metadata,
  ) async {
    final List<File> files = await _allEncryptedFiles();
    final List<int> recoveryWrapKey = requireRecoveryWrapKey(session);
    for (final File file in files) {
      final ParsedEncryptedDocument parsed = _cryptoService.parseFileBytes(
        await file.readAsBytes(),
      );
      final List<int> plaintextBytes = await _cryptoService.decryptBytes(
        headerBytes: parsed.headerBytes,
        ciphertextBytes: parsed.ciphertextBytes,
        context: DecryptionContext.recovery(
          recoveryWrapKey: recoveryWrapKey,
          vaultId: session.vaultId,
        ),
      );
      final EncryptionResult encryption = await _cryptoService.encryptBytes(
        documentId: parsed.header.fileId,
        vaultId: parsed.header.vaultId,
        plaintextBytes: plaintextBytes,
        contentType: parsed.header.contentType,
        recoveryWrapKey: recoveryWrapKey,
        recoverySlotKdf: metadata.kdf,
        createdAt: parsed.header.createdAt,
        updatedAt: DateTime.now(),
      );
      await atomicWriteBytes(file, encryption.toFileBytes());
    }
  }

  Future<List<File>> _allEncryptedFiles() async {
    final Directory vaultRoot = await _pathStrategy.vaultRootDirectory();
    final File manifest = File(await _pathStrategy.manifestPath());
    final List<File> files = <File>[if (manifest.existsSync()) manifest];

    await for (final FileSystemEntity entity in vaultRoot.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File || entity.path == manifest.path) {
        continue;
      }
      if (entity.path.endsWith('.enc') ||
          entity.path.endsWith('.enc.previous')) {
        files.add(entity);
      }
    }
    return files;
  }

  Future<DeviceWrappedPayload> _storeWrappedRecoveryKey({
    required VaultId vaultId,
    required List<int> recoveryWrapKey,
    required KeystoreAuthKind authKind,
  }) async {
    final DeviceWrappedPayload payload = await _deviceKeyManager
        .wrapWithDeviceKey(
          vaultId: vaultId,
          plaintextBytes: recoveryWrapKey,
          authKind: authKind,
        );
    await _deviceKeyManager.storeWrappedRecoveryKey(
      vaultId: vaultId,
      record: WrappedRecoveryKeyRecord(
        slotId: payload.slotId,
        nonceBase64: payload.nonceBase64,
        ciphertextBase64: payload.ciphertextBase64,
        wrappedAt: DateTime.now(),
        formatVersion: DataVersions.wrappedRecoveryKey,
        platform: payload.platform,
      ),
    );
    await _deviceKeyManager.purgeInactiveDeviceKeys(
      vaultId,
      activeAuthKind: authKind,
    );
    return payload;
  }

  Future<KeystoreAuthKind> _requireCurrentKeystoreAuthKind() async {
    final AppUnlockMode mode = await _appLockService.getUnlockMode();
    return requireKeystoreAuthKindForMode(appLock: _appLockService, mode: mode);
  }

  Future<void> _resumeRewrapIfNeeded(
    UnlockedVaultSession session,
    RecoveryMetadata metadata,
  ) async {
    if (await _requireOpenIndex().getAppValue(kRewrapInProgressKey) != 'true') {
      return;
    }
    await _rewrapVaultForTrustedDevice(session, metadata);
    await _setRewrapState(inProgress: false);
    await rebuildIndex(session);
  }

  Future<void> _setRewrapState({required bool inProgress}) async {
    final IndexDatabase indexDb = _requireOpenIndex();
    await indexDb.setAppValue(
      kRewrapInProgressKey,
      inProgress ? 'true' : 'false',
    );
    if (inProgress) {
      await indexDb.setAppValue(
        kRewrapStartedAtKey,
        DateTime.now().toIso8601String(),
      );
      return;
    }
    await indexDb.deleteAppValue(kRewrapStartedAtKey);
  }

  Future<List<String>> _copyChatFilesBesideEntry({
    required String fromEntryPath,
    required String toEntryPath,
    required UnlockedVaultSession session,
  }) async {
    if (fromEntryPath == toEntryPath) return const [];
    final from = VaultPathStrategy.chatFileBesideEntry(fromEntryPath);
    final to = VaultPathStrategy.chatFileBesideEntry(toEntryPath);
    final sources = <String, String>{};
    for (final suffix in ['', '.previous', '.tmp']) {
      final source = File('$from$suffix');
      if (source.existsSync()) sources[source.path] = '$to$suffix';
    }
    for (final entry in sources.entries) {
      final target = File(entry.value);
      if (!target.existsSync()) continue;
      final sourceBytes = await readDecryptedAssetBytes(session, entry.key);
      final targetBytes = await readDecryptedAssetBytes(session, entry.value);
      if (sourceBytes == null ||
          targetBytes == null ||
          !listEquals(sourceBytes, targetBytes)) {
        throw StateError('無法確認聊天紀錄內容一致');
      }
    }
    for (final entry in sources.entries) {
      final target = File(entry.value);
      if (target.existsSync()) continue;
      await target.parent.create(recursive: true);
      try {
        // .tmp 是聊天恢復檔，不能拿來當複製過程的暫存檔。
        await File(entry.key).copy(target.path);
      } on Object {
        await deleteFileIfExists(target.path);
        rethrow;
      }
    }
    return sources.keys.toList();
  }

  Future<void> deleteChatFilesBesideEntry(String entryPath) =>
      deleteEntryChatFiles(entryPath);

  Future<void> _deleteEntryFilesOnDisk({
    required DiaryEntrySummary record,
    required List<AssetAttachment> attachments,
  }) async {
    await deleteFileIfExists(record.filePath);
    await deleteChatFilesBesideEntry(record.filePath);
    await _deleteAttachmentsOnDisk(date: record.date, attachments: attachments);
  }

  Future<void> _deleteAttachmentsOnDisk({
    required DateOnly date,
    required Iterable<AssetAttachment> attachments,
  }) async {
    for (final AssetAttachment attachment in attachments) {
      final String assetPath = await _pathStrategy.attachmentAbsolutePath(
        date: date,
        attachment: attachment,
      );
      await deleteFileIfExists(assetPath);
    }
  }

  Future<void> _deleteObsoleteFilesAfterSave(Iterable<String> paths) async {
    // 儲存結果已可讀取後，舊檔清理失敗只會留下可修復的孤兒檔，不應把成功儲存回報為失敗。
    for (final String path in paths) {
      try {
        await deleteFileIfExists(path);
      } on FileSystemException {
        continue;
      }
    }
  }

  Future<T> runVaultMutation<T>(Future<T> Function() operation) {
    final Completer<T> completer = Completer<T>();
    final Future<void> previous = _mutationTail;
    _mutationTail = () async {
      try {
        await previous;
      } on Object {
        // 前一項錯誤已交還原呼叫端，不阻斷後續 vault 寫入。
      }
      try {
        completer.complete(await operation());
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    }();
    return completer.future;
  }

  String _generateRecoveryKey() {
    final String first = generateBackupId().replaceFirst('bkp_', '');
    final String second = generateBackupId().replaceFirst('bkp_', '');
    final String raw = '$first$second';
    return raw
        .replaceAll('_', '')
        .replaceAll('-', '')
        .substring(0, 24)
        .toUpperCase()
        .replaceAllMapped(
          RegExp(r'.{4}'),
          (Match match) => '${match.group(0)}-',
        )
        .replaceAll(RegExp(r'-$'), '');
  }

  Future<void> closeUnlockedResources() async {
    await _people.closeUnlockedResources();
    await _indexDatabaseManager.close();
  }

  Future<void> clearTrustedDeviceAccess() async {
    final RecoveryMetadata? metadata = await readRecoveryMetadata();
    if (metadata == null) {
      return;
    }
    await _deviceKeyManager.clearTrustedKey(metadata.vaultId);
  }

  /// 目前 session 的 Keystore 保護是否與解鎖模式偏好一致。
  Future<bool> needsKeystoreMigration(UnlockedVaultSession session) async {
    final KeystoreAuthKind expected = await _requireCurrentKeystoreAuthKind();
    final WrappedRecoveryKeyRecord? wrappedRecord = await _deviceKeyManager
        .readWrappedRecoveryKey(session.vaultId);
    String? syncedSuffix;
    try {
      syncedSuffix = await _requireOpenIndex().getAppValue(
        kKeystoreWrapModeKey,
      );
    } on StateError {
      return !keystoreSlotsMatchExpected(
        session: session,
        expected: expected,
        wrappedRecord: wrappedRecord,
      );
    }
    return !trustedProtectionMatches(
      session: session,
      expected: expected,
      syncedSuffix: syncedSuffix,
      wrappedRecord: wrappedRecord,
    );
  }

  Future<UnlockedVaultSession> ensureKeystoreMatchesUnlockMode(
    UnlockedVaultSession session, {
    AppUnlockMode? targetMode,
  }) async {
    if (targetMode != null) {
      final UnlockModeCapabilityFailure? failure =
          await precheckUnlockModeChange(
            appLock: _appLockService,
            mode: targetMode,
          );
      if (failure != null) {
        throw UnlockModeCapabilityException(failure);
      }
    }
    final KeystoreAuthKind expected = targetMode != null
        ? keystoreAuthFor(targetMode)
        : await _requireCurrentKeystoreAuthKind();
    final WrappedRecoveryKeyRecord? wrappedRecord = await _deviceKeyManager
        .readWrappedRecoveryKey(session.vaultId);
    String? syncedSuffix;
    try {
      syncedSuffix = await _requireOpenIndex().getAppValue(
        kKeystoreWrapModeKey,
      );
    } on StateError {
      await _openIndexForSession(session);
      syncedSuffix = await _requireOpenIndex().getAppValue(
        kKeystoreWrapModeKey,
      );
    }
    if (trustedProtectionMatches(
      session: session,
      expected: expected,
      syncedSuffix: syncedSuffix,
      wrappedRecord: wrappedRecord,
    )) {
      return session;
    }
    if (needsOnlyIndexSuffixSync(
      session: session,
      expected: expected,
      syncedSuffix: syncedSuffix,
      wrappedRecord: wrappedRecord,
    )) {
      await _requireOpenIndex().setAppValue(
        kKeystoreWrapModeKey,
        expected.storageSuffix,
      );
      return session;
    }
    final UnlockedVaultSession refreshed =
        await refreshTrustedSessionProtection(session, authKind: expected);
    await _requireOpenIndex().setAppValue(
      kKeystoreWrapModeKey,
      expected.storageSuffix,
    );
    return refreshed;
  }

  Future<UnlockedVaultSession> refreshTrustedSessionProtection(
    UnlockedVaultSession session, {
    required KeystoreAuthKind authKind,
  }) async {
    final RecoveryMetadata metadata = await _requireMetadataForSession(session);
    final TrustedDeviceInfo deviceInfo = await _deviceKeyManager
        .ensureDeviceKey(metadata.vaultId, authKind: authKind);
    await _storeWrappedRecoveryKey(
      vaultId: metadata.vaultId,
      recoveryWrapKey: requireRecoveryWrapKey(session),
      authKind: authKind,
    );
    return session.copyWith(deviceSlotId: deviceInfo.slotId);
  }

  /// 解鎖後 attach 搜尋索引：開啟連線、必要時重建不相容 schema、同步標籤樣式。
  ///
  /// schema 正常時不會全量 [rebuildIndex]；只有不相容時才從正式 vault 重建。
  /// 人物：只確保 analytics 表存在，不解密名冊、不背景全量 rebuild。
  Future<void> ensureIndexReady(UnlockedVaultSession session) async {
    await _openIndexForSession(session);
    if (!await _requireOpenIndex().hasExpectedIndexSchema()) {
      await _indexDatabaseManager.deleteDatabaseFiles();
      await _openIndexForSession(session);
      await rebuildIndex(session);
      return;
    }
    await _requireOpenIndex().ensurePeopleAnalyticsTable();
    await syncTagStylesBetweenVaultAndIndex();
  }

  Future<PeopleCatalog> readPeopleCatalog(UnlockedVaultSession session) =>
      _people.readPeopleCatalog(session);

  Future<List<Person>> listPeople(UnlockedVaultSession session) =>
      _people.listPeople(session);

  Future<List<RelationshipType>> listRelationshipTypes(
    UnlockedVaultSession session,
  ) => _people.listRelationshipTypes(session);

  Future<Person> createPerson(
    UnlockedVaultSession session,
    PersonDraft draft, {
    bool confirmWarnings = false,
  }) => _people.createPerson(session, draft, confirmWarnings: confirmWarnings);

  Future<Person> updatePerson(
    UnlockedVaultSession session,
    PersonId personId,
    PersonDraft draft, {
    bool confirmWarnings = false,
    bool addOldNameAsAlias = false,
  }) => _people.updatePerson(
    session,
    personId,
    draft,
    confirmWarnings: confirmWarnings,
    addOldNameAsAlias: addOldNameAsAlias,
  );

  Future<void> deletePerson(UnlockedVaultSession session, PersonId id) =>
      _people.deletePerson(session, id);

  /// 新增自訂關係類型；[label] 寫入當前語系，另一語拷貝同一字串。
  Future<RelationshipType> addRelationshipType(
    UnlockedVaultSession session, {
    required String label,
    required bool preferZh,
  }) => _people.addRelationshipType(session, label: label, preferZh: preferZh);

  /// 只改當前語系對應的 label；另一語不變。
  Future<RelationshipType> renameRelationshipType(
    UnlockedVaultSession session, {
    required String id,
    required String label,
    required bool preferZh,
  }) => _people.renameRelationshipType(
    session,
    id: id,
    label: label,
    preferZh: preferZh,
  );

  /// 刪除類型，並從所有人物 relationships 清掉該 id。回傳受影響人數。
  Future<int> deleteRelationshipType(UnlockedVaultSession session, String id) =>
      _people.deleteRelationshipType(session, id);

  /// 依 [orderedIds] 重排關係類型；必須剛好涵蓋現行全部 id。
  Future<void> reorderRelationshipTypes(
    UnlockedVaultSession session,
    List<String> orderedIds,
  ) => _people.reorderRelationshipTypes(session, orderedIds);

  /// 統計過期或尚未建立時自動全量重建；並行呼叫會共用同一個 in-flight Future。
  Future<void> ensurePeopleAnalyticsReady(UnlockedVaultSession session) =>
      _people.ensurePeopleAnalyticsReady(session);

  Future<Map<PersonId, PersonMentionStats>> allPersonMentionStats(
    UnlockedVaultSession session, {
    DateTime? now,
  }) => _people.allPersonMentionStats(session, now: now);

  Future<List<DiaryEntrySummary>> relatedEntriesForPerson(
    UnlockedVaultSession session,
    PersonId personId,
  ) => _people.relatedEntriesForPerson(session, personId);

  Future<List<PersonScopedMentionRank>> topMentionedPeople(
    UnlockedVaultSession session, {
    required int limit,
    String? yearPrefix,
    String? monthPrefix,
  }) => _people.topMentionedPeople(
    session,
    limit: limit,
    yearPrefix: yearPrefix,
    monthPrefix: monthPrefix,
  );

  @visibleForTesting
  Future<int> pendingPeopleAnalysisDocumentCountForTest(
    UnlockedVaultSession session,
  ) => _people.pendingPeopleAnalysisDocumentCountForTest(session);

  Future<void> _openIndexForSession(UnlockedVaultSession session) {
    return _indexDatabaseManager.openForSession(session);
  }

  IndexDatabase _requireOpenIndex() => _indexDatabaseManager.requireOpen();
}
