import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quill_lock_diary/domain/diary/diary_entry.dart';
import 'package:quill_lock_diary/infrastructure/database/index_database_manager.dart';
import 'package:quill_lock_diary/infrastructure/markdown/front_matter_codec.dart';
import 'package:quill_lock_diary/infrastructure/storage/easy_diary_backup_import.dart';
import 'package:quill_lock_diary/infrastructure/storage/vault_archive_io.dart';
import 'package:quill_lock_diary/infrastructure/storage/vault_repository.dart';

import '../helpers/vault_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late VaultTestHarness harness;
  late VaultArchiveIo archiveIo;

  setUp(() async {
    harness = await VaultTestHarness.create();
    archiveIo = VaultArchiveIo(
      pathStrategy: harness.pathStrategy,
      repository: harness.repository,
      frontMatterCodec: const FrontMatterCodec(),
      indexDatabaseManager: IndexDatabaseManager(harness.pathStrategy),
      easyDiaryBackupImporterFactory: () => EasyDiaryBackupImporter(
        realmReaderEnabled: true,
      ),
    );
  });

  tearDown(() async {
    await harness.dispose();
  });

  test('mock Realm 通道可匯入日記與 Photos 附件', () async {
    const MethodChannel channel = MethodChannel('quill_lock_diary/easy_diary_realm');
    final Directory backupRoot = Directory(p.join(harness.tempDir.path, 'easy_backup'));
    final Directory databaseDir = Directory(p.join(backupRoot.path, 'Backup', 'Database'))
      ..createSync(recursive: true);
    final Directory photosDir = Directory(p.join(backupRoot.path, 'Photos'))
      ..createSync(recursive: true);
    final File realmFile = File(p.join(databaseDir.path, 'diary.realm_20260601_235852'))
      ..writeAsStringSync('');
    await File(p.join(backupRoot.path, 'preference.json')).writeAsString('{}');
    await File(p.join(photosDir.path, 'snap.png')).writeAsBytes(<int>[1, 2, 3, 4]);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      if (call.method == 'readDiaryBackup') {
        expect(call.arguments['realmPath'], realmFile.path);
        return <String, Object>{
          'entries': <Map<String, Object?>>[
            <String, Object?>{
              'title': 'Backup Title',
              'contents': 'Body from Easy Diary',
              'dateString': '2026-06-01',
              'currentTimeMillis': DateTime.parse('2026-06-01T12:00:00').millisecondsSinceEpoch,
              'isEncrypt': false,
              'photos': <Map<String, Object?>>[
                <String, Object?>{'photoKey': 'snap.png', 'mimeType': 'image/png'},
              ],
            },
          ],
        };
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final setup = await harness.repository.setupRecoveryKey();
    final EasyDiaryBackupImporter importer = EasyDiaryBackupImporter(
      realmChannel: channel,
      realmReaderEnabled: true,
    );

    final PortableImportResult? result = await importer.tryImportFromExtractedRoot(
      session: setup.session,
      repository: harness.repository,
      extractedRoot: backupRoot,
    );

    expect(result, isNotNull);
    expect(result!.importedEntries, 1);
    expect(result.skippedFiles, 0);
    expect(result.skippedAttachments, 0);

    final entries = await harness.repository.listEntries();
    expect(entries, hasLength(1));
    final DiaryEntry? imported = await harness.repository.loadEntry(
      setup.session,
      entries.single.id,
    );
    expect(imported?.title, 'Backup Title');
    expect(imported?.markdownBody, contains('Body from Easy Diary'));
    expect(imported?.date.value, '2026-06-01');

    final attachments = await harness.repository.loadAttachments(entries.single.id);
    expect(attachments, hasLength(1));
    expect(attachments.single.safeFilename, 'snap.png');
    expect(attachments.single.mimeType, 'image/png');
  });

  test('可匯入無副檔名 UUID 相片並辨識為 JPEG', () async {
    const MethodChannel channel = MethodChannel('quill_lock_diary/easy_diary_realm');
    const String photoUuid = 'fe3121ef-e13e-41dd-a7c4-3f860786ff74';
    final Directory backupRoot = Directory(p.join(harness.tempDir.path, 'easy_uuid_photo'));
    final Directory databaseDir = Directory(p.join(backupRoot.path, 'Backup', 'Database'))
      ..createSync(recursive: true);
    final Directory photosDir = Directory(p.join(backupRoot.path, 'Photos'))
      ..createSync(recursive: true);
    await File(p.join(databaseDir.path, 'diary.realm_20260601_235852')).writeAsString('');
    await File(p.join(backupRoot.path, 'preference.json')).writeAsString('{}');
    await File(p.join(photosDir.path, photoUuid)).writeAsBytes(
      <int>[0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10],
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      if (call.method == 'readDiaryBackup') {
        return <String, Object>{
          'entries': <Map<String, Object?>>[
            <String, Object?>{
              'title': '有圖日記',
              'contents': '內文\n$photoUuid\n結尾',
              'dateString': '2026-06-01',
              'currentTimeMillis': DateTime.parse('2026-06-01T12:00:00').millisecondsSinceEpoch,
              'isEncrypt': false,
              'photos': <Map<String, Object?>>[
                <String, Object?>{'photoKey': photoUuid},
              ],
            },
          ],
        };
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final setup = await harness.repository.setupRecoveryKey();
    final EasyDiaryBackupImporter importer = EasyDiaryBackupImporter(
      realmChannel: channel,
      realmReaderEnabled: true,
    );

    final PortableImportResult? result = await importer.tryImportFromExtractedRoot(
      session: setup.session,
      repository: harness.repository,
      extractedRoot: backupRoot,
    );

    expect(result?.importedEntries, 1);
    expect(result?.skippedAttachments, 0);

    final entries = await harness.repository.listEntries();
    final DiaryEntry? imported = await harness.repository.loadEntry(
      setup.session,
      entries.single.id,
    );
    expect(imported?.markdownBody, isNot(contains(photoUuid)));

    final attachments = await harness.repository.loadAttachments(entries.single.id);
    expect(attachments, hasLength(1));
    expect(attachments.single.mimeType, 'image/jpeg');
    expect(attachments.single.safeFilename, '$photoUuid.jpg');
  });

  test('zip 結構可觸發 Easy Diary 匯入分流', () async {
    const MethodChannel channel = MethodChannel('quill_lock_diary/easy_diary_realm');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      if (call.method == 'readDiaryBackup') {
        return <String, Object>{
          'entries': <Map<String, Object?>>[
            <String, Object?>{
              'title': 'Zip Backup Entry',
              'contents': 'From zip',
              'dateString': '2026-06-02',
              'currentTimeMillis': DateTime.parse('2026-06-02T08:00:00').millisecondsSinceEpoch,
              'isEncrypt': false,
              'photos': <Map<String, Object?>>[],
            },
          ],
        };
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final File zipFile = File(p.join(harness.tempDir.path, 'easy_diary_backup.zip'));
    final Archive archive = Archive()
      ..addFile(ArchiveFile.string('preference.json', '{}'))
      ..addFile(
        ArchiveFile(
          'Backup/Database/diary.realm_20260601_235852',
          0,
          <int>[],
        ),
      )
      ..addFile(
        ArchiveFile(
          'Photos/.keep',
          0,
          <int>[],
        ),
      );
    await zipFile.writeAsBytes(ZipEncoder().encode(archive));

    final setup = await harness.repository.setupRecoveryKey();
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
    expect(imported?.title, 'Zip Backup Entry');
  });
}
