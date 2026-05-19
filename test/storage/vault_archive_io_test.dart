import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quill_lock_diary/domain/diary/diary_entry.dart';
import 'package:quill_lock_diary/domain/shared/value_objects.dart';
import 'package:quill_lock_diary/infrastructure/database/index_database.dart';
import 'package:quill_lock_diary/infrastructure/database/index_database_manager.dart';
import 'package:quill_lock_diary/infrastructure/markdown/front_matter_codec.dart';
import 'package:quill_lock_diary/infrastructure/storage/vault_archive_io.dart';
import 'package:quill_lock_diary/infrastructure/storage/vault_repository.dart';

import '../helpers/vault_test_harness.dart';

void main() {
  late VaultTestHarness harness;
  late VaultArchiveIo archiveIo;

  setUp(() async {
    harness = await VaultTestHarness.create();
    archiveIo = VaultArchiveIo(
      pathStrategy: harness.pathStrategy,
      repository: harness.repository,
      frontMatterCodec: const FrontMatterCodec(),
      indexDatabaseManager: IndexDatabaseManager(harness.pathStrategy),
    );
  });

  tearDown(() async {
    await harness.dispose();
  });

  test('Markdown 匯出會把 index.md 與附件放在同一個資料夾', () async {
    final RecoverySetupResult setup = await harness.repository.setupRecoveryKey();
    final Directory sourceDirectory = Directory(p.join(harness.tempDir.path, 'source'))
      ..createSync(recursive: true);
    final File sourceAttachment = File(p.join(sourceDirectory.path, 'photo.jpg'))
      ..writeAsBytesSync(const <int>[1, 2, 3, 4]);

    await harness.repository.saveEntry(
      setup.session,
      DiaryEntry(
        id: generateEntryId(),
        vaultId: setup.session.vaultId,
        title: 'Morning Note',
        date: const DateOnly('2026-05-19'),
        createdAt: DateTime.parse('2026-05-19T08:00:00Z'),
        updatedAt: DateTime.parse('2026-05-19T08:00:00Z'),
        markdownBody: '# Morning Note\n\nHello export',
      ),
      pendingAttachments: <PendingAttachment>[
        PendingAttachment(
          sourcePath: sourceAttachment.path,
          mimeType: 'image/jpeg',
          originalFilename: 'photo.jpg',
        ),
      ],
    );

    final Directory exportParent = Directory(p.join(harness.tempDir.path, 'exports'))
      ..createSync(recursive: true);
    final Directory output = await archiveIo.exportMarkdown(
      session: setup.session,
      parentDirectory: exportParent,
    );

    final File exportedIndex = File(
      p.join(output.path, '2026-05-19', 'Morning Note', 'index.md'),
    );
    final File exportedAttachment = File(
      p.join(output.path, '2026-05-19', 'Morning Note', 'photo.jpg'),
    );

    expect(exportedIndex.existsSync(), isTrue);
    expect(exportedAttachment.existsSync(), isTrue);
    expect(await exportedIndex.readAsString(), contains('  - "./photo.jpg"'));
    expect(await exportedAttachment.readAsBytes(), const <int>[1, 2, 3, 4]);
  });

  test('可匯入單篇 Markdown 與同資料夾附件', () async {
    final RecoverySetupResult setup = await harness.repository.setupRecoveryKey();
    final Directory importRoot = Directory(p.join(harness.tempDir.path, 'import_md'))
      ..createSync(recursive: true);
    final Directory entryDirectory = Directory(
      p.join(importRoot.path, '2026-05-20', 'Trip Note'),
    )..createSync(recursive: true);

    File(p.join(entryDirectory.path, 'image.png')).writeAsBytesSync(const <int>[9, 8, 7]);
    File(p.join(entryDirectory.path, 'index.md')).writeAsStringSync('''---
title: "Trip Note"
date: "2026-05-20"
attachments:
  - "./image.png"
---

# Trip Note

Imported from markdown.
''');

    final PortableImportResult result = await archiveIo.importDocuments(
      session: setup.session,
      rootDirectory: importRoot,
    );

    expect(result.importedEntries, 1);

    final entries = await harness.repository.listEntries();
    expect(entries, hasLength(1));

    final DiaryEntry? imported = await harness.repository.loadEntry(
      setup.session,
      entries.single.id,
    );
    final attachments = await harness.repository.loadAttachments(entries.single.id);

    expect(imported?.title, 'Trip Note');
    expect(imported?.date.value, '2026-05-20');
    expect(imported?.markdownBody, contains('Imported from markdown.'));
    expect(attachments, hasLength(1));
    expect(attachments.single.safeFilename, 'image.png');
  });

  test('可匯入 Easy Diary HTML 與本地圖片', () async {
    final RecoverySetupResult setup = await harness.repository.setupRecoveryKey();
    final Directory importRoot = Directory(p.join(harness.tempDir.path, 'import_html'))
      ..createSync(recursive: true);

    File(p.join(importRoot.path, 'cover.jpg')).writeAsBytesSync(const <int>[5, 4, 3]);
    File(p.join(importRoot.path, 'easy-diary.html')).writeAsStringSync('''
<html>
  <head>
    <title>Easy Diary Entry</title>
  </head>
  <body>
    <h1>Easy Diary Entry</h1>
    <p>2026-05-21</p>
    <p>Hello <strong>HTML</strong> import.</p>
    <img src="cover.jpg" alt="cover">
  </body>
</html>
''');

    final PortableImportResult result = await archiveIo.importDocuments(
      session: setup.session,
      rootDirectory: importRoot,
    );

    expect(result.importedEntries, 1);

    final entries = await harness.repository.listEntries();
    expect(entries, hasLength(1));

    final DiaryEntry? imported = await harness.repository.loadEntry(
      setup.session,
      entries.single.id,
    );
    final attachments = await harness.repository.loadAttachments(entries.single.id);

    expect(imported?.title, 'Easy Diary Entry');
    expect(imported?.date.value, '2026-05-21');
    expect(imported?.markdownBody, contains('Hello HTML import.'));
    expect(imported?.markdownBody, isNot(contains('![image]')));
    expect(imported?.markdownBody, isNot(contains('cover.jpg')));
    expect(attachments, hasLength(1));
    expect(attachments.single.safeFilename, 'cover.jpg');
  });

  test('可匯入 Easy Diary 匯出的單行 HTML 版面', () async {
    final RecoverySetupResult setup = await harness.repository.setupRecoveryKey();
    final Directory importRoot = Directory(p.join(harness.tempDir.path, 'import_easy_diary'))
      ..createSync(recursive: true);

    File(p.join(importRoot.path, '20260519163405.html')).writeAsStringSync(
      "<!DOCTYPE html><html><head><title>Insert title here</title></head><body>"
      "<div class='title-right'>週二心情</div>"
      "<div class='datetime'>2026-05-19 16:34:05</div>"
      "<motion class='contents'>今天天氣很好。</div>"
      "<div class='photo-container'><img src='data:image/png;base64, iVBORw0KGgo=' alt='mood'></div>"
      '</body></html>',
    );

    final PortableImportResult result = await archiveIo.importDocuments(
      session: setup.session,
      rootDirectory: importRoot,
    );

    expect(result.importedEntries, 1);

    final entries = await harness.repository.listEntries();
    final DiaryEntry? imported = await harness.repository.loadEntry(
      setup.session,
      entries.single.id,
    );

    expect(imported?.title, '週二心情');
    expect(imported?.date.value, '2026-05-19');
    expect(imported?.createdAt.hour, 16);
    expect(imported?.createdAt.minute, 34);
    expect(imported?.createdAt.second, 5);
    expect(imported?.markdownBody, contains('今天天氣很好。'));
    expect(imported?.markdownBody, isNot(contains('週二心情')));
    expect(imported?.markdownBody, isNot(contains('![image]')));
    expect(imported?.markdownBody, isNot(contains('embedded_')));
    expect((await harness.repository.loadAttachments(entries.single.id)), isNotEmpty);
  });

  test('可從單一 Easy Diary HTML 匯入多篇日記', () async {
    final RecoverySetupResult setup = await harness.repository.setupRecoveryKey();
    final Directory importRoot = Directory(p.join(harness.tempDir.path, 'import_multi_html'))
      ..createSync(recursive: true);

    File(p.join(importRoot.path, 'multi.html')).writeAsStringSync(
      '<html><body>'
      "<div class='title-right'>第一篇</div>"
      "<motion class='datetime'>2026年5月17日 星期日 上午10:28:28 [台北標準時間]</div>"
      "<div class='contents'>第一篇內容</div>"
      "<div class='photo-container'><img src='data:image/png;base64,iVBORw0KGgo=' alt='snap'></div>"
      '<hr>'
      "<div class='title-right'>第二篇</div>"
      "<div class='datetime'>2026年4月18日 星期六 上午2:01:15 [台北標準時間]</div>"
      "<div class='contents'>第二篇內容</div>"
      '</body></html>',
    );

    final PortableImportResult result = await archiveIo.importDocuments(
      session: setup.session,
      rootDirectory: importRoot,
    );

    expect(result.importedEntries, 2);

    final entries = await harness.repository.listEntries();
    expect(entries, hasLength(2));

    final List<DiaryEntry> loaded = <DiaryEntry>[];
    for (final EntryIndexRecord record in entries) {
      final DiaryEntry? entry = await harness.repository.loadEntry(setup.session, record.id);
      if (entry != null) {
        loaded.add(entry);
      }
    }

    expect(loaded.map((DiaryEntry entry) => entry.title).toList(), containsAll(<String>['第一篇', '第二篇']));
    expect(loaded.map((DiaryEntry entry) => entry.date.value).toList(),
        containsAll(<String>['2026-05-17', '2026-04-18']));
    for (final DiaryEntry entry in loaded) {
      expect(entry.markdownBody, isNot(contains('![image]')));
      expect(entry.markdownBody, isNot(contains('embedded_')));
    }

    final DiaryEntry firstLoaded = loaded.firstWhere((DiaryEntry entry) => entry.title == '第一篇');
    expect(firstLoaded.createdAt.hour, 10);
    expect(firstLoaded.createdAt.minute, 28);
    expect(firstLoaded.createdAt.second, 28);

    final DiaryEntry secondLoaded = loaded.firstWhere((DiaryEntry entry) => entry.title == '第二篇');
    expect(secondLoaded.createdAt.hour, 2);
    expect(secondLoaded.createdAt.minute, 1);
    expect(secondLoaded.createdAt.second, 15);

    final EntryIndexRecord firstEntry = entries.firstWhere(
      (EntryIndexRecord record) => loaded.any(
        (DiaryEntry entry) => entry.id == record.id && entry.title == '第一篇',
      ),
    );
    final attachments = await harness.repository.loadAttachments(firstEntry.id);
    expect(attachments, hasLength(1));
    expect(attachments.single.safeFilename, 'embedded_1.png');
  });

  test('Markdown 匯出 zip 會保留 index.md 與附件路徑', () async {
    final RecoverySetupResult setup = await harness.repository.setupRecoveryKey();
    final Directory sourceDirectory = Directory(p.join(harness.tempDir.path, 'zip_source'))
      ..createSync(recursive: true);
    final File sourceAttachment = File(p.join(sourceDirectory.path, 'receipt.pdf'))
      ..writeAsBytesSync(const <int>[7, 7, 7]);

    await harness.repository.saveEntry(
      setup.session,
      DiaryEntry(
        id: generateEntryId(),
        vaultId: setup.session.vaultId,
        title: 'Zip Export',
        date: const DateOnly('2026-05-22'),
        createdAt: DateTime.parse('2026-05-22T09:00:00Z'),
        updatedAt: DateTime.parse('2026-05-22T09:00:00Z'),
        markdownBody: 'Zip body',
      ),
      pendingAttachments: <PendingAttachment>[
        PendingAttachment(
          sourcePath: sourceAttachment.path,
          mimeType: 'application/pdf',
          originalFilename: 'receipt.pdf',
        ),
      ],
    );

    final File zipFile = File(p.join(harness.tempDir.path, 'portable_export.zip'));
    await archiveIo.writePortableExportZip(
      session: setup.session,
      target: zipFile,
    );

    final Archive archive = ZipDecoder().decodeBytes(await zipFile.readAsBytes());
    final List<String> names = archive.files.map((ArchiveFile file) => file.name).toList();

    expect(
      names,
      contains(
        allOf(contains('2026-05-22'), contains('Zip Export'), contains('index.md')),
      ),
    );
    expect(
      names,
      contains(
        allOf(contains('2026-05-22'), contains('Zip Export'), contains('receipt.pdf')),
      ),
    );
  });

  test('可從 zip 匯入 Markdown 與附件', () async {
    final RecoverySetupResult setup = await harness.repository.setupRecoveryKey();
    final File zipFile = File(p.join(harness.tempDir.path, 'portable_import.zip'));
    final Archive archive = Archive()
      ..addFile(
        ArchiveFile.string(
          'diary_export_123/2026-05-23/Zip Import/index.md',
          '''---
title: "Zip Import"
date: "2026-05-23"
attachments:
  - "./photo.png"
---

# Zip Import

Imported from zip.
''',
        ),
      )
      ..addFile(
        ArchiveFile(
          'diary_export_123/2026-05-23/Zip Import/photo.png',
          3,
          const <int>[6, 5, 4],
        ),
      );

    await zipFile.writeAsBytes(ZipEncoder().encode(archive)!);

    final PortableImportResult result = await archiveIo.importDocumentsFromZip(
      session: setup.session,
      zipFile: zipFile,
    );

    expect(result.importedEntries, 1);

    final entries = await harness.repository.listEntries();
    expect(entries, hasLength(1));

    final DiaryEntry? imported = await harness.repository.loadEntry(
      setup.session,
      entries.single.id,
    );
    final attachments = await harness.repository.loadAttachments(entries.single.id);

    expect(imported?.title, 'Zip Import');
    expect(imported?.date.value, '2026-05-23');
    expect(imported?.markdownBody, contains('Imported from zip.'));
    expect(attachments, hasLength(1));
    expect(attachments.single.safeFilename, 'photo.png');
  });
}
