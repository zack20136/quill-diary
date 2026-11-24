import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:quill_diary/domain/attachment/asset_attachment.dart';
import 'package:quill_diary/domain/diary/diary_entry.dart';
import 'package:quill_diary/domain/diary/diary_entry_summary.dart';
import 'package:quill_diary/domain/people/person.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/crypto/crypto_service.dart';
import 'package:quill_diary/infrastructure/database/entry_index_sorting.dart';
import 'package:quill_diary/infrastructure/markdown/front_matter_codec.dart';
import 'package:quill_diary/infrastructure/storage/portable/html_export_person_anonymizer.dart';
import 'package:quill_diary/infrastructure/storage/portable/portable_date_text.dart';
import 'package:quill_diary/infrastructure/storage/shared/media_type_utils.dart';
import 'package:quill_diary/infrastructure/storage/shared/vault_file_ops.dart';
import 'package:quill_diary/infrastructure/storage/vault_path_strategy.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';

class HtmlExportOptions {
  const HtmlExportOptions({
    this.includeImages = true,
    bool externalAssets = false,
    this.hidePersonNames = false,
    this.useEnglishPersonLabels = false,
    this.documentTitle = '',
    this.untitledEntryTitle = '',
    this.unembeddedAttachmentsHeading = '',
    this.htmlLang = '',
  }) : externalAssets = includeImages && externalAssets;

