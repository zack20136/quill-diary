import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quill_diary/domain/diary/diary_entry.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/storage/vault_archive_io.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';

import '../helpers/vault/vault_test_harness.dart';

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

  test('writeBackupZip 會排除衍生的本機索引檔', () async {
    final RecoverySetupResult setup = await harness.repository
        .setupRecoveryKey();
    await harness.repository.saveEntry(
      setup.session,
      DiaryEntry(
        id: generateEntryId(),
        vaultId: setup.session.vaultId,
        title: 'Index Exclusion',
        date: const DateOnly('2026-06-01'),
        createdAt: DateTime.parse('2026-06-01T08:00:00Z'),
        updatedAt: DateTime.parse('2026-06-01T08:00:00Z'),
        markdownBody: 'backup should not include derived index',
      ),
    );
    final Directory vaultRoot = await harness.pathStrategy.vaultRootDirectory();
    File(p.join(vaultRoot.path, 'index', 'derived.sqlite'))
      ..createSync(recursive: true)
      ..writeAsBytesSync(const <int>[9, 9, 9]);

    final File backupFile = File(p.join(harness.tempDir.path, 'no_index.zip'));
    await archiveIo.writeBackupZip(backupFile);

    final Archive archive = ZipDecoder().decodeBytes(
      await backupFile.readAsBytes(),
    );
    final List<String> names = archive.files
        .map((ArchiveFile file) => file.name)
        .toList();

    expect(names.any((String name) => name.startsWith('index/')), isFalse);
    expect(names, contains('recovery.json'));
  });

  test('inspectBackup 會拒絕不安全的壓縮檔路徑', () async {
    final File backupFile = File(p.join(harness.tempDir.path, 'unsafe.zip'));
    final Archive archive = Archive()
      ..addFile(ArchiveFile.string('recovery.json', '{}'))
      ..addFile(ArchiveFile('../evil.md.enc', 1, const <int>[1]));
    await backupFile.writeAsBytes(ZipEncoder().encode(archive));

    final report = await archiveIo.inspectBackup(backupFile);

    expect(report.ok, isFalse);
    expect(report.message, contains('不安全路徑'));
  });
}
