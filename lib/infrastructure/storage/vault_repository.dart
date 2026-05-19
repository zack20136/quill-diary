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
import '../security/device_key_manager.dart';
import 'vault_path_strategy.dart';
import 'vault_state_keys.dart';

/// Attachment selected in the UI but not yet persisted into the encrypted vault.
class PendingAttachment {
  const PendingAttachment({
    required this.sourcePath,
    required this.mimeType,
    required this.originalFilename,
  });

  final String sourcePath;
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
        await readRecoveryMetadata() ?? (throw StateError('尚未建立 Recovery Key。'));
    if (!await _deviceKeyManager.hasTrustedKey(metadata.vaultId)) {
      throw StateError('這台裝置尚未註冊，請使用 Recovery Key 解鎖。');
    }

    final WrappedRecoveryKeyRecord record =
        await _deviceKeyManager.readWrappedRecoveryKey(metadata.vaultId) ??
            (throw StateError('找不到受信任裝置的 Recovery 金鑰資料。'));
    final TrustedDeviceInfo deviceInfo =
        await _deviceKeyManager.readDeviceInfo(metadata.vaultId) ??
            (throw StateError('找不到受信任裝置資訊。'));

    if (record.slotId != deviceInfo.slotId) {
      await _deviceKeyManager.clearTrustedKey(metadata.vaultId);
      throw StateError('受信任裝置資料不一致，請使用 Recovery Key 重新建立。');
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
    } on Object catch (error, stackTrace) {
      await _deviceKeyManager.clearTrustedKey(metadata.vaultId);
      Error.throwWithStackTrace(
        StateError(
          '受信任裝置資料已失效，請重新使用 Recovery Key 解鎖。（unwrapWithDeviceKey：$error）',
        ),
        stackTrace,
      );
    }

    await _verifyRecoveryKey(metadata, recoveryWrapKey);

    final UnlockedVaultSession session = UnlockedVaultSession(
      vaultId: metadata.vaultId,
      trustedDevice: true,
      recoveryWrapKey: recoveryWrapKey,
      deviceSlotId: deviceInfo.slotId,
    );
    await _openIndexForSession(session);
    try {
      await _resumeRewrapIfNeeded(session, metadata);
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        StateError(
          '日記庫重新包裝未完成（下次啟動會自動繼續，或請檢查加密檔是否毀損）。原因：$error',
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
      throw StateError('Recovery Key 已存在。');
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
      recoveryKeyVersion: 2,
      recoveryKeyHint: recoveryKey.substring(recoveryKey.length - 4),
      createdAt: DateTime.now(),
      kdf: recoveryKdf,
    );

    final File file = File(await _pathStrategy.recoveryMetadataPath());
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(metadata.toJson()),
      flush: true,
    );
    _cachedRecoveryMetadata = metadata;

    final bool biometricEnabled = await _appLockService.isBiometricLockEnabled();
    final TrustedDeviceInfo deviceInfo = await _deviceKeyManager.ensureDeviceKey(
      metadata.vaultId,
      userAuthenticationRequired: biometricEnabled,
    );
    await _storeWrappedRecoveryKey(
      vaultId: metadata.vaultId,
      recoveryWrapKey: recoveryWrapKey,
    );

    final UnlockedVaultSession session = UnlockedVaultSession(
      vaultId: metadata.vaultId,
      trustedDevice: true,
      recoveryWrapKey: recoveryWrapKey,
      deviceSlotId: deviceInfo.slotId,
    );
    await _openIndexForSession(session);
    await _writeEncryptedManifest(session, metadata);

