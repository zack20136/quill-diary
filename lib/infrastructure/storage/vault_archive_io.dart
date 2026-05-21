import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import '../../domain/attachment/asset_attachment.dart';
import '../../domain/diary/diary_entry.dart';
import '../../domain/recovery/recovery_metadata.dart';
import '../../domain/security/unlocked_vault_session.dart';
import '../../domain/shared/value_objects.dart';
import '../database/index_database.dart';
import '../database/index_database_manager.dart';
import '../markdown/front_matter_codec.dart';
import 'restore_precheck.dart';
import 'vault_path_strategy.dart';
import 'tag_styles_store.dart';
import 'vault_repository.dart';

class PortableImportResult {
  const PortableImportResult({
    required this.importedEntries,
    required this.skippedFiles,
  });

  final int importedEntries;
  final int skippedFiles;
}

class VaultArchiveIo {
  VaultArchiveIo({
    required VaultPathStrategy pathStrategy,
    required VaultRepository repository,
    required FrontMatterCodec frontMatterCodec,
    required IndexDatabaseManager indexDatabaseManager,
  })  : _pathStrategy = pathStrategy,
        _repository = repository,
        _frontMatterCodec = frontMatterCodec,
        _indexDatabaseManager = indexDatabaseManager;

  final VaultPathStrategy _pathStrategy;
  final VaultRepository _repository;
  final FrontMatterCodec _frontMatterCodec;
  final IndexDatabaseManager _indexDatabaseManager;

  Future<File> writeBackupZip(File target) async {
    final Directory vaultRoot = await _pathStrategy.vaultRootDirectory();
    await target.parent.create(recursive: true);
    final ZipFileEncoder encoder = ZipFileEncoder();
    encoder.create(target.path);
    await encoder.addDirectory(
      vaultRoot,
      includeDirName: false,
      filter: (FileSystemEntity entity, double progress) {
        final String relative = p.relative(entity.path, from: vaultRoot.path);
        final List<String> segments = p.split(relative);
        if (segments.isNotEmpty && segments.first == 'index') {
          return ZipFileOperation.skip;
        }
        return ZipFileOperation.include;
      },
    );
    await encoder.close();
    return target;
  }

  Future<Directory> exportMarkdown({
    required UnlockedVaultSession session,
    required Directory parentDirectory,
  }) async {
    final List<EntryIndexRecord> entries = await _repository.listEntries();
    final Directory vaultRoot = await _pathStrategy.vaultRootDirectory();
    final Directory exportRoot = Directory(
      p.join(
        parentDirectory.path,
        'diary_export_${DateTime.now().millisecondsSinceEpoch}',
      ),
    );
    await exportRoot.create(recursive: true);

    final Set<String> usedEntryDirectories = <String>{};

    for (final EntryIndexRecord record in entries) {
      final List<Object?> loaded = await Future.wait<Object?>(<Future<Object?>>[
        _repository.loadEntry(session, record.id),
        _repository.loadAttachments(record.id),
      ]);
      final DiaryEntry? entry = loaded[0] as DiaryEntry?;
      if (entry == null) {
        continue;
      }

      final List<AssetAttachment> attachments = loaded[1] as List<AssetAttachment>;
      final Directory entryDirectory = await _createExportEntryDirectory(
        exportRoot: exportRoot,
        entry: entry,
        usedRelativePaths: usedEntryDirectories,
      );
      final Map<AssetId, String> attachmentFileNames = _buildExportAttachmentFileNames(
        attachments,
      );
      final String exportMarkdown = _frontMatterCodec.encode(
        entry,
        attachments: attachments,
        attachmentPathBuilder: (AssetAttachment attachment) =>
            './${attachmentFileNames[attachment.id] ?? attachment.safeFilename}',
      );

      await File(
        p.join(entryDirectory.path, 'index.md'),
      ).writeAsString(
        exportMarkdown,
        flush: true,
      );

      await _exportAttachments(
        session: session,
        entry: entry,
        attachments: attachments,
        attachmentFileNames: attachmentFileNames,
        entryDirectory: entryDirectory,
        vaultRoot: vaultRoot,
      );
    }

    return exportRoot;
  }

  Future<File> writePortableExportZip({
    required UnlockedVaultSession session,
    required File target,
  }) async {
    final Directory tempRoot = await _createWorkingDirectory('portable_export');
    try {
      final Directory exportRoot = await exportMarkdown(
        session: session,
        parentDirectory: tempRoot,
      );
      await target.parent.create(recursive: true);
      final ZipFileEncoder encoder = ZipFileEncoder();
      encoder.create(target.path);
      await encoder.addDirectory(exportRoot, includeDirName: true);
      await encoder.close();
      return target;
    } finally {
      if (tempRoot.existsSync()) {
        await tempRoot.delete(recursive: true);
      }
    }
  }

