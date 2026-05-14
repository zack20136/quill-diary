import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
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
import '../drive/drive_backup_service.dart';
import '../markdown/front_matter_codec.dart';
import '../security/device_key_manager.dart';
import 'vault_path_strategy.dart';

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

class RecoverySetupResult {
  const RecoverySetupResult({
    required this.recoveryKey,
    required this.session,
  });

  final String recoveryKey;
  final UnlockedVaultSession session;
}

class VaultRepository {
  VaultRepository({
    required VaultPathStrategy pathStrategy,
    required FrontMatterCodec frontMatterCodec,
    required CryptoService cryptoService,
    required IndexDatabase indexDatabase,
    required DeviceKeyManager deviceKeyManager,
    required DriveBackupService driveBackupService,
  })  : _pathStrategy = pathStrategy,
        _frontMatterCodec = frontMatterCodec,
        _cryptoService = cryptoService,
        _indexDatabase = indexDatabase,
        _deviceKeyManager = deviceKeyManager,
        _driveBackupService = driveBackupService;

  static const String _lastRebuildAtKey = 'last_rebuild_at';
  static const String _rewrapInProgressKey = 'rewrap_in_progress';
  static const String _rewrapStartedAtKey = 'rewrap_started_at';

  final VaultPathStrategy _pathStrategy;
  final FrontMatterCodec _frontMatterCodec;
  final CryptoService _cryptoService;
  final IndexDatabase _indexDatabase;
  final DeviceKeyManager _deviceKeyManager;
  final DriveBackupService _driveBackupService;

  RecoveryMetadata? _cachedRecoveryMetadata;

  Future<void> initialize() async {
    await _pathStrategy.ensureBaseDirectories();
    await _indexDatabase.initialize();
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

    try {
      final List<int> recoveryWrapKey = await _deviceKeyManager.unwrapWithDeviceKey(
        vaultId: metadata.vaultId,
        slotId: record.slotId,
        nonceBase64: record.nonceBase64,
        ciphertextBase64: record.ciphertextBase64,
      );
      await _verifyRecoveryKey(metadata, recoveryWrapKey);

      final UnlockedVaultSession session = UnlockedVaultSession(
        vaultId: metadata.vaultId,
        trustedDevice: true,
        recoveryWrapKey: recoveryWrapKey,
        deviceSlotId: deviceInfo.slotId,
      );
      await _resumeRewrapIfNeeded(session, metadata);
      return session;
    } catch (_) {
      await _deviceKeyManager.clearTrustedKey(metadata.vaultId);
      throw StateError('受信任裝置資料已失效，請重新使用 Recovery Key 解鎖。');
    }
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

    final TrustedDeviceInfo deviceInfo = await _deviceKeyManager.ensureDeviceKey(metadata.vaultId);
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

    final TrustedDeviceInfo deviceInfo = await _deviceKeyManager.ensureDeviceKey(metadata.vaultId);
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

    await _setRewrapState(inProgress: true);
    await _rewrapVaultForTrustedDevice(session, metadata);
    await _setRewrapState(inProgress: false);
    await rebuildIndex(session);
    return session;
  }

  Future<List<EntryIndexRecord>> listEntries({
    String? searchQuery,
    DateOnly? date,
  }) {
    return _indexDatabase.listEntries(searchQuery: searchQuery, date: date);
  }

  Future<List<DateOnly>> monthEntryDates(DateTime month) {
    return _indexDatabase.monthEntryDates(month);
  }

  Future<DiaryEntry?> loadEntry(
    UnlockedVaultSession session,
    EntryId entryId,
  ) async {
    final EntryIndexRecord? indexRecord = await _indexDatabase.getEntryById(entryId);
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
    return _frontMatterCodec.decode(markdown).copyWith(vaultId: indexRecord.vaultId);
  }

  Future<List<AssetAttachment>> loadAttachments(EntryId entryId) {
    return _indexDatabase.attachmentsForEntry(entryId);
  }

