import '../../../domain/attachment/asset_attachment.dart';
import '../../../domain/diary/diary_entry.dart';
import '../../database/index_database.dart';
import '../vault_repository.dart';

typedef ResolvedImportAttachments = ({
  List<PendingAttachment> attachments,
  int skippedAttachments,
});

class ImportFileTotals {
  const ImportFileTotals({
    required this.importedEntries,
    required this.skippedFiles,
    required this.skippedAttachments,
  });

  final int importedEntries;
  final int skippedFiles;
  final int skippedAttachments;
}

class ParsedImportEntry {
  const ParsedImportEntry({
    required this.entry,
    required this.attachments,
    this.skippedAttachments = 0,
  });

  final DiaryEntry entry;
  final List<PendingAttachment> attachments;
  final int skippedAttachments;

  bool get isEmpty =>
      entry.markdownBody.trim().isEmpty &&
      (entry.normalizedTitle == null || entry.normalizedTitle!.isEmpty) &&
      attachments.isEmpty;
}

class HtmlExportDocument {
  const HtmlExportDocument({
    required this.record,
    required this.entry,
    required this.attachments,
  });

  final EntryIndexRecord record;
  final DiaryEntry? entry;
  final List<AssetAttachment> attachments;
}
