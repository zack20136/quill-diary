import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import '../../../domain/recovery/recovery_metadata.dart';
import '../../database/index_database_manager.dart';
import '../restore_precheck.dart';
import '../shared/archive_extract.dart';
import '../tag_styles_store.dart';
import '../vault_path_strategy.dart';
import '../vault_repository.dart';
import 'portable_io_types.dart';

class VaultBackupIo {
  VaultBackupIo({
    required VaultPathStrategy pathStrategy,
    required VaultRepository repository,
    required IndexDatabaseManager indexDatabaseManager,
  })  : _pathStrategy = pathStrategy,
        _repository = repository,
        _indexDatabaseManager = indexDatabaseManager;

  final VaultPathStrategy _pathStrategy;
  final VaultRepository _repository;
  final IndexDatabaseManager _indexDatabaseManager;

  Future<File> writeBackupZip(File target) async {
    final Directory vaultRoot = await _pathStrategy.vaultRootDirectory();
    await target.parent.create(recursive: true);
    final ZipFileEncoder encoder = ZipFileEncoder();
    encoder.create(target.path);
    await encoder.addDirectory(
      vaultRoot,
      includeDirName: false,
      filter: (FileSystemEntity entity, double progress) {
        final String relative = p.relative(entity.path, from: vaultRoot.path);
        final List<String> segments = p.split(relative);
        if (segments.isNotEmpty && segments.first == 'index') {
          return ZipFileOperation.skip;
        }
        return ZipFileOperation.include;
      },
    );
    await encoder.close();
    return target;
  }

  Future<BackupHealthReport> checkBackupHealth(File backupFile) async {
    final List<BackupHealthStatusItem> items = <BackupHealthStatusItem>[];
    if (!backupFile.existsSync()) {
      return const BackupHealthReport(
        ok: false,
        statusItems: <BackupHealthStatusItem>[
          BackupHealthStatusItem(
            label: '檔案狀態',
            ok: false,
            message: '找不到剛建立的備份檔案',
          ),
        ],
        entrySampleFound: false,
        hasRecoveryMetadata: false,
        hasManifest: false,
        message: '找不到備份檔案，請重新建立一次備份。',
      );
    }

    late final Archive archive;
    try {
      archive = await decodeBackupArchive(backupFile);
      items.add(
        const BackupHealthStatusItem(
          label: 'ZIP',
          ok: true,
          message: '備份壓縮檔可以讀取',
        ),
      );
    } on Object {
      return const BackupHealthReport(
        ok: false,
        statusItems: <BackupHealthStatusItem>[
          BackupHealthStatusItem(
            label: 'ZIP',
            ok: false,
            message: '備份壓縮檔無法讀取',
          ),
        ],
        entrySampleFound: false,
        hasRecoveryMetadata: false,
        hasManifest: false,
        message: '備份檔不是有效的 .jbackup，請重新建立備份。',
      );
    }

    if (archive.files.isEmpty) {
      return const BackupHealthReport(
        ok: false,
        statusItems: <BackupHealthStatusItem>[
          BackupHealthStatusItem(
            label: 'ZIP',
            ok: false,
            message: '備份壓縮檔沒有內容',
          ),
        ],
        entrySampleFound: false,
        hasRecoveryMetadata: false,
        hasManifest: false,
        message: '備份檔不是有效的 .jbackup，請重新建立備份。',
      );
    }

    final BackupArchiveInspection inspection = _inspectArchive(archive);

    items
      ..add(
        BackupHealthStatusItem(
          label: '檔案路徑',
          ok: inspection.safePaths,
          message: inspection.safePaths ? '備份內部路徑正常' : '備份內含不安全路徑',
        ),
      )
      ..add(
        BackupHealthStatusItem(
          label: '復原金鑰',
          ok: inspection.hasRecovery,
          message: inspection.hasRecovery ? '包含復原金鑰資訊' : '缺少復原金鑰資訊',
        ),
      )
      ..add(
        BackupHealthStatusItem(
          label: '日記庫資料',
          ok: inspection.hasVaultPayload || inspection.hasManifest,
          message: inspection.hasVaultPayload || inspection.hasManifest
              ? '包含日記庫資料結構'
              : '找不到日記或附件資料',
        ),
      )
      ..add(
        BackupHealthStatusItem(
          label: '加密檢查',
          ok: inspection.hasManifest || inspection.entrySampleFound,
          message: inspection.hasManifest
              ? '包含加密 manifest'
              : inspection.entrySampleFound
                  ? '包含至少一篇加密日記'
                  : '缺少可檢查的加密資料',
        ),
      );

    final bool ok = inspection.isRestorable;
    return BackupHealthReport(
      ok: ok,
      statusItems: List<BackupHealthStatusItem>.unmodifiable(items),
      entrySampleFound: inspection.entrySampleFound,
      hasRecoveryMetadata: inspection.hasRecovery,
      hasManifest: inspection.hasManifest,
      message: ok ? '備份檔案檢查通過。' : '備份檢查未通過，檔案可能無法還原。',
    );
  }