  Future<DiaryEntry> saveEntry(
    UnlockedVaultSession session,
    DiaryEntry draft, {
    List<PendingAttachment> pendingAttachments = const <PendingAttachment>[],
  }) async {
    final RecoveryMetadata metadata = await _requireMetadataForSession(session);
    final List<int> recoveryWrapKey = _requireRecoveryWrapKey(session);
    final List<AssetAttachment> existingFromDb =
        await _indexDatabase.attachmentsForEntry(draft.id);
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

    await _indexDatabase.upsertEntry(
      entry: normalized,
      filePath: filePath,
      previewText: previewTextFromMarkdown(normalized.markdownBody),
      contentHash: await _hashString(markdown),
      encryptedFileSize: fileBytes.lengthInBytes,
      encryptedModifiedAt: DateTime.now(),
    );
    await _indexDatabase.replaceAttachments(
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
    await _indexDatabase.upsertSearchDocument(
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
    await _indexDatabase.markEntryDeleted(entryId);
  }

  Future<List<EntryIndexRecord>> searchEntries(String query) {
    return _indexDatabase.searchEntries(query);
  }

  Future<void> rebuildIndex(UnlockedVaultSession session) async {
    final RecoveryMetadata metadata = await _requireMetadataForSession(session);
    await _indexDatabase.rebuild();

    final Directory vaultRoot = await _pathStrategy.vaultRootDirectory();
    final Directory entriesDirectory = Directory(p.join(vaultRoot.path, 'entries'));
    if (!entriesDirectory.existsSync()) {
      await _indexDatabase.setAppValue(_lastRebuildAtKey, DateTime.now().toIso8601String());
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

      await _indexDatabase.upsertEntry(
        entry: entry,
        filePath: entity.path,
        previewText: previewTextFromMarkdown(entry.markdownBody),
        contentHash: await _hashString(markdown),
        encryptedFileSize: await entity.length(),
        encryptedModifiedAt: await entity.lastModified(),
      );
      await _indexDatabase.upsertSearchDocument(
        entry: entry,
        previewText: previewTextFromMarkdown(entry.markdownBody),
      );
      await _indexDatabase.replaceAttachments(
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

    await _indexDatabase.setAppValue(_lastRebuildAtKey, DateTime.now().toIso8601String());
  }

  Future<File> exportMarkdownVault(UnlockedVaultSession session) async {
    final List<EntryIndexRecord> entries = await listEntries();
    final Directory exportRoot = Directory(
      p.join(
        (await _pathStrategy.exportsDirectory()).path,
        'markdown_${DateTime.now().millisecondsSinceEpoch}',
      ),
    );
    final Directory entryRoot = Directory(p.join(exportRoot.path, 'entries'));
    final Directory assetRoot = Directory(p.join(exportRoot.path, 'assets'));
    await entryRoot.create(recursive: true);
    await assetRoot.create(recursive: true);

    for (final EntryIndexRecord record
        in entries.where((EntryIndexRecord item) => !item.isDeleted)) {
      final DiaryEntry? entry = await loadEntry(session, record.id);
      if (entry == null) {
        continue;
      }

      final List<AssetAttachment> attachments = await loadAttachments(entry.id);
      final String exportMarkdown = _frontMatterCodec.encode(
        entry,
        attachments: attachments,
      );
      final Directory yearMonthDirectory = Directory(
        p.join(entryRoot.path, entry.date.yearString, entry.date.monthPadded),
      );
      await yearMonthDirectory.create(recursive: true);
      await File(p.join(yearMonthDirectory.path, '${entry.date.value}-${_exportNameSuffix(entry)}.md'))
          .writeAsString(
        exportMarkdown,
        flush: true,
      );

      for (final AssetAttachment attachment in attachments) {
        final File encryptedFile = File(
          await _pathStrategy.assetAbsolutePath(
            date: entry.date,
            assetId: attachment.id,
            extension: p.extension(attachment.safeFilename).replaceFirst('.', ''),
          ),
        );
        if (!encryptedFile.existsSync()) {
          continue;
        }

        final ParsedEncryptedDocument parsed =
            _cryptoService.parseFileBytes(await encryptedFile.readAsBytes());
        final List<int> bytes = await _cryptoService.decryptBytes(
          headerBytes: parsed.headerBytes,
          ciphertextBytes: parsed.ciphertextBytes,
          context: _decryptionContext(session),
        );
        final Directory assetDirectory = Directory(
          p.join(assetRoot.path, entry.date.yearString, entry.date.monthPadded),
        );
        await assetDirectory.create(recursive: true);
        await File(p.join(assetDirectory.path, attachment.safeFilename)).writeAsBytes(
          bytes,
          flush: true,
        );
      }
    }

    return File(exportRoot.path);
  }

  Future<File> createBackupSnapshot() async {
    final Directory vaultRoot = await _pathStrategy.vaultRootDirectory();
    final Directory backupsDirectory = await _pathStrategy.backupsDirectory();
    await backupsDirectory.create(recursive: true);

    final String backupId = generateBackupId();
    final File target = File(p.join(backupsDirectory.path, '$backupId.jbackup'));
    final ZipFileEncoder encoder = ZipFileEncoder();
    encoder.create(target.path);
    await encoder.addDirectory(vaultRoot, includeDirName: false);
    await encoder.close();

    final List<EntryIndexRecord> entries = await listEntries();
    await _indexDatabase.recordBackupHistory(
      BackupHistoryRecord(
        backupId: backupId,
        provider: 'local',
        createdAt: DateTime.now(),
        status: 'created',
        entryCount: entries.where((EntryIndexRecord record) => !record.isDeleted).length,
        assetCount: 0,
        byteSize: await target.length(),
      ),
    );
    return target;
  }

  Future<void> restoreBackup(File backupFile) async {
    final Directory vaultRoot = await _pathStrategy.vaultRootDirectory();
    final Directory tempRoot = Directory('${vaultRoot.path}_restore_tmp');
    if (tempRoot.existsSync()) {
      await tempRoot.delete(recursive: true);
    }
    await tempRoot.create(recursive: true);

    final Archive archive = ZipDecoder().decodeBytes(
      await backupFile.readAsBytes(),
      verify: true,
    );
    for (final ArchiveFile archiveFile in archive.files) {
      _ensureSafeArchivePath(archiveFile.name);
      final String outputPath = p.join(tempRoot.path, archiveFile.name);
      if (archiveFile.isFile) {
        final File file = File(outputPath);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(archiveFile.content as List<int>, flush: true);
      } else {
        await Directory(outputPath).create(recursive: true);
      }
    }

    if (vaultRoot.existsSync()) {
      await vaultRoot.delete(recursive: true);
    }
    await vaultRoot.create(recursive: true);
    await for (final FileSystemEntity entity
        in tempRoot.list(recursive: true, followLinks: false)) {
      final String relative = p.relative(entity.path, from: tempRoot.path);
      final String destination = p.join(vaultRoot.path, relative);
      if (entity is Directory) {
        await Directory(destination).create(recursive: true);
      } else if (entity is File) {
        await File(destination).parent.create(recursive: true);
        await entity.copy(destination);
      }
    }

    await tempRoot.delete(recursive: true);
    _cachedRecoveryMetadata = null;
    await _resetLocalIndexState();
  }

  Future<String?> uploadLatestBackupToDrive() async {
    final File snapshot = await createBackupSnapshot();
    final String? remoteId = await _driveBackupService.uploadBackup(snapshot);
    await _indexDatabase.recordBackupHistory(
      BackupHistoryRecord(
        backupId: generateBackupId(),
        provider: 'google_drive',
        remoteFileId: remoteId,
        createdAt: DateTime.now(),
        status: remoteId == null ? 'failed' : 'uploaded',
        entryCount: (await listEntries()).length,
        assetCount: 0,
        byteSize: await snapshot.length(),
        errorCode: remoteId == null ? 'E-BACKUP-003' : null,
      ),
    );
    return remoteId;
  }

  Future<void> restoreLatestDriveBackup() async {
    final File? backupFile = await _driveBackupService.downloadLatestBackup(
      destinationDirectory: await _pathStrategy.backupsDirectory(),
    );
    if (backupFile == null) {
      throw StateError('Google Drive 沒有可還原的備份。');
    }
    await restoreBackup(backupFile);
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

  Future<void> _verifyRecoveryKey(
    RecoveryMetadata metadata,
    List<int> recoveryWrapKey,
  ) async {
    final File manifest = File(await _pathStrategy.manifestPath());
    if (!manifest.existsSync()) {
      return;
    }

    final ParsedEncryptedDocument parsed = _cryptoService.parseFileBytes(await manifest.readAsBytes());
    await _cryptoService.decryptBytes(
      headerBytes: parsed.headerBytes,
      ciphertextBytes: parsed.ciphertextBytes,
      context: DecryptionContext.recovery(
        recoveryWrapKey: recoveryWrapKey,
        vaultId: metadata.vaultId,
      ),
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
      final String extension = p.extension(pending.originalFilename).replaceFirst('.', '');
      final String safeFilename = extension.isEmpty ? assetId : '$assetId.$extension';
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
          originalFilename: pending.originalFilename,
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
    final DeviceWrappedPayload payload = await _deviceKeyManager.wrapWithDeviceKey(
      vaultId: vaultId,
      plaintextBytes: recoveryWrapKey,
    );
    await _deviceKeyManager.storeWrappedRecoveryKey(
      vaultId: vaultId,
      record: WrappedRecoveryKeyRecord(
        slotId: payload.slotId,
        nonceBase64: payload.nonceBase64,
        ciphertextBase64: payload.ciphertextBase64,
        wrappedAt: DateTime.now(),
        formatVersion: 1,
        platform: payload.platform,
      ),
    );
  }

  Future<void> _resumeRewrapIfNeeded(
    UnlockedVaultSession session,
    RecoveryMetadata metadata,
  ) async {
    if (await _indexDatabase.getAppValue(_rewrapInProgressKey) != 'true') {
      return;
    }
    await _rewrapVaultForTrustedDevice(session, metadata);
    await _setRewrapState(inProgress: false);
    await rebuildIndex(session);
  }

  Future<void> _setRewrapState({required bool inProgress}) async {
    await _indexDatabase.setAppValue(_rewrapInProgressKey, inProgress ? 'true' : 'false');
    if (inProgress) {
      await _indexDatabase.setAppValue(
        _rewrapStartedAtKey,
        DateTime.now().toIso8601String(),
      );
      return;
    }
    await _indexDatabase.deleteAppValue(_rewrapStartedAtKey);
  }

  Future<void> _resetLocalIndexState() async {
    await _indexDatabase.clearForRebuild();
    await _indexDatabase.deleteAppValue(_lastRebuildAtKey);
    await _indexDatabase.deleteAppValue(_rewrapInProgressKey);
    await _indexDatabase.deleteAppValue(_rewrapStartedAtKey);
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

  void _ensureSafeArchivePath(String relativePath) {
    if (relativePath.contains('..') || p.isAbsolute(relativePath)) {
      throw const FormatException('備份檔包含不安全的路徑。');
    }
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

  String _exportNameSuffix(DiaryEntry entry) {
    final String title = entry.normalizedTitle ?? '';
    if (title.isNotEmpty) {
      final String sanitized = title
          .replaceAll(RegExp(r'[^\w\u4e00-\u9fff-]+'), '-')
          .replaceAll(RegExp(r'-+'), '-')
          .replaceAll(RegExp(r'^-|-$'), '');
      if (sanitized.isNotEmpty) {
        return sanitized;
      }
    }
    return entry.id.substring(entry.id.length - 6).toLowerCase();
  }
}
