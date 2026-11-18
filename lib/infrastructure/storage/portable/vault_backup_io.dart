import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:quill_diary/domain/recovery/recovery_key.dart';
import 'package:quill_diary/domain/recovery/recovery_key_identity.dart';
import 'package:quill_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_diary/infrastructure/database/index_database_manager.dart';
import 'package:quill_diary/infrastructure/storage/backup_task_progress.dart';
import 'package:quill_diary/infrastructure/storage/editor_draft_store.dart';
import 'package:quill_diary/infrastructure/storage/portable/backup_archive_inspection.dart';
import 'package:quill_diary/infrastructure/storage/restore_precheck.dart';
import 'package:quill_diary/infrastructure/storage/shared/archive_extract.dart';
import 'package:quill_diary/infrastructure/storage/shared/zip_structure.dart';
import 'package:quill_diary/infrastructure/storage/vault_path_strategy.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';

/// 讀寫加密完整日記庫備份 zip 封存。
///
/// 一般正式資料直接複製密文；分身由儲存層去除草稿後重新加密。
/// 搜尋索引視為衍生資料，還原後重建。
class VaultBackupIo {
  VaultBackupIo({
    required this._pathStrategy,
    required this._repository,
    required this._indexDatabaseManager,
    required this._editorDraftStore,
    this.personaBackupFiles,
  });

  final VaultPathStrategy _pathStrategy;
  final VaultRepository _repository;
  final IndexDatabaseManager _indexDatabaseManager;
  final EditorDraftStore _editorDraftStore;

  /// 已在日記庫修改序列內呼叫；回傳 ZIP 相對路徑及正式分身密文。
  final Future<Map<String, Uint8List>> Function()? personaBackupFiles;

  Future<File> writeBackupZip(
    File target, {
    VaultBackupPurpose purpose = VaultBackupPurpose.normal,
    BackupTaskProgressListener? onProgress,
  }) => _repository.runVaultMutation(
    () => _writeBackupZip(target, purpose: purpose, onProgress: onProgress),
  );

