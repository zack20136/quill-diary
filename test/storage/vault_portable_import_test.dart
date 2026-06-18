import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quill_diary/domain/diary/diary_entry.dart';
import 'package:quill_diary/infrastructure/storage/vault_archive_io.dart';
import 'package:quill_diary/infrastructure/storage/vault_transfer_service.dart';

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

  test('imports markdown exports with attachments', () async {
    final setup = await harness.repository.setupRecoveryKey();
    final Directory importRoot = Directory(
      p.join(harness.tempDir.path, 'import_md'),
    )..createSync(recursive: true);
    final Directory entryDirectory = Directory(
      p.join(importRoot.path, '2026-05-20', 'Trip Note'),
    )..createSync(recursive: true);

    File(
      p.join(entryDirectory.path, 'image.png'),
    ).writeAsBytesSync(const <int>[9, 8, 7]);
    File(p.join(entryDirectory.path, 'index.md')).writeAsStringSync('''---
title: "Trip Note"
date: "2026-05-20"
attachments:
  - "./image.png"
---

# Trip Note

Imported from markdown.
''');

    final result = await archiveIo.importDocuments(
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
    final attachments = await harness.repository.loadAttachments(
      entries.single.id,
    );

    expect(imported?.title, 'Trip Note');
    expect(imported?.date.value, '2026-05-20');
    expect(imported?.markdownBody, contains('Imported from markdown.'));
    expect(attachments, hasLength(1));
    expect(attachments.single.safeFilename, 'image.png');
  });

  test('imports markdown exports from zip archives', () async {
    final setup = await harness.repository.setupRecoveryKey();
    final File zipFile = File(
      p.join(harness.tempDir.path, 'portable_import.zip'),
    );
    final Archive archive = Archive()
      ..addFile(
        ArchiveFile.string('2026-05-23/Zip Import/index.md', '''---
title: "Zip Import"
date: "2026-05-23"
attachments:
  - "./photo.png"
---

# Zip Import

Imported from zip.
'''),
      )
      ..addFile(
        ArchiveFile('2026-05-23/Zip Import/photo.png', 3, const <int>[6, 5, 4]),
      );

    await zipFile.writeAsBytes(ZipEncoder().encode(archive));

    final result = await archiveIo.importDocumentsFromZip(
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
    final attachments = await harness.repository.loadAttachments(
      entries.single.id,
    );

    expect(imported?.title, 'Zip Import');
    expect(imported?.date.value, '2026-05-23');
    expect(imported?.markdownBody, contains('Imported from zip.'));
    expect(attachments, hasLength(1));
    expect(attachments.single.safeFilename, 'photo.png');
  });

  test('skips html files that are not Quill Diary exports', () async {
    final setup = await harness.repository.setupRecoveryKey();
    final Directory importRoot = Directory(
      p.join(harness.tempDir.path, 'import_ed_html_skip'),
    )..createSync(recursive: true);

    File(p.join(importRoot.path, 'easy-diary.html')).writeAsStringSync('''
<html><body>
  <div class='title-right'>Easy Diary Entry</div>
  <div class='contents'><p>Hello</p></div>
</body></html>
''');

    final result = await archiveIo.importDocuments(
      session: setup.session,
      rootDirectory: importRoot,
    );

    expect(result.importedEntries, 0);
    expect(result.skippedFiles, 1);
    expect(await harness.repository.listEntries(), isEmpty);
  });

  test(
    'uniqueImportedDocumentFileName keeps extensions and avoids collisions',
    () {
      expect(
        VaultTransferService.uniqueImportedDocumentFileName(
          sourceName: '2026-05-20.md',
          extension: '.md',
          index: 0,
        ),
        '0001_2026-05-20.md',
      );
      expect(
        VaultTransferService.uniqueImportedDocumentFileName(
          sourceName: '2026-05-20.md',
          extension: '.md',
          index: 1,
        ),
        '0002_2026-05-20.md',
      );
      expect(
        VaultTransferService.uniqueImportedDocumentFileName(
          sourceName: '',
          extension: '.html',
          index: 2,
        ),
        '0003_imported_entry2.html',
      );
    },
  );
}