  final bool includeImages;
  final bool externalAssets;
  final bool hidePersonNames;
  final bool useEnglishPersonLabels;
  final String documentTitle;
  final String untitledEntryTitle;
  final String unembeddedAttachmentsHeading;
  final String htmlLang;
}

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

  int get imageCount => entries.fold<int>(
    0,
    (int sum, HtmlExportEntrySummary e) => sum + e.imageCount,
  );

  int get imageBytes => entries.fold<int>(
    0,
    (int sum, HtmlExportEntrySummary e) => sum + e.imageBytes,
  );

  /// 依是否內嵌圖片估算實際匯出檔大小。
  int estimatedExportBytes({
    required bool includeImages,
    bool externalAssets = false,
  }) {
    final int textBytes = entries.fold<int>(
      0,
      (int sum, HtmlExportEntrySummary e) => sum + e.textBytes,
    );
    if (!includeImages) {
      return textBytes;
    }
    return textBytes +
        (externalAssets ? imageBytes : ((imageBytes * 4 + 2) ~/ 3));
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
/// 這些格式刻意與加密完整日記庫備份 zip 分開，
/// 讓使用者可檢視並以散檔重新匯入。
class PortableExportIo {
  PortableExportIo({
    required this._pathStrategy,
    required this._repository,
    required this._frontMatterCodec,
  });

  final VaultPathStrategy _pathStrategy;
  final VaultRepository _repository;
  final FrontMatterCodec _frontMatterCodec;

  Future<Directory> exportMarkdown({
    required UnlockedVaultSession session,
    required Directory parentDirectory,
    Set<EntryId>? entryIds,
    MarkdownExportOptions options = const MarkdownExportOptions(),
  }) async {
    final List<DiaryEntrySummary> allEntries = await _repository.listEntries();
    final Set<EntryId>? selected = entryIds
        ?.map((EntryId id) => id.trim())
        .where((EntryId id) => id.isNotEmpty)
        .toSet();
    final List<DiaryEntrySummary> entries = selected == null
        ? allEntries
        : allEntries
              .where((DiaryEntrySummary record) => selected.contains(record.id))
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

    for (final DiaryEntrySummary record in entries) {
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

      await File(p.join(entryDirectory.path, 'index.md'))
          .writeAsString(exportMarkdown, flush: true);

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
      await deleteWorkingDirectory(tempRoot);
    }
  }

  Future<HtmlExportEstimate> estimateSelectedHtmlExport({
    required Set<EntryId> entryIds,
  }) async {
    final summaries = <HtmlExportEntrySummary>[];
    for (final record in await _selectedHtmlEntries(entryIds)) {
      final title = record.title;
      final textBytes =
          utf8.encode('${title ?? ''}\n${record.tags.join(',')}\n').length +
          record.charCount;
      final attachments = await _repository.loadAttachments(record.id);

      var entryImageCount = 0;
      var entryImageBytes = 0;
      for (final AssetAttachment attachment in attachments) {
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
    final List<DiaryEntrySummary> entries = await _repository.listEntries();
    final List<List<AssetAttachment>> attachmentLists = await Future.wait(
      entries.map(
        (DiaryEntrySummary record) => _repository.loadAttachments(record.id),
      ),
    );

    final List<MarkdownExportEntrySummary> summaries =
        <MarkdownExportEntrySummary>[];
    for (var index = 0; index < entries.length; index++) {
      final DiaryEntrySummary record = entries[index];
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
    await _writeHtml(
      session: session,
      entryIds: entryIds,
      target: target,
      options: options,
    );
    return target;
  }

  Future<Directory> writeSelectedHtmlBundle({
    required UnlockedVaultSession session,
    required Set<EntryId> entryIds,
    required Directory target,
    required HtmlExportOptions options,
  }) async {
    await _writeHtml(
      session: session,
      entryIds: entryIds,
      target: File(p.join(target.path, 'diary.html')),
      assets: Directory(p.join(target.path, 'assets')),
      options: options,
    );
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

  Future<List<DiaryEntrySummary>> _selectedHtmlEntries(
    Set<EntryId> entryIds,
  ) async {
    final selected = entryIds.map((id) => id.trim()).toSet();
    return (await _repository.listEntries())
        .where((record) => selected.contains(record.id))
        .toList()
      ..sort(compareEntriesNewestFirst);
  }

  Future<void> _writeHtml({
    required UnlockedVaultSession session,
    required Set<EntryId> entryIds,
    required File target,
    required HtmlExportOptions options,
    Directory? assets,
  }) => _repository.runVaultMutation(() async {
    final work = await createWorkingDirectory(_pathStrategy, 'html_assets');
    try {
      await target.parent.create(recursive: true);
      final sink = target.openWrite();
      sink.done.ignore();
      try {
        await _writeHtmlDocument(
          sink: sink,
          session: session,
          entryIds: entryIds,
          options: options,
          work: work,
          assets: assets,
        );
        await sink.flush();
      } finally {
        await sink.close();
      }
    } finally {
      await deleteWorkingDirectory(work);
    }
  });

  Future<void> _writeHtmlDocument({
    required IOSink sink,
    required UnlockedVaultSession session,
    required Set<EntryId> entryIds,
    required HtmlExportOptions options,
    required Directory work,
    Directory? assets,
  }) async {
    HtmlExportPersonAnonymizer? anonymizer;
    if (options.hidePersonNames) {
      final List<Person> people = await _repository.listPeople(session);
      anonymizer = HtmlExportPersonAnonymizer(
        people: people,
        useEnglishLabels: options.useEnglishPersonLabels,
      );
    }

    sink.write(_htmlHeader(options));
    var imageOrdinal = 1;
    var fileOrdinal = 1;
    final crypto = LocalCryptoService();
    final context = vaultDecryptionContext(session);
    for (final record in await _selectedHtmlEntries(entryIds)) {
      final entry = await _repository.loadEntry(session, record.id);
      if (entry == null) throw StateError('找不到要匯出的日記。');
      final String? rawTitle =
          entry.normalizedTitle ??
          (options.untitledEntryTitle.trim().isEmpty
              ? null
              : options.untitledEntryTitle.trim());
      final String? title = rawTitle == null
          ? null
          : anonymizer?.anonymizePlainText(rawTitle) ?? rawTitle;
      final List<String> tags = entry.tags
          .map((String tag) => anonymizer?.anonymizePlainText(tag) ?? tag)
          .toList(growable: false);
      final String markdownBody =
          anonymizer?.anonymizeMarkdownBody(entry.markdownBody) ??
          entry.markdownBody;

      sink.writeln('<article class="entry">');
      sink.writeln('<header class="entry-header">');
      sink.writeln(
        '<p class="entry-date">${_escapeHtml(formatQuillDiaryExportEntryDateTime(entry))}</p>',
      );
      if (title != null && title.isNotEmpty) {
        sink.writeln('<h2>${_escapeHtml(title)}</h2>');
      }
      if (tags.isNotEmpty) {
        sink.writeln('<ul class="tags">');
        for (final String tag in tags) {
          sink.writeln('<li>${_escapeHtml(tag)}</li>');
        }
        sink.writeln('</ul>');
      }
      sink.writeln('</header>');
      sink.writeln('<section class="entry-body">');
      sink.writeln(exportMarkdownBodyToHtml(markdownBody));
      sink.writeln('</section>');
      if (options.includeImages) {
        final attachments = await _repository.loadAttachments(entry.id);
        final images = attachments.where(_isImageAttachment);
        if (images.isNotEmpty) {
          sink.writeln('<section class="embedded-images">');
          for (final attachment in images) {
            final label =
                'image-${imageOrdinal++}.${extensionFromMimeType(attachment.mimeType)}';
            final source = File(
              await _pathStrategy.attachmentAbsolutePath(
                date: entry.date,
                attachment: attachment,
              ),
            );
            final fixed = await source.copy(p.join(work.path, 'source.enc'));
            try {
              final bytes = crypto.readAuthenticatedFile(
                fixed,
                context,
                documentId: attachment.id,
                contentType: attachment.mimeType,
              );
              final alt = _escapeHtmlAttribute(label);
              sink.write('<figure><img src="');
              if (assets == null) {
                final mime = _escapeHtmlAttribute(attachment.mimeType);
                sink.write('data:$mime;base64,');
                await sink.addStream(
                  base64.encoder.bind(bytes).transform(utf8.encoder),
                );
              } else {
                await assets.create(recursive: true);
                await writeByteStreamToFile(
                  bytes,
                  File(p.join(assets.path, label)),
                );
                sink.write('assets/$label');
              }
              sink.writeln('" alt="$alt"></figure>');
            } finally {
              await deleteFileIfExists(fixed.path);
            }
          }
          sink.writeln('</section>');
        }
        final files = attachments.where(
          (attachment) => !_isImageAttachment(attachment),
        );
        if (files.isNotEmpty) {
          sink.writeln('<section class="attachment-list">');
          final heading = options.unembeddedAttachmentsHeading.trim();
          if (heading.isNotEmpty) {
            sink.writeln('<h3>${_escapeHtml(heading)}</h3>');
          }
          sink.writeln('<ul>');
          for (final attachment in files) {
            final label =
                'file-${fileOrdinal++}.${extensionFromMimeType(attachment.mimeType)}';
            sink.writeln(
              '<li>$label · ${_escapeHtml(attachment.mimeType)} · ${_formatBytes(attachment.byteSize)}</li>',
            );
          }
          sink.writeln('</ul></section>');
        }
      }
      sink.writeln('</article>');
      await sink.flush();
    }
    sink.writeln('</main></body></html>');
  }

  String _htmlHeader(HtmlExportOptions options) {
    final String htmlLang = _nonBlankOr(options.htmlLang, 'zh-Hant');
    final String documentTitle = _nonBlankOr(
      options.documentTitle,
      'Quill Diary',
    );
    return '''
<!doctype html>
<html lang="${_escapeHtmlAttribute(htmlLang)}">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${_escapeHtml(documentTitle)}</title>
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
''';
  }

  bool _isImageAttachment(AssetAttachment attachment) {
    return attachment.mimeType.toLowerCase().startsWith('image/');
  }

  String _nonBlankOr(String value, String fallback) {
    final String trimmed = value.trim();
    return trimmed.isEmpty ? fallback : trimmed;
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

    await File(p.join(entryDirectory.path, outputName))
        .writeAsBytes(bytes, flush: true);
  }
}

/// 將日記正文 Markdown 轉成可攜式匯出用的 HTML 片段。
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

    final Match? taskItem = RegExp(r'^-\s*\[([ xX])\]\s*(.*)$')
        .firstMatch(trimmed);
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
