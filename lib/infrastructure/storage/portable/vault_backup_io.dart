import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import '../../../domain/recovery/recovery_metadata.dart';
import '../../database/index_database_manager.dart';
import '../restore_precheck.dart';
import '../shared/archive_extract.dart';
import '../tag_styles_store.dart';
import '../backup_task_progress.dart';
import '../vault_path_strategy.dart';
import '../vault_repository.dart';
import 'backup_archive_inspection.dart';

/// 讀寫加密完整 vault 備份 zip 封存。
///
/// 備份複製 vault 權威加密檔與復原中繼資料；
/// 搜尋索引視為衍生資料，還原後重建。
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

  Future<File> writeBackupZip(
    File target, {
    BackupTaskProgressListener? onProgress,
  }) async {
    final Directory vaultRoot = await _pathStrategy.vaultRootDirectory();
    await target.parent.create(recursive: true);
    onProgress?.call(
      const BackupTaskProgress(phase: BackupTaskPhase.creatingBackup),
    );
    final ZipFileEncoder encoder = ZipFileEncoder();
    encoder.create(target.path);
    try {
      await encoder.addDirectory(
        vaultRoot,
        includeDirName: false,
        filter: (FileSystemEntity entity, double progress) {
          onProgress?.call(
            BackupTaskProgress(
              phase: BackupTaskPhase.creatingBackup,
              fraction: progress.clamp(0.0, 1.0),
            ),
          );
          final String relative = p.relative(entity.path, from: vaultRoot.path);
          final List<String> segments = p.split(relative);
          if (segments.isNotEmpty && segments.first == 'index') {
            return ZipFileOperation.skip;
          }
          return ZipFileOperation.include;
        },
      );
    } finally {
      await encoder.close();
    }
    return target;
  }

  /// 備份檢查（`inspectBackup`）：驗證 zip 結構與 recovery.json。
  Future<BackupInspectResult> inspectBackup(File backupFile) async {
    if (!backupFile.existsSync()) {
      return const BackupInspectResult(
        ok: false,
        message: VaultBackupLayout.missingFileMessage,
        layout: VaultBackupLayout.empty,
      );
    }

    try {
      final OpenedZipArchive zip = await openZipArchive(backupFile);
      try {
        return _inspectOpenedZip(zip);
      } finally {
        await zip.close();
      }
    } on Object {
      return const BackupInspectResult(
        ok: false,
        message: VaultBackupLayout.invalidZipMessage,
        layout: VaultBackupLayout.empty,
      );
    }
  }

  BackupInspectResult _inspectOpenedZip(OpenedZipArchive zip) {
    if (zip.archive.files.isEmpty) {
      return const BackupInspectResult(
        ok: false,
        message: VaultBackupLayout.invalidZipMessage,
        layout: VaultBackupLayout.empty,
      );
    }

    final VaultBackupLayout layout = inspectZipEntryNames(
      zip.archive.files.map((ArchiveFile file) => file.name),
    );
    var ok = layout.isRestorable;
    var message = ok ? '備份檔案檢查通過。' : layout.failureMessage;

    if (ok && layout.hasRecovery) {
      final Uint8List? recoveryBytes =
          readZipEntry(zip.archive, pathSuffix: 'recovery.json');
      if (recoveryBytes == null || parseRecoveryMetadataBytes(recoveryBytes) == null) {
        ok = false;
        message = VaultBackupLayout.invalidRecoveryJsonMessage;
      }
    }

    return BackupInspectResult(ok: ok, message: message, layout: layout);
  }

  /// 還原前驗證 zip 結構並讀取 recovery 預覽；不合格拋 [StateError]。
  Future<BackupRecoveryPreview> prepareRestorePreview(File backupFile) async {
    try {
      final OpenedZipArchive zip = await openZipArchive(backupFile);
      try {
        if (zip.archive.files.isEmpty) {
          throw StateError(kInvalidBackupArchiveMessage);
        }
        final VaultBackupLayout layout = inspectZipEntryNames(
          zip.archive.files.map((ArchiveFile file) => file.name),
        );
        if (!layout.isRestorable) {
          throw StateError(layout.failureMessage);
        }
        final Uint8List? recoveryBytes =
            readZipEntry(zip.archive, pathSuffix: 'recovery.json');
        final RecoveryMetadata? metadata = recoveryBytes == null
            ? null
            : parseRecoveryMetadataBytes(recoveryBytes);
        if (metadata == null) {
          throw StateError(VaultBackupLayout.invalidRecoveryJsonMessage);
        }
        return BackupRecoveryPreview(
          hasRecovery: true,
          metadata: metadata,
        );
      } finally {
        await zip.close();
      }
    } on StateError {
      rethrow;
    } on Object {
      throw StateError(kInvalidBackupArchiveMessage);
    }
  }

  Future<BackupRecoveryPreview> peekBackupRecovery(File backupFile) {
    return prepareRestorePreview(backupFile);
  }

  Future<void> verifyBackupRecoveryKey(File backupFile, String recoveryKey) async {
    try {
      final OpenedZipArchive zip = await openZipArchive(backupFile);
      try {
        final Uint8List? recoveryBytes =
            readZipEntry(zip.archive, pathSuffix: 'recovery.json');
        final RecoveryMetadata? metadata = recoveryBytes == null
            ? null
            : parseRecoveryMetadataBytes(recoveryBytes);
        if (metadata == null) {
          throw StateError('此備份沒有復原金鑰資訊，無法驗證。');
        }
        final Uint8List? sampleBytes = readEncryptedSampleBytes(zip.archive);
        if (sampleBytes == null) {
          throw StateError(kBackupNoEncryptedSampleMessage);
        }
        await _repository.verifyRecoveryKeyAgainstBackupBytes(
          metadata: metadata,
          recoveryKey: recoveryKey,
          encryptedDocumentBytes: sampleBytes,
        );
      } finally {
        await zip.close();
      }
    } on StateError {
      rethrow;
    } on Object {
      throw StateError(kInvalidBackupArchiveMessage);
    }
  }

  Future<void> restoreBackupZip(
    File backupFile, {
    bool preserveTrustedDeviceAccess = false,
    BackupTaskProgressListener? onProgress,
  }) async {
    final Directory vaultRoot = await _pathStrategy.vaultRootDirectory();
    final Directory tempRoot = Directory('${vaultRoot.path}_restore_tmp');
    if (tempRoot.existsSync()) {
      await tempRoot.delete(recursive: true);
    }
    await tempRoot.create(recursive: true);

    try {
      final OpenedZipArchive zip = await openZipArchive(backupFile);
      try {
        _ensureZipRestorable(zip);
        await extractArchiveToDirectory(
          zip: zip,
          targetDirectory: tempRoot,
          onProgress: onProgress,
        );
      } finally {
        await zip.close();
      }
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
      // repository 或索引可能已關閉；改從磁碟上的 vault 檔案讀取。
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

  void _ensureZipRestorable(OpenedZipArchive zip) {
    final VaultBackupLayout layout = inspectZipEntryNames(
      zip.archive.files.map((ArchiveFile file) => file.name),
    );
    if (!layout.safePaths) {
      throw StateError(kInvalidBackupArchiveMessage);
    }
    if (!layout.isRestorable) {
      throw StateError(layout.failureMessage);
    }
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

/// 完整備份 zip 備份檢查結果（`inspectBackup`）。
final class BackupInspectResult {
  const BackupInspectResult({
    required this.ok,
    required this.message,
    required this.layout,
  });

  final bool ok;
  final String message;
  final VaultBackupLayout layout;
}
