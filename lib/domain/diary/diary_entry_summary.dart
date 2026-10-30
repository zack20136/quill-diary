import 'package:quill_diary/domain/shared/value_objects.dart';

class DiaryEntrySummary {
  const DiaryEntrySummary({
    required this.id,
    required this.vaultId,
    required this.filePath,
    required this.title,
    required this.previewText,
    this.previewMarkdown = '',
    required this.date,
    required this.createdAt,
    required this.updatedAt,
    required this.tags,
    required this.wordCount,
    required this.charCount,
    required this.attachmentCount,
    this.imageAttachmentCount = 0,
    this.fileAttachmentCount = 0,
    this.previewImagePaths = const <String>[],
  });

  final EntryId id;
  final VaultId vaultId;
  final String filePath;
  final String? title;
  final String previewText;
  final String previewMarkdown;
  final DateOnly date;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> tags;
  final int wordCount;
  final int charCount;
  final int attachmentCount;
  final int imageAttachmentCount;
  final int fileAttachmentCount;
  final List<String> previewImagePaths;
}
