import '../../domain/diary/diary_entry.dart';

class CreateEntryUseCase {
  const CreateEntryUseCase();

  Future<DiaryEntry> call(DiaryEntry draft) async {
    // TODO(zack): wire this to markdown serialization, encryption, and storage.
    return draft;
  }
}
