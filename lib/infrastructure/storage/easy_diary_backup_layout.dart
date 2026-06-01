import 'dart:io';

import 'package:path/path.dart' as p;

/// Easy Diary 完整備份 zip 解壓後的目錄配置（preference.json + Backup/Database + Photos）。
class EasyDiaryBackupLayout {
  const EasyDiaryBackupLayout({
    required this.rootDirectory,
    required this.realmSnapshotFile,
    required this.photosDirectory,
  });

  final Directory rootDirectory;
  final File realmSnapshotFile;
  final Directory photosDirectory;

  /// 在 [extractedRoot] 內尋找符合 Easy Diary 完整備份結構的根目錄。
  static EasyDiaryBackupLayout? tryResolve(Directory extractedRoot) {
    if (!extractedRoot.existsSync()) {
      return null;
    }

    final List<File> preferenceFiles = <File>[];
    _collectPreferenceJsonFiles(extractedRoot, preferenceFiles);
    if (preferenceFiles.isEmpty) {
      return null;
    }

    for (final File preferenceFile in preferenceFiles) {
      final Directory candidateRoot = preferenceFile.parent;
      final Directory databaseDir = Directory(
        p.join(candidateRoot.path, 'Backup', 'Database'),
      );
      final Directory photosDir = Directory(p.join(candidateRoot.path, 'Photos'));
      if (!databaseDir.existsSync() || !photosDir.existsSync()) {
        continue;
      }

      final File? realmFile = _pickLatestRealmSnapshot(databaseDir);
      if (realmFile == null) {
        continue;
      }

      return EasyDiaryBackupLayout(
        rootDirectory: candidateRoot,
        realmSnapshotFile: realmFile,
        photosDirectory: photosDir,
      );
    }

    return null;
  }

  static void _collectPreferenceJsonFiles(Directory root, List<File> output) {
    for (final FileSystemEntity entity in root.listSync(followLinks: false)) {
      if (entity is File && p.basename(entity.path) == 'preference.json') {
        output.add(entity);
      } else if (entity is Directory) {
        _collectPreferenceJsonFiles(entity, output);
      }
    }
  }

  static File? _pickLatestRealmSnapshot(Directory databaseDir) {
    final List<File> candidates = databaseDir
        .listSync(followLinks: false)
        .whereType<File>()
        .where((File file) {
          final String name = p.basename(file.path).toLowerCase();
          return name.startsWith('diary.realm');
        })
        .toList(growable: false);
    if (candidates.isEmpty) {
      return null;
    }

    candidates.sort((File a, File b) => p.basename(b.path).compareTo(p.basename(a.path)));
    return candidates.first;
  }
}
