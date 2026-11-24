import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:quill_diary/domain/diary/editor_draft.dart';
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
    final Directory draftDir = await _pathStrategy.editorDraftDirectory(
      draftKey,
    );
    await draftDir.create(recursive: true);
    await (await _pathStrategy.editorDraftPendingDirectory(draftKey))
        .create(recursive: true);

    await writeEncryptedVaultJson(
      file: File(await _pathStrategy.editorDraftFilePath(draftKey)),
      crypto: _cryptoService,
      session: session,
      metadata: metadata,
      documentId: 'draft_$draftKey',
      plaintextBytes: utf8.encode(jsonEncode(record.toJson())),
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
      beforeCommit: beforeCommit,
      onCommitted: onCommitted,
    );
    await _prunePendingFiles(draftKey, record);
  }

  Future<void> delete(String draftKey) async {
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
    final recoveryWrapKey = requireRecoveryWrapKey(session);
    final directory = await _pathStrategy.editorDraftPendingDirectory(draftKey);
    await directory.create(recursive: true);
    final storedName =
        '${DateTime.now().microsecondsSinceEpoch}_${_sanitizeFileName(p.basename(filename))}.enc';
    final file = File(p.join(directory.path, storedName));
    final now = DateTime.now();
    final encrypted = await _cryptoService.encryptBytes(
      documentId: draftAttachmentDocumentId(draftKey, storedName),
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

  Future<Uint8List> readPendingAttachment(
    ({String draftKey, String path}) source,
    UnlockedVaultSession session,
  ) async {
    final bytes = await readEncryptedDraftAttachment(
      crypto: _cryptoService,
      source: source,
      context: vaultDecryptionContext(session),
    );
    return bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
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

  Future<String> pendingAbsolutePath(
    String draftKey,
    String relativePath,
  ) async {
    final Directory draftDir = await _pathStrategy.editorDraftDirectory(
      draftKey,
    );
    final String safeRelative = _safePendingRelativePath(relativePath);
    final String root = p.normalize(draftDir.path);
    final String absolute = p.normalize(
      p.join(root, safeRelative.replaceAll('/', p.separator)),
    );
    if (absolute != root && !p.isWithin(root, absolute)) {
      throw const FormatException('草稿附件路徑無效。');
    }
    return absolute;
  }

  String _safePendingRelativePath(String relativePath) {
    final String normalized = relativePath.replaceAll('\\', '/').trim();
    final bool absolute =
        normalized.startsWith('/') ||
        RegExp(r'^[A-Za-z]:').hasMatch(normalized) ||
        p.isAbsolute(relativePath);
    final String collapsed = p.posix.normalize(normalized);
    if (normalized.isEmpty ||
        normalized.contains('\u0000') ||
        absolute ||
        collapsed.isEmpty ||
        collapsed == '.' ||
        collapsed.startsWith('../') ||
        collapsed == '..' ||
        p.posix.split(collapsed).contains('..')) {
      throw const FormatException('草稿附件路徑無效。');
    }
    return collapsed;
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
      followLinks: false,
    )) {
      if (entity is! File) {
        continue;
      }
      final String relative = await pendingRelativePath(draftKey, entity.path);
      if (!keepRelativePaths.contains(relative)) {
        await entity.delete();
      }
    }
  }

  String _sanitizeFileName(String fileName) {
    final String trimmed = fileName.trim();
    if (trimmed.isEmpty) {
      return 'attachment.bin';
    }
    return trimmed.replaceAll(RegExp(r'[^\w.\-]'), '_');
  }
}