  Future<PortableImportResult> importDocuments({
    required UnlockedVaultSession session,
    required Directory rootDirectory,
  }) async {
    if (!rootDirectory.existsSync()) {
      throw StateError('找不到要匯入的資料夾：${rootDirectory.path}');
    }

    final Directory tempDirectory = await _createWorkingDirectory('import_work');
    try {
      final List<File> importFiles = await _discoverImportFiles(rootDirectory);
      int importedEntries = 0;
      int skippedFiles = 0;

      for (final File file in importFiles) {
        final List<_ImportedDocument> documents = await _parseImportFile(
          file: file,
          importRootDirectory: rootDirectory,
          tempDirectory: tempDirectory,
        );
        if (documents.isEmpty) {
          skippedFiles++;
          continue;
        }

        for (final _ImportedDocument document in documents) {
          if (document.isEmpty) {
            skippedFiles++;
            continue;
          }

          await _repository.saveEntry(
            session,
            document.entry,
            pendingAttachments: document.attachments,
          );
          importedEntries++;
        }
      }

      return PortableImportResult(
        importedEntries: importedEntries,
        skippedFiles: skippedFiles,
      );
    } finally {
      if (tempDirectory.existsSync()) {
        await tempDirectory.delete(recursive: true);
      }
    }
  }

  Future<PortableImportResult> importDocumentsFromZip({
    required UnlockedVaultSession session,
    required File zipFile,
  }) async {
    final Directory tempRoot = await _createWorkingDirectory('import_zip');
    try {
      final Archive archive = ZipDecoder().decodeBytes(
        await zipFile.readAsBytes(),
        verify: true,
      );
      for (final ArchiveFile archiveFile in archive.files) {
        _ensureSafeArchivePath(archiveFile.name);
        final String outputPath = p.join(tempRoot.path, archiveFile.name);
        if (archiveFile.isFile) {
          final File file = File(outputPath);
          await file.parent.create(recursive: true);
          await file.writeAsBytes(
            archiveFile.content as List<int>,
            flush: true,
          );
        } else {
          await Directory(outputPath).create(recursive: true);
        }
      }
      return await importDocuments(
        session: session,
        rootDirectory: tempRoot,
      );
    } finally {
      if (tempRoot.existsSync()) {
        await tempRoot.delete(recursive: true);
      }
    }
  }

  /// 還原前驗證復原金鑰；失敗拋 [StateError]，不修改本機 vault。
  Future<void> verifyBackupRecoveryKey(File backupFile, String recoveryKey) async {
    final BackupRecoveryPreview preview = await peekBackupRecovery(backupFile);
    if (!preview.hasRecovery || preview.metadata == null) {
      throw StateError('此備份沒有復原金鑰資訊，無法驗證。');
    }
    final List<int>? sampleBytes = await _readSampleEncryptedDocumentFromBackup(backupFile);
    if (sampleBytes == null) {
      throw StateError(kBackupNoEncryptedSampleMessage);
    }
    await _repository.verifyRecoveryKeyAgainstBackupBytes(
      metadata: preview.metadata!,
      recoveryKey: recoveryKey,
      encryptedDocumentBytes: sampleBytes,
    );
  }

  /// Reads [recovery.json] from a `.jbackup` without writing to disk.
  Future<BackupRecoveryPreview> peekBackupRecovery(File backupFile) async {
    try {
      final Archive archive = ZipDecoder().decodeBytes(
        await backupFile.readAsBytes(),
        verify: true,
      );
      final ArchiveFile? recoveryEntry = _findRecoveryJsonEntry(archive);
      if (recoveryEntry == null || !recoveryEntry.isFile) {
        return const BackupRecoveryPreview(hasRecovery: false);
      }
      final Object? decoded = jsonDecode(
        utf8.decode(recoveryEntry.content as List<int>),
      );
      if (decoded is! Map<String, Object?>) {
        return const BackupRecoveryPreview(hasRecovery: false);
      }
      return BackupRecoveryPreview(
        hasRecovery: true,
        metadata: RecoveryMetadata.fromJson(decoded),
      );
    } on Object {
      throw StateError(kInvalidBackupArchiveMessage);
    }
  }

