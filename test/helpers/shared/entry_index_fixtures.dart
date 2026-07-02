import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/database/index_database.dart';

EntryIndexRecord buildEntryIndexRecord({
  String id = 'jrn_TEST0001',
  String vaultId = 'vlt_TEST0001',
  String filePath = '/tmp/entry.ldj2',
  String? title = '測試標題',
  String previewText = 'preview',
  String previewMarkdown = '',
  DateOnly? date,
  DateTime? createdAt,
  DateTime? updatedAt,
  List<String> tags = const <String>['生活'],
  int wordCount = 10,
  int charCount = 20,
  int attachmentCount = 0,
  int imageAttachmentCount = 0,
  int fileAttachmentCount = 0,
  List<String> previewImagePaths = const <String>[],
}) {
  final DateTime created = createdAt ?? DateTime.parse('2026-05-13T20:30:12Z');
  return EntryIndexRecord(
    id: id,
    vaultId: vaultId,
    filePath: filePath,
    title: title,
    previewText: previewText,
    previewMarkdown: previewMarkdown,
    date: date ?? const DateOnly('2026-05-13'),
    createdAt: created,
    updatedAt: updatedAt ?? created.add(const Duration(hours: 1)),
    tags: tags,
    wordCount: wordCount,
    charCount: charCount,
    attachmentCount: attachmentCount,
    imageAttachmentCount: imageAttachmentCount,
    fileAttachmentCount: fileAttachmentCount,
    previewImagePaths: previewImagePaths,
  );
}
