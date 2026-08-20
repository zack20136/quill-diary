import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quill_diary/domain/diary/diary_entry.dart';
import 'package:quill_diary/domain/people/person.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/storage/vault_archive_io.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';

import '../../helpers/vault/vault_test_harness.dart';

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

  test('writeBackupZip 會排除索引與隔離區檔案但保留正式資料', () async {
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
    await harness.repository.createPerson(
      setup.session,
      PersonDraft(name: '備份人物'),
    );
    final Directory vaultRoot = await harness.pathStrategy.vaultRootDirectory();
    File(p.join(vaultRoot.path, 'index', 'derived.sqlite'))
      ..createSync(recursive: true)
      ..writeAsBytesSync(const <int>[9, 9, 9]);
    File(p.join(vaultRoot.path, 'quarantine', 'damaged.bin'))
      ..createSync(recursive: true)
      ..writeAsBytesSync(const <int>[8, 8, 8]);
    File(p.join(vaultRoot.path, 'assets', '2026', '06', 'photo.png.enc'))
      ..createSync(recursive: true)
      ..writeAsBytesSync(const <int>[7, 7, 7]);

    final File backupFile = File(p.join(harness.tempDir.path, 'no_index.zip'));
    await archiveIo.writeBackupZip(backupFile);

    final Archive archive = ZipDecoder().decodeBytes(
      await backupFile.readAsBytes(),
    );
    final List<String> names = archive.files
        .map((ArchiveFile file) => file.name)
        .toList();

    expect(names.any((String name) => name.startsWith('index/')), isFalse);
    expect(names.any((String name) => name.startsWith('quarantine/')), isFalse);
    expect(
      names.any((String name) => name.startsWith('entries/')),
      isTrue,
    );
    expect(
      names.any((String name) => name.startsWith('assets/')),
      isTrue,
    );
    expect(names, contains('people.json.enc'));
    expect(names, contains('recovery.json'));
  });

  test('完整備份還原會恢復人物名冊當時的內容', () async {
    final RecoverySetupResult setup = await harness.repository
        .setupRecoveryKey();
    final Person backedUpPerson = await harness.repository.createPerson(
      setup.session,
      PersonDraft(
        name: '林小雨',
        aliases: const <String>['小雨'],
        relationships: const <PersonRelationship>{PersonRelationship.friend},
        relationshipDescription: '大學同學',
        notes: '喜歡登山',
        friendliness: FriendlinessLevel(4),
        birthday: PersonBirthday(month: 3, day: 14),
        acquaintanceYear: 2018,
      ),
    );
    final File backupFile = File(
      p.join(harness.tempDir.path, 'people_round_trip.zip'),
    );
    await archiveIo.writeBackupZip(backupFile);

    await harness.repository.createPerson(
      setup.session,
      PersonDraft(name: '備份後新增人物'),
    );
    expect(await harness.repository.listPeople(setup.session), hasLength(2));

    await archiveIo.restoreBackupZip(
      backupFile,
      preserveTrustedDeviceAccess: true,
    );
    final List<Person> restored = await harness.repository.listPeople(
      setup.session,
    );

    expect(restored, hasLength(1));
    expect(restored.single.id, backedUpPerson.id);
    expect(restored.single.name, '林小雨');
    expect(restored.single.aliases, const <String>['小雨']);
    expect(restored.single.relationships, const <PersonRelationship>{
      PersonRelationship.friend,
    });
    expect(restored.single.relationshipDescription, '大學同學');
    expect(restored.single.notes, '喜歡登山');
    expect(restored.single.friendliness, FriendlinessLevel(4));
    expect(restored.single.birthday, PersonBirthday(month: 3, day: 14));
    expect(restored.single.acquaintanceYear, 2018);
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
