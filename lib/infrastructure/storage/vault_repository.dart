import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../domain/attachment/asset_attachment.dart';
import '../../domain/diary/diary_entry.dart';
import '../../domain/recovery/kdf_descriptor.dart';
import '../../domain/recovery/recovery_metadata.dart';
import '../../domain/security/unlocked_vault_session.dart';
import '../../domain/shared/value_objects.dart';
import '../crypto/crypto_service.dart';
import '../database/index_database.dart';
import '../database/index_database_manager.dart';
import '../markdown/front_matter_codec.dart';
import '../security/app_lock_service.dart';
import '../security/app_unlock_mode.dart';
import '../security/device_key_manager.dart';
import '../security/keystore_unlock_policy.dart';
import '../security/unlock_mode_policy.dart';
import 'restore_precheck.dart';
import 'pinned_entries_store.dart';
import 'tag_styles_store.dart';
import 'shared/media_type_utils.dart';
import 'shared/vault_file_ops.dart';
import 'vault_path_strategy.dart';
import 'vault_state_keys.dart';

/// UI 中已選取但尚未寫入加密 vault 的附件。
class PendingAttachment {
  PendingAttachment({
    this.bytes,
    this.sourcePath,
    required this.mimeType,
    required this.originalFilename,
  }) : assert(
         (bytes != null && bytes.isNotEmpty) ||
             (sourcePath != null && sourcePath.trim().isNotEmpty),
         'PendingAttachment 需要 bytes 或 sourcePath',
       );

  /// 內嵌或已讀入記憶體的附件（例如 HTML 資料 URI）。
  final Uint8List? bytes;

  /// 本機檔案路徑（編輯器選檔或匯入的外部圖片）。
  final String? sourcePath;
  final String mimeType;
  final String originalFilename;
}

/// 同流程建立新 Recovery Key 並完成可信裝置存取時回傳的結果。
class RecoverySetupResult {
  const RecoverySetupResult({required this.recoveryKey, required this.session});

  final String recoveryKey;
  final UnlockedVaultSession session;
}

class VaultRepairReport {
  const VaultRepairReport({
    required this.entryCount,
    required this.duration,
    required this.finishedAt,
    required this.relocatedEntries,
    required this.removedDuplicateEntries,
    required this.skippedCorruptEntries,
    required this.tagsAdded,
    required this.relocatedAssets,
    required this.removedOrphanAssets,
    this.warnings = const <String>[],
  });

  final int entryCount;
  final Duration duration;
  final DateTime finishedAt;
  final int relocatedEntries;
  final int removedDuplicateEntries;
  final int skippedCorruptEntries;
  final int tagsAdded;
  final int relocatedAssets;
  final int removedOrphanAssets;
  final List<String> warnings;
}

class _EntrySearchFields {
  const _EntrySearchFields({
    required this.previewText,
    required this.titleSearchText,
    required this.bodySearchText,
  });

  final String previewText;
  final String titleSearchText;
  final String bodySearchText;
}

class _ScannedEntry {
  const _ScannedEntry({
    required this.entry,
    required this.filePath,
    required this.markdown,
    required this.attachments,
    required this.searchFields,
    required this.encryptedFileSize,
    required this.encryptedModifiedAt,
  });

  final DiaryEntry entry;
  final String filePath;
  final String markdown;
  final List<AssetAttachment> attachments;
  final _EntrySearchFields searchFields;
  final int encryptedFileSize;
  final DateTime encryptedModifiedAt;
}

class _RawScannedEntry {
  const _RawScannedEntry({
    required this.entry,
    required this.filePath,
    required this.markdown,
    required this.attachments,
    required this.searchFields,
    required this.encryptedFileSize,
    required this.encryptedModifiedAt,
    required this.needsVaultIdRewrite,
  });

  final DiaryEntry entry;
  final String filePath;
  final String markdown;
  final List<AssetAttachment> attachments;
  final _EntrySearchFields searchFields;
  final int encryptedFileSize;
  final DateTime encryptedModifiedAt;
  final bool needsVaultIdRewrite;
}

class _EntryRepairStats {
  const _EntryRepairStats({
    required this.scanned,
    required this.relocatedEntries,
    required this.removedDuplicateEntries,
    required this.skippedCorruptEntries,
    required this.warnings,
  });

  final List<_ScannedEntry> scanned;
  final int relocatedEntries;
  final int removedDuplicateEntries;
  final int skippedCorruptEntries;
  final List<String> warnings;
}

class _AssetRepairStats {
  const _AssetRepairStats({
    required this.relocatedAssets,
    required this.removedOrphanAssets,
    required this.warnings,
  });

  final int relocatedAssets;
  final int removedOrphanAssets;
  final List<String> warnings;
}

/// 加密 vault 儲存的主要協調層。
///
/// 此儲存庫負責 Recovery Key 建立／解鎖、可信裝置 session 還原、
/// 加密條目／附件 I/O 與索引同步。
class VaultRepository {
  VaultRepository({
    required VaultPathStrategy pathStrategy,
    required FrontMatterCodec frontMatterCodec,
    required CryptoService cryptoService,
    required IndexDatabaseManager indexDatabaseManager,
    required DeviceKeyManager deviceKeyManager,
    required AppLockService appLockService,
  }) : _pathStrategy = pathStrategy,
       _frontMatterCodec = frontMatterCodec,
       _cryptoService = cryptoService,
       _indexDatabaseManager = indexDatabaseManager,
       _deviceKeyManager = deviceKeyManager,
       _appLockService = appLockService;

