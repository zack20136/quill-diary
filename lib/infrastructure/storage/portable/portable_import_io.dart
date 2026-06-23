import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../../domain/diary/diary_entry.dart';
import '../../../domain/security/unlocked_vault_session.dart';
import '../../../domain/shared/value_objects.dart';
import '../../markdown/front_matter_codec.dart';
import '../import/easy_diary/easy_diary_backup_import.dart';
import '../shared/archive_extract.dart';
import '../shared/media_type_utils.dart';
import '../shared/portable_import_result.dart';
import '../shared/vault_file_ops.dart';
import '../vault_path_strategy.dart';
import '../vault_repository.dart';
import 'html_import_parser.dart';
import 'portable_date_text.dart';
import 'portable_io_types.dart';

/// 供測試與平台專用 Easy Diary 匯入接線使用的工廠掛鉤。
typedef EasyDiaryBackupImporterFactory = EasyDiaryBackupImporter Function();

/// 匯入可攜式 Markdown／HTML 文件與委派的第三方備份。
///
/// 匯入器將散落的使用者文件正規化為 [DiaryEntry] 模型，
/// 並由 [VaultRepository] 處理加密與索引同步。
class PortableImportIo {
  PortableImportIo({
    required VaultPathStrategy pathStrategy,
    required VaultRepository repository,
    required FrontMatterCodec frontMatterCodec,
    EasyDiaryBackupImporterFactory? easyDiaryBackupImporterFactory,
  }) : _pathStrategy = pathStrategy,
       _repository = repository,
       _frontMatterCodec = frontMatterCodec,
       _easyDiaryBackupImporterFactory =
           easyDiaryBackupImporterFactory ?? EasyDiaryBackupImporter.new;

  final VaultPathStrategy _pathStrategy;
  final VaultRepository _repository;
  final FrontMatterCodec _frontMatterCodec;
  final EasyDiaryBackupImporterFactory _easyDiaryBackupImporterFactory;

  /// 遞迴匯入資料夾內的 `.md`、`.html`、`.htm`。
  Future<PortableImportResult> importDocuments({
    required UnlockedVaultSession session,
    required Directory rootDirectory,
  }) async {
    if (!rootDirectory.existsSync()) {
      throw StateError('找不到要匯入的資料夾：${rootDirectory.path}');
    }

    final List<File> importFiles = await _discoverImportFiles(rootDirectory);
    int importedEntries = 0;
    int skippedFiles = 0;
    int skippedAttachments = 0;

    for (final File file in importFiles) {
      final String extension = p.extension(file.path).toLowerCase();
      if (extension == '.html' || extension == '.htm') {
        final ImportFileTotals fileTotals = await _importQuillDiaryHtmlFile(
          session: session,
          file: file,
          importRootDirectory: rootDirectory,
        );
        importedEntries += fileTotals.importedEntries;
        skippedFiles += fileTotals.skippedFiles;
        skippedAttachments += fileTotals.skippedAttachments;
        continue;
      }

      final List<ParsedImportEntry> parsedEntries =
          await _parseMarkdownExportFile(
            file: file,
            importRootDirectory: rootDirectory,
          );
      if (parsedEntries.isEmpty) {
        skippedFiles++;
        continue;
      }

      final ImportFileTotals totals = await _persistParsedEntries(
        session: session,
        parsedEntries: parsedEntries,
      );
      importedEntries += totals.importedEntries;
      skippedFiles += totals.skippedFiles;
      skippedAttachments += totals.skippedAttachments;
    }

    if (importedEntries > 0) {
      await _repository.syncTagStylesBetweenVaultAndIndex();
    }

    return PortableImportResult(
      importedEntries: importedEntries,
      skippedFiles: skippedFiles,
      skippedAttachments: skippedAttachments,
    );
  }

  /// 解壓 zip 後優先嘗試 Easy Diary 完整備份，否則走 Markdown / HTML 可攜式匯入。
  Future<PortableImportResult> importDocumentsFromZip({
    required UnlockedVaultSession session,
    required File zipFile,
  }) async {
    final Directory tempRoot = await createWorkingDirectory(
      _pathStrategy,
      'import_zip',
    );
    final OpenedZipArchive zip = await openZipArchive(zipFile);
    try {
      try {
        await extractArchiveToDirectory(zip: zip, targetDirectory: tempRoot);
      } finally {
        await zip.close();
      }

      final EasyDiaryBackupImporter easyDiaryImporter =
          _easyDiaryBackupImporterFactory();
      final PortableImportResult? easyDiaryResult = await easyDiaryImporter
          .tryImportFromExtractedRoot(
            session: session,
            repository: _repository,
            extractedRoot: tempRoot,
          );
      if (easyDiaryResult != null) {
        if (easyDiaryResult.importedEntries > 0) {
          await _repository.syncTagStylesBetweenVaultAndIndex();
        }
        return easyDiaryResult;
      }

      final PortableImportResult portableResult = await importDocuments(
        session: session,
        rootDirectory: tempRoot,
      );
      if (portableResult.importedEntries == 0 &&
          portableResult.skippedFiles == 0 &&
          portableResult.skippedAttachments == 0) {
        return const PortableImportResult(
          importedEntries: 0,
          skippedFiles: 0,
          failureCode: PortableImportFailureCode.zipNoEntries,
        );
      }
      return portableResult;
    } finally {
      if (tempRoot.existsSync()) {
        await tempRoot.delete(recursive: true);
      }
    }
  }

