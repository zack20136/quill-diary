import '../../domain/diary/diary_entry.dart';
import '../../domain/shared/value_objects.dart';

class FrontMatterCodec {
  const FrontMatterCodec();

  String encode(DiaryEntry entry) {
    // TODO(zack): replace with YAML front matter serialization.
    return [
      '---',
      'id: "${entry.id}"',
      'date: "${entry.date}"',
      'schema_version: 1',
      '---',
      '',
      entry.markdownBody,
    ].join('\n');
  }

  DiaryEntry decode(String document) {
    // TODO(zack): parse front matter and markdown body into a domain model.
    return DiaryEntry(
      id: 'draft',
      vaultId: 'vault',
      date: const DateOnly('1970-01-01'),
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      markdownBody: document,
    );
  }
}
