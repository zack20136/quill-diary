import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
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
import 'tag_styles_store.dart';
import 'shared/media_type_utils.dart';
import 'shared/vault_file_ops.dart';
import 'vault_path_strategy.dart';
import 'vault_state_keys.dart';

/// Attachment selected in the UI but not yet persisted into the encrypted vault.
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

  /// 內嵌或已讀入記憶體的附件（例如 HTML data URI）。
  final Uint8List? bytes;

  /// 本機檔案路徑（編輯器選檔或匯入的外部圖片）。
  final String? sourcePath;
  final String mimeType;
  final String originalFilename;
}

/// Result returned when a new Recovery Key is created and trusted-device access
/// is established in the same flow.
class RecoverySetupResult {
  const RecoverySetupResult({
    required this.recoveryKey,
    required this.session,
  });

  final String recoveryKey;
  final UnlockedVaultSession session;
}

class IndexRebuildReport {
  const IndexRebuildReport({
    required this.entryCount,
    required this.duration,
    required this.finishedAt,
  });

  final int entryCount;
  final Duration duration;
  final DateTime finishedAt;
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

/// Main coordination layer for encrypted vault storage.
///
/// This repository owns Recovery Key setup/unlock, trusted-device session
/// restoration, encrypted entry/asset I/O, and index synchronization.
class VaultRepository {
  VaultRepository({
    required VaultPathStrategy pathStrategy,
    required FrontMatterCodec frontMatterCodec,
    required CryptoService cryptoService,
    required IndexDatabaseManager indexDatabaseManager,
    required DeviceKeyManager deviceKeyManager,
    required AppLockService appLockService,
  })  : _pathStrategy = pathStrategy,
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
    final TrustedDeviceInfo deviceInfo = await _deviceKeyManager.readDeviceInfo(metadata.vaultId) ??
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
        StateError(
          '可信裝置資料已失效，請重新使用復原金鑰解鎖。',
        ),
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

