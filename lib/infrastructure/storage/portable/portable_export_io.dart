import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import '../../../domain/attachment/asset_attachment.dart';
import '../../../domain/diary/diary_entry.dart';
import '../../../domain/people/person.dart';
import '../../../domain/security/unlocked_vault_session.dart';
import '../../../domain/shared/value_objects.dart';
import '../../database/index_database.dart';
import '../../markdown/front_matter_codec.dart';
import '../../database/entry_index_sorting.dart';
import '../shared/media_type_utils.dart';
import '../shared/vault_file_ops.dart';
import '../vault_path_strategy.dart';
import '../vault_repository.dart';
import 'html_export_person_anonymizer.dart';
import 'portable_date_text.dart';
import 'portable_io_types.dart';

/// HTML 可攜式匯出選項。
class HtmlExportOptions {
  const HtmlExportOptions({
    this.includeImages = true,
    this.hidePersonNames = false,
    this.useEnglishPersonLabels = false,
  });

  final bool includeImages;
  final bool hidePersonNames;
  final bool useEnglishPersonLabels;
}

/// Markdown ZIP 可攜式匯出選項。
class MarkdownExportOptions {
  const MarkdownExportOptions({
    this.hidePersonNames = false,
    this.useEnglishPersonLabels = false,
  });

  final bool hidePersonNames;
  final bool useEnglishPersonLabels;
}

/// HTML 匯出候補清單中的單篇摘要（供確認 dialog 選取）。
class HtmlExportEntrySummary {
  const HtmlExportEntrySummary({
    required this.id,
    required this.date,
    required this.title,
    required this.imageCount,
    required this.imageBytes,
    required this.textBytes,
  });

  final EntryId id;
  final DateOnly date;
  final String? title;
  final int imageCount;
  final int imageBytes;
  final int textBytes;
}

/// 嵌入圖片資料前，對所選 HTML 匯出的尺寸估算。
class HtmlExportEstimate {
  const HtmlExportEstimate({required this.entries});

  final List<HtmlExportEntrySummary> entries;

  int get entryCount => entries.length;

  int get imageCount =>
      entries.fold<int>(0, (int sum, HtmlExportEntrySummary e) => sum + e.imageCount);

  int get imageBytes =>
      entries.fold<int>(0, (int sum, HtmlExportEntrySummary e) => sum + e.imageBytes);

  /// 依是否內嵌圖片估算實際匯出檔大小。
  int estimatedExportBytes({required bool includeImages}) {
    final int textBytes = entries.fold<int>(
      0,
      (int sum, HtmlExportEntrySummary e) => sum + e.textBytes,
    );
    if (!includeImages) {
      return textBytes;
    }
    return textBytes + ((imageBytes * 4 + 2) ~/ 3);
  }

  DateOnly? get firstDate {
    DateOnly? first;
    for (final HtmlExportEntrySummary entry in entries) {
      if (first == null || entry.date.value.compareTo(first.value) < 0) {
        first = entry.date;
      }
    }
    return first;
  }

  DateOnly? get lastDate {
    DateOnly? last;
    for (final HtmlExportEntrySummary entry in entries) {
      if (last == null || entry.date.value.compareTo(last.value) > 0) {
        last = entry.date;
      }
    }
    return last;
  }

  bool exceedsImageBytes(int thresholdBytes) => imageBytes >= thresholdBytes;

  /// 依選中 ID 產生子集合估算（順序維持原候補順序）。
  HtmlExportEstimate forSelected(Set<EntryId> selectedIds) {
    return HtmlExportEstimate(
      entries: entries
          .where((HtmlExportEntrySummary e) => selectedIds.contains(e.id))
          .toList(growable: false),
    );
  }
}

/// Markdown ZIP 匯出前的輕量估算。
class MarkdownExportEntrySummary {
  const MarkdownExportEntrySummary({
    required this.id,
    required this.date,
    required this.title,
    required this.attachmentCount,
    required this.attachmentBytes,
    required this.textBytes,
  });

  final EntryId id;
  final DateOnly date;
  final String? title;
  final int attachmentCount;
  final int attachmentBytes;
  final int textBytes;
}

class MarkdownExportEstimate {
  const MarkdownExportEstimate({required this.entries});

  final List<MarkdownExportEntrySummary> entries;

  int get entryCount => entries.length;

