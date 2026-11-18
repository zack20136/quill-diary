import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:quill_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/domain/tag/tag.dart';
import 'package:quill_diary/infrastructure/crypto/crypto_service.dart';
import 'package:quill_diary/infrastructure/database/index_database.dart';
import 'package:quill_diary/infrastructure/storage/shared/vault_file_ops.dart';
import 'package:quill_diary/infrastructure/storage/vault_path_strategy.dart';

class TagCatalogException implements Exception {
  const TagCatalogException();
}

/// 呼叫端在日記庫修改序列內操作，避免遷移與備份或輪替交錯。
class TagCatalogStore {
  TagCatalogStore(this._pathStrategy, this._crypto);
  static const int _maxCatalogBytes = 16 * 1024 * 1024;
  static const String _catalogDocumentId = 'tag_styles';
  final VaultPathStrategy _pathStrategy;
  final CryptoService _crypto;

  List<TagCatalogItem> _decode(List<int> bytes) {
    if (bytes.length > _maxCatalogBytes) {
      throw const FormatException('標籤目錄超過大小上限');
    }
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! List) throw const FormatException('標籤目錄不是清單');
    final items = <TagCatalogItem>[];
    for (final raw in decoded) {
      if (raw is! Map ||
          raw['label'] is! String ||
          (raw['label'] as String).trim().isEmpty ||
          raw['accent_argb'] != null && raw['accent_argb'] is! int ||
          raw['accent_is_custom'] != null && raw['accent_is_custom'] is! bool) {
        throw const FormatException('標籤目錄內容不正確');
      }
      items.add(TagCatalogItem.fromJson(raw)!);
    }
    return _normalizeItems(items);
  }

  Future<List<int>> _decrypt(File file, UnlockedVaultSession session) async {
    if (await file.length() > _maxCatalogBytes + 65560) {
      throw const FormatException('標籤加密檔超過大小上限');
    }
    final parsed = _crypto.parseFileBytes(await file.readAsBytes());
    if (parsed.header.vaultId != session.vaultId ||
        parsed.header.fileId != _catalogDocumentId ||
        parsed.header.contentType != 'application/json') {
      throw const FormatException('標籤目錄身分不符');
    }
    return _crypto.decryptBytes(
      headerBytes: parsed.headerBytes,
      ciphertextBytes: parsed.ciphertextBytes,
      context: vaultDecryptionContext(session),
    );
  }

  Future<void> _writeBytes(
    File file,
    List<int> bytes,
    UnlockedVaultSession session,
    RecoveryMetadata metadata,
  ) async {
    await writeEncryptedVaultJson(
      file: file,
      crypto: _crypto,
      session: session,
      metadata: metadata,
      documentId: _catalogDocumentId,
      plaintextBytes: bytes,
      validateTemporary: (temporary) async {
        final restored = await _decrypt(temporary, session);
        _decode(restored);
        if (!listEquals(bytes, restored)) {
          throw const FormatException('標籤遷移核對失敗');
        }
      },
    );
  }

  Future<Uint8List> _readLegacy(File file) async {
    if (await file.length() > _maxCatalogBytes) {
      throw const FormatException('標籤目錄超過大小上限');
    }
    return file.readAsBytes();
  }

  Future<List<File>> _legacyFiles() async {
    final path = await _pathStrategy.legacyTagCatalogPath();
    return [
      for (final suffix in ['', '.previous', '.tmp'])
        if (File('$path$suffix').existsSync()) File('$path$suffix'),
    ];
  }

  Future<void> _migrate(
    File encrypted,
    UnlockedVaultSession session,
    RecoveryMetadata metadata,
  ) async {
    final legacyFiles = await _legacyFiles();
    final hasEncryptedSidecars =
        File('${encrypted.path}.previous').existsSync() ||
        File('${encrypted.path}.tmp').existsSync();
    if (legacyFiles.isEmpty && !hasEncryptedSidecars) return;
    final original = legacyFiles.isEmpty
        ? null
        : await _readLegacy(legacyFiles.first);
    if (original != null) _decode(original);
    Future<void> validateCopy(File file) async {
      final restored = await _decrypt(file, session);
      _decode(restored);
      if (original != null && !listEquals(original, restored)) {
        throw const FormatException('標籤明文與加密副本不一致');
      }
    }

    await recoverFileReplacement(encrypted, validate: validateCopy);
    if (original == null) return;
    if (!encrypted.existsSync()) {
      await _writeBytes(encrypted, original, session, metadata);
      await validateCopy(encrypted);
    }
    if (File('${encrypted.path}.tmp').existsSync() ||
        File('${encrypted.path}.previous').existsSync()) {
      throw const FileSystemException('標籤加密替換副本尚未完成清理');
    }
    // 先刪舊副本。中斷時，下次仍以核對過的明文來源為準。
    for (final file in legacyFiles.reversed) {
      await file.delete();
    }
  }

  Future<List<TagCatalogItem>> read(
    UnlockedVaultSession session,
    RecoveryMetadata metadata,
  ) async {
    try {
      final file = File(await _pathStrategy.tagCatalogPath());
      await _migrate(file, session, metadata);
      return file.existsSync()
          ? _decode(await _decrypt(file, session))
          : const [];
    } on Object {
      throw const TagCatalogException();
    }
  }

  Future<void> write(
    List<TagCatalogItem> items,
    UnlockedVaultSession session,
    RecoveryMetadata metadata,
  ) async {
    await read(session, metadata);
    await _saveCatalog(items, session, metadata);
  }

  Future<void> _saveCatalog(
    List<TagCatalogItem> items,
    UnlockedVaultSession session,
    RecoveryMetadata metadata,
  ) async {
    try {
      final payload = _normalizeItems(items)
          .map((item) => item.toJson())
          .toList();
      await _writeBytes(
        File(await _pathStrategy.tagCatalogPath()),
        utf8.encode(jsonEncode(payload)),
        session,
        metadata,
      );
    } on Object {
      throw const TagCatalogException();
    }
  }

  Future<Map<String, Uint8List>> preserveLegacyFiles(
    UnlockedVaultSession session,
    RecoveryMetadata metadata,
  ) async {
    var hasPrimary = File(await _pathStrategy.tagCatalogPath()).existsSync();
    final files = <String, Uint8List>{};
    for (final legacy in await _legacyFiles()) {
      final path = hasPrimary
          ? 'preservation/tag_styles_${generateBackupId()}.json.enc'
          : 'tag_styles.json.enc';
      final now = DateTime.now();
      files[path] = (await _crypto.encryptBytes(
        documentId: hasPrimary ? 'tag_styles_preservation' : _catalogDocumentId,
        vaultId: session.vaultId,
        plaintextBytes: await _readLegacy(legacy),
        contentType: 'application/json',
        recoveryWrapKey: requireRecoveryWrapKey(session),
        recoverySlotKdf: metadata.kdf,
        createdAt: now,
        updatedAt: now,
      )).toFileBytes();
      hasPrimary = true;
    }
    return files;
  }

  static Map<String, int> toAccentMap(List<TagCatalogItem> items) {
    return <String, int>{
      for (final TagCatalogItem item in _normalizeItems(items))
        if (item.accentArgb != null) item.normalized: item.accentArgb!,
    };
  }

  /// 後面的項目覆寫較早的鍵。
  static List<TagCatalogItem> merge(
    List<TagCatalogItem> base,
    List<TagCatalogItem> overlay,
  ) {
    return _normalizeItems(<TagCatalogItem>[...base, ...overlay]);
  }

  static List<TagCatalogItem> _normalizeItems(List<TagCatalogItem> items) {
    final Map<String, int> indexByNorm = <String, int>{};
    final List<TagCatalogItem> normalized = <TagCatalogItem>[];

    for (final TagCatalogItem item in items) {
      final String normalizedKey = item.normalized;
      if (normalizedKey.isEmpty) {
        continue;
      }
      final int? existingIndex = indexByNorm[normalizedKey];
      if (existingIndex == null) {
        indexByNorm[normalizedKey] = normalized.length;
        normalized.add(
          TagCatalogItem(
            label: item.displayLabel,
            accentArgb: item.accentArgb,
            accentIsCustom: item.accentIsCustom,
          ),
        );
        continue;
      }
      final TagCatalogItem previous = normalized[existingIndex];
      normalized[existingIndex] = TagCatalogItem(
        label: item.displayLabel,
        accentArgb: item.accentArgb ?? previous.accentArgb,
        accentIsCustom: item.accentIsCustom ?? previous.accentIsCustom,
      );
    }

    return normalized;
  }

  Future<void> ensureLabels(
    Iterable<String> labels,
    UnlockedVaultSession session,
    RecoveryMetadata metadata,
  ) async {
    final Set<String> seenNormalized = <String>{};
    final List<TagCatalogItem> overlay = <TagCatalogItem>[];
    for (final String raw in labels) {
      final String displayLabel = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
      final String normalized = normalizeText(displayLabel);
      if (normalized.isEmpty || !seenNormalized.add(normalized)) {
        continue;
      }
      overlay.add(TagCatalogItem(label: displayLabel));
    }
    if (overlay.isEmpty) {
      return;
    }
    final List<TagCatalogItem> catalog = await read(session, metadata);
    final existing = catalog.map((item) => item.normalized).toSet();
    if (seenNormalized.every(existing.contains)) {
      return;
    }
    await _saveCatalog([...catalog, ...overlay], session, metadata);
  }

  Future<void> applyToIndex(
    IndexDatabase indexDb,
    UnlockedVaultSession session,
    RecoveryMetadata metadata,
  ) async {
    final List<TagCatalogItem> catalog = await read(session, metadata);
    if (catalog.isEmpty) {
      return;
    }
    for (final TagCatalogItem item in catalog) {
      if (item.accentArgb == null) {
        continue;
      }
      await indexDb.upsertTagAccentArgb(item.label, item.accentArgb!);
    }
  }
}
