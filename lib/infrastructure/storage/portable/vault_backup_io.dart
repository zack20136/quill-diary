import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:path/path.dart' as p;
import 'package:quill_diary/domain/recovery/recovery_key.dart';
import 'package:quill_diary/domain/recovery/recovery_key_identity.dart';
import 'package:quill_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/crypto/crypto_service.dart';
import 'package:quill_diary/infrastructure/storage/backup_task_progress.dart';
import 'package:quill_diary/infrastructure/storage/portable/backup_archive_inspection.dart';
import 'package:quill_diary/infrastructure/storage/portable/backup_integrity.dart';
import 'package:quill_diary/infrastructure/storage/portable/vault_restore_transaction.dart';
import 'package:quill_diary/infrastructure/storage/restore_precheck.dart';
import 'package:quill_diary/infrastructure/storage/shared/archive_extract.dart';
import 'package:quill_diary/infrastructure/storage/shared/vault_file_ops.dart';
import 'package:quill_diary/infrastructure/storage/shared/zip_structure.dart';
import 'package:quill_diary/infrastructure/storage/tag_catalog_store.dart';
import 'package:quill_diary/infrastructure/storage/vault_path_strategy.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';
import 'package:quill_diary/shared/data_versions.dart';

/// 讀寫加密完整日記庫備份 zip 封存。
///
/// 一般正式資料直接複製密文；分身由儲存層去除草稿後重新加密。
/// 搜尋索引視為衍生資料，還原後重建。
class VaultBackupIo {
  VaultBackupIo({
    required this._pathStrategy,
    required this._repository,
    this.personaBackupFiles,
  });