  int get attachmentCount => entries.fold<int>(
    0,
    (int sum, MarkdownExportEntrySummary e) => sum + e.attachmentCount,
  );

  int get estimatedBytes => entries.fold<int>(
    0,
    (int sum, MarkdownExportEntrySummary e) =>
        sum + e.textBytes + e.attachmentBytes,
  );

  DateOnly? get firstDate {
    DateOnly? first;
    for (final MarkdownExportEntrySummary entry in entries) {
      if (first == null || entry.date.value.compareTo(first.value) < 0) {
        first = entry.date;
      }
    }
    return first;
  }

  DateOnly? get lastDate {
    DateOnly? last;
    for (final MarkdownExportEntrySummary entry in entries) {
      if (last == null || entry.date.value.compareTo(last.value) > 0) {
        last = entry.date;
      }
    }
    return last;
  }

  MarkdownExportEstimate forSelected(Set<EntryId> selectedIds) {
    return MarkdownExportEstimate(
      entries: entries
          .where((MarkdownExportEntrySummary e) => selectedIds.contains(e.id))
          .toList(growable: false),
    );
  }
}

/// 寫入使用者可攜的 Markdown、ZIP 與所選條目 HTML 匯出。
///
/// 這些格式刻意與加密完整 vault 備份 zip 分開，
/// 讓使用者可檢視並以散檔重新匯入。
class PortableExportIo {
  PortableExportIo({
    required VaultPathStrategy pathStrategy,
    required VaultRepository repository,
    required FrontMatterCodec frontMatterCodec,
  }) : _pathStrategy = pathStrategy,
       _repository = repository,
       _frontMatterCodec = frontMatterCodec;

  final VaultPathStrategy _pathStrategy;
  final VaultRepository _repository;
  final FrontMatterCodec _frontMatterCodec;

  static const String kNoHtmlExportEntriesMessage = '沒有可匯出的日記。';