  Future<void> restoreBackupZip(
    File backupFile, {
    bool preserveTrustedDeviceAccess = false,
  }) async {
    final Directory vaultRoot = await _pathStrategy.vaultRootDirectory();
    final Directory tempRoot = Directory('${vaultRoot.path}_restore_tmp');
    if (tempRoot.existsSync()) {
      await tempRoot.delete(recursive: true);
    }
    await tempRoot.create(recursive: true);

    try {
      final Archive archive = ZipDecoder().decodeBytes(
        await backupFile.readAsBytes(),
        verify: true,
      );
      for (final ArchiveFile archiveFile in archive.files) {
        _ensureSafeArchivePath(archiveFile.name);
        final String outputPath = p.join(tempRoot.path, archiveFile.name);
        if (archiveFile.isFile) {
          final File file = File(outputPath);
          await file.parent.create(recursive: true);
          await file.writeAsBytes(
            archiveFile.content as List<int>,
            flush: true,
          );
        } else {
          await Directory(outputPath).create(recursive: true);
        }
      }
    } on Object {
      if (tempRoot.existsSync()) {
        await tempRoot.delete(recursive: true);
      }
      throw StateError(kInvalidBackupArchiveMessage);
    }

    _validateRestoredVaultPayload(tempRoot);

    Map<String, int> localTagStyles = <String, int>{};
    try {
      if (_indexDatabaseManager.isOpen) {
        localTagStyles = await _repository.fetchTagAccentArgbMap();
      }
    } on Object {
      // Index may already be closed; fall back to vault file on disk.
    }
    if (localTagStyles.isEmpty) {
      localTagStyles = await TagStylesStore(_pathStrategy).read();
    }

    final Directory incomingVault = Directory('${vaultRoot.path}.incoming');
    if (incomingVault.existsSync()) {
      await incomingVault.delete(recursive: true);
    }
    await _copyDirectoryTree(tempRoot, incomingVault);
    await tempRoot.delete(recursive: true);

    Directory? previousBackup;
    if (vaultRoot.existsSync()) {
      previousBackup = Directory(
        '${vaultRoot.path}.bak_${DateTime.now().microsecondsSinceEpoch}',
      );
      await vaultRoot.rename(previousBackup.path);
    }
    try {
      await incomingVault.rename(vaultRoot.path);
      if (previousBackup != null && previousBackup.existsSync()) {
        await previousBackup.delete(recursive: true);
      }
    } on Object catch (error, stackTrace) {
      if (!vaultRoot.existsSync() &&
          previousBackup != null &&
          previousBackup.existsSync()) {
        await previousBackup.rename(vaultRoot.path);
      }
      if (incomingVault.existsSync()) {
        await incomingVault.delete(recursive: true);
      }
      Error.throwWithStackTrace(error, stackTrace);
    }

    final Directory strayVaultIndex = Directory(p.join(vaultRoot.path, 'index'));
    if (strayVaultIndex.existsSync()) {
      await strayVaultIndex.delete(recursive: true);
    }

    if (localTagStyles.isNotEmpty) {
      final TagStylesStore tagStylesStore = TagStylesStore(_pathStrategy);
      final Map<String, int> restoredVaultStyles = await tagStylesStore.read();
      await tagStylesStore.write(
        TagStylesStore.merge(restoredVaultStyles, localTagStyles),
      );
    }

    await _repository.closeUnlockedResources();
    await _indexDatabaseManager.deleteDatabaseFiles();
    _repository.clearRecoveryMetadataCache();
    if (!preserveTrustedDeviceAccess) {
      await _repository.clearTrustedDeviceAccess();
    }
  }

  Future<List<int>?> _readSampleEncryptedDocumentFromBackup(File backupFile) async {
    try {
      final Archive archive = ZipDecoder().decodeBytes(
        await backupFile.readAsBytes(),
        verify: true,
      );
      final ArchiveFile? manifest = _findEncryptedEntry(
        archive,
        endsWith: 'manifest.json.enc',
      );
      if (manifest != null && manifest.isFile) {
        return manifest.content as List<int>;
      }
      ArchiveFile? firstEntryEnc;
      for (final ArchiveFile file in archive.files) {
        if (!file.isFile) {
          continue;
        }
        final String normalized = p.posix.normalize(file.name).toLowerCase();
        if (normalized.endsWith('.md.enc')) {
          firstEntryEnc = file;
          break;
        }
      }
      if (firstEntryEnc != null) {
        return firstEntryEnc.content as List<int>;
      }
      return null;
    } on Object {
      throw StateError(kInvalidBackupArchiveMessage);
    }
  }

  ArchiveFile? _findEncryptedEntry(
    Archive archive, {
    required String endsWith,
  }) {
    for (final ArchiveFile file in archive.files) {
      if (!file.isFile) {
        continue;
      }
      final String normalized = p.posix.normalize(file.name).toLowerCase();
      if (normalized == endsWith || normalized.endsWith('/$endsWith')) {
        return file;
      }
    }
    return null;
  }

  ArchiveFile? _findRecoveryJsonEntry(Archive archive) {
    for (final ArchiveFile file in archive.files) {
      if (!file.isFile) {
        continue;
      }
      final String normalized = p.posix.normalize(file.name);
      if (normalized == 'recovery.json' || normalized.endsWith('/recovery.json')) {
        return file;
      }
    }
    return null;
  }

  void _validateRestoredVaultPayload(Directory root) {
    final bool hasRecovery = File(p.join(root.path, 'recovery.json')).existsSync();
    final bool hasEntries = Directory(p.join(root.path, 'entries')).existsSync();
    if (!hasRecovery && !hasEntries) {
      throw StateError('備份檔內容不完整，找不到日記庫資料。');
    }
  }

  Future<void> _copyDirectoryTree(Directory source, Directory destination) async {
    await destination.create(recursive: true);
    await for (final FileSystemEntity entity
        in source.list(recursive: true, followLinks: false)) {
      final String relative = p.relative(entity.path, from: source.path);
      final String targetPath = p.join(destination.path, relative);
      if (entity is Directory) {
        await Directory(targetPath).create(recursive: true);
      } else if (entity is File) {
        await File(targetPath).parent.create(recursive: true);
        await entity.copy(targetPath);
      }
    }
  }

  Future<Directory> _createExportEntryDirectory({
    required Directory exportRoot,
    required DiaryEntry entry,
    required Set<String> usedRelativePaths,
  }) async {
    final Directory dateDirectory = Directory(
      p.join(exportRoot.path, _sanitizePathSegment(entry.date.value)),
    );
    await dateDirectory.create(recursive: true);

    final String baseFolderName = _portableEntryFolderName(entry);
    String candidate = baseFolderName;
    int suffix = 2;
    while (usedRelativePaths.contains(
      p.join(entry.date.value, candidate).toLowerCase(),
    )) {
      candidate = '$baseFolderName-$suffix';
      suffix++;
    }
    usedRelativePaths.add(p.join(entry.date.value, candidate).toLowerCase());

    final Directory entryDirectory = Directory(
      p.join(dateDirectory.path, candidate),
    );
    await entryDirectory.create(recursive: true);
    return entryDirectory;
  }