  final VaultPathStrategy _pathStrategy;
  final FrontMatterCodec _frontMatterCodec;
  final CryptoService _cryptoService;
  final IndexDatabaseManager _indexDatabaseManager;
  final DeviceKeyManager _deviceKeyManager;
  final AppLockService _appLockService;

  RecoveryMetadata? _cachedRecoveryMetadata;

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
        await readRecoveryMetadata() ?? (throw StateError('尚未建立復原金鑰。'));
    if (!await _deviceKeyManager.hasTrustedKey(metadata.vaultId)) {
      throw StateError('這台裝置尚未註冊，請使用復原金鑰解鎖。');
    }

    final WrappedRecoveryKeyRecord record =
        await _deviceKeyManager.readWrappedRecoveryKey(metadata.vaultId) ??
        (throw StateError('找不到可信裝置的 Recovery 金鑰資料。'));
    final TrustedDeviceInfo deviceInfo =
        await _deviceKeyManager.readDeviceInfo(metadata.vaultId) ??
        (throw StateError('找不到可信裝置資訊。'));
    if (record.slotId != deviceInfo.slotId) {
      await _deviceKeyManager.clearTrustedKey(metadata.vaultId);
      throw StateError('可信裝置資料不一致，請使用復原金鑰重新建立。');
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
        StateError('可信裝置資料已失效，請重新使用復原金鑰解鎖。'),
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
        await readRecoveryMetadata() ?? (throw StateError('尚未建立復原金鑰。'));
    final WrappedRecoveryKeyRecord record =
        await _deviceKeyManager.readWrappedRecoveryKey(metadata.vaultId) ??
        (throw StateError('找不到可信裝置的 Recovery 金鑰資料。'));
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
        formatVersion:
            WrappedRecoveryKeyRecord.kWrappedRecoveryKeyFormatVersion,
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
        await readRecoveryMetadata() ?? (throw StateError('尚未建立復原金鑰。'));
    if (priorSession.vaultId != metadata.vaultId) {
      throw StateError('還原後的日記庫與解鎖 session 不一致，請使用復原金鑰解鎖。');
    }

    final List<int> recoveryWrapKey = _requireRecoveryWrapKey(priorSession);
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
      recoveryKeyVersion: 1,
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
  Future<RecoverySetupResult> rotateRecoveryKey(
    UnlockedVaultSession session,
  ) async {
    final RecoveryMetadata oldMetadata = await _requireMetadataForSession(
      session,
    );
    final List<int> oldWrapKey = _requireRecoveryWrapKey(session);
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
      await rebuildIndex(updatedSession);
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
      throw StateError(kBackupRecoveryKeyMismatchMessage);
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
      throw StateError(wrapFailure.message);
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

  Future<List<EntryIndexRecord>> listEntries({
    String? searchQuery,
    DateOnly? date,
  }) {
    return _requireOpenIndex().listEntries(
      searchQuery: searchQuery,
      date: date,
    );
  }

  Future<List<DateOnly>> monthEntryDates(DateTime month) {
    return _requireOpenIndex().monthEntryDates(month);
  }

  Future<List<EntryIndexRecord>> listEntriesForMonth(DateTime month) {
    return _requireOpenIndex().listEntriesForMonth(month);
  }

  Future<DiaryEntry?> loadEntry(
    UnlockedVaultSession session,
    EntryId entryId,
  ) async {
    final EntryIndexRecord? indexRecord = await _requireOpenIndex()
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
      context: _decryptionContext(session),
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
    if (_sameStringLists(entry.attachmentIds, indexedIds)) {
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
    return PinnedEntriesStore(_pathStrategy).setPinnedMany(
      entryIds,
      pinned: pinned,
    );
  }

  Future<void> _prunePinnedEntriesToExisting(Iterable<EntryId> existingIds) {
    return PinnedEntriesStore(_pathStrategy).pruneTo(existingIds);
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

  Future<void> ensureTagCatalogLabels(Iterable<String> labels) async {
    final Set<String> seenNormalized = <String>{};
    final List<TagCatalogItem> overlay = <TagCatalogItem>[];
    for (final String raw in labels) {
      final String displayLabel = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
      final String normalized = normalizeText(displayLabel);
      if (normalized.isEmpty || !seenNormalized.add(normalized)) {
        continue;
      }
      overlay.add(TagCatalogItem(label: displayLabel));
    }
    if (overlay.isEmpty) {
      return;
    }
    final List<TagCatalogItem> catalog = await listTagCatalog();
    await _persistTagCatalogToVault(TagStylesStore.merge(catalog, overlay));
  }

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
    final List<EntryIndexRecord> records = await listEntries();
    int updatedCount = 0;
    for (final EntryIndexRecord record in records) {
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

      if (_entryTagsEqual(entry.tags, nextTags)) {
        continue;
      }

      await saveEntry(session, entry.copyWith(tags: nextTags));
      updatedCount++;
    }
    return updatedCount;
  }

  bool _entryTagsEqual(List<String> left, List<String> right) {
    if (left.length != right.length) {
      return false;
    }
    for (int i = 0; i < left.length; i++) {
      if (left[i] != right[i]) {
        return false;
      }
    }
    return true;
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

    final List<EntryIndexRecord> records = await listEntries();
    int updatedCount = 0;
    for (final EntryIndexRecord record in records) {
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

  Future<void> _applyTagCatalogFromVaultToIndex() async {
    final List<TagCatalogItem> catalog = await TagStylesStore(
      _pathStrategy,
    ).read();
    if (catalog.isEmpty) {
      return;
    }
    final IndexDatabase indexDb = _requireOpenIndex();
    for (final TagCatalogItem item in catalog) {
      if (item.accentArgb == null) {
        continue;
      }
      await indexDb.upsertTagAccentArgb(item.label, item.accentArgb!);
    }
  }

  /// 重建或還原後保持 vault 檔案與索引同步。
  Future<void> syncTagStylesBetweenVaultAndIndex() async {
    await _applyTagCatalogFromVaultToIndex();
  }

  Future<DiaryEntry> saveEntry(
    UnlockedVaultSession session,
    DiaryEntry draft, {
    List<PendingAttachment> pendingAttachments = const <PendingAttachment>[],
  }) async {
    final RecoveryMetadata metadata = await _requireMetadataForSession(session);
    final List<int> recoveryWrapKey = _requireRecoveryWrapKey(session);
    final IndexDatabase indexDb = _requireOpenIndex();
    final EntryIndexRecord? previousRecord = await indexDb.getEntryById(
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
    await _deleteAttachmentsOnDisk(
      date: previousDate,
      attachments: removedAttachments,
    );

    final List<AssetAttachment> newAttachments = await _storePendingAttachments(
      entry: draft,
      pendingAttachments: pendingAttachments,
      recoveryWrapKey: recoveryWrapKey,
      recoverySlotKdf: metadata.kdf,
      vaultId: metadata.vaultId,
    );

    final List<AssetAttachment> allAttachments = <AssetAttachment>[
      ...existingKept,
      ...newAttachments,
    ];
    final DateTime attachmentOrderBase = draft.createdAt;
    final List<AssetAttachment> orderedAttachments = <AssetAttachment>[
      for (int i = 0; i < allAttachments.length; i++)
        allAttachments[i].copyWith(
          createdAt: attachmentOrderBase.add(Duration(milliseconds: i)),
        ),
    ];
    final DiaryEntry normalized = draft.copyWith(
      vaultId: metadata.vaultId,
      attachmentIds: orderedAttachments
          .map((AssetAttachment asset) => asset.id)
          .toList(),
      updatedAt: DateTime.now(),
    );

    if (previousRecord != null && previousRecord.date != normalized.date) {
      for (final AssetAttachment attachment in existingKept) {
        final String oldPath = await _assetAbsolutePathFor(
          date: previousRecord.date,
          attachment: attachment,
        );
        await _relocateAssetFileIfNeeded(
          date: normalized.date,
          attachment: attachment,
          currentPath: oldPath,
        );
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
    await _atomicWriteBytes(File(filePath), fileBytes);
    if (previousRecord != null && previousRecord.filePath != filePath) {
      await deleteFileIfExists(previousRecord.filePath);
    }

    final _EntrySearchFields searchFields = _buildEntrySearchFields(normalized);

    await indexDb.upsertEntry(
      entry: normalized,
      filePath: filePath,
      previewText: searchFields.previewText,
      titleSearchText: searchFields.titleSearchText,
      bodySearchText: searchFields.bodySearchText,
      contentHash: await _hashString(markdown),
      encryptedFileSize: fileBytes.lengthInBytes,
      encryptedModifiedAt: DateTime.now(),
    );
    await indexDb.replaceAttachments(
      normalized.id,
      orderedAttachments,
      <AssetId, String>{
        for (final AssetAttachment attachment in orderedAttachments)
          attachment.id: await _assetAbsolutePathFor(
            date: normalized.date,
            attachment: attachment,
          ),
      },
    );
    await _writeEncryptedManifest(session, metadata);
    await ensureTagCatalogLabels(normalized.tags);
    return normalized;
  }

  Future<void> deleteEntry(
    UnlockedVaultSession session,
    EntryId entryId,
  ) async {
    final IndexDatabase indexDb = _requireOpenIndex();
    final EntryIndexRecord? record = await indexDb.getEntryById(entryId);
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

  Future<List<EntryIndexRecord>> searchEntries(String query) {
    return _requireOpenIndex().searchEntries(query);
  }

  Future<void> rebuildIndex(UnlockedVaultSession session) async {
    await _rebuildIndex(session);
  }

  Future<void> _rebuildIndex(
    UnlockedVaultSession session, {
    List<_ScannedEntry>? preScannedEntries,
  }) async {
    await _openIndexForSession(session);
    final RecoveryMetadata metadata = await _requireMetadataForSession(session);
    final IndexDatabase indexDb = _requireOpenIndex();
    await indexDb.rebuild();

    final Set<String> collectedTagLabels = <String>{};

    if (preScannedEntries != null) {
      for (final _ScannedEntry scanned in preScannedEntries) {
        await indexDb.upsertEntry(
          entry: scanned.entry,
          filePath: scanned.filePath,
          previewText: scanned.searchFields.previewText,
          titleSearchText: scanned.searchFields.titleSearchText,
          bodySearchText: scanned.searchFields.bodySearchText,
          contentHash: await _hashString(scanned.markdown),
          encryptedFileSize: scanned.encryptedFileSize,
          encryptedModifiedAt: scanned.encryptedModifiedAt,
        );
        await indexDb.replaceAttachments(
          scanned.entry.id,
          scanned.attachments,
          <AssetId, String>{
            for (final AssetAttachment attachment in scanned.attachments)
              attachment.id: await _pathStrategy.assetAbsolutePath(
                date: scanned.entry.date,
                assetId: attachment.id,
                extension: p
                    .extension(attachment.safeFilename)
                    .replaceFirst('.', ''),
              ),
          },
        );
        collectedTagLabels.addAll(scanned.entry.tags);
      }
    } else {
      final Directory vaultRoot = await _pathStrategy.vaultRootDirectory();
      final Directory entriesDirectory = Directory(
        p.join(vaultRoot.path, 'entries'),
      );
      if (entriesDirectory.existsSync()) {
        await for (final FileSystemEntity entity in entriesDirectory.list(
          recursive: true,
          followLinks: false,
        )) {
          if (entity is! File || !entity.path.endsWith('.md.enc')) {
            continue;
          }

          final ParsedEncryptedDocument parsed = _cryptoService.parseFileBytes(
            await entity.readAsBytes(),
          );
          final String markdown = await _cryptoService.decryptMarkdown(
            headerBytes: parsed.headerBytes,
            ciphertextBytes: parsed.ciphertextBytes,
            context: _decryptionContext(session),
          );
          final DiaryEntry entry = _frontMatterCodec
              .decode(markdown)
              .copyWith(vaultId: metadata.vaultId);
          final List<AssetAttachment> attachments =
              await _findAttachmentsForEntry(entry);
          final _EntrySearchFields searchFields = _buildEntrySearchFields(
            entry,
          );

          await indexDb.upsertEntry(
            entry: entry,
            filePath: entity.path,
            previewText: searchFields.previewText,
            titleSearchText: searchFields.titleSearchText,
            bodySearchText: searchFields.bodySearchText,
            contentHash: await _hashString(markdown),
            encryptedFileSize: await entity.length(),
            encryptedModifiedAt: await entity.lastModified(),
          );
          await indexDb
              .replaceAttachments(entry.id, attachments, <AssetId, String>{
                for (final AssetAttachment attachment in attachments)
                  attachment.id: await _pathStrategy.assetAbsolutePath(
                    date: entry.date,
                    assetId: attachment.id,
                    extension: p
                        .extension(attachment.safeFilename)
                        .replaceFirst('.', ''),
                  ),
              });
          collectedTagLabels.addAll(entry.tags);
        }
      }
    }

    await listTagCatalog();
    if (collectedTagLabels.isNotEmpty) {
      await ensureTagCatalogLabels(collectedTagLabels);
    }
    await indexDb.setAppValue(
      kLastRebuildAtKey,
      DateTime.now().toIso8601String(),
    );
    await indexDb.setAppValue(
      kIndexGenerationKey,
      IndexDatabase.indexGeneration.toString(),
    );
    await syncTagStylesBetweenVaultAndIndex();
    await _prunePinnedEntriesToExisting(
      (await listEntries()).map((EntryIndexRecord item) => item.id),
    );
  }

  Future<VaultRepairReport> repairVaultWithReport(
    UnlockedVaultSession session,
  ) async {
    final Stopwatch stopwatch = Stopwatch()..start();
    await _openIndexForSession(session);
    final RecoveryMetadata metadata = await _requireMetadataForSession(session);

    final _EntryRepairStats entryStats = await _scanAndRepairEntries(
      session,
      metadata,
    );

    await listTagCatalog();
    final Set<String> catalogNorms = (await listTagCatalog())
        .map((TagCatalogItem item) => item.normalized)
        .toSet();
    final Set<String> collectedTagLabels = <String>{};
    for (final _ScannedEntry scanned in entryStats.scanned) {
      collectedTagLabels.addAll(scanned.entry.tags);
    }
    var tagsAdded = 0;
    for (final String raw in collectedTagLabels) {
      final String displayLabel = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
      final String normalized = normalizeText(displayLabel);
      if (normalized.isEmpty || catalogNorms.contains(normalized)) {
        continue;
      }
      tagsAdded++;
      catalogNorms.add(normalized);
    }
    if (collectedTagLabels.isNotEmpty) {
      await ensureTagCatalogLabels(collectedTagLabels);
    }

    final _AssetRepairStats assetStats = await _repairAssets(
      entryStats.scanned,
    );

    final List<_ScannedEntry> indexEntries = <_ScannedEntry>[];
    for (final _ScannedEntry scanned in entryStats.scanned) {
      final List<AssetAttachment> attachments = await _findAttachmentsForEntry(
        scanned.entry,
      );
      indexEntries.add(
        _ScannedEntry(
          entry: scanned.entry,
          filePath: scanned.filePath,
          markdown: scanned.markdown,
          attachments: attachments,
          searchFields: scanned.searchFields,
          encryptedFileSize: scanned.encryptedFileSize,
          encryptedModifiedAt: scanned.encryptedModifiedAt,
        ),
      );
    }

    await _rebuildIndex(session, preScannedEntries: indexEntries);
    await _prunePinnedEntriesToExisting(
      indexEntries.map((_ScannedEntry item) => item.entry.id),
    );
    await _writeEncryptedManifest(session, metadata);

    stopwatch.stop();
    return VaultRepairReport(
      entryCount: indexEntries.length,
      duration: stopwatch.elapsed,
      finishedAt: DateTime.now(),
      relocatedEntries: entryStats.relocatedEntries,
      removedDuplicateEntries: entryStats.removedDuplicateEntries,
      skippedCorruptEntries: entryStats.skippedCorruptEntries,
      tagsAdded: tagsAdded,
      relocatedAssets: assetStats.relocatedAssets,
      removedOrphanAssets: assetStats.removedOrphanAssets,
      warnings: <String>[...entryStats.warnings, ...assetStats.warnings],
    );
  }

  Future<_EntryRepairStats> _scanAndRepairEntries(
    UnlockedVaultSession session,
    RecoveryMetadata metadata,
  ) async {
    final Directory vaultRoot = await _pathStrategy.vaultRootDirectory();
    final Directory entriesDirectory = Directory(
      p.join(vaultRoot.path, 'entries'),
    );
    if (!entriesDirectory.existsSync()) {
      return const _EntryRepairStats(
        scanned: <_ScannedEntry>[],
        relocatedEntries: 0,
        removedDuplicateEntries: 0,
        skippedCorruptEntries: 0,
        warnings: <String>[],
      );
    }

    final List<_RawScannedEntry> rawScans = <_RawScannedEntry>[];
    final List<String> warnings = <String>[];
    var skippedCorruptEntries = 0;

    await for (final FileSystemEntity entity in entriesDirectory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File || !entity.path.endsWith('.md.enc')) {
        continue;
      }

      try {
        final ParsedEncryptedDocument parsed = _cryptoService.parseFileBytes(
          await entity.readAsBytes(),
        );
        final String markdown = await _cryptoService.decryptMarkdown(
          headerBytes: parsed.headerBytes,
          ciphertextBytes: parsed.ciphertextBytes,
          context: _decryptionContext(session),
        );
        final DiaryEntry decoded = _frontMatterCodec.decode(markdown);
        final DiaryEntry entry = decoded.copyWith(vaultId: metadata.vaultId);
        final List<AssetAttachment> attachments =
            await _findAttachmentsForEntry(entry);
        rawScans.add(
          _RawScannedEntry(
            entry: entry,
            filePath: entity.path,
            markdown: markdown,
            attachments: attachments,
            searchFields: _buildEntrySearchFields(entry),
            encryptedFileSize: await entity.length(),
            encryptedModifiedAt: await entity.lastModified(),
            needsVaultIdRewrite: decoded.vaultId != metadata.vaultId,
          ),
        );
      } on Object {
        skippedCorruptEntries++;
        warnings.add(
          p.relative(entity.path, from: vaultRoot.path).replaceAll('\\', '/'),
        );
      }
    }

    final Map<String, List<_RawScannedEntry>> entriesById =
        <String, List<_RawScannedEntry>>{};
    for (final _RawScannedEntry raw in rawScans) {
      entriesById
          .putIfAbsent(raw.entry.id, () => <_RawScannedEntry>[])
          .add(raw);
    }

    final List<String> pathsToDelete = <String>[];
    var removedDuplicateEntries = 0;
    final List<_RawScannedEntry> authoritative = <_RawScannedEntry>[];
    for (final List<_RawScannedEntry> group in entriesById.values) {
      group.sort(
        (_RawScannedEntry a, _RawScannedEntry b) =>
            b.entry.updatedAt.compareTo(a.entry.updatedAt),
      );
      authoritative.add(group.first);
      for (var index = 1; index < group.length; index++) {
        pathsToDelete.add(group[index].filePath);
        removedDuplicateEntries++;
      }
    }

    var relocatedEntries = 0;
    final List<_ScannedEntry> scanned = <_ScannedEntry>[];
    for (final _RawScannedEntry raw in authoritative) {
      final String canonicalPath = await _pathStrategy.entryAbsolutePath(
        date: raw.entry.date,
        entryId: raw.entry.id,
      );
      final String currentPath = p.normalize(raw.filePath);
      final String normalizedCanonical = p.normalize(canonicalPath);
      var finalPath = currentPath;
      var finalMarkdown = raw.markdown;
      var finalSize = raw.encryptedFileSize;
      var finalModified = raw.encryptedModifiedAt;

      if (currentPath != normalizedCanonical || raw.needsVaultIdRewrite) {
        if (!raw.needsVaultIdRewrite && currentPath != normalizedCanonical) {
          final File sourceFile = File(currentPath);
          if (sourceFile.existsSync()) {
            final Directory parent = File(normalizedCanonical).parent;
            await parent.create(recursive: true);
            await sourceFile.rename(normalizedCanonical);
            finalPath = normalizedCanonical;
            finalSize = await File(finalPath).length();
            finalModified = await File(finalPath).lastModified();
            relocatedEntries++;
          }
        } else {
          finalPath = await _persistEntryForRepair(
            session: session,
            metadata: metadata,
            entry: raw.entry,
            attachments: raw.attachments,
            targetPath: normalizedCanonical,
            deletePathAfter: currentPath != normalizedCanonical
                ? currentPath
                : null,
          );
          finalMarkdown = _frontMatterCodec.encode(
            raw.entry,
            attachments: raw.attachments,
          );
          final File repairedFile = File(finalPath);
          finalSize = await repairedFile.length();
          finalModified = await repairedFile.lastModified();
          if (currentPath != normalizedCanonical) {
            relocatedEntries++;
          }
        }
      }

      scanned.add(
        _ScannedEntry(
          entry: raw.entry,
          filePath: finalPath,
          markdown: finalMarkdown,
          attachments: raw.attachments,
          searchFields: raw.searchFields,
          encryptedFileSize: finalSize,
          encryptedModifiedAt: finalModified,
        ),
      );
    }

    for (final String path in pathsToDelete) {
      await deleteFileIfExists(path);
    }

    return _EntryRepairStats(
      scanned: scanned,
      relocatedEntries: relocatedEntries,
      removedDuplicateEntries: removedDuplicateEntries,
      skippedCorruptEntries: skippedCorruptEntries,
      warnings: warnings,
    );
  }

  Future<String> _persistEntryForRepair({
    required UnlockedVaultSession session,
    required RecoveryMetadata metadata,
    required DiaryEntry entry,
    required List<AssetAttachment> attachments,
    required String targetPath,
    String? deletePathAfter,
  }) async {
    final List<int> recoveryWrapKey = _requireRecoveryWrapKey(session);
    final String markdown = _frontMatterCodec.encode(
      entry,
      attachments: attachments,
    );
    final EncryptionResult encryption = await _cryptoService.encryptMarkdown(
      documentId: entry.id,
      vaultId: metadata.vaultId,
      markdown: markdown,
      recoveryWrapKey: recoveryWrapKey,
      recoverySlotKdf: metadata.kdf,
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
    );
    await _atomicWriteBytes(File(targetPath), encryption.toFileBytes());
    if (deletePathAfter != null &&
        p.normalize(deletePathAfter) != p.normalize(targetPath)) {
      await deleteFileIfExists(deletePathAfter);
    }
    return targetPath;
  }

  Future<_AssetRepairStats> _repairAssets(List<_ScannedEntry> entries) async {
    final Set<String> referencedAssetIds = <String>{};
    final Map<String, DateOnly> assetDates = <String, DateOnly>{};
    for (final _ScannedEntry scanned in entries) {
      for (final AssetId assetId in scanned.entry.attachmentIds) {
        referencedAssetIds.add(assetId);
        assetDates[assetId] = scanned.entry.date;
      }
    }

    final List<String> warnings = <String>[];
    for (final String assetId in referencedAssetIds) {
      final bool foundOnDisk = await _assetExistsAnywhere(assetId);
      if (!foundOnDisk) {
        warnings.add('missing_asset:$assetId');
      }
    }

    final Directory vaultRoot = await _pathStrategy.vaultRootDirectory();
    final Directory assetsDirectory = Directory(
      p.join(vaultRoot.path, 'assets'),
    );
    if (!assetsDirectory.existsSync()) {
      return _AssetRepairStats(
        relocatedAssets: 0,
        removedOrphanAssets: 0,
        warnings: warnings,
      );
    }

    var relocatedAssets = 0;
    var removedOrphanAssets = 0;

    await for (final FileSystemEntity entity in assetsDirectory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File || !entity.path.endsWith('.enc')) {
        continue;
      }

      final String fileName = p.basename(entity.path).replaceFirst('.enc', '');
      final String assetId = p.basenameWithoutExtension(fileName);
      if (!referencedAssetIds.contains(assetId)) {
        await entity.delete();
        removedOrphanAssets++;
        continue;
      }

      final DateOnly? date = assetDates[assetId];
      if (date == null) {
        continue;
      }

      final String extension = p.extension(fileName).replaceFirst('.', '');
      final String canonicalPath = await _pathStrategy.assetAbsolutePath(
        date: date,
        assetId: assetId,
        extension: extension.isEmpty ? 'bin' : extension,
      );
      if (p.normalize(entity.path) == p.normalize(canonicalPath)) {
        continue;
      }

      final bool moved = await _relocateAssetFileIfNeeded(
        date: date,
        attachment: AssetAttachment(
          id: assetId,
          entryId: '',
          mimeType: mimeTypeFromExtension(extension),
          safeFilename: fileName,
          byteSize: await entity.length(),
          createdAt: await entity.lastModified(),
          sha256: '',
        ),
        currentPath: entity.path,
      );
      if (moved) {
        relocatedAssets++;
      }
    }

    return _AssetRepairStats(
      relocatedAssets: relocatedAssets,
      removedOrphanAssets: removedOrphanAssets,
      warnings: warnings,
    );
  }

  Future<bool> _assetExistsAnywhere(String assetId) async {
    final Directory vaultRoot = await _pathStrategy.vaultRootDirectory();
    final Directory assetsDirectory = Directory(
      p.join(vaultRoot.path, 'assets'),
    );
    if (!assetsDirectory.existsSync()) {
      return false;
    }

    await for (final FileSystemEntity entity in assetsDirectory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File || !entity.path.endsWith('.enc')) {
        continue;
      }
      final String fileName = p.basename(entity.path).replaceFirst('.enc', '');
      if (p.basenameWithoutExtension(fileName) == assetId) {
        return true;
      }
    }
    return false;
  }

  Future<bool> _relocateAssetFileIfNeeded({
    required DateOnly date,
    required AssetAttachment attachment,
    required String currentPath,
  }) async {
    final String newPath = await _assetAbsolutePathFor(
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
    final Directory newParent = File(newPath).parent;
    await newParent.create(recursive: true);
    await oldFile.rename(newPath);
    return true;
  }

  DecryptionContext _decryptionContext(UnlockedVaultSession session) {
    return DecryptionContext(
      vaultId: session.vaultId,
      trustedDevice: session.trustedDevice,
      recoveryWrapKey: session.recoveryWrapKey,
      deviceSlotId: session.deviceSlotId,
    );
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
        context: _decryptionContext(session),
      );
      return Uint8List.fromList(plain);
    } on Object {
      return null;
    }
  }

  /// 僅在 catalog 為空時寫入預設標籤；已存在則 no-op。需 index 已開啟。
  /// [locale] 應與目前 App 介面語系一致（例如 [Localizations.localeOf]）。
  Future<bool> seedDefaultTagCatalogIfEmpty({required Locale locale}) async {
    final List<TagCatalogItem> existing = await listTagCatalog();
    if (existing.isNotEmpty) {
      return false;
    }
    final List<TagCatalogItem> defaultCatalog = defaultTagCatalogForLocale(
      locale,
    );
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

  List<int> _requireRecoveryWrapKey(UnlockedVaultSession session) {
    final List<int>? recoveryWrapKey = session.recoveryWrapKey;
    if (recoveryWrapKey == null) {
      throw StateError('目前 session 沒有可用的 Recovery wrapping key。');
    }
    return recoveryWrapKey;
  }

  Future<void> _verifyRecoveryDecryptFile(
    File file,
    DecryptionContext recoveryContext,
  ) async {
    final ParsedEncryptedDocument parsed = _cryptoService.parseFileBytes(
      await file.readAsBytes(),
    );
    try {
      await _cryptoService.decryptBytes(
        headerBytes: parsed.headerBytes,
        ciphertextBytes: parsed.ciphertextBytes,
        context: recoveryContext,
      );
    } on SecretBoxAuthenticationError {
      throw StateError('復原金鑰與日記庫資料不相符。若為更新金鑰前的舊備份，請輸入建立該備份時保存的復原金鑰。');
    }
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

    return <File>[...entryEncrypted, ...otherEncrypted];
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
    String? authFailurePath;
    bool sawParsableEncryptedFile = false;
    for (final File file in fallbackTargets) {
      late final ParsedEncryptedDocument parsed;
      try {
        parsed = _cryptoService.parseFileBytes(await file.readAsBytes());
      } on Object catch (parseErr, _) {
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
        authFailurePath ??= file.path;
      } on Object catch (decryptErr, _) {
        verificationProblem ??= decryptErr;
      }
    }

    if (verificationProblem != null) {
      throw StateError(
        '無法用現有加密檔驗證復原金鑰（至少一個檔案疑似毀損或格式異常）。'
        ' 最近一次驗證問題：$verificationProblem',
      );
    }

    if (sawParsableEncryptedFile && authFailurePath != null) {
      throw StateError('復原金鑰與現有日記庫資料不相符。（路徑：$authFailurePath）');
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
    final List<EntryIndexRecord> entries = await listEntries();
    final Map<String, Object?> manifest = <String, Object?>{
      'vault_id': metadata.vaultId,
      'entry_count': entries.length,
      'asset_count': 0,
      'oldest_entry_date': entries.isEmpty ? null : entries.last.date.value,
      'newest_entry_date': entries.isEmpty ? null : entries.first.date.value,
      'app_version': '1.0.0',
    };

    final EncryptionResult encryption = await _cryptoService.encryptBytes(
      documentId: 'manifest',
      vaultId: metadata.vaultId,
      plaintextBytes: utf8.encode(jsonEncode(manifest)),
      contentType: 'application/json',
      recoveryWrapKey: _requireRecoveryWrapKey(session),
      recoverySlotKdf: metadata.kdf,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _atomicWriteBytes(
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
      final AssetId assetId = generateAssetId();
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
      final EncryptionResult encrypted = await _cryptoService.encryptBytes(
        documentId: assetId,
        vaultId: vaultId,
        plaintextBytes: sourceBytes,
        contentType: pending.mimeType,
        recoveryWrapKey: recoveryWrapKey,
        recoverySlotKdf: recoverySlotKdf,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final String assetPath = await _pathStrategy.assetAbsolutePath(
        date: entry.date,
        assetId: assetId,
        extension: extension.isEmpty ? 'bin' : extension,
      );
      await _atomicWriteBytes(File(assetPath), encrypted.toFileBytes());
      results.add(
        AssetAttachment(
          id: assetId,
          entryId: entry.id,
          mimeType: pending.mimeType,
          originalFilename: originalFilename.isEmpty ? null : originalFilename,
          safeFilename: safeFilename,
          byteSize: sourceBytes.length,
          createdAt: DateTime.now(),
          sha256: await _hashBytes(sourceBytes),
        ),
      );
    }
    return results;
  }

  Future<List<AssetAttachment>> _findAttachmentsForEntry(
    DiaryEntry entry,
  ) async {
    final Directory vaultRoot = await _pathStrategy.vaultRootDirectory();
    final Directory assetsDirectory = Directory(
      p.join(vaultRoot.path, 'assets'),
    );
    if (!assetsDirectory.existsSync()) {
      return const <AssetAttachment>[];
    }

    final List<AssetAttachment> matches = <AssetAttachment>[];
    await for (final FileSystemEntity entity in assetsDirectory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File || !entity.path.endsWith('.enc')) {
        continue;
      }

      final String fileName = p.basename(entity.path).replaceFirst('.enc', '');
      final String assetId = p.basenameWithoutExtension(fileName);
      if (!entry.attachmentIds.contains(assetId)) {
        continue;
      }
      matches.add(
        AssetAttachment(
          id: assetId,
          entryId: entry.id,
          mimeType: mimeTypeFromExtension(p.extension(fileName)),
          safeFilename: fileName,
          byteSize: await entity.length(),
          createdAt: await entity.lastModified(),
          sha256: '',
        ),
      );
    }
    return matches;
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
      await _atomicWriteBytes(file, encryption.toFileBytes());
    }
  }

  Future<void> _rewrapVaultForTrustedDevice(
    UnlockedVaultSession session,
    RecoveryMetadata metadata,
  ) async {
    final List<File> files = await _allEncryptedFiles();
    final List<int> recoveryWrapKey = _requireRecoveryWrapKey(session);
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
      await _atomicWriteBytes(file, encryption.toFileBytes());
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
      if (entity.path.endsWith('.enc')) {
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
        formatVersion:
            WrappedRecoveryKeyRecord.kWrappedRecoveryKeyFormatVersion,
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

  Future<void> _deleteEntryFilesOnDisk({
    required EntryIndexRecord record,
    required List<AssetAttachment> attachments,
  }) async {
    await deleteFileIfExists(record.filePath);
    await _deleteAttachmentsOnDisk(date: record.date, attachments: attachments);
  }

  Future<String> _assetAbsolutePathFor({
    required DateOnly date,
    required AssetAttachment attachment,
  }) async {
    final String extension = p
        .extension(attachment.safeFilename)
        .replaceFirst('.', '');
    return _pathStrategy.assetAbsolutePath(
      date: date,
      assetId: attachment.id,
      extension: extension.isEmpty ? 'bin' : extension,
    );
  }

  Future<void> _deleteAttachmentsOnDisk({
    required DateOnly date,
    required Iterable<AssetAttachment> attachments,
  }) async {
    for (final AssetAttachment attachment in attachments) {
      final String assetPath = await _assetAbsolutePathFor(
        date: date,
        attachment: attachment,
      );
      await deleteFileIfExists(assetPath);
    }
  }

  Future<void> _atomicWriteBytes(File file, Uint8List bytes) async {
    await file.parent.create(recursive: true);
    final File tempFile = File('${file.path}.tmp');
    await tempFile.writeAsBytes(bytes, flush: true);
    if (file.existsSync()) {
      await file.delete();
    }
    await tempFile.rename(file.path);
  }

  Future<String> _hashString(String value) async {
    return _hashBytes(utf8.encode(value));
  }

  Future<String> _hashBytes(List<int> bytes) async {
    final Hash hash = await Sha256().hash(bytes);
    return hash.bytes
        .map((int byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
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

  Future<void> closeUnlockedResources() {
    return _indexDatabaseManager.close();
  }

  Future<void> clearTrustedDeviceAccess() async {
    final RecoveryMetadata? metadata = await readRecoveryMetadata();
    if (metadata == null) {
      return;
    }
    await _deviceKeyManager.clearTrustedKey(metadata.vaultId);
  }

  Future<void> deleteDerivedLocalState() {
    return _indexDatabaseManager.deleteDatabaseFiles();
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
        throw StateError(failure.message);
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
      recoveryWrapKey: _requireRecoveryWrapKey(session),
      authKind: authKind,
    );
    return session.copyWith(deviceSlotId: deviceInfo.slotId);
  }

  /// 解鎖後 attach 搜尋索引：開啟連線、必要時重置損壞 schema、同步標籤樣式。
  ///
  /// 不會全量 [rebuildIndex]；vault 變更後的重建由還原、金鑰替換或手動修復觸發。
  Future<void> ensureIndexReady(UnlockedVaultSession session) async {
    await _openIndexForSession(session);
    if (!await _requireOpenIndex().hasExpectedIndexSchema()) {
      await _indexDatabaseManager.deleteDatabaseFiles();
      await _openIndexForSession(session);
      return;
    }
    await syncTagStylesBetweenVaultAndIndex();
  }

  /// 測試用：清除索引中的 Keystore 後綴同步欄位。
  @visibleForTesting
  Future<void> deleteKeystoreWrapModeSuffixForTest() async {
    await _requireOpenIndex().deleteAppValue(kKeystoreWrapModeKey);
  }

  Future<void> _openIndexForSession(UnlockedVaultSession session) {
    return _indexDatabaseManager.openForSession(session);
  }

  IndexDatabase _requireOpenIndex() => _indexDatabaseManager.requireOpen();

  bool _sameStringLists(List<String> left, List<String> right) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) {
        return false;
      }
    }
    return true;
  }

  _EntrySearchFields _buildEntrySearchFields(DiaryEntry entry) {
    return _EntrySearchFields(
      previewText: previewTextFromMarkdown(entry.markdownBody),
      titleSearchText: _titleSearchText(entry.title),
      bodySearchText: _bodySearchText(entry.markdownBody),
    );
  }

  String _titleSearchText(String? title) {
    final String? trimmed = title?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return '';
    }
    return normalizeSearchText(trimmed);
  }

  String _bodySearchText(String markdownBody) {
    return normalizeSearchText(searchableTextFromMarkdown(markdownBody));
  }
}