  /// 還原同 vault 後沿用還原前 session 的 wrap key，不再觸發裝置驗證。
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
        StateError(
          '日記庫重新包裝未完成，下次啟動會自動繼續。若問題持續，請檢查加密檔是否毀損。',
        ),
        stackTrace,
      );
    }
    return session;
  }

  /// 在從備份還原並覆寫 vault 目錄後呼叫，避免仍沿用記憶體內舊的 recovery metadata。
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
    final List<int> recoveryWrapKey = await _cryptoService.deriveRecoveryWrapKey(
      recoveryKey: recoveryKey,
      kdf: recoveryKdf,
    );

    final RecoveryMetadata metadata = RecoveryMetadata(
      vaultId: generateVaultId(),
      recoveryEnabled: true,
      recoveryKeyVersion: 1,
      recoveryKeyHint: recoveryKey.substring(recoveryKey.length - 4),
      createdAt: DateTime.now(),
      kdf: recoveryKdf,
    );

    final KeystoreAuthKind authKind = await _requireCurrentKeystoreAuthKind();
    final TrustedDeviceInfo deviceInfo = await _deviceKeyManager.ensureDeviceKey(
      metadata.vaultId,
      authKind: authKind,
    );

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
    await _seedDefaultTagCatalog();

    return RecoverySetupResult(
      recoveryKey: recoveryKey,
      session: session,
    );
  }

  /// 輪替復原金鑰：先重加密 vault，最後才更新 [recovery.json]。
  Future<RecoverySetupResult> rotateRecoveryKey(UnlockedVaultSession session) async {
    final RecoveryMetadata oldMetadata = await _requireMetadataForSession(session);
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

      UnlockedVaultSession updatedSession = session.copyWith(recoveryWrapKey: newWrapKey);
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
    final List<int> recoveryWrapKey = await _cryptoService.deriveRecoveryWrapKey(
      recoveryKey: recoveryKey,
      kdf: metadata.kdf,
    );
    final ParsedEncryptedDocument parsed =
        _cryptoService.parseFileBytes(encryptedDocumentBytes);
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
        await readRecoveryMetadata() ?? (throw StateError('找不到 Recovery metadata。'));
    final List<int> recoveryWrapKey = await _cryptoService.deriveRecoveryWrapKey(
      recoveryKey: recoveryKey,
      kdf: metadata.kdf,
    );
    await _verifyRecoveryKey(metadata, recoveryWrapKey);

    final AppUnlockMode unlockMode = await _appLockService.getUnlockMode();
    final UnlockModeCapabilityFailure? wrapFailure = await precheckUnlockModeChange(
      appLock: _appLockService,
      mode: unlockMode,
    );
    if (wrapFailure != null) {
      throw StateError(wrapFailure.message);
    }
    final KeystoreAuthKind authKind = keystoreAuthFor(unlockMode);
    final TrustedDeviceInfo deviceInfo = await _deviceKeyManager.ensureDeviceKey(
      metadata.vaultId,
      authKind: authKind,
    );

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
        StateError(
          '日記庫重新包裝失敗，已保留進行中旗標以便下次自動續跑。',
        ),
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
    return _requireOpenIndex().listEntries(searchQuery: searchQuery, date: date);
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
    final EntryIndexRecord? indexRecord = await _requireOpenIndex().getEntryById(entryId);
    if (indexRecord == null) {
      return null;
    }

    final File file = File(indexRecord.filePath);
    if (!file.existsSync()) {
      return null;
    }

    final ParsedEncryptedDocument parsed = _cryptoService.parseFileBytes(await file.readAsBytes());
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
    final List<AssetAttachment> attachments =
        await _requireOpenIndex().attachmentsForEntry(entry.id);
    if (attachments.isEmpty) {
      return entry;
    }

    final List<AssetId> indexedIds =
        attachments.map((AssetAttachment attachment) => attachment.id).toList(growable: false);
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

  Future<void> upsertTagCatalogItem(String label, {int? accentArgb}) async {
    final String displayLabel = label.trim().replaceAll(RegExp(r'\s+'), ' ');
    final String normalized = normalizeText(displayLabel);
    if (normalized.isEmpty) {
      throw ArgumentError.value(label, 'label', '標籤名稱不可為空白');
    }

    final List<TagCatalogItem> catalog = await listTagCatalog();
    final List<TagCatalogItem> merged = TagStylesStore.merge(
      catalog,
      <TagCatalogItem>[TagCatalogItem(label: displayLabel, accentArgb: accentArgb)],
    );
    await _persistTagCatalogToVault(merged);
    final TagCatalogItem saved = merged.firstWhere(
      (TagCatalogItem item) => item.normalized == normalized,
    );
    if (saved.accentArgb != null) {
      await _requireOpenIndex().upsertTagAccentArgb(saved.label, saved.accentArgb!);
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

  Future<void> upsertTagAccentArgb(String tag, int accentArgb) async {
    await upsertTagCatalogItem(tag, accentArgb: accentArgb);
  }

  Future<void> deleteTagAccentArgb(String tag) async {
    await deleteTagCatalogItem(tag);
  }

  /// Removes [tag] from every diary entry and clears any saved accent color.
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
      final bool hasTag = record.tags.any((String t) => normalizeText(t) == normalized);
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
    final List<TagCatalogItem> catalog = await TagStylesStore(_pathStrategy).read();
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

  /// Keeps vault file and index in sync after rebuild or restore.
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
    final EntryIndexRecord? previousRecord = await indexDb.getEntryById(draft.id);
    final DateOnly previousDate = previousRecord?.date ?? draft.date;
    final List<AssetAttachment> existingFromDb = await indexDb.attachmentsForEntry(draft.id);
    final Set<AssetId> keepExistingIds = draft.attachmentIds.toSet();
    final Map<AssetId, AssetAttachment> existingById = <AssetId, AssetAttachment>{
      for (final AssetAttachment attachment in existingFromDb) attachment.id: attachment,
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
    await _deleteAttachmentsOnDisk(date: previousDate, attachments: removedAttachments);

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
      attachmentIds: orderedAttachments.map((AssetAttachment asset) => asset.id).toList(),
      updatedAt: DateTime.now(),
    );

    if (previousRecord != null && previousRecord.date != normalized.date) {
      for (final AssetAttachment attachment in existingKept) {
        final String oldPath =
            await _assetAbsolutePathFor(date: previousRecord.date, attachment: attachment);
        final String newPath =
            await _assetAbsolutePathFor(date: normalized.date, attachment: attachment);
        if (oldPath == newPath) {
          continue;
        }
        final File oldFile = File(oldPath);
        if (!oldFile.existsSync()) {
          continue;
        }
        final Directory newParent = File(newPath).parent;
        if (!newParent.existsSync()) {
          await newParent.create(recursive: true);
        }
        await oldFile.rename(newPath);
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

    final List<AssetAttachment> attachments = await indexDb.attachmentsForEntry(entryId);
    await _deleteEntryFilesOnDisk(record: record, attachments: attachments);
    await indexDb.removeEntry(entryId);

    final RecoveryMetadata metadata = await _requireMetadataForSession(session);
    await _writeEncryptedManifest(session, metadata);
  }

  Future<List<EntryIndexRecord>> searchEntries(String query) {
    return _requireOpenIndex().searchEntries(query);
  }

  Future<void> rebuildIndex(UnlockedVaultSession session) async {
    await _openIndexForSession(session);
    final RecoveryMetadata metadata = await _requireMetadataForSession(session);
    final IndexDatabase indexDb = _requireOpenIndex();
    await indexDb.rebuild();

    final Directory vaultRoot = await _pathStrategy.vaultRootDirectory();
    final Directory entriesDirectory = Directory(p.join(vaultRoot.path, 'entries'));
    if (!entriesDirectory.existsSync()) {
      await indexDb.setAppValue(kLastRebuildAtKey, DateTime.now().toIso8601String());
      await indexDb.setAppValue(
        kSearchSchemaVersionKey,
        IndexDatabase.searchSchemaVersion.toString(),
      );
      return;
    }

    await for (final FileSystemEntity entity
        in entriesDirectory.list(recursive: true, followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.md.enc')) {
        continue;
      }

      final ParsedEncryptedDocument parsed = _cryptoService.parseFileBytes(await entity.readAsBytes());
      final String markdown = await _cryptoService.decryptMarkdown(
        headerBytes: parsed.headerBytes,
        ciphertextBytes: parsed.ciphertextBytes,
        context: _decryptionContext(session),
      );
      final DiaryEntry entry = _frontMatterCodec.decode(markdown).copyWith(
            vaultId: metadata.vaultId,
          );
      final List<AssetAttachment> attachments = await _findAttachmentsForEntry(entry);
      final _EntrySearchFields searchFields = _buildEntrySearchFields(entry);

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
      await indexDb.replaceAttachments(
        entry.id,
        attachments,
        <AssetId, String>{
          for (final AssetAttachment attachment in attachments)
            attachment.id: await _pathStrategy.assetAbsolutePath(
              date: entry.date,
              assetId: attachment.id,
              extension: p.extension(attachment.safeFilename).replaceFirst('.', ''),
            ),
        },
      );
    }

    await indexDb.setAppValue(kLastRebuildAtKey, DateTime.now().toIso8601String());
    await indexDb.setAppValue(
      kSearchSchemaVersionKey,
      IndexDatabase.searchSchemaVersion.toString(),
    );
    await syncTagStylesBetweenVaultAndIndex();
  }

  Future<IndexRebuildReport> rebuildIndexWithReport(UnlockedVaultSession session) async {
    final Stopwatch stopwatch = Stopwatch()..start();
    await rebuildIndex(session);
    final List<EntryIndexRecord> entries = await listEntries();
    stopwatch.stop();
    return IndexRebuildReport(
      entryCount: entries.length,
      duration: stopwatch.elapsed,
      finishedAt: DateTime.now(),
    );
  }

  DecryptionContext _decryptionContext(UnlockedVaultSession session) {
    return DecryptionContext(
      vaultId: session.vaultId,
      trustedDevice: session.trustedDevice,
      recoveryWrapKey: session.recoveryWrapKey,
      deviceSlotId: session.deviceSlotId,
    );
  }

  /// Reads and decrypts a vault asset (`.enc` on disk) for in-memory preview — e.g. list thumbnails.
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
      final ParsedEncryptedDocument parsed = _cryptoService.parseFileBytes(await file.readAsBytes());
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

  Future<void> _seedDefaultTagCatalog() async {
    final List<TagCatalogItem> existing = await listTagCatalog();
    if (existing.isNotEmpty) {
      return;
    }
    await _persistTagCatalogToVault(kDefaultTagCatalog);
    final IndexDatabase indexDb = _requireOpenIndex();
    for (final TagCatalogItem item in kDefaultTagCatalog) {
      if (item.accentArgb == null) {
        continue;
      }
      await indexDb.upsertTagAccentArgb(item.label, item.accentArgb!);
    }
  }

  Future<RecoveryMetadata> _requireMetadataForSession(UnlockedVaultSession session) async {
    final RecoveryMetadata metadata =
        await readRecoveryMetadata() ?? (throw StateError('找不到 Recovery metadata。'));
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
    final ParsedEncryptedDocument parsed = _cryptoService.parseFileBytes(await file.readAsBytes());
    try {
      await _cryptoService.decryptBytes(
        headerBytes: parsed.headerBytes,
        ciphertextBytes: parsed.ciphertextBytes,
        context: recoveryContext,
      );
    } on SecretBoxAuthenticationError {
      throw StateError(
        '復原金鑰與日記庫資料不相符。若為更新金鑰前的舊備份，請輸入建立該備份時保存的復原金鑰。',
      );
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

    await for (final FileSystemEntity entity
        in vaultRoot.list(recursive: true, followLinks: false)) {
      if (entity is! File) {
        continue;
      }
      if (!_isUnderVaultContentSubdir(entity.path, vaultRoot.path)) {
        continue;
      }
      if (entity.path == manifestPath || !entity.path.toLowerCase().endsWith('.enc')) {
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

    final List<File> fallbackTargets = await _encryptedFilesForRecoveryVerification();
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
      throw StateError(
        '復原金鑰與現有日記庫資料不相符。（路徑：$authFailurePath）',
      );
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
      'schema_version': 1,
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
      final String originalFilename = p.basename(pending.originalFilename.trim());
      final String extension = p.extension(originalFilename).replaceFirst('.', '');
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

  Future<List<AssetAttachment>> _findAttachmentsForEntry(DiaryEntry entry) async {
    final Directory vaultRoot = await _pathStrategy.vaultRootDirectory();
    final Directory assetsDirectory = Directory(p.join(vaultRoot.path, 'assets'));
    if (!assetsDirectory.existsSync()) {
      return const <AssetAttachment>[];
    }

    final List<AssetAttachment> matches = <AssetAttachment>[];
    await for (final FileSystemEntity entity
        in assetsDirectory.list(recursive: true, followLinks: false)) {
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
      final ParsedEncryptedDocument parsed = _cryptoService.parseFileBytes(await file.readAsBytes());
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
      final ParsedEncryptedDocument parsed = _cryptoService.parseFileBytes(await file.readAsBytes());
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
    final List<File> files = <File>[
      if (manifest.existsSync()) manifest,
    ];

    await for (final FileSystemEntity entity
        in vaultRoot.list(recursive: true, followLinks: false)) {
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
    final DeviceWrappedPayload payload = await _deviceKeyManager.wrapWithDeviceKey(
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
        formatVersion: WrappedRecoveryKeyRecord.kWrappedRecoveryKeyFormatVersion,
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
    await indexDb.setAppValue(kRewrapInProgressKey, inProgress ? 'true' : 'false');
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
    final String extension = p.extension(attachment.safeFilename).replaceFirst('.', '');
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
      final String assetPath = await _assetAbsolutePathFor(date: date, attachment: attachment);
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
    return hash.bytes.map((int byte) => byte.toRadixString(16).padLeft(2, '0')).join();
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
        .replaceAllMapped(RegExp(r'.{4}'), (Match match) => '${match.group(0)}-')
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
    final WrappedRecoveryKeyRecord? wrappedRecord =
        await _deviceKeyManager.readWrappedRecoveryKey(session.vaultId);
    String? syncedSuffix;
    try {
      syncedSuffix = await _requireOpenIndex().getAppValue(kKeystoreWrapModeKey);
    } on StateError {
      return true;
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
      final UnlockModeCapabilityFailure? failure = await precheckUnlockModeChange(
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
    final WrappedRecoveryKeyRecord? wrappedRecord =
        await _deviceKeyManager.readWrappedRecoveryKey(session.vaultId);
    String? syncedSuffix;
    try {
      syncedSuffix = await _requireOpenIndex().getAppValue(kKeystoreWrapModeKey);
    } on StateError {
      await _openIndexForSession(session);
      syncedSuffix = await _requireOpenIndex().getAppValue(kKeystoreWrapModeKey);
    }
    if (trustedProtectionMatches(
      session: session,
      expected: expected,
      syncedSuffix: syncedSuffix,
      wrappedRecord: wrappedRecord,
    )) {
      return session;
    }
    final UnlockedVaultSession refreshed = await refreshTrustedSessionProtection(
      session,
      authKind: expected,
    );
    await _requireOpenIndex().setAppValue(kKeystoreWrapModeKey, expected.storageSuffix);
    return refreshed;
  }

  Future<UnlockedVaultSession> refreshTrustedSessionProtection(
    UnlockedVaultSession session, {
    required KeystoreAuthKind authKind,
  }) async {
    final RecoveryMetadata metadata = await _requireMetadataForSession(session);
    final TrustedDeviceInfo deviceInfo = await _deviceKeyManager.ensureDeviceKey(
      metadata.vaultId,
      authKind: authKind,
    );
    await _storeWrappedRecoveryKey(
      vaultId: metadata.vaultId,
      recoveryWrapKey: _requireRecoveryWrapKey(session),
      authKind: authKind,
    );
    return session.copyWith(deviceSlotId: deviceInfo.slotId);
  }

  Future<void> ensureIndexReady(UnlockedVaultSession session) async {
    await _openIndexForSession(session);
    await _seedDefaultTagCatalog();
    final IndexDatabase indexDb = _requireOpenIndex();
    final String? lastRebuildAt = await indexDb.getAppValue(kLastRebuildAtKey);
    final String? searchSchemaVersion = await indexDb.getAppValue(kSearchSchemaVersionKey);
    final bool needsSearchSchemaRebuild =
        searchSchemaVersion != IndexDatabase.searchSchemaVersion.toString();
    if (lastRebuildAt == null || needsSearchSchemaRebuild) {
      await rebuildIndex(session);
    } else {
      await syncTagStylesBetweenVaultAndIndex();
    }
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