  Future<void> verifyBackupRecoveryKey(File backupFile, String recoveryKey) async {
    final BackupRecoveryPreview preview = await peekBackupRecovery(backupFile);
    if (!preview.hasRecovery || preview.metadata == null) {
      throw StateError('此備份沒有復原金鑰資訊，無法驗證。');
    }
    final List<int>? sampleBytes = await _readSampleEncryptedDocumentFromBackup(backupFile);
    if (sampleBytes == null) {
      throw StateError(kBackupNoEncryptedSampleMessage);
    }
    await _repository.verifyRecoveryKeyAgainstBackupBytes(
      metadata: preview.metadata!,
      recoveryKey: recoveryKey,
      encryptedDocumentBytes: sampleBytes,
    );
  }

  Future<BackupRecoveryPreview> peekBackupRecovery(File backupFile) async {
    try {
      final Archive archive = await decodeBackupArchive(backupFile);
      final ArchiveFile? recoveryEntry = _findRecoveryJsonEntry(archive);
      if (recoveryEntry == null || !recoveryEntry.isFile) {
        return const BackupRecoveryPreview(hasRecovery: false);
      }
      final Object? decoded = jsonDecode(
        utf8.decode(recoveryEntry.content as List<int>),
      );
      if (decoded is! Map<String, Object?>) {
        return const BackupRecoveryPreview(hasRecovery: false);
      }
      return BackupRecoveryPreview(
        hasRecovery: true,
        metadata: RecoveryMetadata.fromJson(decoded),
      );
    } on Object {
      throw StateError(kInvalidBackupArchiveMessage);
    }
  }

  Future<void> restoreBackupZip(
    File backupFile, {
    bool preserveTrustedDeviceAccess = false,
  }) async {
    final Directory vaultRoot = await _pathStrategy.vaultRootDirectory();
    final Directory tempRoot = Directory('${vaultRoot.path}_restore_tmp');
    if (tempRoot.existsSync()) {
      await tempRoot.delete(recursive: true);
    }
    await tempRoot.create(recursive: true);

    try {
      final Archive archive = await decodeBackupArchive(backupFile);
      _ensureArchiveRestorable(archive);
      await extractArchiveToDirectory(
        archive: archive,
        targetDirectory: tempRoot,
      );
    } on StateError {
      if (tempRoot.existsSync()) {
        await tempRoot.delete(recursive: true);
      }
      rethrow;
    } on Object {
      if (tempRoot.existsSync()) {
        await tempRoot.delete(recursive: true);
      }
      throw StateError(kInvalidBackupArchiveMessage);
    }

    _validateRestoredVaultPayload(tempRoot);

    List<TagCatalogItem> localTagCatalog = const <TagCatalogItem>[];
    try {
      localTagCatalog = await _repository.listTagCatalog();
    } on Object {
      // Repository or index may already be closed; fall back to vault file on disk.
    }
    if (localTagCatalog.isEmpty) {
      localTagCatalog = await TagStylesStore(_pathStrategy).read();
    }

    final Directory incomingVault = Directory('${vaultRoot.path}.incoming');
    if (incomingVault.existsSync()) {
      await incomingVault.delete(recursive: true);
    }
    await _copyDirectoryTree(tempRoot, incomingVault);
    await tempRoot.delete(recursive: true);

    Directory? previousBackup;
    if (vaultRoot.existsSync()) {
      previousBackup = Directory(
        '${vaultRoot.path}.bak_${DateTime.now().microsecondsSinceEpoch}',
      );
      await vaultRoot.rename(previousBackup.path);
    }
    try {
      await incomingVault.rename(vaultRoot.path);
      if (previousBackup != null && previousBackup.existsSync()) {
        await previousBackup.delete(recursive: true);
      }
    } on Object catch (error, stackTrace) {
      if (!vaultRoot.existsSync() &&
          previousBackup != null &&
          previousBackup.existsSync()) {
        await previousBackup.rename(vaultRoot.path);
      }
      if (incomingVault.existsSync()) {
        await incomingVault.delete(recursive: true);
      }
      Error.throwWithStackTrace(error, stackTrace);
    }

    final Directory strayVaultIndex = Directory(p.join(vaultRoot.path, 'index'));
    if (strayVaultIndex.existsSync()) {
      await strayVaultIndex.delete(recursive: true);
    }

    if (localTagCatalog.isNotEmpty) {
      final TagStylesStore tagStylesStore = TagStylesStore(_pathStrategy);
      final List<TagCatalogItem> restoredVaultStyles = await tagStylesStore.read();
      await tagStylesStore.write(
        TagStylesStore.merge(restoredVaultStyles, localTagCatalog),
      );
    }

    await _repository.closeUnlockedResources();
    await _indexDatabaseManager.deleteDatabaseFiles();
    _repository.clearRecoveryMetadataCache();
    if (!preserveTrustedDeviceAccess) {
      await _repository.clearTrustedDeviceAccess();
    }
  }

