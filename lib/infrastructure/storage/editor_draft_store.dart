import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../domain/recovery/recovery_metadata.dart';
import '../../domain/security/unlocked_vault_session.dart';
import '../../features/editor/application/editor_draft_models.dart';
import '../crypto/crypto_service.dart';
import 'vault_path_strategy.dart';

/// 管理本地加密草稿與待上傳附件暫存。
class EditorDraftStore {
  EditorDraftStore({
    required VaultPathStrategy pathStrategy,
    required CryptoService cryptoService,
  }) : _pathStrategy = pathStrategy,
       _cryptoService = cryptoService;

  static const String _materializedPreviewRootName = 'quill_diary_draft_preview';

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
    UnlockedVaultSession session,
  ) async {
    final RecoveryMetadata metadata = await _requireMetadataForSession(session);
    final List<int> recoveryWrapKey =
        session.recoveryWrapKey ??
        (throw StateError('目前 session 缺少 recovery wrap key。'));
    final Directory draftDir = await _pathStrategy.editorDraftDirectory(
      draftKey,
    );
    await draftDir.create(recursive: true);
    await (await _pathStrategy.editorDraftPendingDirectory(
      draftKey,
    )).create(recursive: true);

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
    await File(
      await _pathStrategy.editorDraftFilePath(draftKey),
    ).writeAsBytes(encrypted.toFileBytes(), flush: true);
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

  /// 讀入來源檔並以 LDJ2 加密寫入 `pending/*.enc`，回傳相對路徑。
  Future<String> stagePendingFile(
    String draftKey,
    String sourcePath,
    UnlockedVaultSession session,
  ) async {
    final String trimmed = sourcePath.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(sourcePath, 'sourcePath', '來源檔案路徑不可為空。');
    }
    final File sourceFile = File(trimmed);
    if (!sourceFile.existsSync()) {
      throw FileSystemException('找不到待暫存的附件', trimmed);
    }

    final RecoveryMetadata metadata = await _requireMetadataForSession(session);
    final List<int> recoveryWrapKey =
        session.recoveryWrapKey ??
        (throw StateError('目前 session 缺少 recovery wrap key。'));

    final Directory pendingDir = await _pathStrategy
        .editorDraftPendingDirectory(draftKey);
    await pendingDir.create(recursive: true);
    final String baseName = _sanitizeFileName(p.basename(trimmed));
    final String storedName =
        '${DateTime.now().microsecondsSinceEpoch}_$baseName.enc';
    final String absoluteEncPath = p.join(pendingDir.path, storedName);
    final Uint8List sourceBytes = await sourceFile.readAsBytes();
    final DateTime now = DateTime.now();
    final EncryptionResult encrypted = await _cryptoService.encryptBytes(
      documentId: 'draft_pending_${draftKey}_$storedName',
      vaultId: metadata.vaultId,
      plaintextBytes: sourceBytes,
      contentType: _mimeTypeFromFileName(baseName),
      recoveryWrapKey: recoveryWrapKey,
      recoverySlotKdf: metadata.kdf,
      createdAt: now,
      updatedAt: now,
    );
    await File(
      absoluteEncPath,
    ).writeAsBytes(encrypted.toFileBytes(), flush: true);
    return await pendingRelativePath(draftKey, absoluteEncPath);
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
    final Map<String, String> draftCache = _materializedPreviewCache.putIfAbsent(
      draftKey,
      () => <String, String>{},
    );
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
    final Directory previewRoot = Directory(
      p.join(Directory.systemTemp.path, _materializedPreviewRootName),
    );
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
        _materializedPreviewCache[draftKey]?.remove(relative);
      }
    }
  }

  Future<Directory> _materializedPreviewDirectory(String draftKey) async {
    return Directory(
      p.join(
        Directory.systemTemp.path,
        _materializedPreviewRootName,
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

  String _mimeTypeFromFileName(String fileName) {
    switch (p.extension(fileName).toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.gif':
        return 'image/gif';
      default:
        return 'application/octet-stream';
    }
  }
}