    return RecoverySetupResult(
      recoveryKey: recoveryKey,
      session: session,
    );
  }

  Future<UnlockedVaultSession> unlockWithRecoveryKey(String recoveryKey) async {
    final RecoveryMetadata metadata =
        await readRecoveryMetadata() ?? (throw StateError('找不到 Recovery metadata。'));
    final List<int> recoveryWrapKey = await _cryptoService.deriveRecoveryWrapKey(
      recoveryKey: recoveryKey,
      kdf: metadata.kdf,
    );
    await _verifyRecoveryKey(metadata, recoveryWrapKey);

    final bool biometricEnabled = await _appLockService.isBiometricLockEnabled();
    final TrustedDeviceInfo deviceInfo = await _deviceKeyManager.ensureDeviceKey(
      metadata.vaultId,
      userAuthenticationRequired: biometricEnabled,
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
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        StateError(
          '日記庫重新包裝失敗（已保留進行中旗標以便下次自動續跑）：$error',
        ),
        stackTrace,
      );
    }

    await _storeWrappedRecoveryKey(
      vaultId: metadata.vaultId,
      recoveryWrapKey: recoveryWrapKey,
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

  Future<Map<String, int>> fetchTagAccentArgbMap() {
    return _requireOpenIndex().fetchTagAccentArgbMap();
  }

  Future<void> upsertTagAccentArgb(String tag, int accentArgb) {
    return _requireOpenIndex().upsertTagAccentArgb(tag, accentArgb);
  }

  Future<void> deleteTagAccentArgb(String tag) {
    return _requireOpenIndex().deleteTagAccentArgb(tag);
  }

  Future<DiaryEntry> saveEntry(
    UnlockedVaultSession session,
    DiaryEntry draft, {
    List<PendingAttachment> pendingAttachments = const <PendingAttachment>[],
  }) async {
    final RecoveryMetadata metadata = await _requireMetadataForSession(session);
    final List<int> recoveryWrapKey = _requireRecoveryWrapKey(session);
    final List<AssetAttachment> existingFromDb =
        await _requireOpenIndex().attachmentsForEntry(draft.id);
    final Set<AssetId> keepExistingIds = draft.attachmentIds.toSet();
    final List<AssetAttachment> existingKept = existingFromDb
        .where((AssetAttachment a) => keepExistingIds.contains(a.id))
        .toList();
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
    final DiaryEntry normalized = draft.copyWith(
      vaultId: metadata.vaultId,
      attachmentIds: allAttachments.map((AssetAttachment asset) => asset.id).toList(),
      updatedAt: DateTime.now(),
    );

    final String markdown = _frontMatterCodec.encode(
      normalized,
      attachments: allAttachments,
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

    await _requireOpenIndex().upsertEntry(
      entry: normalized,
      filePath: filePath,
      previewText: previewTextFromMarkdown(normalized.markdownBody),
      contentHash: await _hashString(markdown),
      encryptedFileSize: fileBytes.lengthInBytes,
      encryptedModifiedAt: DateTime.now(),
    );
    await _requireOpenIndex().replaceAttachments(
      normalized.id,
      allAttachments,
      <AssetId, String>{
        for (final AssetAttachment attachment in allAttachments)
          attachment.id: await _pathStrategy.assetAbsolutePath(
            date: normalized.date,
            assetId: attachment.id,
            extension: p.extension(attachment.safeFilename).replaceFirst('.', ''),
          ),
      },
    );
    await _requireOpenIndex().upsertSearchDocument(
      entry: normalized,
      previewText: previewTextFromMarkdown(normalized.markdownBody),
    );
    await _writeEncryptedManifest(session, metadata);
    return normalized;
  }

  Future<void> deleteEntry(
    UnlockedVaultSession session,
    EntryId entryId,
  ) async {
    final DiaryEntry? entry = await loadEntry(session, entryId);
    if (entry == null) {
      return;
    }
    await saveEntry(session, entry.copyWith(isDeleted: true));
    await _requireOpenIndex().markEntryDeleted(entryId);
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

      await indexDb.upsertEntry(
        entry: entry,
        filePath: entity.path,
        previewText: previewTextFromMarkdown(entry.markdownBody),
        contentHash: await _hashString(markdown),
        encryptedFileSize: await entity.length(),
        encryptedModifiedAt: await entity.lastModified(),
      );
      await indexDb.upsertSearchDocument(
        entry: entry,
        previewText: previewTextFromMarkdown(entry.markdownBody),
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
        '無法用現有加密檔驗證 Recovery Key（至少一個檔案疑似毀損或格式異常）。'
        ' 最近一次驗證問題：$verificationProblem',
      );
    }

    if (sawParsableEncryptedFile && authFailurePath != null) {
      throw StateError(
        'Recovery Key 與現有 vault 資料不相符。（路徑：$authFailurePath）',
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
      'entry_count': entries.where((EntryIndexRecord item) => !item.isDeleted).length,
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
      final List<int> sourceBytes = await File(pending.sourcePath).readAsBytes();
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
          mimeType: _mimeTypeFromExtension(p.extension(fileName)),
          safeFilename: fileName,
          byteSize: await entity.length(),
          createdAt: await entity.lastModified(),
          sha256: '',
        ),
      );
    }
    return matches;
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

  Future<void> _storeWrappedRecoveryKey({
    required VaultId vaultId,
    required List<int> recoveryWrapKey,
  }) async {
    final bool biometricEnabled = await _appLockService.isBiometricLockEnabled();
    final DeviceWrappedPayload payload = await _deviceKeyManager.wrapWithDeviceKey(
      vaultId: vaultId,
      plaintextBytes: recoveryWrapKey,
      userAuthenticationRequired: biometricEnabled,
    );
    await _deviceKeyManager.storeWrappedRecoveryKey(
      vaultId: vaultId,
      record: WrappedRecoveryKeyRecord(
        slotId: payload.slotId,
        nonceBase64: payload.nonceBase64,
        ciphertextBase64: payload.ciphertextBase64,
        wrappedAt: DateTime.now(),
        formatVersion: 2,
        platform: payload.platform,
      ),
    );
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

  String _mimeTypeFromExtension(String extension) {
    switch (extension.toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      default:
        return 'application/octet-stream';
    }
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

  Future<UnlockedVaultSession> refreshTrustedSessionProtection(
    UnlockedVaultSession session, {
    required bool biometricRequired,
  }) async {
    final RecoveryMetadata metadata = await _requireMetadataForSession(session);
    final TrustedDeviceInfo deviceInfo = await _deviceKeyManager.ensureDeviceKey(
      metadata.vaultId,
      userAuthenticationRequired: biometricRequired,
    );
    final DeviceWrappedPayload payload = await _deviceKeyManager.wrapWithDeviceKey(
      vaultId: metadata.vaultId,
      plaintextBytes: _requireRecoveryWrapKey(session),
      userAuthenticationRequired: biometricRequired,
    );
    await _deviceKeyManager.storeWrappedRecoveryKey(
      vaultId: metadata.vaultId,
      record: WrappedRecoveryKeyRecord(
        slotId: payload.slotId,
        nonceBase64: payload.nonceBase64,
        ciphertextBase64: payload.ciphertextBase64,
        wrappedAt: DateTime.now(),
        formatVersion: 2,
        platform: deviceInfo.platform,
      ),
    );
    return session.copyWith(deviceSlotId: deviceInfo.slotId);
  }

  Future<void> ensureIndexReady(UnlockedVaultSession session) async {
    await _openIndexForSession(session);
    if (await _requireOpenIndex().getAppValue(kLastRebuildAtKey) == null) {
      await rebuildIndex(session);
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

}
