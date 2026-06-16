import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quill_diary/infrastructure/storage/shared/archive_extract.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('archive_extract_test_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'openZipArchive lists entries without reading all file bytes upfront',
    () async {
      final File zipFile = File(p.join(tempDir.path, 'sample.zip'));
      final Archive archive = Archive()
        ..addFile(
          ArchiveFile.string('recovery.json', '{"vault_id":"vlt_test"}'),
        )
        ..addFile(ArchiveFile.string('entries/a.md.enc', 'encrypted'));
      await zipFile.writeAsBytes(ZipEncoder().encode(archive));

      final OpenedZipArchive opened = await openZipArchive(zipFile);
      try {
        expect(
          opened.archive.files.map((ArchiveFile file) => file.name),
          containsAll(<String>['recovery.json', 'entries/a.md.enc']),
        );
        expect(
          readZipEntry(opened.archive, pathSuffix: 'recovery.json'),
          isNotNull,
        );
      } finally {
        await opened.close();
      }
    },
  );

  test('extractArchiveToDirectory streams files to disk', () async {
    final File zipFile = File(p.join(tempDir.path, 'extract.zip'));
    final Archive archive = Archive()
      ..addFile(ArchiveFile.string('nested/recovery.json', 'payload'));
    await zipFile.writeAsBytes(ZipEncoder().encode(archive));

    final Directory target = Directory(p.join(tempDir.path, 'out'));
    final OpenedZipArchive opened = await openZipArchive(zipFile);
    try {
      await extractArchiveToDirectory(zip: opened, targetDirectory: target);
    } finally {
      await opened.close();
    }

    expect(
      File(p.join(target.path, 'nested', 'recovery.json')).readAsStringSync(),
      'payload',
    );
  });
}