  Future<List<int>?> _readSampleEncryptedDocumentFromBackup(File backupFile) async {
    try {
      final Archive archive = await decodeBackupArchive(backupFile);
      final ArchiveFile? manifest = _findEncryptedEntry(
        archive,
        endsWith: 'manifest.json.enc',
      );
      if (manifest != null && manifest.isFile) {
        return manifest.content as List<int>;
      }
      ArchiveFile? firstEntryEnc;
      for (final ArchiveFile file in archive.files) {
        if (!file.isFile) {
          continue;
        }
        final String normalized = p.posix.normalize(file.name).toLowerCase();
        if (normalized.endsWith('.md.enc')) {
          firstEntryEnc = file;
          break;
        }
      }
      if (firstEntryEnc != null) {
        return firstEntryEnc.content as List<int>;
      }
      return null;
    } on Object {
      throw StateError(kInvalidBackupArchiveMessage);
    }
  }

  ArchiveFile? _findEncryptedEntry(
    Archive archive, {
    required String endsWith,
  }) {
    for (final ArchiveFile file in archive.files) {
      if (!file.isFile) {
        continue;
      }
      final String normalized = p.posix.normalize(file.name).toLowerCase();
      if (normalized == endsWith || normalized.endsWith('/$endsWith')) {
        return file;
      }
    }
    return null;
  }

  ArchiveFile? _findRecoveryJsonEntry(Archive archive) {
    for (final ArchiveFile file in archive.files) {
      if (!file.isFile) {
        continue;
      }
      final String normalized = p.posix.normalize(file.name);
      if (normalized == 'recovery.json' || normalized.endsWith('/recovery.json')) {
        return file;
      }
    }
    return null;
  }

  void _ensureArchiveRestorable(Archive archive) {
    final BackupArchiveInspection inspection = _inspectArchive(archive);
    if (!inspection.safePaths) {
      throw StateError(kInvalidBackupArchiveMessage);
    }
    if (!inspection.isRestorable) {
      throw StateError('備份檔內容不完整，缺少必要的加密資料。');
    }
  }

  BackupArchiveInspection _inspectArchive(Archive archive) {
    var safePaths = true;
    var hasRecovery = false;
    var hasManifest = false;
    var entrySampleFound = false;
    var hasVaultPayload = false;

    for (final ArchiveFile file in archive.files) {
      final String rawName = file.name.replaceAll('\\', '/');
      final String normalized = p.posix.normalize(rawName);
      if (rawName.contains('..') || p.posix.isAbsolute(normalized)) {
        safePaths = false;
      }
      if (file.isFile &&
          (normalized == 'recovery.json' || normalized.endsWith('/recovery.json'))) {
        hasRecovery = true;
      }
      if (file.isFile &&
          (normalized == 'manifest.json.enc' ||
              normalized.endsWith('/manifest.json.enc'))) {
        hasManifest = true;
      }
      if (file.isFile &&
          normalized.startsWith('entries/') &&
          normalized.endsWith('.md.enc')) {
        entrySampleFound = true;
      }
      if (normalized.startsWith('entries/') || normalized.startsWith('assets/')) {
        hasVaultPayload = true;
      }
    }

    return BackupArchiveInspection(
      safePaths: safePaths,
      hasRecovery: hasRecovery,
      hasManifest: hasManifest,
      entrySampleFound: entrySampleFound,
      hasVaultPayload: hasVaultPayload,
    );
  }

  void _validateRestoredVaultPayload(Directory root) {
    final bool hasRecovery = File(p.join(root.path, 'recovery.json')).existsSync();
    final bool hasEntries = Directory(p.join(root.path, 'entries')).existsSync();
    if (!hasRecovery && !hasEntries) {
      throw StateError('備份檔內容不完整，找不到日記庫資料。');
    }
  }

  Future<void> _copyDirectoryTree(Directory source, Directory destination) async {
    await destination.create(recursive: true);
    await for (final FileSystemEntity entity
        in source.list(recursive: true, followLinks: false)) {
      final String relative = p.relative(entity.path, from: source.path);
      final String targetPath = p.join(destination.path, relative);
      if (entity is Directory) {
        await Directory(targetPath).create(recursive: true);
      } else if (entity is File) {
        await File(targetPath).parent.create(recursive: true);
        await entity.copy(targetPath);
      }
    }
  }
}

class BackupHealthStatusItem {
  const BackupHealthStatusItem({
    required this.label,
    required this.ok,
    required this.message,
  });

  final String label;
  final bool ok;
  final String message;
}

class BackupHealthReport {
  const BackupHealthReport({
    required this.ok,
    required this.statusItems,
    required this.entrySampleFound,
    required this.hasRecoveryMetadata,
    required this.hasManifest,
    required this.message,
  });

  final bool ok;
  final List<BackupHealthStatusItem> statusItems;
  final bool entrySampleFound;
  final bool hasRecoveryMetadata;
  final bool hasManifest;
  final String message;
}