  Future<ImportFileTotals> _persistParsedEntries({
    required UnlockedVaultSession session,
    required List<ParsedImportEntry> parsedEntries,
  }) async {
    var importedEntries = 0;
    var skippedFiles = 0;
    var skippedAttachments = 0;

    for (final ParsedImportEntry parsedEntry in parsedEntries) {
      if (parsedEntry.isEmpty) {
        skippedFiles++;
        continue;
      }

      await _repository.saveEntry(
        session,
        parsedEntry.entry,
        pendingAttachments: parsedEntry.attachments,
      );
      importedEntries++;
      skippedAttachments += parsedEntry.skippedAttachments;
    }

    return ImportFileTotals(
      importedEntries: importedEntries,
      skippedFiles: skippedFiles,
      skippedAttachments: skippedAttachments,
    );
  }

  Future<List<File>> _discoverImportFiles(Directory rootDirectory) async {
    final List<File> files = <File>[];

    await for (final FileSystemEntity entity in rootDirectory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) {
        continue;
      }

      final String extension = p.extension(entity.path).toLowerCase();
      if (extension == '.md' || extension == '.html' || extension == '.htm') {
        files.add(entity);
      }
    }

    files.sort((File a, File b) => a.path.compareTo(b.path));
    return files;
  }

  Future<List<ParsedImportEntry>> _parseMarkdownExportFile({
    required File file,
    required Directory importRootDirectory,
  }) async {
    final String extension = p.extension(file.path).toLowerCase();
    if (extension == '.md') {
      final ParsedImportEntry? parsedEntry = await _parseMarkdownExportDocument(
        file: file,
        importRootDirectory: importRootDirectory,
      );
      return parsedEntry == null
          ? const <ParsedImportEntry>[]
          : <ParsedImportEntry>[parsedEntry];
    }
    return const <ParsedImportEntry>[];
  }

  Future<ImportFileTotals> _importQuillDiaryHtmlFile({
    required UnlockedVaultSession session,
    required File file,
    required Directory importRootDirectory,
  }) async {
    final String html = await file.readAsString();
    if (!isQuillDiaryExportHtml(html)) {
      return const ImportFileTotals(
        importedEntries: 0,
        skippedFiles: 1,
        skippedAttachments: 0,
      );
    }
    return _importQuillDiaryExportFile(
      session: session,
      file: file,
      html: html,
      importRootDirectory: importRootDirectory,
    );
  }

  Future<ImportFileTotals> _importQuillDiaryExportFile({
    required UnlockedVaultSession session,
    required File file,
    required String html,
    required Directory importRootDirectory,
  }) async {
    final List<ParsedImportEntry> parsedEntries =
        await _parseQuillDiaryExportArticles(
          file: file,
          html: html,
          importRootDirectory: importRootDirectory,
        );

    if (parsedEntries.isEmpty) {
      return const ImportFileTotals(
        importedEntries: 0,
        skippedFiles: 1,
        skippedAttachments: 0,
      );
    }

    return _persistParsedEntries(
      session: session,
      parsedEntries: parsedEntries,
    );
  }

  Future<ParsedImportEntry?> _parseMarkdownExportDocument({
    required File file,
    required Directory importRootDirectory,
  }) async {
    final String document = await file.readAsString();
    final FileStat stat = await file.stat();
    final DecodedFrontMatterDocument decoded = _frontMatterCodec.decodeDocument(
      document,
    );
    final Map<String, Object?> frontMatter = decoded.frontMatter;
    final String body = decoded.body.trimRight();

    final List<String> attachmentReferences = <String>{
      ...decoded.attachmentPaths,
      ..._extractMarkdownLocalLinks(body),
    }.toList(growable: false);

    final ResolvedImportAttachments resolvedAttachments =
        await _resolveImportAttachments(
          references: attachmentReferences,
          baseDirectory: file.parent,
          importRootDirectory: importRootDirectory,
        );

    final DateTime fallbackTime = stat.modified;
    final String inferredTitle = _inferMarkdownTitle(file, body);
    final DiaryEntry entry = DiaryEntry(
      id: generateEntryId(),
      vaultId: 'vlt_LOCAL',
      title: decoded.entry.normalizedTitle ?? inferredTitle,
      date: frontMatter.containsKey('date')
          ? decoded.entry.date
          : (parsePortableDateOnly('${file.path}\n$document') ??
                DateOnly.fromDateTime(fallbackTime)),
      createdAt:
          frontMatter.containsKey('created_at') &&
              decoded.entry.createdAt.millisecondsSinceEpoch > 0
          ? decoded.entry.createdAt
          : fallbackTime,
      updatedAt:
          frontMatter.containsKey('updated_at') &&
              decoded.entry.updatedAt.millisecondsSinceEpoch > 0
          ? decoded.entry.updatedAt
          : fallbackTime,
      markdownBody: body,
      tags: decoded.entry.tags,
    );

    return ParsedImportEntry(
      entry: entry,
      attachments: resolvedAttachments.attachments,
      skippedAttachments: resolvedAttachments.skippedAttachments,
    );
  }

  Future<List<ParsedImportEntry>> _parseQuillDiaryExportArticles({
    required File file,
    required String html,
    required Directory importRootDirectory,
  }) async {
    final FileStat stat = await file.stat();
    final String bodyHtml = extractHtmlBody(html);
    final List<String> quillDiaryArticleSections = splitQuillDiaryArticles(
      bodyHtml,
    );
    final List<ParsedImportEntry> parsedEntries = <ParsedImportEntry>[];

    for (final String quillDiaryArticleHtml in quillDiaryArticleSections) {
      final ParsedImportEntry? parsedEntry =
          await _parseQuillDiaryExportArticle(
            quillDiaryArticleHtml: quillDiaryArticleHtml,
            file: file,
            stat: stat,
            importRootDirectory: importRootDirectory,
          );
      if (parsedEntry != null && !parsedEntry.isEmpty) {
        parsedEntries.add(parsedEntry);
      }
    }

    return parsedEntries;
  }

  Future<ParsedImportEntry?> _parseQuillDiaryExportArticle({
    required String quillDiaryArticleHtml,
    required File file,
    required FileStat stat,
    required Directory importRootDirectory,
  }) async {
    final String? dateText = extractHtmlClassText(
      quillDiaryArticleHtml,
      'entry-date',
    );
    final String? title = extractFirstHtmlTagText(quillDiaryArticleHtml, 'h2');
    final String? entryBodyHtml = extractBlockInnerHtml(
      quillDiaryArticleHtml,
      'section',
      'entry-body',
    );
    if (entryBodyHtml == null && title == null && dateText == null) {
      return null;
    }

    final List<String> tags = extractQuillDiaryTags(quillDiaryArticleHtml);

    final String attachmentSourceHtml =
        '${extractBlockInnerHtml(quillDiaryArticleHtml, 'section', 'embedded-images') ?? ''}\n'
        '${extractBlockInnerHtml(quillDiaryArticleHtml, 'section', 'attachment-list') ?? ''}';
    final ResolvedImportAttachments resolvedAttachments =
        await _resolveImportAttachments(
          references: extractHtmlAttachmentReferences(attachmentSourceHtml),
          baseDirectory: file.parent,
          importRootDirectory: importRootDirectory,
        );

    final String markdownBody = exportHtmlBodyToMarkdown(
      entryBodyHtml ?? '',
    ).trimRight();
    final DateTime fallbackTimestamp = stat.modified;
    final ({DateOnly date, DateTime createdAt, DateTime updatedAt}) times =
        resolveQuillDiaryImportEntryTimes(
          dateText: dateText,
          fallback: fallbackTimestamp,
        );
    final DateOnly entryDate = dateText == null
        ? (parsePortableDateOnly(quillDiaryArticleHtml) ?? times.date)
        : times.date;

    final DiaryEntry entry = DiaryEntry(
      id: generateEntryId(),
      vaultId: 'vlt_LOCAL',
      title: title?.trim().isNotEmpty == true
          ? title!.trim()
          : _fallbackImportTitle(file),
      date: entryDate,
      createdAt: times.createdAt,
      updatedAt: times.updatedAt,
      markdownBody: markdownBody,
      tags: tags,
    );

    return ParsedImportEntry(
      entry: entry,
      attachments: resolvedAttachments.attachments,
      skippedAttachments: resolvedAttachments.skippedAttachments,
    );
  }

  Future<ResolvedImportAttachments> _resolveImportAttachments({
    required Iterable<String> references,
    required Directory baseDirectory,
    required Directory importRootDirectory,
  }) async {
    final List<PendingAttachment> attachments = <PendingAttachment>[];
    final Set<String> seenPaths = <String>{};
    var embeddedIndex = 1;
    var skippedAttachments = 0;

    for (final String rawReference in references) {
      final String reference = rawReference.trim();
      if (reference.isEmpty) {
        continue;
      }
      if (isIgnoredImportReference(reference)) {
        continue;
      }

      if (reference.startsWith('data:')) {
        final ({String mimeType, Uint8List bytes})? decoded =
            _decodeDataUriReference(reference);
        if (decoded == null) {
          skippedAttachments++;
          continue;
        }

        final String extension = extensionFromMimeType(decoded.mimeType);
        final String fileName = 'embedded_${embeddedIndex++}.$extension';
        attachments.add(
          PendingAttachment(
            bytes: decoded.bytes,
            mimeType: decoded.mimeType,
            originalFilename: fileName,
          ),
        );
        continue;
      }

      final String normalizedReference = Uri.decodeFull(
        reference.split('#').first.split('?').first,
      );
      final String resolvedPath = p.normalize(
        p.join(baseDirectory.path, normalizedReference),
      );
      if (!_isPathWithinRoot(resolvedPath, importRootDirectory.path)) {
        skippedAttachments++;
        continue;
      }

      final String dedupeKey = resolvedPath.toLowerCase();
      if (!seenPaths.add(dedupeKey)) {
        continue;
      }

      final File sourceFile = File(resolvedPath);
      if (!sourceFile.existsSync()) {
        skippedAttachments++;
        continue;
      }

      final String originalFilename = p.basename(sourceFile.path);
      attachments.add(
        PendingAttachment(
          sourcePath: sourceFile.path,
          mimeType: mimeTypeFromFileName(originalFilename),
          originalFilename: originalFilename,
        ),
      );
    }

    return (attachments: attachments, skippedAttachments: skippedAttachments);
  }

  List<String> _extractMarkdownLocalLinks(String markdown) {
    final RegExp linkPattern = RegExp(
      r'!?\[[^\]]*\]\(([^)]+)\)',
      multiLine: true,
    );

    return linkPattern
        .allMatches(markdown)
        .map((Match match) => (match.group(1) ?? '').trim())
        .where((String value) => value.isNotEmpty)
        .toList(growable: false);
  }

  String _inferMarkdownTitle(File file, String body) {
    final String? heading = _extractFirstMarkdownHeading(body);
    if (heading != null) {
      return heading;
    }
    return _fallbackImportTitle(file);
  }

  String _fallbackImportTitle(File file) {
    final String stem = p.basenameWithoutExtension(file.path);
    if (stem.toLowerCase() == 'index') {
      final String parentName = p.basename(file.parent.path).trim();
      if (parentName.isNotEmpty) {
        return parentName;
      }
    }
    return stem.trim().isEmpty ? 'Imported Entry' : stem.trim();
  }

  String? _extractFirstMarkdownHeading(String body) {
    final Match? match = RegExp(
      r'^\s*#\s+(.+)$',
      multiLine: true,
    ).firstMatch(body);
    final String value = match?.group(1)?.trim() ?? '';
    return value.isEmpty ? null : value;
  }

  ({String mimeType, Uint8List bytes})? _decodeDataUriReference(
    String dataUri,
  ) {
    if (!dataUri.startsWith('data:')) {
      return null;
    }

    final int commaIndex = dataUri.indexOf(',');
    if (commaIndex == -1) {
      return null;
    }

    final String metadata = dataUri
        .substring('data:'.length, commaIndex)
        .trim();
    String payload = dataUri.substring(commaIndex + 1);
    if (payload.startsWith(' ')) {
      payload = payload.trimLeft();
    }
    if (payload.isEmpty) {
      return null;
    }

    final String mimeType = metadata.split(';').first.trim().toLowerCase();
    final bool isBase64 = metadata.toLowerCase().contains(';base64');

    if (!isBase64) {
      return null;
    }

    try {
      final Uint8List bytes = Uint8List.fromList(
        base64Decode(payload.replaceAll(RegExp(r'\s'), '')),
      );
      if (bytes.isEmpty) {
        return null;
      }

      return (
        mimeType: mimeType.isEmpty ? 'application/octet-stream' : mimeType,
        bytes: bytes,
      );
    } on Object {
      return null;
    }
  }

  bool _isPathWithinRoot(String targetPath, String rootPath) {
    final String normalizedTarget = p.normalize(targetPath);
    final String normalizedRoot = p.normalize(rootPath);
    return normalizedTarget == normalizedRoot ||
        p.isWithin(normalizedRoot, normalizedTarget);
  }
}
