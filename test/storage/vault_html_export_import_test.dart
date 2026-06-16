import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quill_diary/infrastructure/database/index_database.dart';
import 'package:quill_diary/domain/diary/diary_entry.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/storage/vault_archive_io.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';

import '../helpers/vault_test_harness.dart';

void main() {
  late VaultTestHarness harness;
  late VaultArchiveIo archiveIo;

  setUp(() async {
    harness = await VaultTestHarness.create();
    archiveIo = harness.createArchiveIo();
  });

  tearDown(() async {
    await harness.dispose();
  });

  test('選取日記可合併匯出單一 HTML 並內嵌圖片', () async {
    final setup = await harness.setupRecoveryKey();
    final Directory sourceDirectory = Directory(
      p.join(harness.tempDir.path, 'html_source'),
    )..createSync(recursive: true);
    final File sourceImage = File(p.join(sourceDirectory.path, 'cover.png'))
      ..writeAsBytesSync(const <int>[1, 2, 3, 4, 5]);
    final File sourcePdf = File(p.join(sourceDirectory.path, 'note.pdf'))
      ..writeAsBytesSync(const <int>[6, 7, 8]);

    final String selectedId = generateEntryId();
    await harness.repository.saveEntry(
      setup.session,
      DiaryEntry(
        id: selectedId,
        vaultId: setup.session.vaultId,
        title: 'HTML <Export>',
        date: const DateOnly('2026-05-28'),
        createdAt: DateTime.parse('2026-05-28T08:00:00Z'),
        updatedAt: DateTime.parse('2026-05-28T09:00:00Z'),
        tags: const <String>['分享', 'HTML'],
        mood: '開心 & 安心',
        markdownBody: '# Heading\n\nHello <script>alert(1)</script>\n\n- item',
      ),
      pendingAttachments: <PendingAttachment>[
        PendingAttachment(
          sourcePath: sourceImage.path,
          mimeType: 'image/png',
          originalFilename: 'cover.png',
        ),
        PendingAttachment(
          sourcePath: sourcePdf.path,
          mimeType: 'application/pdf',
          originalFilename: 'note.pdf',
        ),
      ],
    );
    await harness.repository.saveEntry(
      setup.session,
      DiaryEntry(
        id: generateEntryId(),
        vaultId: setup.session.vaultId,
        title: 'Not selected',
        date: const DateOnly('2026-05-29'),
        createdAt: DateTime.parse('2026-05-29T08:00:00Z'),
        updatedAt: DateTime.parse('2026-05-29T08:00:00Z'),
        markdownBody: 'should not export',
      ),
    );

    final HtmlExportEstimate estimate = await archiveIo.estimateSelectedHtmlExport(
      entryIds: <String>{selectedId},
    );
    final File output = File(p.join(harness.tempDir.path, 'selected.html'));
    await archiveIo.writeSelectedHtmlExport(
      session: setup.session,
      entryIds: <String>{selectedId},
      target: output,
    );

    final String html = await output.readAsString();
    expect(estimate.entryCount, 1);
    expect(estimate.imageCount, 1);
    expect(estimate.imageBytes, 5);
    expect(estimate.estimatedHtmlBytes, greaterThan(5));
    expect(html, contains('HTML &lt;Export&gt;'));
    expect(html, contains('class="entry-date">2026-05-28'));
    expect(html, isNot(contains('建立：')));
    expect(html, isNot(contains('更新：')));
    expect(html, contains('開心 &amp; 安心'));
    expect(html, contains('<h1>Heading</h1>'));
    expect(html, contains('&lt;script&gt;alert(1)&lt;/script&gt;'));
    expect(html, contains('data:image/png;base64,AQIDBAU='));
    expect(html, isNot(contains('<h1>Quill Diary 匯出</h1>')));
    expect(html, isNot(contains('<figcaption>cover.png</figcaption>')));
    expect(html, contains('note.pdf · application/pdf'));
    expect(html, isNot(contains('Not selected')));
  });

  test('可匯入 Quill Diary 匯出的 HTML', () async {
    final setup = await harness.setupRecoveryKey();
    final Directory sourceDirectory = Directory(
      p.join(harness.tempDir.path, 'roundtrip_source'),
    )..createSync(recursive: true);
    final File sourceImage = File(p.join(sourceDirectory.path, 'cover.png'))
      ..writeAsBytesSync(const <int>[1, 2, 3, 4, 5]);

    final String selectedId = generateEntryId();
    await harness.repository.saveEntry(
      setup.session,
      DiaryEntry(
        id: selectedId,
        vaultId: setup.session.vaultId,
        title: 'HTML Roundtrip',
        date: const DateOnly('2026-05-28'),
        createdAt: DateTime.parse('2026-05-28T08:00:00Z'),
        updatedAt: DateTime.parse('2026-05-28T09:00:00Z'),
        tags: const <String>['分享', 'HTML'],
        mood: '開心 & 安心',
        markdownBody: '# Heading\n\nHello **world**\n\n- item',
      ),
      pendingAttachments: <PendingAttachment>[
        PendingAttachment(
          sourcePath: sourceImage.path,
          mimeType: 'image/png',
          originalFilename: 'cover.png',
        ),
      ],
    );

    final File exported = File(p.join(harness.tempDir.path, 'roundtrip.html'));
    await archiveIo.writeSelectedHtmlExport(
      session: setup.session,
      entryIds: <String>{selectedId},
      target: exported,
    );

    final PortableImportResult result = await archiveIo.importDocuments(
      session: setup.session,
      rootDirectory: harness.tempDir,
    );

    expect(result.importedEntries, 1);

    final entries = await harness.repository.listEntries();
    expect(entries, hasLength(2));

    final EntryIndexRecord importedRecord = entries.firstWhere(
      (EntryIndexRecord record) => record.id != selectedId,
    );
    final DiaryEntry? imported = await harness.repository.loadEntry(
      setup.session,
      importedRecord.id,
    );
    final attachments = await harness.repository.loadAttachments(importedRecord.id);

    expect(imported?.title, 'HTML Roundtrip');
    expect(imported?.date.value, '2026-05-28');
    expect(imported?.createdAt, DateTime.parse('2026-05-28T08:00:00Z').toLocal());
    expect(imported?.tags, const <String>['分享', 'HTML']);
    expect(imported?.mood, '開心 & 安心');
    expect(imported?.markdownBody, contains('# Heading'));
    expect(imported?.markdownBody, contains('Hello **world**'));
    expect(imported?.markdownBody, contains('- item'));
    expect(imported?.markdownBody, isNot(contains('![image]')));
    expect(attachments, hasLength(1));
    expect(attachments.single.mimeType, 'image/png');
  });

  test('可從 Quill Diary 匯出的單一 HTML 匯入多篇日記', () async {
    final setup = await harness.setupRecoveryKey();
    final Directory sourceDirectory = Directory(
      p.join(harness.tempDir.path, 'multi_roundtrip_source'),
    )..createSync(recursive: true);
    final File sourceImage = File(p.join(sourceDirectory.path, 'snap.png'))
      ..writeAsBytesSync(const <int>[9, 8, 7]);

    final String firstId = generateEntryId();
    final String secondId = generateEntryId();
    await harness.repository.saveEntry(
      setup.session,
      DiaryEntry(
        id: firstId,
        vaultId: setup.session.vaultId,
        title: '第一篇',
        date: const DateOnly('2026-05-17'),
        createdAt: DateTime.parse('2026-05-17T10:28:28Z'),
        updatedAt: DateTime.parse('2026-05-17T10:28:28Z'),
        markdownBody: '第一篇內容',
      ),
      pendingAttachments: <PendingAttachment>[
        PendingAttachment(
          sourcePath: sourceImage.path,
          mimeType: 'image/png',
          originalFilename: 'snap.png',
        ),
      ],
    );
    await harness.repository.saveEntry(
      setup.session,
      DiaryEntry(
        id: secondId,
        vaultId: setup.session.vaultId,
        title: '第二篇',
        date: const DateOnly('2026-04-18'),
        createdAt: DateTime.parse('2026-04-18T02:01:15Z'),
        updatedAt: DateTime.parse('2026-04-18T02:01:15Z'),
        markdownBody: '第二篇內容',
      ),
    );

    final File exported = File(p.join(harness.tempDir.path, 'multi_roundtrip.html'));
    await archiveIo.writeSelectedHtmlExport(
      session: setup.session,
      entryIds: <String>{firstId, secondId},
      target: exported,
    );

    final PortableImportResult result = await archiveIo.importDocuments(
      session: setup.session,
      rootDirectory: harness.tempDir,
    );

    expect(result.importedEntries, 2);

    final entries = await harness.repository.listEntries();
    expect(entries, hasLength(4));

    final List<DiaryEntry> imported = <DiaryEntry>[];
    for (final EntryIndexRecord record in entries) {
      if (record.id == firstId || record.id == secondId) {
        continue;
      }
      final DiaryEntry? entry = await harness.repository.loadEntry(
        setup.session,
        record.id,
      );
      if (entry != null) {
        imported.add(entry);
      }
    }

    expect(
      imported.map((DiaryEntry entry) => entry.title).toList(),
      containsAll(<String>['第一篇', '第二篇']),
    );
    expect(
      imported.map((DiaryEntry entry) => entry.date.value).toList(),
      containsAll(<String>['2026-05-17', '2026-04-18']),
    );
    expect(
      imported.map((DiaryEntry entry) => entry.markdownBody).toList(),
      containsAll(<String>['第一篇內容', '第二篇內容']),
    );

    final DiaryEntry firstImported =
        imported.firstWhere((DiaryEntry entry) => entry.title == '第一篇');
    final attachments = await harness.repository.loadAttachments(firstImported.id);
    expect(attachments, hasLength(1));
    expect(attachments.single.mimeType, 'image/png');
  });

  test('HTML 匯出沒有可用日記時回報錯誤', () async {
    final setup = await harness.setupRecoveryKey();
    final File output = File(p.join(harness.tempDir.path, 'empty.html'));

    expect(
      () => archiveIo.writeSelectedHtmlExport(
        session: setup.session,
        entryIds: <String>{'jrn_NOT_FOUND'},
        target: output,
      ),
      throwsA(
        isA<StateError>().having(
          (StateError error) => error.message,
          'message',
          '沒有可匯出的日記。',
        ),
      ),
    );
  });
}
