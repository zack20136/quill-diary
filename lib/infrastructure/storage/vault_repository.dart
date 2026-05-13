import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math';

import 'package:archive/archive_io.dart';
import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;

import '../../domain/attachment/asset_attachment.dart';
import '../../domain/diary/diary_entry.dart';
import '../../domain/recovery/recovery_metadata.dart';
import '../../domain/shared/value_objects.dart';
import '../crypto/crypto_service.dart';
import '../database/index_database.dart';
import '../drive/drive_backup_service.dart';
import '../markdown/front_matter_codec.dart';
import '../security/app_lock_service.dart';
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

  bool get isImage => mimeType.startsWith('image/');
}

class VaultRepository {
  VaultRepository({
    required VaultPathStrategy pathStrategy,
    required FrontMatterCodec frontMatterCodec,
    required CryptoService cryptoService,
    required IndexDatabase indexDatabase,
    required AppLockService appLockService,
    required DriveBackupService driveBackupService,
  })  : _pathStrategy = pathStrategy,
        _frontMatterCodec = frontMatterCodec,
        _cryptoService = cryptoService,
        _indexDatabase = indexDatabase,
        _appLockService = appLockService,
        _driveBackupService = driveBackupService;

  final VaultPathStrategy _pathStrategy;
  final FrontMatterCodec _frontMatterCodec;
  final CryptoService _cryptoService;
  final IndexDatabase _indexDatabase;
  final AppLockService _appLockService;
  final DriveBackupService _driveBackupService;

  RecoveryMetadata? _cachedRecoveryMetadata;

  Future<void> initialize() async {
    await _pathStrategy.ensureBaseDirectories();
    await _indexDatabase.initialize();
    _cachedRecoveryMetadata = await readRecoveryMetadata();
    if (_cachedRecoveryMetadata != null) {
      await _appLockService.ensureDeviceSecret();
    }
    if ((await _indexDatabase.getAppValue('last_rebuild_at')) == null) {
      await rebuildIndex();
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
      return null;
    }
    _cachedRecoveryMetadata = RecoveryMetadata.fromJson(decoded);
    return _cachedRecoveryMetadata;
  }

  Future<String> setupRecoveryKey() async {
    final RecoveryMetadata? existing = await readRecoveryMetadata();
    if (existing != null) {
      return '已建立 Recovery Key（提示：${existing.recoveryKeyHint}）';
    }

    final String recoveryKey = _generateRecoveryKey();
    final Random random = Random.secure();
    final List<int> saltBytes = List<int>.generate(16, (_) => random.nextInt(256));
    final List<int> wrapKey = await _cryptoService.deriveRecoveryWrapKey(
      recoveryKey: recoveryKey,
      saltBytes: saltBytes,
    );
    final RecoveryMetadata metadata = RecoveryMetadata(
      vaultId: generateVaultId(),
      recoveryEnabled: true,
      recoveryKeyVersion: 1,
      recoveryKeyHint: recoveryKey.substring(recoveryKey.length - 4),
      createdAt: DateTime.now(),
      kdfAlgorithm: 'pbkdf2-sha256',
      kdfSaltBase64: base64Encode(saltBytes),
    );
    final File file = File(await _pathStrategy.recoveryMetadataPath());
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(metadata.toJson()),
      flush: true,
    );
    await _appLockService.ensureDeviceSecret();
    await _appLockService.saveRecoveryWrapKey(
      vaultId: metadata.vaultId,
      keyBytes: wrapKey,
    );
    _cachedRecoveryMetadata = metadata;
    await _writeEncryptedManifest();
    return recoveryKey;
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

  Future<DiaryEntry?> loadEntry(EntryId entryId) async {
    final EntryIndexRecord? indexRecord = await _indexDatabase.getEntryById(entryId);
    if (indexRecord == null) {
      return null;
    }
    final File file = File(indexRecord.filePath);
    if (!file.existsSync()) {
      return null;
    }

    final ParsedEncryptedDocument parsed =
        _cryptoService.parseFileBytes(await file.readAsBytes());
    final RecoveryMetadata? metadata = await readRecoveryMetadata();
    final String deviceSecret = await _appLockService.ensureDeviceSecret();
    final List<int>? recoveryWrapKey = metadata == null
        ? null
        : await _appLockService.readRecoveryWrapKey(metadata.vaultId);
    final String markdown = await _cryptoService.decryptMarkdown(
      headerBytes: parsed.headerBytes,
      ciphertextBytes: parsed.ciphertextBytes,
      deviceSecret: deviceSecret,
      recoveryWrapKey: recoveryWrapKey,
    );
    return _frontMatterCodec.decode(markdown).copyWith(
          vaultId: indexRecord.vaultId,
        );
  }

