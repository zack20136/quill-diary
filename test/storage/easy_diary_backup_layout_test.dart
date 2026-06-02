import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quill_lock_diary/infrastructure/storage/import/easy_diary/easy_diary_backup_layout.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('easy_diary_layout_test_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('可辨識扁平根目錄的 Easy Diary 完整備份', () async {
    final Directory root = Directory(p.join(tempDir.path, 'backup_root'));
    await root.create(recursive: true);
    await File(p.join(root.path, 'preference.json')).writeAsString('{}');
    final Directory databaseDir = Directory(p.join(root.path, 'Backup', 'Database'))
      ..createSync(recursive: true);
    Directory(p.join(root.path, 'Photos')).createSync(recursive: true);
    await File(p.join(databaseDir.path, 'diary.realm_20260601_235852')).writeAsString('');

    final EasyDiaryBackupLayout? layout = EasyDiaryBackupLayout.tryResolve(root);
    expect(layout, isNotNull);
    expect(layout!.realmSnapshotFile.path, endsWith('diary.realm_20260601_235852'));
    expect(layout.photosDirectory.path, endsWith('Photos'));
  });

  test('會選較新檔名的 diary.realm 快照', () async {
    final Directory root = Directory(p.join(tempDir.path, 'backup_newer'));
    await root.create(recursive: true);
    await File(p.join(root.path, 'preference.json')).writeAsString('{}');
    final Directory databaseDir = Directory(p.join(root.path, 'Backup', 'Database'))
      ..createSync(recursive: true);
    Directory(p.join(root.path, 'Photos')).createSync(recursive: true);
    await File(p.join(databaseDir.path, 'diary.realm_20260101_000000')).writeAsString('');
    await File(p.join(databaseDir.path, 'diary.realm_20260601_235852')).writeAsString('');

    final EasyDiaryBackupLayout? layout = EasyDiaryBackupLayout.tryResolve(root);
    expect(layout?.realmSnapshotFile.path, endsWith('diary.realm_20260601_235852'));
  });

  test('缺少 Photos 時不視為 Easy Diary 完整備份', () async {
    final Directory root = Directory(p.join(tempDir.path, 'backup_no_photos'));
    await root.create(recursive: true);
    await File(p.join(root.path, 'preference.json')).writeAsString('{}');
    Directory(p.join(root.path, 'Backup', 'Database')).createSync(recursive: true);

    expect(EasyDiaryBackupLayout.tryResolve(root), isNull);
  });
}