  final VaultPathStrategy _pathStrategy;
  final VaultRepository _repository;
  final _crypto = LocalCryptoService();
  bool _restoring = false;

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
    final metadata =
        await _repository.readRecoveryMetadata() ??
        (throw const VaultBackupException(VaultBackupIssue.missingRecovery));
    final session =
        _repository.unlockedSessionForBackup ??
        (throw StateError('備份需要已解鎖的日記庫。'));
    final wrapKey = requireRecoveryWrapKey(session);
    final context = vaultDecryptionContext(session);
    final id = generateBackupId();
    final generated = <String, List<int>>{
      'recovery.json': utf8.encode(
        jsonEncode({
          ...metadata.toJson(),
          'backup_format_version': DataVersions.vaultBackup,
          'backup_id': id,
        }),
      ),
      ...preservedTags,
      ...publishedPersonas,
    };
    final files = <String, File>{};
    await for (final item in vaultRoot.list(
      recursive: true,
      followLinks: false,
    )) {
      if (item is! File) continue;
      final path = p
          .split(p.relative(item.path, from: vaultRoot.path))
          .join('/');
      if (backupMemberType(path) != 'file' ||
          generated.containsKey(path) ||
          path.startsWith('personas/') ||
          path.startsWith('preservation/')) {
        continue;
      }
      files[path] = item;
    }
    final names = [...files.keys, ...generated.keys]..sort();
    await target.parent.create(recursive: true);
    onProgress?.call(
      const BackupTaskProgress(phase: BackupTaskPhase.creatingBackup),
    );
    final ZipFileEncoder encoder = ZipFileEncoder();
    encoder.create(target.path, level: ZipFileEncoder.store);
    try {
      final sha256 = const DartSha256();
      final members = [
        backupMember(
          path: 'entries',
          length: 0,
          hash: (await sha256.hash([])).bytes,
        ),
      ];
      encoder.addArchiveFile(ArchiveFile.directory('entries/'));
      for (final name in names) {
        final bytes = generated[name];
        final file = files[name];
        if (bytes != null) {
          members.add(
            backupMember(
              path: name,
              length: bytes.length,
              hash: (await sha256.hash(bytes)).bytes,
            ),
          );
          encoder.addArchiveFile(ArchiveFile(name, bytes.length, bytes));
        } else {
          if (purpose == VaultBackupPurpose.normal && name.endsWith('.enc')) {
            await _crypto.verifyFile(file!, context);
          }
          members.add(
            backupMember(
              path: name,
              length: await file!.length(),
              hash: (await sha256File(file)).bytes,
            ),
          );
          await encoder.addFile(file, name);
        }
        onProgress?.call(
          BackupTaskProgress(
            phase: BackupTaskPhase.creatingBackup,
            fraction: (members.length - 1) / (names.length + 1),
          ),
        );
      }
      final payload = await backupIntegrityPayload(
        backupId: id,
        metadata: metadata,
        purpose: purpose,
        members: members,
      );
      final now = DateTime.now();
      final envelope = (await _crypto.encryptBytes(
        documentId: 'backup_integrity_$id',
        vaultId: metadata.vaultId,
        plaintextBytes: utf8.encode(jsonEncode(payload)),
        contentType: 'application/json',
        recoveryWrapKey: wrapKey,
        recoverySlotKdf: metadata.kdf,
        createdAt: now,
        updatedAt: now,
      )).toFileBytes();
      encoder.addArchiveFile(
        ArchiveFile(backupIntegrityPath, envelope.length, envelope),
      );
    } finally {
      await encoder.close();
    }
    final archive = await openZipArchive(target);
    try {
      await verifyBackupIntegrity(
        archive: archive.archive,
        crypto: _crypto,
        backupId: id,
        metadata: metadata,
        wrapKey: wrapKey,
      );
    } finally {
      await archive.close();
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
    } on VaultBackupException catch (error) {
      return BackupInspectResult(
        ok: false,
        issue: error.issue,
        layout: VaultBackupLayout.empty,
      );
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
      recoveryMetadata = _readBackupPreview(zip.archive)?.metadata;
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
        return _requireRestorableBackup(zip);
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

  Future<VerifiedBackupKey> verifyBackupRecoveryKey(
    File backupFile,
    String recoveryKey,
  ) async {
    final normalized = RecoveryKey.normalize(recoveryKey);
    try {
      final zip = await openZipArchive(backupFile);
      try {
        final preview =
            _readBackupPreview(zip.archive) ??
            (throw const VaultBackupException(
              VaultBackupIssue.recoveryInfoMissing,
            ));
        final metadata = preview.metadata;
        final wrapKey = await _crypto.deriveRecoveryWrapKey(
          recoveryKey: normalized,
          kdf: metadata.kdf,
        );
        final sample =
            zip.archive.findFile(
              preview.backupId == null
                  ? 'manifest.json.enc'
                  : backupIntegrityPath,
            ) ??
            zip.archive.files
                .where(
                  (file) =>
                      file.isFile &&
                      file.name.startsWith('entries/') &&
                      file.name.endsWith('.md.enc'),
                )
                .firstOrNull;
        if (sample == null) {
          throw const VaultBackupException(VaultBackupIssue.noEncryptedSample);
        }
        final work = await createWorkingDirectory(_pathStrategy, 'restore_key');
        try {
          final file = File(p.join(work.path, 'sample.enc'));
          final output = OutputFileStream(file.path);
          try {
            writeZipEntry(sample, output);
          } finally {
            await output.close();
          }
          await _crypto.verifyFile(
            file,
            DecryptionContext.recovery(
              recoveryWrapKey: wrapKey,
              vaultId: metadata.vaultId,
            ),
          );
        } finally {
          await deleteWorkingDirectory(work);
        }
        return (preview: preview, wrapKey: wrapKey, recoveryKey: normalized);
      } finally {
        await zip.close();
      }
    } on SecretBoxAuthenticationError {
      throw const VaultBackupException(VaultBackupIssue.recoveryKeyMismatch);
    } on VaultBackupException {
      rethrow;
    } on Object {
      throw const VaultBackupException(VaultBackupIssue.invalidArchive);
    }
  }

  Future<UnlockedVaultSession> restoreBackupZip(
    File backupFile, {
    bool preserveTrustedDeviceAccess = false,
    BackupRecoveryPreview? expectedPreview,
    VerifiedBackupKey? verifiedKey,
    BackupTaskProgressListener? onProgress,
  }) async {
    if (_restoring) throw StateError('已有日記庫還原正在執行。');
    _restoring = true;
    try {
      return await _repository.runVaultMutation(() async {
        final transaction = await VaultRestoreTransaction.forPaths(
          _pathStrategy,
        );
        await transaction.prepare();
        final UnlockedVaultSession restored;
        try {
          restored = await _extractAndPrepare(
            backupFile,
            transaction: transaction,
            expectedPreview: expectedPreview,
            verifiedKey: verifiedKey,
            preserveTrustedDeviceAccess: preserveTrustedDeviceAccess,
            onProgress: onProgress,
          );
        } on Object {
          await transaction.recover();
          rethrow;
        }
        await _repository.switchToRestoredVault(transaction, restored);
        return restored;
      });
    } finally {
      _restoring = false;
    }
  }

  Future<UnlockedVaultSession> _extractAndPrepare(
    File backupFile, {
    required VaultRestoreTransaction transaction,
    required BackupRecoveryPreview? expectedPreview,
    required VerifiedBackupKey? verifiedKey,
    required bool preserveTrustedDeviceAccess,
    BackupTaskProgressListener? onProgress,
  }) async {
    final OpenedZipArchive zip;
    try {
      zip = await openZipArchive(backupFile);
    } on ArchiveExtractionLimitException {
      throw const VaultBackupException(
        VaultBackupIssue.extractionLimitExceeded,
      );
    } on Object {
      throw const VaultBackupException(VaultBackupIssue.invalidArchive);
    }
    try {
      final preview = _requireRestorableBackup(zip);
      final metadata = preview.metadata;
      for (final expected in [expectedPreview, verifiedKey?.preview]) {
        if (expected != null &&
            (expected.backupId != preview.backupId ||
                !expected.metadata.hasSameRecoveryGenerationAs(metadata))) {
          throw const VaultBackupException(
            VaultBackupIssue.invalidBackupIntegrity,
          );
        }
      }
      final trusted = verifiedKey == null
          ? await _repository.trustedSessionForBackup(metadata)
          : null;
      final wrapKey = verifiedKey?.wrapKey ?? trusted?.recoveryWrapKey;
      if (wrapKey == null || preserveTrustedDeviceAccess && trusted == null) {
        throw const VaultBackupException(VaultBackupIssue.recoveryKeyMismatch);
      }
      final id = preview.backupId;
      if (id != null) {
        try {
          await verifyBackupIntegrity(
            archive: zip.archive,
            crypto: _crypto,
            backupId: id,
            metadata: metadata,
            wrapKey: wrapKey,
          );
        } on Object {
          throw const VaultBackupException(
            VaultBackupIssue.invalidBackupIntegrity,
          );
        }
      }
      final size = zip.archive.files.fold<int>(
        0,
        (sum, file) => sum + file.size,
      );
      await transaction.checkSpace(size + 32 * 1024 * 1024);
      final candidate = Directory(p.join(transaction.candidate.path, 'vault'));
      try {
        await extractArchiveToDirectory(
          zip: zip,
          targetDirectory: candidate,
          onProgress: onProgress,
          include: (path, isFile) =>
              backupMemberType(path) == (isFile ? 'file' : 'directory') ||
              id == null &&
                  (path == 'tag_styles.json' ||
                      path == 'recovery_rotation.pending' ||
                      path == 'recovery_rotation.pending.previous' ||
                      path == 'recovery_rotation.pending.tmp'),
        );
      } on ArchiveExtractionLimitException {
        throw const VaultBackupException(
          VaultBackupIssue.extractionLimitExceeded,
        );
      } on FormatException {
        throw const VaultBackupException(VaultBackupIssue.invalidArchive);
      }
      _validateRestoredVaultPayload(candidate);
      if (id != null) {
        await atomicWriteString(
          File(p.join(candidate.path, 'recovery.json')),
          jsonEncode(metadata.toJson()),
        );
      }
      try {
        return await _repository.prepareRestoredVault(
          workingRoot: transaction.candidate,
          metadata: metadata,
          session: UnlockedVaultSession(
            vaultId: metadata.vaultId,
            recoveryWrapKey: wrapKey,
            trustedDevice:
                preserveTrustedDeviceAccess && trusted?.trustedDevice == true,
            deviceSlotId: preserveTrustedDeviceAccess
                ? trusted?.deviceSlotId
                : null,
          ),
          recoveryKey: verifiedKey?.recoveryKey,
        );
      } on TagCatalogException catch (error) {
        if (error.kind == TagCatalogFailure.io) rethrow;
        throw const VaultBackupException(VaultBackupIssue.invalidBackupContent);
      } on Object catch (error) {
        if (!isUnreadableContentError(error)) rethrow;
        throw const VaultBackupException(VaultBackupIssue.invalidBackupContent);
      }
    } finally {
      await zip.close();
    }
  }

  BackupRecoveryPreview _requireRestorableBackup(OpenedZipArchive zip) {
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
    return _readBackupPreview(zip.archive) ??
        (throw const VaultBackupException(
          VaultBackupIssue.invalidRecoveryJson,
        ));
  }

  BackupRecoveryPreview? _readBackupPreview(Archive archive) {
    final Uint8List? bytes = readZipEntry(
      archive,
      relativePath: 'recovery.json',
    );
    if (bytes == null) return null;
    final metadata = parseRecoveryMetadataBytes(bytes);
    if (metadata == null) return null;
    return BackupRecoveryPreview(
      metadata: metadata,
      backupId: readBackupId(
        archive,
        jsonDecode(utf8.decode(bytes)) as Map<String, Object?>,
      ),
    );
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
