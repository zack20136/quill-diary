import 'dart:convert';
import 'dart:io';

import '../../domain/shared/value_objects.dart';
import 'shared/vault_file_ops.dart';
import 'vault_path_strategy.dart';

/// 在 [vault/pinned_entries.json] 持久化首頁釘選狀態，隨 vault 備份與還原。
class PinnedEntriesStore {
  PinnedEntriesStore(this._pathStrategy);

  static const int formatVersion = 1;

  final VaultPathStrategy _pathStrategy;

  Future<String> _filePath() => _pathStrategy.pinnedEntriesPath();

  Future<Set<EntryId>> readIds() async {
    final File file = File(await _filePath());
    if (!file.existsSync()) {
      return <EntryId>{};
    }
    try {
      final Object? decoded = jsonDecode(await file.readAsString());
      return _parseEntryIds(decoded);
    } on Object {
      // 保留損毀檔案供手動復原；讀取失敗時降級為空集合。
      return <EntryId>{};
    }
  }

  Future<void> writeIds(Set<EntryId> ids) async {
    final Set<EntryId> normalized = ids
        .map((EntryId id) => id.trim())
        .where((String id) => id.isNotEmpty)
        .toSet();
    final File file = File(await _filePath());
    if (normalized.isEmpty) {
      await _deleteFile(file);
      return;
    }
    final List<String> ordered = normalized.toList()..sort();
    final Map<String, Object?> payload = <String, Object?>{
      'version': formatVersion,
      'entry_ids': ordered,
    };
    await atomicWriteString(
      file,
      const JsonEncoder.withIndent('  ').convert(payload),
    );
  }

  Future<void> setPinned(EntryId entryId, {required bool pinned}) async {
    final Set<EntryId> next = await readIds();
    if (pinned) {
      next.add(entryId);
    } else {
      next.remove(entryId);
    }
    await writeIds(next);
  }

  Future<void> setPinnedMany(Iterable<EntryId> entryIds, {required bool pinned}) async {
    final Set<EntryId> next = await readIds();
    for (final EntryId id in entryIds) {
      if (pinned) {
        next.add(id);
      } else {
        next.remove(id);
      }
    }
    await writeIds(next);
  }

  Future<void> pruneTo(Iterable<EntryId> existingEntryIds) async {
    final Set<EntryId> existing = existingEntryIds.toSet();
    final Set<EntryId> current = await readIds();
    final Set<EntryId> pruned = current.where(existing.contains).toSet();
    if (pruned.length == current.length) {
      return;
    }
    await writeIds(pruned);
  }

  Future<void> remove(EntryId entryId) {
    return setPinned(entryId, pinned: false);
  }

  static Set<EntryId> _parseEntryIds(Object? decoded) {
    if (decoded is! Map<Object?, Object?>) {
      return <EntryId>{};
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

  Future<void> _deleteFile(File file) async {
    if (file.existsSync()) {
      await file.delete();
    }
  }
}