  Future<Directory> exportMarkdown({
    required UnlockedVaultSession session,
    required Directory parentDirectory,
    Set<EntryId>? entryIds,
    MarkdownExportOptions options = const MarkdownExportOptions(),
  }) async {
    final List<EntryIndexRecord> allEntries = await _repository.listEntries();
    final Set<EntryId>? selected = entryIds
        ?.map((EntryId id) => id.trim())
        .where((EntryId id) => id.isNotEmpty)
        .toSet();
    final List<EntryIndexRecord> entries = selected == null
        ? allEntries
        : allEntries
              .where((EntryIndexRecord record) => selected.contains(record.id))
              .toList(growable: false);

    HtmlExportPersonAnonymizer? anonymizer;
    if (options.hidePersonNames) {
      final List<Person> people = await _repository.listPeople(session);
      anonymizer = HtmlExportPersonAnonymizer(
        people: people,
        useEnglishLabels: options.useEnglishPersonLabels,
      );
    }

    final Directory vaultRoot = await _pathStrategy.vaultRootDirectory();
    final Directory exportRoot = parentDirectory;
    await exportRoot.create(recursive: true);

    final Set<String> usedEntryDirectories = <String>{};

    for (final EntryIndexRecord record in entries) {
      final List<Object?> loaded = await Future.wait<Object?>(<Future<Object?>>[
        _repository.loadEntry(session, record.id),
        _repository.loadAttachments(record.id),
      ]);
      DiaryEntry? entry = loaded[0] as DiaryEntry?;
      if (entry == null) {
        continue;
      }

      if (anonymizer != null) {
        final String? rawTitle = entry.normalizedTitle;
        entry = entry.copyWith(
          title: rawTitle == null
              ? null
              : anonymizer.anonymizePlainText(rawTitle),
          clearTitle: rawTitle == null,
          tags: entry.tags
              .map(anonymizer.anonymizePlainText)
              .toList(growable: false),
          markdownBody: anonymizer.anonymizeMarkdownBody(entry.markdownBody),
        );
      }

      final List<AssetAttachment> attachments =
          loaded[1] as List<AssetAttachment>;
      final Directory entryDirectory = await _createExportEntryDirectory(
        exportRoot: exportRoot,
        entry: entry,
        usedRelativePaths: usedEntryDirectories,
      );
      final Map<AssetId, String> attachmentFileNames =
          _buildExportAttachmentFileNames(attachments);
      final String exportMarkdown = _frontMatterCodec.encode(
        entry,
        attachments: attachments,
        attachmentPathBuilder: (AssetAttachment attachment) =>
            './${attachmentFileNames[attachment.id] ?? attachment.safeFilename}',
      );

      await File(
        p.join(entryDirectory.path, 'index.md'),
      ).writeAsString(exportMarkdown, flush: true);

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

  Future<File> writeMarkdownZip({
    required UnlockedVaultSession session,
    required File target,
    Set<EntryId>? entryIds,
    MarkdownExportOptions options = const MarkdownExportOptions(),
  }) async {
    final Directory tempRoot = await createWorkingDirectory(
      _pathStrategy,
      'portable_export',
    );
    try {
      await exportMarkdown(
        session: session,
        parentDirectory: tempRoot,
        entryIds: entryIds,
        options: options,
      );
      await target.parent.create(recursive: true);
      final ZipFileEncoder encoder = ZipFileEncoder();
      encoder.create(target.path);
      await encoder.addDirectory(tempRoot, includeDirName: false);
      await encoder.close();
      return target;
    } finally {
      if (tempRoot.existsSync()) {
        await tempRoot.delete(recursive: true);
      }
    }
  }

  Future<HtmlExportEstimate> estimateSelectedHtmlExport({
    required Set<EntryId> entryIds,
  }) async {
    final List<HtmlExportDocument> documents =
        await _requireSelectedHtmlExportDocuments(
          session: null,
          entryIds: entryIds,
          loadEntries: false,
        );

    final List<HtmlExportEntrySummary> summaries = <HtmlExportEntrySummary>[];
    for (final HtmlExportDocument document in documents) {
      final DiaryEntry? entry = document.entry;
      final EntryIndexRecord record = document.record;
      final int textBytes;
      final String? title;
      if (entry != null) {
        title = entry.normalizedTitle;
        textBytes = utf8
            .encode(
              '${entry.normalizedTitle ?? ''}\n${entry.tags.join(',')}\n${entry.markdownBody}',
            )
            .length;
      } else {
        title = record.title;
        textBytes =
            utf8
                .encode('${record.title ?? ''}\n${record.tags.join(',')}\n')
                .length +
            record.charCount;
      }

      var entryImageCount = 0;
      var entryImageBytes = 0;
      for (final AssetAttachment attachment in document.attachments) {
        if (_isImageAttachment(attachment)) {
          entryImageCount++;
          entryImageBytes += attachment.byteSize;
        }
      }

      summaries.add(
        HtmlExportEntrySummary(
          id: record.id,
          date: record.date,
          title: title,
          imageCount: entryImageCount,
          imageBytes: entryImageBytes,
          textBytes: textBytes,
        ),
      );
    }

    return HtmlExportEstimate(entries: summaries);
  }

  Future<MarkdownExportEstimate> estimateMarkdownExport() async {
    final List<EntryIndexRecord> entries = await _repository.listEntries();
    final List<List<AssetAttachment>> attachmentLists = await Future.wait(
      entries.map(
        (EntryIndexRecord record) => _repository.loadAttachments(record.id),
      ),
    );

    final List<MarkdownExportEntrySummary> summaries =
        <MarkdownExportEntrySummary>[];
    for (var index = 0; index < entries.length; index++) {
      final EntryIndexRecord record = entries[index];
      final List<AssetAttachment> attachments = attachmentLists[index];
      var attachmentBytes = 0;
      for (final AssetAttachment attachment in attachments) {
        attachmentBytes += attachment.byteSize;
      }
      summaries.add(
        MarkdownExportEntrySummary(
          id: record.id,
          date: record.date,
          title: record.title,
          attachmentCount: attachments.length,
          attachmentBytes: attachmentBytes,
          textBytes:
              utf8
                  .encode('${record.title ?? ''}\n${record.tags.join(',')}\n')
                  .length +
              record.charCount,
        ),
      );
    }

    return MarkdownExportEstimate(entries: summaries);
  }

  Future<File> writeSelectedHtmlExport({
    required UnlockedVaultSession session,
    required Set<EntryId> entryIds,
    required File target,
    HtmlExportOptions options = const HtmlExportOptions(),
  }) async {
    final List<HtmlExportDocument> documents =
        await _requireSelectedHtmlExportDocuments(
          session: session,
          entryIds: entryIds,
          loadEntries: true,
        );

    final String html = await _buildSelectedHtmlDocument(
      session: session,
      documents: documents,
      options: options,
    );
    await target.parent.create(recursive: true);
    await target.writeAsString(html, flush: true);
    return target;
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

  Map<AssetId, String> _buildExportAttachmentFileNames(
    List<AssetAttachment> attachments,
  ) {
    final Map<AssetId, String> results = <AssetId, String>{};
    final Set<String> usedNames = <String>{};

    for (final AssetAttachment attachment in attachments) {
      final String preferredName =
          attachment.originalFilename?.trim().isNotEmpty == true
          ? attachment.originalFilename!.trim()
          : attachment.safeFilename;
      results[attachment.id] = _uniqueFileName(preferredName, usedNames);
    }

    return results;
  }

  Future<List<HtmlExportDocument>> _loadSelectedHtmlExportDocuments({
    required UnlockedVaultSession? session,
    required Set<EntryId> entryIds,
    required bool loadEntries,
  }) async {
    if (entryIds.isEmpty) {
      return const <HtmlExportDocument>[];
    }

    final Set<EntryId> selected = entryIds
        .map((EntryId id) => id.trim())
        .toSet();
    final List<EntryIndexRecord> records =
        (await _repository.listEntries())
            .where((EntryIndexRecord record) => selected.contains(record.id))
            .toList()
          ..sort(compareEntriesNewestFirst);

    final UnlockedVaultSession? exportSession = loadEntries
        ? session ?? (throw StateError('缺少匯出 HTML 所需的解鎖 session。'))
        : null;
    final List<HtmlExportDocument?> documents =
        await Future.wait<HtmlExportDocument?>(
          records.map(
            (EntryIndexRecord record) => _loadHtmlExportDocument(
              record: record,
              session: exportSession,
              loadEntry: loadEntries,
            ),
          ),
        );
    return documents.whereType<HtmlExportDocument>().toList(growable: false);
  }

  Future<List<HtmlExportDocument>> _requireSelectedHtmlExportDocuments({
    required UnlockedVaultSession? session,
    required Set<EntryId> entryIds,
    required bool loadEntries,
  }) async {
    final List<HtmlExportDocument> documents =
        await _loadSelectedHtmlExportDocuments(
          session: session,
          entryIds: entryIds,
          loadEntries: loadEntries,
        );
    if (documents.isEmpty) {
      throw StateError(kNoHtmlExportEntriesMessage);
    }
    return documents;
  }

  Future<HtmlExportDocument?> _loadHtmlExportDocument({
    required EntryIndexRecord record,
    required UnlockedVaultSession? session,
    required bool loadEntry,
  }) async {
    final List<Object?> loaded = await Future.wait<Object?>(<Future<Object?>>[
      if (loadEntry) _repository.loadEntry(session!, record.id),
      _repository.loadAttachments(record.id),
    ]);
    final DiaryEntry? entry = loadEntry ? loaded[0] as DiaryEntry? : null;
    if (loadEntry && entry == null) {
      return null;
    }
    return HtmlExportDocument(
      record: record,
      entry: entry,
      attachments: loaded[loadEntry ? 1 : 0] as List<AssetAttachment>,
    );
  }

  Future<String> _buildSelectedHtmlDocument({
    required UnlockedVaultSession session,
    required List<HtmlExportDocument> documents,
    required HtmlExportOptions options,
  }) async {
    HtmlExportPersonAnonymizer? anonymizer;
    if (options.hidePersonNames) {
      final List<Person> people = await _repository.listPeople(session);
      anonymizer = HtmlExportPersonAnonymizer(
        people: people,
        useEnglishLabels: options.useEnglishPersonLabels,
      );
    }

    var imageOrdinal = 1;
    var fileOrdinal = 1;
    final StringBuffer body = StringBuffer();
    for (final HtmlExportDocument document in documents) {
      final DiaryEntry entry = document.entry!;
      final String rawTitle = entry.normalizedTitle ?? '未命名日記';
      final String title = anonymizer?.anonymizePlainText(rawTitle) ?? rawTitle;
      final List<String> tags = entry.tags
          .map(
            (String tag) => anonymizer?.anonymizePlainText(tag) ?? tag,
          )
          .toList(growable: false);
      final String markdownBody =
          anonymizer?.anonymizeMarkdownBody(entry.markdownBody) ??
          entry.markdownBody;

      body.writeln('<article class="entry">');
      body.writeln('<header class="entry-header">');
      body.writeln(
        '<p class="entry-date">${_escapeHtml(formatQuillDiaryExportEntryDateTime(entry))}</p>',
      );
      body.writeln('<h2>${_escapeHtml(title)}</h2>');
      if (tags.isNotEmpty) {
        body.writeln('<ul class="tags">');
        for (final String tag in tags) {
          body.writeln('<li>${_escapeHtml(tag)}</li>');
        }
        body.writeln('</ul>');
      }
      body.writeln('</header>');
      body.writeln('<section class="entry-body">');
      body.writeln(_markdownToExportHtml(markdownBody));
      body.writeln('</section>');
      body.writeln(
        await _htmlAttachmentsSection(
          session: session,
          entry: entry,
          attachments: document.attachments,
          includeImages: options.includeImages,
          nextImageLabel: (AssetAttachment attachment) {
            final String extension = extensionFromMimeType(attachment.mimeType);
            final String label = 'image-$imageOrdinal.$extension';
            imageOrdinal += 1;
            return label;
          },
          nextFileLabel: (AssetAttachment attachment) {
            final String extension = extensionFromMimeType(attachment.mimeType);
            final String label = 'file-$fileOrdinal.$extension';
            fileOrdinal += 1;
            return label;
          },
        ),
      );
      body.writeln('</article>');
    }

    return '''
<!doctype html>
<html lang="zh-Hant">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Quill Diary 匯出</title>
  <style>
    :root {
      color-scheme: light;
      --bg: #f7f4ee;
      --paper: #fffdf8;
      --ink: #22231f;
      --muted: #6a6d63;
      --line: #dfd8cb;
      --accent: #4c7a67;
      --accent-soft: #dcebe3;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      background: var(--bg);
      color: var(--ink);
      font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      line-height: 1.55;
    }
    main {
      width: min(920px, calc(100% - 32px));
      margin: 0 auto;
      padding: 40px 0 56px;
    }
    h1, h2, h3 { line-height: 1.25; }
    .entry {
      background: var(--paper);
      border: 1px solid var(--line);
      border-radius: 14px;
      padding: 26px;
      margin: 22px 0;
      box-shadow: 0 10px 28px rgba(35, 31, 24, 0.06);
    }
    .entry-date {
      margin: 0 0 8px;
      color: var(--accent);
      font-weight: 700;
      letter-spacing: 0.02em;
    }
    .entry h2 { margin: 0 0 12px; font-size: 1.45rem; }
    .tags {
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
      padding: 0;
      margin: 16px 0 0;
      list-style: none;
    }
    .tags li {
      border-radius: 999px;
      background: var(--accent-soft);
      color: #244839;
      padding: 3px 10px;
      font-size: 0.88rem;
      font-weight: 650;
    }
    .entry-body { margin-top: 16px; }
    .entry-body p { margin: 0 0 0.65em; }
    .entry-body p:last-child { margin-bottom: 0; }
    .entry-body ul:not(.task-list) {
      margin: 0 0 0.65em;
      padding-left: 1.35em;
    }
    .entry-body ul:last-child { margin-bottom: 0; }
    .entry-body h1,
    .entry-body h2,
    .entry-body h3,
    .entry-body h4,
    .entry-body h5,
    .entry-body h6 {
      margin: 0.85em 0 0.4em;
    }
    .entry-body > :first-child { margin-top: 0; }
    .entry-body pre {
      overflow-x: auto;
      border-radius: 10px;
      background: #292b27;
      color: #f4f1e9;
      padding: 14px;
    }
    .entry-body code {
      border-radius: 5px;
      background: rgba(76, 122, 103, 0.12);
      padding: 1px 5px;
    }
    .entry-body pre code { background: transparent; padding: 0; }
    .entry-body ul.task-list {
      list-style: none;
      margin: 0 0 0.65em;
      padding-left: 0;
    }
    .task-list-item {
      list-style: none;
      margin: 0;
      padding: 0;
    }
    .task-list-item label {
      display: inline-flex;
      align-items: flex-start;
      gap: 8px;
    }
    .task-list-item input {
      flex: 0 0 auto;
      margin-top: 0.2em;
    }
    .entry-body blockquote {
      margin: 1em 0;
      padding-left: 14px;
      border-left: 4px solid var(--accent);
      color: var(--muted);
    }
    .embedded-images {
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 12px;
      margin-top: 20px;
    }
    figure { margin: 0; }
    figure img {
      display: block;
      width: 100%;
      height: auto;
      border-radius: 10px;
      border: 1px solid var(--line);
      background: #fff;
    }
    .attachment-list {
      color: var(--muted);
      font-size: 0.88rem;
    }
    .attachment-list { margin-top: 18px; }
    @media print {
      body { background: white; }
      main { width: 100%; padding: 0; }
      .entry { box-shadow: none; break-inside: avoid; }
    }
  </style>
</head>
<body>
  <main>
    ${body.toString()}
  </main>
</body>
</html>
''';
  }

  Future<String> _htmlAttachmentsSection({
    required UnlockedVaultSession session,
    required DiaryEntry entry,
    required List<AssetAttachment> attachments,
    required bool includeImages,
    required String Function(AssetAttachment attachment) nextImageLabel,
    required String Function(AssetAttachment attachment) nextFileLabel,
  }) async {
    // 關閉「匯出圖片與附件」時略過全部附件。
    if (!includeImages || attachments.isEmpty) {
      return '';
    }

    final StringBuffer images = StringBuffer();
    final List<({AssetAttachment attachment, String label})> listed =
        <({AssetAttachment attachment, String label})>[];
    for (final AssetAttachment attachment in attachments) {
      if (!_isImageAttachment(attachment)) {
        listed.add((attachment: attachment, label: nextFileLabel(attachment)));
        continue;
      }

      final String encryptedPath = await _pathStrategy.assetAbsolutePath(
        date: entry.date,
        assetId: attachment.id,
        extension: p.extension(attachment.safeFilename).replaceFirst('.', ''),
      );
      final Uint8List? bytes = await _repository.readDecryptedAssetBytes(
        session,
        encryptedPath,
        maxEncryptedFileBytes: 1 << 62,
      );
      if (bytes == null) {
        listed.add((
          attachment: attachment,
          label: nextImageLabel(attachment),
        ));
        continue;
      }

      final String label = nextImageLabel(attachment);
      images.writeln('<figure>');
      images.writeln(
        '<img src="data:${_escapeHtmlAttribute(attachment.mimeType)};base64,${base64Encode(bytes)}" alt="${_escapeHtmlAttribute(label)}">',
      );
      images.writeln('</figure>');
    }

    final StringBuffer html = StringBuffer();
    if (images.isNotEmpty) {
      html.writeln('<section class="embedded-images">');
      html.write(images.toString());
      html.writeln('</section>');
    }
    if (listed.isNotEmpty) {
      html.writeln('<section class="attachment-list">');
      html.writeln('<h3>未內嵌附件</h3>');
      html.writeln('<ul>');
      for (final ({AssetAttachment attachment, String label}) item in listed) {
        html.writeln(
          '<li>${_escapeHtml(item.label)} · ${_escapeHtml(item.attachment.mimeType)} · ${_formatBytes(item.attachment.byteSize)}</li>',
        );
      }
      html.writeln('</ul>');
      html.writeln('</section>');
    }
    return html.toString();
  }

  String _markdownToExportHtml(String markdown) =>
      exportMarkdownBodyToHtml(markdown);

  bool _isImageAttachment(AssetAttachment attachment) {
    return attachment.mimeType.toLowerCase().startsWith('image/');
  }

  String _escapeHtml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  String _escapeHtmlAttribute(String input) =>
      _escapeHtml(input).replaceAll('\n', ' ');

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    final double kib = bytes / 1024;
    if (kib < 1024) {
      return '${kib.toStringAsFixed(kib >= 10 ? 0 : 1)} KB';
    }
    final double mib = kib / 1024;
    if (mib < 1024) {
      return '${mib.toStringAsFixed(mib >= 10 ? 0 : 1)} MB';
    }
    final double gib = mib / 1024;
    return '${gib.toStringAsFixed(gib >= 10 ? 0 : 1)} GB';
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
      final List<AssetAttachment> batch = attachments
          .skip(index)
          .take(batchSize)
          .toList();
      await Future.wait<void>(
        batch.map(
          (AssetAttachment attachment) => _exportAttachment(
            session: session,
            entry: entry,
            attachment: attachment,
            outputName:
                attachmentFileNames[attachment.id] ?? attachment.safeFilename,
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
    final String extension = p
        .extension(attachment.safeFilename)
        .replaceFirst('.', '');
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
}

/// Converts diary body markdown to portable export HTML fragment.
String exportMarkdownBodyToHtml(String markdown) {
  final List<String> lines = markdown
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n');
  final StringBuffer html = StringBuffer();
  final List<String> paragraph = <String>[];
  var inList = false;
  var inTaskList = false;
  var inCodeBlock = false;
  final StringBuffer codeBlock = StringBuffer();

  void closeList() {
    if (inTaskList) {
      html.writeln('</ul>');
      inTaskList = false;
    }
    if (inList) {
      html.writeln('</ul>');
      inList = false;
    }
  }

  void flushParagraph() {
    if (paragraph.isEmpty) {
      return;
    }
    closeList();
    html.writeln(
      '<p>${paragraph.map(_exportInlineMarkdownToHtml).join('<br>')}</p>',
    );
    paragraph.clear();
  }

  for (final String line in lines) {
    if (line.trimLeft().startsWith('```')) {
      if (inCodeBlock) {
        html.writeln(
          '<pre><code>${_exportEscapeHtml(codeBlock.toString().trimRight())}</code></pre>',
        );
        codeBlock.clear();
        inCodeBlock = false;
      } else {
        flushParagraph();
        closeList();
        inCodeBlock = true;
      }
      continue;
    }
    if (inCodeBlock) {
      codeBlock.writeln(line);
      continue;
    }

    final String trimmed = line.trim();
    if (trimmed.isEmpty) {
      flushParagraph();
      closeList();
      continue;
    }

    final Match? heading = RegExp(r'^(#{1,6})\s+(.+)$').firstMatch(trimmed);
    if (heading != null) {
      flushParagraph();
      closeList();
      final int level = (heading.group(1) ?? '#').length.clamp(1, 6).toInt();
      html.writeln(
        '<h$level>${_exportInlineMarkdownToHtml(heading.group(2) ?? '')}</h$level>',
      );
      continue;
    }

    final Match? taskItem = RegExp(
      r'^-\s*\[([ xX])\]\s*(.*)$',
    ).firstMatch(trimmed);
    if (taskItem != null) {
      flushParagraph();
      if (inList) {
        closeList();
      }
      if (!inTaskList) {
        html.writeln('<ul class="task-list">');
        inTaskList = true;
      }
      final String marker = taskItem.group(1) ?? ' ';
      final String checkedAttr = marker.toLowerCase() == 'x' ? ' checked' : '';
      html.writeln(
        '<li class="task-list-item"><label><input type="checkbox"$checkedAttr disabled> '
        '${_exportInlineMarkdownToHtml(taskItem.group(2) ?? '')}</label></li>',
      );
      continue;
    }

    final Match? bullet = RegExp(r'^[-*]\s+(.+)$').firstMatch(trimmed);
    if (bullet != null) {
      flushParagraph();
      closeList();
      if (!inList) {
        html.writeln('<ul>');
        inList = true;
      }
      html.writeln(
        '<li>${_exportInlineMarkdownToHtml(bullet.group(1) ?? '')}</li>',
      );
      continue;
    }

    closeList();
    paragraph.add(line);
  }

  if (inCodeBlock) {
    html.writeln(
      '<pre><code>${_exportEscapeHtml(codeBlock.toString().trimRight())}</code></pre>',
    );
  }
  flushParagraph();
  closeList();
  return html.toString();
}

String _exportInlineMarkdownToHtml(String input) {
  String output = _exportEscapeHtml(input);
  output = output.replaceAllMapped(
    RegExp(r'`([^`]+)`'),
    (Match match) => '<code>${match.group(1)}</code>',
  );
  output = output.replaceAllMapped(
    RegExp(r'\*\*([^*]+)\*\*'),
    (Match match) => '<strong>${match.group(1)}</strong>',
  );
  output = output.replaceAllMapped(
    RegExp(r'\*([^*]+)\*'),
    (Match match) => '<em>${match.group(1)}</em>',
  );
  output = output.replaceAllMapped(RegExp(r'\[([^\]]+)\]\(([^)]+)\)'), (
    Match match,
  ) {
    final String label = match.group(1) ?? '';
    final String href = match.group(2) ?? '';
    return '<a href="${_exportEscapeHtmlAttribute(href)}">$label</a>';
  });
  return output;
}

String _exportEscapeHtml(String input) {
  return input
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}

String _exportEscapeHtmlAttribute(String input) =>
    _exportEscapeHtml(input).replaceAll('\n', ' ');
