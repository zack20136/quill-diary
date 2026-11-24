import 'dart:convert';
import 'dart:io';

import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/storage/shared/vault_file_ops.dart';
import 'package:quill_diary/infrastructure/storage/vault_path_strategy.dart';
import 'package:quill_diary/shared/data_versions.dart';

/// 在 [vault/pinned_entries.json] 持久化首頁釘選狀態，隨日記庫備份與還原。
class PinnedEntriesStore {
  PinnedEntriesStore(this._pathStrategy);

  final VaultPathStrategy _pathStrategy;

  Future<Set<EntryId>> readIds({bool strict = false}) async {
    final File file = File(await _pathStrategy.pinnedEntriesPath());
    if (!file.existsSync()) {
      return <EntryId>{};
    }
    Object? decoded;
    try {
      decoded = jsonDecode(await file.readAsString());
    } on Object {
      if (strict) rethrow;
      // 保留損毀檔案供手動復原；讀取失敗時降級為空集合。
      return <EntryId>{};
    }
    if (strict &&
        (decoded is! Map ||
            decoded['entry_ids'] is! List ||
            (decoded['entry_ids'] as List).any(
              (id) => id is! String || id.trim().isEmpty,
            ))) {
      throw const FormatException('釘選資料格式不正確。');
    }
    return _parseEntryIds(decoded);
  }

  Future<void> _writeIds(Set<EntryId> ids) async {
    final Set<EntryId> normalized = ids
        .map((EntryId id) => id.trim())
        .where((String id) => id.isNotEmpty)
        .toSet();
    final File file = File(await _pathStrategy.pinnedEntriesPath());
    if (normalized.isEmpty) {
      if (file.existsSync()) await file.delete();
      return;
    }
    final List<String> ordered = normalized.toList()..sort();
    final Map<String, Object?> payload = <String, Object?>{
      'version': DataVersions.pinnedEntries,
      'entry_ids': ordered,
    };
    await atomicWriteString(
      file,
      const JsonEncoder.withIndent('  ').convert(payload),
    );
  }

  Future<void> setPinned(EntryId entryId, {required bool pinned}) =>
      setPinnedMany([entryId], pinned: pinned);

  Future<void> setPinnedMany(
    Iterable<EntryId> entryIds, {
    required bool pinned,
  }) async {
    final Set<EntryId> next = await readIds();
    for (final EntryId id in entryIds) {
      if (pinned) {
        next.add(id);
      } else {
        next.remove(id);
      }
    }
    await _writeIds(next);
  }

  Future<void> pruneTo(Iterable<EntryId> existingEntryIds) async {
    final Set<EntryId> existing = existingEntryIds.toSet();
    final Set<EntryId> current = await readIds();
    final Set<EntryId> pruned = current.where(existing.contains).toSet();
    if (pruned.length == current.length) {
      return;
    }
    await _writeIds(pruned);
  }

  Future<void> remove(EntryId entryId) {
    return setPinned(entryId, pinned: false);
  }

  static Set<EntryId> _parseEntryIds(Object? decoded) {
    if (decoded is! Map<Object?, Object?>) {
      return <EntryId>{};
    }
    if (decoded.containsKey('version') &&
        decoded['version'] != DataVersions.pinnedEntries) {
      throw const FormatException('不支援的釘選資料格式版本');
    }
    final Object? rawIds = decoded['entry_ids'];
    if (rawIds is! List<Object?>) {
      return <EntryId>{};
    }
    final Set<EntryId> ids = <EntryId>{};
    for (final Object? raw in rawIds) {
      final String id = '$raw'.trim();
      if (id.isNotEmpty) {
        ids.add(id);
      }
    }
    return ids;
  }
}
