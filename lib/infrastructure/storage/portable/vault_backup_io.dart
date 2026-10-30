import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:quill_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_diary/infrastructure/database/index_database_manager.dart';
import 'package:quill_diary/infrastructure/storage/backup_task_progress.dart';
import 'package:quill_diary/infrastructure/storage/editor_draft_store.dart';
import 'package:quill_diary/infrastructure/storage/portable/backup_archive_inspection.dart';
import 'package:quill_diary/infrastructure/storage/restore_precheck.dart';
import 'package:quill_diary/infrastructure/storage/shared/archive_extract.dart';
import 'package:quill_diary/infrastructure/storage/vault_path_strategy.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';

/// 讀寫加密完整 vault 備份 zip 封存。
///
/// 備份複製 vault 權威加密檔與復原中繼資料；
/// 搜尋索引視為衍生資料，還原後重建。
class VaultBackupIo {
  VaultBackupIo({
    required this._pathStrategy,
    required this._repository,
    required this._indexDatabaseManager,
    required this._editorDraftStore,
    this._prepareVault,
  });

  final VaultPathStrategy _pathStrategy;
  final VaultRepository _repository;
  final IndexDatabaseManager _indexDatabaseManager;
  final EditorDraftStore _editorDraftStore;
  final Future<void> Function()? _prepareVault;

  Future<File> writeBackupZip(
    File target, {
    BackupTaskProgressListener? onProgress,
  }) => _repository.runVaultMutation(() async {
    await _prepareVault?.call();
    return _writeBackupZip(target, onProgress: onProgress);
  });

