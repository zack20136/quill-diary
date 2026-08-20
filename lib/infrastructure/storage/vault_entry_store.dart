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

  Future<List<EntryIndexRecord>> listEntriesForMonth(DateTime month) =>
      _repository.listEntriesForMonth(month);

  Future<List<EntryIndexRecord>> listEntriesForDateRange({
    required DateOnly firstDate,
    required DateOnly lastDate,
  }) => _repository.listEntriesForDateRange(
    firstDate: firstDate,
    lastDate: lastDate,
  );

  Future<({DateOnly earliest, DateOnly latest})?> entryDateBounds() =>
      _repository.entryDateBounds();

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
    List<VaultFinding> retireFindingsAfterSave = const <VaultFinding>[],
  }) => _repository.saveEntry(
    session,
    draft,
    pendingAttachments: pendingAttachments,
    retireFindingsAfterSave: retireFindingsAfterSave,
  );

  Future<void> deleteEntry(UnlockedVaultSession session, EntryId entryId) =>
      _repository.deleteEntry(session, entryId);

  Future<List<EntryIndexRecord>> searchEntries(String query) =>
      _repository.searchEntries(query);
}
