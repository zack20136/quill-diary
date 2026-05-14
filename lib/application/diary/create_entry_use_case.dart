import '../../domain/diary/diary_entry.dart';
import '../../domain/security/unlocked_vault_session.dart';
import '../../infrastructure/storage/vault_repository.dart';

class CreateEntryUseCase {
  const CreateEntryUseCase(this._repository);

  final VaultRepository _repository;

  Future<DiaryEntry> call(
    UnlockedVaultSession session,
    DiaryEntry draft, {
    List<PendingAttachment> pendingAttachments = const <PendingAttachment>[],
  }) {
    return _repository.saveEntry(
      session,
      draft,
      pendingAttachments: pendingAttachments,
    );
  }
}