  Future<File> _writeBackupZip(
    File target, {
    required VaultBackupPurpose purpose,
    BackupTaskProgressListener? onProgress,
  }) async {
    final preservedTags = await _repository.prepareTagCatalogBackup(
      preservation: purpose == VaultBackupPurpose.preservation,
    );
    final Directory vaultRoot = await _pathStrategy.vaultRootDirectory();
    final personas = Directory(p.join(vaultRoot.path, 'personas'));
    if (personaBackupFiles == null &&
        personas.existsSync() &&
        personas.listSync(followLinks: false).isNotEmpty) {
      throw StateError('備份人物分身需要已解鎖的日記庫');
    }
    final publishedPersonas = await personaBackupFiles?.call() ?? const {};
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
          if (relative == 'tag_styles.json' ||
              relative.startsWith('tag_styles.json.') &&
                  relative != 'tag_styles.json.enc' ||
              preservedTags.containsKey(relative)) {
            return ZipFileOperation.skip;
          }
          if (segments.isNotEmpty &&
              (segments.first == 'index' ||
                  segments.first == 'quarantine' ||
                  segments.first == 'chat_diary_drafts' ||
                  segments.first.toLowerCase() == 'personas' ||
                  segments.first == 'diary_organization_drafts' ||
                  segments.first == 'chat_diary_remote_cleanup' ||
                  segments.any(
                    (s) => s.endsWith('.tmp') || s.endsWith('.previous'),
                  ))) {
            return ZipFileOperation.skip;
          }
          return ZipFileOperation.include;
        },
      );
      for (final entry in preservedTags.entries) {
        encoder.addArchiveFile(
          ArchiveFile(entry.key, entry.value.length, entry.value),
        );
      }
      for (final entry in publishedPersonas.entries) {
        encoder.addArchiveFile(
          ArchiveFile(entry.key, entry.value.length, entry.value),
        );
      }
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
    } on ZipUnsafePathException {
      return const BackupInspectResult(
        ok: false,
        issue: VaultBackupIssue.unsafePath,
        layout: VaultBackupLayout.empty,
      );
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

    final VaultBackupLayout layout = inspectBackupLayout(zip.archive);
    RecoveryMetadata? recoveryMetadata;
    var ok = layout.isRestorable;
    var issue = ok ? VaultBackupIssue.passed : layout.issue;

    if (ok) {
      recoveryMetadata = _readRecoveryMetadataFromZip(zip.archive);
      if (recoveryMetadata == null) {
        ok = false;
        issue = VaultBackupIssue.invalidRecoveryJson;
      }
    }
    if (ok) {
      try {
        ensureArchiveExtractionBudget(zip.archive);
      } on ArchiveExtractionLimitException {
        ok = false;
        issue = VaultBackupIssue.extractionLimitExceeded;
      }
    }

    return BackupInspectResult(
      ok: ok,
      issue: issue,
      layout: layout,
      metadata: recoveryMetadata,
    );
  }

  /// 還原前驗證 zip 結構並讀取 recovery 預覽；不合格拋 [VaultBackupException]。
  Future<BackupRecoveryPreview> prepareRestorePreview(File backupFile) async {
    try {
      final OpenedZipArchive zip = await openZipArchive(backupFile);
      try {
        return BackupRecoveryPreview(metadata: _requireRestorableBackup(zip));
      } finally {
        await zip.close();
      }
    } on VaultBackupException {
      rethrow;
    } on ArchiveExtractionLimitException {
      throw const VaultBackupException(
        VaultBackupIssue.extractionLimitExceeded,
      );
    } on Object {
      throw const VaultBackupException(VaultBackupIssue.invalidArchive);
    }
  }

  Future<void> verifyBackupRecoveryKey(
    File backupFile,
    String recoveryKey,
  ) async {
    final normalized = RecoveryKey.normalize(recoveryKey);
    try {
      final OpenedZipArchive zip = await openZipArchive(backupFile);
      try {
        final RecoveryMetadata? metadata = _readRecoveryMetadataFromZip(
          zip.archive,
        );
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
          recoveryKey: normalized,
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
    await vaultRoot.parent.create(recursive: true);
    final Directory candidate = await vaultRoot.parent.createTemp(
      '${p.basename(vaultRoot.path)}_restore_',
    );
    try {
      final RecoveryMetadata backupMetadata = await _extractRestoreCandidate(
        backupFile,
        candidate,
        onProgress: onProgress,
      );
      _validateRestoredVaultPayload(candidate);
      if (preserveTrustedDeviceAccess) {
        final RecoveryMetadata? local = await _repository
            .readRecoveryMetadata();
        if (local?.hasSameRecoveryGenerationAs(backupMetadata) != true) {
          throw const VaultBackupException(
            VaultBackupIssue.recoveryKeyMismatch,
          );
        }
      }

      Directory? previousBackup;
      if (vaultRoot.existsSync()) {
        previousBackup = Directory(
          '${vaultRoot.path}.bak_${DateTime.now().microsecondsSinceEpoch}',
        );
        await vaultRoot.rename(previousBackup.path);
      }
      try {
        await candidate.rename(vaultRoot.path);
      } on Object {
        if (!vaultRoot.existsSync() && previousBackup != null) {
          await previousBackup.rename(vaultRoot.path);
        }
        rethrow;
      }

      _repository.clearRecoveryMetadataCache();
      final Directory strayVaultIndex = Directory(
        p.join(vaultRoot.path, 'index'),
      );
      if (strayVaultIndex.existsSync()) {
        await strayVaultIndex.delete(recursive: true);
      }

      await _repository.closeUnlockedResources();
      await _indexDatabaseManager.deleteDatabaseFiles();
      await _editorDraftStore.deleteAll();
      if (!preserveTrustedDeviceAccess) {
        await _repository.clearTrustedDeviceAccess();
      }
      if (previousBackup != null) {
        await _deleteRestoreDirectory(previousBackup);
      }
    } finally {
      await _deleteRestoreDirectory(candidate);
    }
  }

  Future<RecoveryMetadata> _extractRestoreCandidate(
    File backupFile,
    Directory candidate, {
    BackupTaskProgressListener? onProgress,
  }) async {
    try {
      final OpenedZipArchive zip = await openZipArchive(backupFile);
      try {
        final RecoveryMetadata metadata = _requireRestorableBackup(zip);
        await extractArchiveToDirectory(
          zip: zip,
          targetDirectory: candidate,
          onProgress: onProgress,
        );
        return metadata;
      } finally {
        await zip.close();
      }
    } on VaultBackupException {
      rethrow;
    } on ArchiveExtractionLimitException {
      throw const VaultBackupException(
        VaultBackupIssue.extractionLimitExceeded,
      );
    } on Object {
      throw const VaultBackupException(VaultBackupIssue.invalidArchive);
    }
  }

  Future<void> _deleteRestoreDirectory(Directory directory) async {
    try {
      if (directory.existsSync()) await directory.delete(recursive: true);
    } on FileSystemException {
      // 清理失敗不能掩蓋原始錯誤，也不撤銷已完成的替換。
    }
  }

  RecoveryMetadata _requireRestorableBackup(OpenedZipArchive zip) {
    if (zip.archive.files.isEmpty) {
      throw const VaultBackupException(VaultBackupIssue.invalidArchive);
    }
    final VaultBackupLayout layout = inspectBackupLayout(zip.archive);
    if (!layout.safePaths) {
      throw const VaultBackupException(VaultBackupIssue.invalidArchive);
    }
    if (!layout.isRestorable) {
      throw VaultBackupException(layout.issue);
    }
    ensureArchiveExtractionBudget(zip.archive);
    return _readRecoveryMetadataFromZip(zip.archive) ??
        (throw const VaultBackupException(
          VaultBackupIssue.invalidRecoveryJson,
        ));
  }

  RecoveryMetadata? _readRecoveryMetadataFromZip(Archive archive) {
    final Uint8List? bytes = readZipEntry(
      archive,
      relativePath: 'recovery.json',
    );
    return bytes == null ? null : parseRecoveryMetadataBytes(bytes);
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
}

/// 完整備份 zip 備份檢查結果（`inspectBackup`）。
final class BackupInspectResult {
  const BackupInspectResult({
    required this.ok,
    required this.issue,
    required this.layout,
    this.metadata,
  });

  final bool ok;
  final VaultBackupIssue issue;
  final VaultBackupLayout layout;
  final RecoveryMetadata? metadata;
}
