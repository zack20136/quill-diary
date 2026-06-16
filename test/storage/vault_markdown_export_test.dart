import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quill_diary/domain/diary/diary_entry.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';

import '../helpers/vault_archive_io_test_harness.dart';

void main() {
  late VaultArchiveIoTestHarness harness;

  setUp(() async {
    harness = await VaultArchiveIoTestHarness.create();
  });

  tearDown(() async {
    await harness.dispose();
  });

  test('Markdown 匯出會把 index.md 與附件放在同一個資料夾', () async {
    final setup = await harness.harness.setupRecoveryKey();
    final Directory sourceDirectory = Directory(
      p.join(harness.tempDir.path, 'source'),
    )..createSync(recursive: true);
    final File sourceAttachment = File(p.join(sourceDirectory.path, 'photo.jpg'))
      ..writeAsBytesSync(const <int>[1, 2, 3, 4]);

    await harness.harness.repository.saveEntry(
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

    final Directory exportParent = Directory(
      p.join(harness.tempDir.path, 'exports'),
    )..createSync(recursive: true);
    final Directory output = await harness.archiveIo.exportMarkdown(
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

  test('Markdown 匯出 zip 會保留 index.md 與附件路徑', () async {
    final setup = await harness.harness.setupRecoveryKey();
    final Directory sourceDirectory = Directory(
      p.join(harness.tempDir.path, 'zip_source'),
    )..createSync(recursive: true);
    final File sourceAttachment = File(p.join(sourceDirectory.path, 'receipt.pdf'))
      ..writeAsBytesSync(const <int>[7, 7, 7]);

    await harness.harness.repository.saveEntry(
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
    await harness.archiveIo.writeMarkdownZip(
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
}