  Map<AssetId, String> _buildExportAttachmentFileNames(List<AssetAttachment> attachments) {
    final Map<AssetId, String> results = <AssetId, String>{};
    final Set<String> usedNames = <String>{};

    for (final AssetAttachment attachment in attachments) {
      final String preferredName = attachment.originalFilename?.trim().isNotEmpty == true
          ? attachment.originalFilename!.trim()
          : attachment.safeFilename;
      results[attachment.id] = _uniqueFileName(
        preferredName,
        usedNames,
      );
    }

    return results;
  }

  Future<List<File>> _discoverImportFiles(Directory rootDirectory) async {
    final List<File> files = <File>[];

    await for (final FileSystemEntity entity
        in rootDirectory.list(recursive: true, followLinks: false)) {
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

  Future<List<_ImportedDocument>> _parseImportFile({
    required File file,
    required Directory importRootDirectory,
    required Directory tempDirectory,
  }) async {
    final String extension = p.extension(file.path).toLowerCase();
    if (extension == '.md') {
      final _ImportedDocument? document = await _parseMarkdownDocument(
        file: file,
        importRootDirectory: importRootDirectory,
        tempDirectory: tempDirectory,
      );
      return document == null ? const <_ImportedDocument>[] : <_ImportedDocument>[document];
    }
    if (extension == '.html' || extension == '.htm') {
      return _parseEasyDiaryHtmlDocuments(
        file: file,
        importRootDirectory: importRootDirectory,
        tempDirectory: tempDirectory,
      );
    }
    return const <_ImportedDocument>[];
  }

  Future<_ImportedDocument?> _parseMarkdownDocument({
    required File file,
    required Directory importRootDirectory,
    required Directory tempDirectory,
  }) async {
    final String document = await file.readAsString();
    final FileStat stat = await file.stat();
    final DecodedFrontMatterDocument decoded = _frontMatterCodec.decodeDocument(document);
    final Map<String, Object?> frontMatter = decoded.frontMatter;
    final String body = decoded.body.trimRight();

    final List<String> attachmentReferences = <String>{
      ...decoded.attachmentPaths,
      ..._extractMarkdownLocalLinks(body),
    }.toList(growable: false);

    final List<PendingAttachment> attachments = await _resolveImportAttachments(
      references: attachmentReferences,
      baseDirectory: file.parent,
      importRootDirectory: importRootDirectory,
      tempDirectory: tempDirectory,
    );

    final DateTime fallbackTime = stat.modified;
    final String inferredTitle = _inferMarkdownTitle(file, body);
    final DiaryEntry entry = DiaryEntry(
      id: generateEntryId(),
      vaultId: 'vlt_LOCAL',
      title: decoded.entry.normalizedTitle ?? inferredTitle,
      date: frontMatter.containsKey('date')
          ? decoded.entry.date
          : (_findDateInText('${file.path}\n$document') ?? DateOnly.fromDateTime(fallbackTime)),
      createdAt: frontMatter.containsKey('created_at') &&
              decoded.entry.createdAt.millisecondsSinceEpoch > 0
          ? decoded.entry.createdAt
          : fallbackTime,
      updatedAt: frontMatter.containsKey('updated_at') &&
              decoded.entry.updatedAt.millisecondsSinceEpoch > 0
          ? decoded.entry.updatedAt
          : fallbackTime,
      markdownBody: body,
      tags: decoded.entry.tags,
      mood: decoded.entry.mood,
    );

    return _ImportedDocument(entry: entry, attachments: attachments);
  }

  Future<List<_ImportedDocument>> _parseEasyDiaryHtmlDocuments({
    required File file,
    required Directory importRootDirectory,
    required Directory tempDirectory,
  }) async {
    final String html = await file.readAsString();
    final FileStat stat = await file.stat();
    final String bodyHtml = _extractHtmlBody(html);
    final List<String> sections = _splitEasyDiarySections(bodyHtml);
    final List<_ImportedDocument> documents = <_ImportedDocument>[];

    for (final String sectionHtml in sections) {
      final _ImportedDocument? document = await _parseEasyDiaryHtmlSection(
        sectionHtml: sectionHtml,
        file: file,
        html: html,
        stat: stat,
        importRootDirectory: importRootDirectory,
        tempDirectory: tempDirectory,
      );
      if (document != null && !document.isEmpty) {
        documents.add(document);
      }
    }

    return documents;
  }

  Future<_ImportedDocument?> _parseEasyDiaryHtmlSection({
    required String sectionHtml,
    required File file,
    required String html,
    required FileStat stat,
    required Directory importRootDirectory,
    required Directory tempDirectory,
  }) async {
    if (!_isEasyDiarySection(sectionHtml)) {
      return null;
    }

    final List<String> attachmentReferences =
        _extractHtmlAttachmentReferences(sectionHtml);
    final List<PendingAttachment> attachments = await _resolveImportAttachments(
      references: attachmentReferences,
      baseDirectory: file.parent,
      importRootDirectory: importRootDirectory,
      tempDirectory: tempDirectory,
    );

    final String? contentsHtml = _extractHtmlClassInnerHtml(sectionHtml, 'contents');
    final String markdownSourceHtml = contentsHtml != null && contentsHtml.trim().isNotEmpty
        ? contentsHtml
        : _stripHtmlImageTags(_composeEasyDiaryEntryHtml(sectionHtml));
    final String markdownBody = _htmlToMarkdown(
      markdownSourceHtml,
      includeImages: false,
    ).trimRight();

    final String? easyDiaryTitle = _extractHtmlClassText(sectionHtml, 'title-right');
    final String? easyDiaryDateText = _extractHtmlClassText(sectionHtml, 'datetime');
    final String title = _extractFirstHtmlTagText(sectionHtml, 'h1') ??
        easyDiaryTitle ??
        _extractFirstHtmlTagText(html, 'title') ??
        _fallbackImportTitle(file);

    final String dateSource = '${file.path}\n${easyDiaryDateText ?? ''}\n$sectionHtml';
    final DateTime? parsedDateTime = _findDateTimeInText(easyDiaryDateText ?? '') ??
        _findDateTimeInText(dateSource);
    final DateOnly entryDate = parsedDateTime != null
        ? DateOnly.fromDateTime(parsedDateTime)
        : (_findDateInText(dateSource) ?? DateOnly.fromDateTime(stat.modified));
    final DateTime entryTimestamp = parsedDateTime ??
        _findDateInText(dateSource)?.toDateTime() ??
        stat.modified;

    final DiaryEntry entry = DiaryEntry(
      id: generateEntryId(),
      vaultId: 'vlt_LOCAL',
      title: title.trim().isEmpty ? _fallbackImportTitle(file) : title.trim(),
      date: entryDate,
      createdAt: entryTimestamp,
      updatedAt: entryTimestamp,
      markdownBody: markdownBody,
    );

    return _ImportedDocument(entry: entry, attachments: attachments);
  }

  List<String> _splitEasyDiarySections(String bodyHtml) {
    final List<String> parts = bodyHtml.split(
      RegExp(r'<hr\b[^>]*>', caseSensitive: false),
    );
    if (parts.length > 1) {
      return parts.where(_isEasyDiarySection).toList(growable: false);
    }
    return bodyHtml.trim().isEmpty ? const <String>[] : <String>[bodyHtml];
  }

  bool _isEasyDiarySection(String sectionHtml) {
    final String trimmed = sectionHtml.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    if (_extractHtmlClassText(sectionHtml, 'title-right') != null ||
        _extractHtmlClassInnerHtml(sectionHtml, 'contents') != null ||
        _extractAllHtmlClassInnerHtml(sectionHtml, 'photo-container').isNotEmpty) {
      return true;
    }

    return RegExp(
      r'<(h[1-6]|p|div|img|ul|ol|blockquote)\b',
      caseSensitive: false,
    ).hasMatch(trimmed);
  }

  String _composeEasyDiaryEntryHtml(String sectionHtml) {
    final StringBuffer buffer = StringBuffer();
    final String? contents = _extractHtmlClassInnerHtml(sectionHtml, 'contents');
    if (contents != null) {
      buffer.writeln(contents);
    }
    for (final String photos in _extractAllHtmlClassInnerHtml(
      sectionHtml,
      'photo-container',
    )) {
      buffer.writeln(photos);
    }

    final String composed = buffer.toString().trim();
    return composed.isEmpty ? sectionHtml.trim() : composed;
  }

  String _stripHtmlImageTags(String html) {
    return html.replaceAll(RegExp(r'<img\b[^>]*>', caseSensitive: false), '');
  }

  Future<List<PendingAttachment>> _resolveImportAttachments({
    required Iterable<String> references,
    required Directory baseDirectory,
    required Directory importRootDirectory,
    required Directory tempDirectory,
  }) async {
    final List<PendingAttachment> attachments = <PendingAttachment>[];
    final Set<String> seenPaths = <String>{};
    int embeddedIndex = 1;

    for (final String rawReference in references) {
      final String reference = rawReference.trim();
      if (reference.isEmpty) {
        continue;
      }
      if (_isIgnoredImportReference(reference)) {
        continue;
      }

      if (reference.startsWith('data:')) {
        final ({String mimeType, Uint8List bytes})? decoded =
            _decodeDataUriReference(reference);
        if (decoded == null) {
          continue;
        }

        final String extension = _extensionFromMimeType(decoded.mimeType);
        final String fileName = 'embedded_${embeddedIndex++}.$extension';
        final File tempFile = File(p.join(tempDirectory.path, fileName));
        await tempFile.writeAsBytes(decoded.bytes, flush: true);
        attachments.add(
          PendingAttachment(
            sourcePath: tempFile.path,
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
        continue;
      }

      final String dedupeKey = resolvedPath.toLowerCase();
      if (!seenPaths.add(dedupeKey)) {
        continue;
      }

      final File sourceFile = File(resolvedPath);
      if (!sourceFile.existsSync()) {
        continue;
      }

      final String originalFilename = p.basename(sourceFile.path);
      attachments.add(
        PendingAttachment(
          sourcePath: sourceFile.path,
          mimeType: _mimeTypeForFileName(originalFilename),
          originalFilename: originalFilename,
        ),
      );
    }

    return attachments;
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

  List<String> _extractHtmlAttachmentReferences(String html) {
    final List<String> references = <String>[];
    final RegExp imgPattern = RegExp(
      r'''<img\b[^>]*\bsrc\s*=\s*(["'])([\s\S]*?)\1''',
      caseSensitive: false,
    );
    for (final Match match in imgPattern.allMatches(html)) {
      final String value = (match.group(2) ?? '').trim();
      if (value.isNotEmpty) {
        references.add(value);
      }
    }

    final RegExp linkPattern = RegExp(
      r'''<a\b[^>]*\bhref\s*=\s*(["'])([\s\S]*?)\1''',
      caseSensitive: false,
    );
    for (final Match match in linkPattern.allMatches(html)) {
      final String value = (match.group(2) ?? '').trim();
      if (value.isNotEmpty && !_isIgnoredImportReference(value)) {
        references.add(value);
      }
    }

    return references;
  }

  String _htmlToMarkdown(String html, {bool includeImages = true}) {
    String output = html;

    output = output.replaceAll(
      RegExp(r'<(script|style)\b[^>]*>[\s\S]*?</\1>', caseSensitive: false),
      '',
    );
    output = output.replaceAll(
      RegExp(r'<!--[\s\S]*?-->'),
      '',
    );
    output = output.replaceAllMapped(
      RegExp(r'<br\s*/?>', caseSensitive: false),
      (_) => '\n',
    );
    output = output.replaceAllMapped(
      RegExp(r'</(p|div|section|article|h[1-6]|ul|ol)\s*>', caseSensitive: false),
      (_) => '\n\n',
    );
    output = output.replaceAllMapped(
      RegExp(r'</(li|tr)\s*>', caseSensitive: false),
      (_) => '\n',
    );
    output = output.replaceAllMapped(
      RegExp(r'<li\b[^>]*>', caseSensitive: false),
      (_) => '- ',
    );
    if (includeImages) {
      output = output.replaceAllMapped(
        RegExp(r"""<img\b[^>]*src=["']([^"']+)["'][^>]*>""", caseSensitive: false),
        (Match match) {
          final String src = (match.group(1) ?? '').trim();
          final String alt = _extractAttributeValue(match.group(0) ?? '', 'alt');
          final String label = alt.isEmpty ? 'image' : alt;
          final String target =
              src.startsWith('data:') ? label : p.basename(src.split('?').first);
          return '![${_escapeMarkdownText(label)}]($target)';
        },
      );
    } else {
      output = output.replaceAll(
        RegExp(r'<img\b[^>]*>', caseSensitive: false),
        '',
      );
    }
    output = output.replaceAllMapped(
      RegExp(
        r"""<a\b[^>]*href=["']([^"']+)["'][^>]*>([\s\S]*?)</a>""",
        caseSensitive: false,
      ),
      (Match match) {
        final String href = (match.group(1) ?? '').trim();
        final String text = _stripHtmlTags(match.group(2) ?? '').trim();
        final String label = text.isEmpty ? href : text;
        return '[${_escapeMarkdownText(label)}]($href)';
      },
    );
    output = output.replaceAll(RegExp(r'<[^>]+>'), ' ');
    output = _decodeHtmlEntities(output);
    output = output.replaceAll(RegExp(r'\r\n?'), '\n');
    output = output.replaceAll(RegExp(r'[ \t]{2,}'), ' ');
    output = output.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    output = output.replaceAll(RegExp(r'\n[ \t]+'), '\n');
    output = output.replaceAll(RegExp(r'[ \t]+\n'), '\n');
    return output.trim();
  }

  String _extractHtmlBody(String html) {
    final Match? match = RegExp(
      r'<body\b[^>]*>([\s\S]*?)</body>',
      caseSensitive: false,
    ).firstMatch(html);
    return match?.group(1) ?? html;
  }

  String? _extractFirstHtmlTagText(String html, String tagName) {
    final Match? match = RegExp(
      '<$tagName\\b[^>]*>([\\s\\S]*?)</$tagName>',
      caseSensitive: false,
    ).firstMatch(html);
    if (match == null) {
      return null;
    }

    final String text = _decodeHtmlEntities(
      _stripHtmlTags(match.group(1) ?? ''),
    ).trim();
    return text.isEmpty ? null : text;
  }

  String? _extractHtmlClassText(String html, String className) {
    final String? innerHtml = _extractHtmlClassInnerHtml(html, className);
    if (innerHtml == null) {
      return null;
    }

    final String text = _decodeHtmlEntities(
      _stripHtmlTags(innerHtml),
    ).trim();
    return text.isEmpty ? null : text;
  }

  String? _extractHtmlClassInnerHtml(String html, String className) {
    final List<String> matches = _extractAllHtmlClassInnerHtml(html, className);
    return matches.isEmpty ? null : matches.first;
  }

  List<String> _extractAllHtmlClassInnerHtml(String html, String className) {
    final RegExp pattern = RegExp(
      r'''<[^>]*\bclass\s*=\s*['"][^'"]*\b''' +
          RegExp.escape(className) +
          r'''\b[^'"]*['"][^>]*>([\s\S]*?)</[^>]+>''',
      caseSensitive: false,
    );

    return pattern
        .allMatches(html)
        .map((Match match) => (match.group(1) ?? '').trim())
        .where((String value) => value.isNotEmpty)
        .toList(growable: false);
  }

  String _stripHtmlTags(String input) {
    return input.replaceAll(RegExp(r'<[^>]+>'), ' ');
  }

  String _decodeHtmlEntities(String input) {
    String output = input
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");

    output = output.replaceAllMapped(
      RegExp(r'&#x([0-9a-fA-F]+);'),
      (Match match) {
        final int? codePoint = int.tryParse(match.group(1) ?? '', radix: 16);
        return codePoint == null ? match.group(0)! : String.fromCharCode(codePoint);
      },
    );
    output = output.replaceAllMapped(
      RegExp(r'&#(\d+);'),
      (Match match) {
        final int? codePoint = int.tryParse(match.group(1) ?? '');
        return codePoint == null ? match.group(0)! : String.fromCharCode(codePoint);
      },
    );
    return output;
  }

  String _extractAttributeValue(String tagSource, String attributeName) {
    final Match? match = RegExp(
      '$attributeName\\s*=\\s*["\']([^"\']*)["\']',
      caseSensitive: false,
    ).firstMatch(tagSource);
    return match?.group(1)?.trim() ?? '';
  }

  String _escapeMarkdownText(String input) {
    return input.replaceAll('[', r'\[').replaceAll(']', r'\]');
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

  DateTime? _findDateTimeInText(String text) {
    final Match? ymdTime = RegExp(
      r'(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})[ T](\d{1,2}):(\d{2})(?::(\d{2}))?',
    ).firstMatch(text);
    if (ymdTime != null) {
      return _dateTimeFromParts(
        year: int.parse(ymdTime.group(1)!),
        month: int.parse(ymdTime.group(2)!),
        day: int.parse(ymdTime.group(3)!),
        hour: int.parse(ymdTime.group(4)!),
        minute: int.parse(ymdTime.group(5)!),
        second: ymdTime.group(6) != null ? int.parse(ymdTime.group(6)!) : 0,
      );
    }

    final Match? cjkTime = RegExp(
      r'(\d{4})\s*年\s*(\d{1,2})\s*月\s*(\d{1,2})\s*日'
      r'(?:\s*星期[一二三四五六日])?'
      r'\s*(上午|下午)?\s*(\d{1,2}):(\d{2})(?::(\d{2}))?',
    ).firstMatch(text);
    if (cjkTime != null) {
      return _dateTimeFromParts(
        year: int.parse(cjkTime.group(1)!),
        month: int.parse(cjkTime.group(2)!),
        day: int.parse(cjkTime.group(3)!),
        hour: _hourFromChinesePeriod(
          hour: int.parse(cjkTime.group(5)!),
          period: cjkTime.group(4),
        ),
        minute: int.parse(cjkTime.group(6)!),
        second: cjkTime.group(7) != null ? int.parse(cjkTime.group(7)!) : 0,
      );
    }

    return null;
  }

  DateTime _dateTimeFromParts({
    required int year,
    required int month,
    required int day,
    required int hour,
    required int minute,
    required int second,
  }) {
    return DateTime(year, month, day, hour, minute, second);
  }

  int _hourFromChinesePeriod({required int hour, String? period}) {
    if (period == '下午' && hour < 12) {
      return hour + 12;
    }
    if (period == '上午' && hour == 12) {
      return 0;
    }
    return hour;
  }

  DateOnly? _findDateInText(String text) {
    final Match? ymd = RegExp(r'(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})').firstMatch(text);
    if (ymd != null) {
      return DateOnly(
        '${ymd.group(1)}-${_pad2(ymd.group(2))}-${_pad2(ymd.group(3))}',
      );
    }

    final Match? korean = RegExp(
      r'(\d{4})\s*년\s*(\d{1,2})\s*월\s*(\d{1,2})\s*일',
    ).firstMatch(text);
    if (korean != null) {
      return DateOnly(
        '${korean.group(1)}-${_pad2(korean.group(2))}-${_pad2(korean.group(3))}',
      );
    }

    final Match? cjk = RegExp(
      r'(\d{4})\s*年\s*(\d{1,2})\s*月\s*(\d{1,2})\s*日',
    ).firstMatch(text);
    if (cjk != null) {
      return DateOnly(
        '${cjk.group(1)}-${_pad2(cjk.group(2))}-${_pad2(cjk.group(3))}',
      );
    }

    return null;
  }

  String _pad2(String? value) {
    final int parsed = int.tryParse(value ?? '') ?? 1;
    return parsed.toString().padLeft(2, '0');
  }

  ({String mimeType, Uint8List bytes})? _decodeDataUriReference(String dataUri) {
    if (!dataUri.startsWith('data:')) {
      return null;
    }

    final int commaIndex = dataUri.indexOf(',');
    if (commaIndex == -1) {
      return null;
    }

    final String metadata = dataUri.substring('data:'.length, commaIndex).trim();
    String payload = dataUri.substring(commaIndex + 1);
    if (payload.startsWith(' ')) {
      payload = payload.trimLeft();
    }
    if (payload.isEmpty) {
      return null;
    }

    final String mimeType = metadata
        .split(';')
        .first
        .trim()
        .toLowerCase();
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

  bool _isIgnoredImportReference(String reference) {
    final String lower = reference.toLowerCase();
    return lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('mailto:') ||
        lower.startsWith('tel:') ||
        lower.startsWith('#');
  }

  bool _isPathWithinRoot(String targetPath, String rootPath) {
    final String normalizedTarget = p.normalize(targetPath);
    final String normalizedRoot = p.normalize(rootPath);
    return normalizedTarget == normalizedRoot || p.isWithin(normalizedRoot, normalizedTarget);
  }

  String _portableEntryFolderName(DiaryEntry entry) {
    final String title = entry.normalizedTitle ?? '';
    if (title.isNotEmpty) {
      final String sanitized = _sanitizePathSegment(title);
      if (sanitized.isNotEmpty) {
        return sanitized;
      }
    }
    return 'entry-${entry.id.substring(entry.id.length - 6).toLowerCase()}';
  }

  String _sanitizePathSegment(String value) {
    return value
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]+'), '-')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .replaceAll(RegExp(r'[. ]+$'), '');
  }

  String _uniqueFileName(String preferredName, Set<String> usedNames) {
    final String cleaned = _sanitizeFileName(preferredName);
    final String extension = p.extension(cleaned);
    final String stem = p.basenameWithoutExtension(cleaned);
    String candidate = cleaned;
    int suffix = 2;

    while (!usedNames.add(candidate.toLowerCase())) {
      candidate = '$stem-$suffix$extension';
      suffix++;
    }

    return candidate;
  }

  String _sanitizeFileName(String value) {
    final String basename = p.basename(value.trim());
    final String sanitized = basename
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]+'), '-')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .replaceAll(RegExp(r'[. ]+$'), '');
    return sanitized.isEmpty ? 'attachment.bin' : sanitized;
  }

  Future<void> _exportAttachments({
    required UnlockedVaultSession session,
    required DiaryEntry entry,
    required List<AssetAttachment> attachments,
    required Map<AssetId, String> attachmentFileNames,
    required Directory entryDirectory,
    required Directory vaultRoot,
  }) async {
    const int batchSize = 3;

    for (int index = 0; index < attachments.length; index += batchSize) {
      final List<AssetAttachment> batch = attachments.skip(index).take(batchSize).toList();
      await Future.wait<void>(
        batch.map(
          (AssetAttachment attachment) => _exportAttachment(
            session: session,
            entry: entry,
            attachment: attachment,
            outputName: attachmentFileNames[attachment.id] ?? attachment.safeFilename,
            entryDirectory: entryDirectory,
            vaultRoot: vaultRoot,
          ),
        ),
      );
    }
  }

  Future<void> _exportAttachment({
    required UnlockedVaultSession session,
    required DiaryEntry entry,
    required AssetAttachment attachment,
    required String outputName,
    required Directory entryDirectory,
    required Directory vaultRoot,
  }) async {
    final String extension = p.extension(attachment.safeFilename).replaceFirst('.', '');
    final File encryptedFile = File(
      p.join(
        vaultRoot.path,
        _pathStrategy.assetRelativePath(
          date: entry.date,
          assetId: attachment.id,
          extension: extension,
        ),
      ),
    );
    if (!encryptedFile.existsSync()) {
      return;
    }

    final List<int>? bytes = await _repository.readDecryptedAssetBytes(
      session,
      encryptedFile.path,
    );
    if (bytes == null) {
      return;
    }

    await File(
      p.join(entryDirectory.path, outputName),
    ).writeAsBytes(bytes, flush: true);
  }

  String _extensionFromMimeType(String mimeType) {
    return switch (mimeType.toLowerCase()) {
      'image/jpeg' => 'jpg',
      'image/png' => 'png',
      'image/gif' => 'gif',
      'image/webp' => 'webp',
      'image/svg+xml' => 'svg',
      'text/plain' => 'txt',
      'text/markdown' => 'md',
      'application/pdf' => 'pdf',
      _ => 'bin',
    };
  }

  String _mimeTypeForFileName(String fileName) {
    return switch (p.extension(fileName).toLowerCase()) {
      '.jpg' || '.jpeg' => 'image/jpeg',
      '.png' => 'image/png',
      '.gif' => 'image/gif',
      '.webp' => 'image/webp',
      '.svg' => 'image/svg+xml',
      '.txt' => 'text/plain',
      '.md' => 'text/markdown',
      '.pdf' => 'application/pdf',
      '.mp4' => 'video/mp4',
      '.mov' => 'video/quicktime',
      _ => 'application/octet-stream',
    };
  }

  void _ensureSafeArchivePath(String relativePath) {
    if (relativePath.contains('..') || p.isAbsolute(relativePath)) {
      throw const FormatException('匯入封存包含不安全的路徑。');
    }
  }

  Future<Directory> _createWorkingDirectory(String prefix) async {
    final Directory appRoot = await _pathStrategy.appRootDirectory();
    final Directory tempRoot = Directory(p.join(appRoot.path, '_tmp'));
    await tempRoot.create(recursive: true);

    final Directory workingDirectory = Directory(
      p.join(tempRoot.path, '${prefix}_${DateTime.now().microsecondsSinceEpoch}'),
    );
    await workingDirectory.create(recursive: true);
    return workingDirectory;
  }
}

class _ImportedDocument {
  const _ImportedDocument({
    required this.entry,
    required this.attachments,
  });

  final DiaryEntry entry;
  final List<PendingAttachment> attachments;

  bool get isEmpty =>
      entry.markdownBody.trim().isEmpty &&
      (entry.normalizedTitle == null || entry.normalizedTitle!.isEmpty) &&
      attachments.isEmpty;
}
