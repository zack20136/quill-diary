import '../../domain/diary/diary_entry.dart';
import '../../infrastructure/storage/vault_repository.dart';

class CreateEntryUseCase {
  const CreateEntryUseCase(this._repository);

  final VaultRepository _repository;

  Future<DiaryEntry> call(
    DiaryEntry draft, {
    List<PendingAttachment> pendingAttachments = const <PendingAttachment>[],
  }) {
    return _repository.saveEntry(
      draft,
      pendingAttachments: pendingAttachments,
    );
  }
}
