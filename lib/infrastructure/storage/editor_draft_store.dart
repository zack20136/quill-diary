import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:quill_diary/domain/diary/diary_draft.dart';
import 'package:quill_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/infrastructure/crypto/crypto_service.dart';
import 'package:quill_diary/infrastructure/storage/shared/media_type_utils.dart';
import 'package:quill_diary/infrastructure/storage/shared/vault_file_ops.dart';
import 'package:quill_diary/infrastructure/storage/vault_path_strategy.dart';

/// 管理本地加密草稿與待上傳附件暫存。
class EditorDraftStore {
  EditorDraftStore({required this._pathStrategy, required this._cryptoService});

  final VaultPathStrategy _pathStrategy;
  final CryptoService _cryptoService;

  /// 已 materialize 的暫時明文路徑快取：`draftKey` → `relativePath` → 絕對路徑。
  final Map<String, Map<String, String>> _materializedPreviewCache =
      <String, Map<String, String>>{};

  Future<EditorDraftRecord?> read(
    String draftKey,
    UnlockedVaultSession session,
  ) async {
    final File file = File(await _pathStrategy.editorDraftFilePath(draftKey));
    await recoverFileReplacement(file);
    if (!file.existsSync()) {
      return null;
    }

    final ParsedEncryptedDocument parsed = _cryptoService.parseFileBytes(
      await file.readAsBytes(),
    );
    final List<int> plain = await _cryptoService.decryptBytes(
      headerBytes: parsed.headerBytes,
      ciphertextBytes: parsed.ciphertextBytes,
      context: DecryptionContext(
        vaultId: session.vaultId,
        trustedDevice: session.trustedDevice,
        recoveryWrapKey: session.recoveryWrapKey,
        deviceSlotId: session.deviceSlotId,
      ),
    );
    final Object? decoded = jsonDecode(utf8.decode(plain));
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('草稿格式不正確。');
    }
    return EditorDraftRecord.fromJson(decoded);
  }

  /// 加密寫入草稿 JSON，並清除不再引用的 pending 附件。
  Future<void> write(
    String draftKey,
    EditorDraftRecord record,
    UnlockedVaultSession session, {
    void Function()? beforeCommit,
    void Function()? onCommitted,
  }) async {
    final RecoveryMetadata metadata = await _requireMetadataForSession(session);
    final List<int> recoveryWrapKey =
        session.recoveryWrapKey ??
        (throw StateError('目前 session 缺少 recovery wrap key。'));
    final Directory draftDir = await _pathStrategy.editorDraftDirectory(
      draftKey,
    );
    await draftDir.create(recursive: true);
    await (await _pathStrategy.editorDraftPendingDirectory(draftKey))
        .create(recursive: true);

    final Uint8List plainBytes = Uint8List.fromList(
      utf8.encode(jsonEncode(record.toJson())),
    );
    final EncryptionResult encrypted = await _cryptoService.encryptBytes(
      documentId: 'draft_$draftKey',
      vaultId: metadata.vaultId,
      plaintextBytes: plainBytes,
      contentType: 'application/json',
      recoveryWrapKey: recoveryWrapKey,
      recoverySlotKdf: metadata.kdf,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
    );
    await replaceFileBytesRecoverably(
      File(await _pathStrategy.editorDraftFilePath(draftKey)),
      encrypted.toFileBytes(),
      beforeCommit: beforeCommit,
      onCommitted: onCommitted,
    );
    await _prunePendingFiles(draftKey, record);
  }

  Future<void> delete(String draftKey) async {
    await clearMaterializedPendingFiles(draftKey);
    final Directory draftDir = await _pathStrategy.editorDraftDirectory(
      draftKey,
    );
    if (!draftDir.existsSync()) {
      return;
    }
    await draftDir.delete(recursive: true);
  }

  /// 刪除所有本地草稿與 pending 附件。
  ///
  /// 還原備份後應呼叫，避免舊草稿與還原後的正式日記庫不一致。
  Future<void> deleteAll() async {
    await clearAllMaterializedPendingFiles();
    final Directory draftsRoot = await _pathStrategy
        .editorDraftsRootDirectory();
    if (!draftsRoot.existsSync()) {
      return;
    }
    await draftsRoot.delete(recursive: true);
  }

  Future<String> stagePendingBytes(
    String draftKey,
    List<int> bytes,
    String filename,
    UnlockedVaultSession session,
  ) async {
    final metadata = await _requireMetadataForSession(session);
    final recoveryWrapKey =
        session.recoveryWrapKey ??
        (throw StateError('目前 session 缺少 recovery wrap key。'));
    final directory = await _pathStrategy.editorDraftPendingDirectory(draftKey);
    await directory.create(recursive: true);
    final storedName =
        '${DateTime.now().microsecondsSinceEpoch}_${_sanitizeFileName(p.basename(filename))}.enc';
    final file = File(p.join(directory.path, storedName));
    final now = DateTime.now();
    final encrypted = await _cryptoService.encryptBytes(
      documentId: 'draft_pending_${draftKey}_$storedName',
      vaultId: metadata.vaultId,
      plaintextBytes: bytes,
      contentType: mimeTypeFromFileName(filename),
      recoveryWrapKey: recoveryWrapKey,
      recoverySlotKdf: metadata.kdf,
      createdAt: now,
      updatedAt: now,
    );
    try {
      await file.writeAsBytes(encrypted.toFileBytes(), flush: true);
    } on Object {
      if (file.existsSync()) await file.delete();
      rethrow;
    }
    return pendingRelativePath(draftKey, file.path);
  }

  /// 讀入來源檔並以 LDJ2 加密暫存，回傳草稿內的相對路徑。
  Future<String> stagePendingFile(
    String draftKey,
    String sourcePath,
    UnlockedVaultSession session,
  ) async {
    final trimmed = sourcePath.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(sourcePath, 'sourcePath', '來源檔案路徑不可為空。');
    }
    return stagePendingBytes(
      draftKey,
      await File(trimmed).readAsBytes(),
      p.basename(trimmed),
      session,
    );
  }

  /// 將加密 pending 附件解密到暫時目錄，供預覽與分享使用。
  ///
  /// UI 不應直接讀取 [pendingAbsolutePath] 指向的 `.enc` 檔。
  Future<String> materializePendingFileForPreview(
    String draftKey,
    String relativePath,
    UnlockedVaultSession session,
  ) async {
    final String normalizedRelative = relativePath.replaceAll('\\', '/');
    final Map<String, String> draftCache = _materializedPreviewCache
        .putIfAbsent(draftKey, () => <String, String>{});
    final String? cached = draftCache[normalizedRelative];
    if (cached != null && File(cached).existsSync()) {
      return cached;
    }

    final String encryptedPath = await pendingAbsolutePath(
      draftKey,
      normalizedRelative,
    );
    final File encryptedFile = File(encryptedPath);
    if (!encryptedFile.existsSync()) {
      throw FileSystemException('找不到待解密的 pending 附件', encryptedPath);
    }

    final ParsedEncryptedDocument parsed = _cryptoService.parseFileBytes(
      await encryptedFile.readAsBytes(),
    );
    final List<int> plain = await _cryptoService.decryptBytes(
      headerBytes: parsed.headerBytes,
      ciphertextBytes: parsed.ciphertextBytes,
      context: DecryptionContext(
        vaultId: session.vaultId,
        trustedDevice: session.trustedDevice,
        recoveryWrapKey: session.recoveryWrapKey,
        deviceSlotId: session.deviceSlotId,
      ),
    );

    final Directory previewDir = await _materializedPreviewDirectory(draftKey);
    await previewDir.create(recursive: true);
    final String outputName = _materializedFileName(normalizedRelative);
    final String outputPath = p.join(previewDir.path, outputName);
    await File(outputPath).writeAsBytes(plain, flush: true);
    draftCache[normalizedRelative] = outputPath;
    return outputPath;
  }

  /// 清除指定草稿的暫時解密檔案。
  Future<void> clearMaterializedPendingFiles(String draftKey) async {
    _materializedPreviewCache.remove(draftKey);
    final Directory previewDir = await _materializedPreviewDirectory(draftKey);
    if (previewDir.existsSync()) {
      await previewDir.delete(recursive: true);
    }
  }

  /// 清除所有草稿的暫時解密檔案（session 鎖定或還原時呼叫）。
  Future<void> clearAllMaterializedPendingFiles() async {
    _materializedPreviewCache.clear();
    final Directory previewRoot = await _pathStrategy
        .editorDraftPreviewRootDirectory();
    if (previewRoot.existsSync()) {
      await previewRoot.delete(recursive: true);
    }
  }

  /// 掃描 drafts 根目錄，回傳仍有 draft.json.enc 的 key 集合。
  Future<Set<String>> listDraftKeys() async {
    final Directory draftsRoot = await _pathStrategy
        .editorDraftsRootDirectory();
    if (!draftsRoot.existsSync()) {
      return <String>{};
    }
    final Set<String> draftKeys = <String>{};
    for (final FileSystemEntity entity in draftsRoot.listSync()) {
      if (entity is! Directory) {
        continue;
      }
      final String draftKey = p.basename(entity.path);
      if (await hasDraft(draftKey)) {
        draftKeys.add(draftKey);
      }
    }
    return draftKeys;
  }

  Future<bool> hasDraft(String draftKey) async {
    return File(await _pathStrategy.editorDraftFilePath(draftKey)).existsSync();
  }

  Future<String> pendingRelativePath(
    String draftKey,
    String absolutePath,
  ) async {
    final Directory draftDir = await _pathStrategy.editorDraftDirectory(
      draftKey,
    );
    return p.relative(absolutePath, from: draftDir.path).replaceAll('\\', '/');
  }

  /// 回傳磁碟上加密 pending 檔的絕對路徑；UI 請改用 [materializePendingFileForPreview]。
  Future<String> pendingAbsolutePath(
    String draftKey,
    String relativePath,
  ) async {
    final Directory draftDir = await _pathStrategy.editorDraftDirectory(
      draftKey,
    );
    return p.normalize(
      p.join(draftDir.path, relativePath.replaceAll('/', p.separator)),
    );
  }

  Future<RecoveryMetadata> _requireMetadataForSession(
    UnlockedVaultSession session,
  ) async {
    final File file = File(await _pathStrategy.recoveryMetadataPath());
    if (!file.existsSync()) {
      throw StateError('找不到 Recovery metadata。');
    }
    final Object? decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Recovery metadata 格式不正確。');
    }
    final RecoveryMetadata metadata = RecoveryMetadata.fromJson(decoded);
    if (metadata.vaultId != session.vaultId) {
      throw StateError('目前 session 與 draft metadata 不一致。');
    }
    return metadata;
  }

  Future<void> _prunePendingFiles(
    String draftKey,
    EditorDraftRecord record,
  ) async {
    final Directory pendingDir = await _pathStrategy
        .editorDraftPendingDirectory(draftKey);
    if (!pendingDir.existsSync()) {
      return;
    }
    final Set<String> keepRelativePaths = record.pendingAttachments
        .map(
          (EditorDraftPendingAttachment attachment) => attachment.relativePath,
        )
        .toSet();
    for (final FileSystemEntity entity in pendingDir.listSync(
      recursive: true,
    )) {
      if (entity is! File) {
        continue;
      }
      final String relative = await pendingRelativePath(draftKey, entity.path);
      if (!keepRelativePaths.contains(relative)) {
        await entity.delete();
        final preview = _materializedPreviewCache[draftKey]?.remove(relative);
        if (preview != null && File(preview).existsSync()) {
          await File(preview).delete();
        }
      }
    }
  }

  Future<Directory> _materializedPreviewDirectory(String draftKey) async {
    return Directory(
      p.join(
        (await _pathStrategy.editorDraftPreviewRootDirectory()).path,
        draftKey,
      ),
    );
  }

  String _materializedFileName(String relativePath) {
    final String base = p.basename(relativePath);
    if (base.endsWith('.enc')) {
      return base.substring(0, base.length - 4);
    }
    return base;
  }

  String _sanitizeFileName(String fileName) {
    final String trimmed = fileName.trim();
    if (trimmed.isEmpty) {
      return 'attachment.bin';
    }
    return trimmed.replaceAll(RegExp(r'[^\w.\-]'), '_');
  }
}