  Future<List<AssetAttachment>> loadAttachments(EntryId entryId) {
    return _indexDatabase.attachmentsForEntry(entryId);
  }

  Future<DiaryEntry> saveEntry(
    DiaryEntry draft, {
    List<PendingAttachment> pendingAttachments = const <PendingAttachment>[],
  }) async {
    final RecoveryMetadata metadata =
        await readRecoveryMetadata() ??
            (throw StateError('請先完成 Recovery Key 設定。'));
    final String deviceSecret = await _appLockService.ensureDeviceSecret();
    final List<int> recoveryWrapKey = await _appLockService.readRecoveryWrapKey(
          metadata.vaultId,
        ) ??
        (throw StateError('找不到 Recovery wrapping key。'));

    final List<AssetAttachment> existingAttachments =
        await _indexDatabase.attachmentsForEntry(draft.id);
    final List<AssetAttachment> newAttachments = await _storePendingAttachments(
      entry: draft,
      pendingAttachments: pendingAttachments,
      recoveryWrapKey: recoveryWrapKey,
      deviceSecret: deviceSecret,
      vaultId: metadata.vaultId,
    );
    final List<AssetAttachment> allAttachments = <AssetAttachment>[
      ...existingAttachments,
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
      deviceSecret: deviceSecret,
      createdAt: normalized.createdAt,
      updatedAt: normalized.updatedAt,
    );
    final String filePath = await _pathStrategy.entryAbsolutePath(
      date: normalized.date,
      entryId: normalized.id,
    );
    await _atomicWriteBytes(File(filePath), encryption.toFileBytes());
    final String contentHash = await _hashString(markdown);
    await _indexDatabase.upsertEntry(
      entry: normalized,
      filePath: filePath,
      previewText: previewTextFromMarkdown(normalized.markdownBody),
      contentHash: contentHash,
      encryptedFileSize: encryption.toFileBytes().lengthInBytes,
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
    await _writeEncryptedManifest();
    return normalized;
  }

  Future<void> deleteEntry(EntryId entryId) async {
    final DiaryEntry? entry = await loadEntry(entryId);
    if (entry == null) {
      return;
    }
    await saveEntry(entry.copyWith(isDeleted: true));
    await _indexDatabase.markEntryDeleted(entryId);
    await _writeEncryptedManifest();
  }

  Future<List<EntryIndexRecord>> searchEntries(String query) {
    return _indexDatabase.searchEntries(query);
  }

  Future<void> rebuildIndex() async {
    await _indexDatabase.rebuild();
    final RecoveryMetadata? metadata = await readRecoveryMetadata();
    if (metadata == null) {
      return;
    }
    final String deviceSecret = await _appLockService.ensureDeviceSecret();
    final List<int>? recoveryWrapKey = await _appLockService.readRecoveryWrapKey(
      metadata.vaultId,
    );
    final Directory vaultRoot = await _pathStrategy.vaultRootDirectory();
    final Directory entriesDirectory = Directory(p.join(vaultRoot.path, 'entries'));
    if (!entriesDirectory.existsSync()) {
      return;
    }

    await for (final FileSystemEntity entity
        in entriesDirectory.list(recursive: true, followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.md.enc')) {
        continue;
      }
      final ParsedEncryptedDocument parsed =
          _cryptoService.parseFileBytes(await entity.readAsBytes());
      final String markdown = await _cryptoService.decryptMarkdown(
        headerBytes: parsed.headerBytes,
        ciphertextBytes: parsed.ciphertextBytes,
        deviceSecret: deviceSecret,
        recoveryWrapKey: recoveryWrapKey,
      );
      final DiaryEntry entry = _frontMatterCodec.decode(markdown).copyWith(
            vaultId: metadata.vaultId,
          );
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
      final List<AssetAttachment> attachments = await _findAttachmentsForEntry(entry);
      await _indexDatabase.replaceAttachments(
        entry.id,
        attachments,
        <AssetId, String>{
          for (final AssetAttachment asset in attachments)
            asset.id: await _pathStrategy.assetAbsolutePath(
              date: entry.date,
              assetId: asset.id,
              extension: p.extension(asset.safeFilename).replaceFirst('.', ''),
            ),
        },
      );
    }
  }

  Future<File> exportMarkdownVault() async {
    final RecoveryMetadata metadata =
        await readRecoveryMetadata() ??
            (throw StateError('尚未建立 Recovery Key，無法匯出。'));
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

    final String deviceSecret = await _appLockService.ensureDeviceSecret();
    final List<int>? recoveryWrapKey = await _appLockService.readRecoveryWrapKey(
      metadata.vaultId,
    );

    for (final EntryIndexRecord record in entries.where((EntryIndexRecord item) => !item.isDeleted)) {
      final DiaryEntry? entry = await loadEntry(record.id);
      if (entry == null) {
        continue;
      }
      final List<AssetAttachment> attachments = await loadAttachments(entry.id);
      final String exportMarkdown = _frontMatterCodec.encode(
        entry,
        attachments: attachments,
      );
      final String markdownName =
          '${entry.date.value}-${_exportNameSuffix(entry)}.md';
      final Directory yearMonthDirectory = Directory(
        p.join(entryRoot.path, entry.date.yearString, entry.date.monthPadded),
      );
      await yearMonthDirectory.create(recursive: true);
      await File(p.join(yearMonthDirectory.path, markdownName)).writeAsString(
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
          deviceSecret: deviceSecret,
          recoveryWrapKey: recoveryWrapKey,
        );
        final Directory assetDirectory = Directory(
          p.join(assetRoot.path, entry.date.yearString, entry.date.monthPadded),
        );
        await assetDirectory.create(recursive: true);
        await File(p.join(assetDirectory.path, attachment.safeFilename))
            .writeAsBytes(bytes, flush: true);
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

    final int entryCount = (await listEntries()).where((EntryIndexRecord record) => !record.isDeleted).length;
    final int assetCount = 0;
    await _indexDatabase.recordBackupHistory(
      BackupHistoryRecord(
        backupId: backupId,
        provider: 'local',
        createdAt: DateTime.now(),
        status: 'created',
        entryCount: entryCount,
        assetCount: assetCount,
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

    final Archive archive =
        ZipDecoder().decodeBytes(await backupFile.readAsBytes(), verify: true);
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
    await rebuildIndex();
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
      throw StateError('Google Drive 上沒有可還原的備份。');
    }
    await restoreBackup(backupFile);
  }

  Future<void> _writeEncryptedManifest() async {
    final RecoveryMetadata? metadata = await readRecoveryMetadata();
    if (metadata == null) {
      return;
    }
    final List<int>? recoveryWrapKey = await _appLockService.readRecoveryWrapKey(
      metadata.vaultId,
    );
    if (recoveryWrapKey == null) {
      return;
    }
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
    final String deviceSecret = await _appLockService.ensureDeviceSecret();
    final EncryptionResult encryption = await _cryptoService.encryptBytes(
      documentId: 'manifest',
      vaultId: metadata.vaultId,
      plaintextBytes: utf8.encode(jsonEncode(manifest)),
      contentType: 'application/json',
      recoveryWrapKey: recoveryWrapKey,
      deviceSecret: deviceSecret,
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
    required String deviceSecret,
    required String vaultId,
  }) async {
    final List<AssetAttachment> results = <AssetAttachment>[];
    for (final PendingAttachment pending in pendingAttachments) {
      final AssetId assetId = generateAssetId();
      final String extension = p.extension(pending.originalFilename).replaceFirst('.', '');
      final String safeFilename = extension.isEmpty ? assetId : '$assetId.$extension';
      final File source = File(pending.sourcePath);
      final List<int> sourceBytes = await source.readAsBytes();
      final EncryptionResult encrypted = await _cryptoService.encryptBytes(
        documentId: assetId,
        vaultId: vaultId,
        plaintextBytes: sourceBytes,
        contentType: pending.mimeType,
        recoveryWrapKey: recoveryWrapKey,
        deviceSecret: deviceSecret,
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
      throw const FormatException('Unsafe archive path detected.');
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
