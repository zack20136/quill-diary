import 'dart:typed_data';

import '../../domain/attachment/asset_attachment.dart';
import '../../domain/diary/diary_entry.dart';
import '../../domain/security/unlocked_vault_session.dart';
import '../../domain/shared/value_objects.dart';
import '../database/index_database.dart';
import 'vault_repository.dart';

class VaultEntryStore {
  const VaultEntryStore(this._repository);

  final VaultRepository _repository;

  Future<List<EntryIndexRecord>> listEntries({String? searchQuery}) =>
      _repository.listEntries(searchQuery: searchQuery);

  Future<List<EntryIndexRecord>> listEntriesByDate(DateOnly date) =>
      _repository.listEntries(date: date);

  Future<List<DateOnly>> monthEntryDates(DateTime month) =>
      _repository.monthEntryDates(month);

  Future<List<EntryIndexRecord>> listEntriesForMonth(DateTime month) =>
      _repository.listEntriesForMonth(month);

  Future<DiaryEntry?> loadEntry(
    UnlockedVaultSession session,
    EntryId entryId,
  ) => _repository.loadEntry(session, entryId);

  Future<Uint8List?> readDecryptedAssetBytes(
    UnlockedVaultSession session,
    String encryptedPath,
  ) => _repository.readDecryptedAssetBytes(session, encryptedPath);

  Future<List<AssetAttachment>> loadAttachments(EntryId entryId) =>
      _repository.loadAttachments(entryId);

  Future<DiaryEntry> saveEntry(
    UnlockedVaultSession session, {
    required DiaryEntry draft,
    List<PendingAttachment> pendingAttachments = const <PendingAttachment>[],
  }) => _repository.saveEntry(
    session,
    draft,
    pendingAttachments: pendingAttachments,
  );

  Future<void> deleteEntry(UnlockedVaultSession session, EntryId entryId) =>
      _repository.deleteEntry(session, entryId);

  Future<List<EntryIndexRecord>> searchEntries(String query) =>
      _repository.searchEntries(query);
}