  Future<File> _writeBackupZip(
    File target, {
    BackupTaskProgressListener? onProgress,
  }) async {
    final Directory vaultRoot = await _pathStrategy.vaultRootDirectory();
    final entries = Directory(p.join(vaultRoot.path, 'entries'));
    if (entries.existsSync()) {
      await for (final entity in entries.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File && entity.path.endsWith('.enc.previous')) {
          final primary = entity.path.substring(
            0,
            entity.path.length - '.previous'.length,
          );
          if (!File(primary).existsSync()) await entity.rename(primary);
        }
      }
    }
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
          if (segments.isNotEmpty &&
              (segments.first == 'index' ||
                  segments.first == 'quarantine' ||
                  segments.first == 'chat_diary_drafts' ||
                  segments.first == 'chat_diary_remote_cleanup' ||
                  segments.any(
                    (s) => s.endsWith('.tmp') || s.endsWith('.previous'),
                  ))) {
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
        issue: VaultBackupIssue.missingFile,
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
        issue: VaultBackupIssue.invalidZip,
        layout: VaultBackupLayout.empty,
      );
    }
  }

  BackupInspectResult _inspectOpenedZip(OpenedZipArchive zip) {
    if (zip.archive.files.isEmpty) {
      return const BackupInspectResult(
        ok: false,
        issue: VaultBackupIssue.invalidZip,
        layout: VaultBackupLayout.empty,
      );
    }

    final VaultBackupLayout layout = inspectZipEntryNames(
      zip.archive.files.map((ArchiveFile file) => file.name),
    );
    var ok = layout.isRestorable;
    var issue = ok ? VaultBackupIssue.passed : layout.issue;

    if (ok && layout.hasRecovery) {
      final Uint8List? recoveryBytes = readZipEntry(
        zip.archive,
        pathSuffix: 'recovery.json',
      );
      if (recoveryBytes == null ||
          parseRecoveryMetadataBytes(recoveryBytes) == null) {
        ok = false;
        issue = VaultBackupIssue.invalidRecoveryJson;
      }
    }

    return BackupInspectResult(ok: ok, issue: issue, layout: layout);
  }

  /// 還原前驗證 zip 結構並讀取 recovery 預覽；不合格拋 [VaultBackupException]。
  Future<BackupRecoveryPreview> prepareRestorePreview(File backupFile) async {
    try {
      final OpenedZipArchive zip = await openZipArchive(backupFile);
      try {
        if (zip.archive.files.isEmpty) {
          throw const VaultBackupException(VaultBackupIssue.invalidArchive);
        }
        final VaultBackupLayout layout = inspectZipEntryNames(
          zip.archive.files.map((ArchiveFile file) => file.name),
        );
        if (!layout.isRestorable) {
          throw VaultBackupException(layout.issue);
        }
        final Uint8List? recoveryBytes = readZipEntry(
          zip.archive,
          pathSuffix: 'recovery.json',
        );
        final RecoveryMetadata? metadata = recoveryBytes == null
            ? null
            : parseRecoveryMetadataBytes(recoveryBytes);
        if (metadata == null) {
          throw const VaultBackupException(
            VaultBackupIssue.invalidRecoveryJson,
          );
        }
        return BackupRecoveryPreview(metadata: metadata);
      } finally {
        await zip.close();
      }
    } on VaultBackupException {
      rethrow;
    } on Object {
      throw const VaultBackupException(VaultBackupIssue.invalidArchive);
    }
  }

  Future<BackupRecoveryPreview> peekBackupRecovery(File backupFile) {
    return prepareRestorePreview(backupFile);
  }

  Future<void> verifyBackupRecoveryKey(
    File backupFile,
    String recoveryKey,
  ) async {
    try {
      final OpenedZipArchive zip = await openZipArchive(backupFile);
      try {
        final Uint8List? recoveryBytes = readZipEntry(
          zip.archive,
          pathSuffix: 'recovery.json',
        );
        final RecoveryMetadata? metadata = recoveryBytes == null
            ? null
            : parseRecoveryMetadataBytes(recoveryBytes);
        if (metadata == null) {
          throw const VaultBackupException(
            VaultBackupIssue.recoveryInfoMissing,
          );
        }
        final Uint8List? sampleBytes = readEncryptedSampleBytes(zip.archive);
        if (sampleBytes == null) {
          throw const VaultBackupException(VaultBackupIssue.noEncryptedSample);
        }
        await _repository.verifyRecoveryKeyAgainstBackupBytes(
          metadata: metadata,
          recoveryKey: recoveryKey,
          encryptedDocumentBytes: sampleBytes,
        );
      } finally {
        await zip.close();
      }
    } on VaultBackupException {
      rethrow;
    } on Object {
      throw const VaultBackupException(VaultBackupIssue.invalidArchive);
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
    } on VaultBackupException {
      if (tempRoot.existsSync()) {
        await tempRoot.delete(recursive: true);
      }
      rethrow;
    } on Object {
      if (tempRoot.existsSync()) {
        await tempRoot.delete(recursive: true);
      }
      throw const VaultBackupException(VaultBackupIssue.invalidArchive);
    }

    _validateRestoredVaultPayload(tempRoot);

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

    final Directory strayVaultIndex = Directory(
      p.join(vaultRoot.path, 'index'),
    );
    if (strayVaultIndex.existsSync()) {
      await strayVaultIndex.delete(recursive: true);
    }

    await _repository.closeUnlockedResources();
    await _indexDatabaseManager.deleteDatabaseFiles();
    await _editorDraftStore.deleteAll();
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
      throw const VaultBackupException(VaultBackupIssue.invalidArchive);
    }
    if (!layout.isRestorable) {
      throw VaultBackupException(layout.issue);
    }
  }

  void _validateRestoredVaultPayload(Directory root) {
    final bool hasRecovery = File(p.join(root.path, 'recovery.json'))
        .existsSync();
    final bool hasEntries = Directory(p.join(root.path, 'entries'))
        .existsSync();
    if (!hasRecovery) {
      throw const VaultBackupException(VaultBackupIssue.missingRecovery);
    }
    if (!hasEntries) {
      throw const VaultBackupException(VaultBackupIssue.missingVaultPayload);
    }
  }

  Future<void> _copyDirectoryTree(
    Directory source,
    Directory destination,
  ) async {
    await destination.create(recursive: true);
    await for (final FileSystemEntity entity in source.list(
      recursive: true,
      followLinks: false,
    )) {
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
    required this.issue,
    required this.layout,
  });

  final bool ok;
  final VaultBackupIssue issue;
  final VaultBackupLayout layout;
}
