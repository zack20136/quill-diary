import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'user_export_paths.dart';
import 'vault_path_strategy.dart';
import 'media_store_export.dart';

/// 記住使用者上次選擇的外部資料夾（備份交付、可攜式匯入／匯出共用）。
class ExternalDirectoryStore {
  ExternalDirectoryStore(this._pathStrategy);

  final VaultPathStrategy _pathStrategy;

  Future<String> _filePath() async {
    final Directory root = await _pathStrategy.appRootDirectory();
    return p.join(root.path, 'external_directory.json');
  }

  Future<String?> readLastDirectory() async {
    final File file = File(await _filePath());
    if (!file.existsSync()) {
      return null;
    }

    try {
      final Object? decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, Object?>) {
        return null;
      }
      final String? directory = decoded['lastDirectory']?.toString().trim();
      if (directory == null || directory.isEmpty) {
        return null;
      }
      if (directory.startsWith('content://')) {
        return directory;
      }
      return Directory(directory).existsSync() ? directory : null;
    } on Object {
      return null;
    }
  }

  Future<void> rememberDirectory(String directory) async {
    final String trimmed = directory.trim();
    if (trimmed.isEmpty) {
      return;
    }
    if (!trimmed.startsWith('content://') && !Directory(trimmed).existsSync()) {
      return;
    }

    final File file = File(await _filePath());
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent(
        '  ',
      ).convert(<String, Object?>{'lastDirectory': trimmed}),
      flush: true,
    );
  }

  Future<void> rememberSavedFilePath(String? savedPath) async {
    if (savedPath == null || savedPath.trim().isEmpty) {
      return;
    }
    if (savedPath.startsWith('content:')) {
      return;
    }

    final String directory = p.dirname(savedPath);
    await rememberDirectory(directory);
  }

  /// 優先使用上次目錄，否則回到 Downloads/quill-diary。
  Future<String?> resolveInitialDirectory() async {
    final String? lastDirectory = await readLastDirectory();
    if (lastDirectory != null) {
      return lastDirectory;
    }
    return _defaultDownloadsSubdirectoryPath();
  }

  Future<String?> _defaultDownloadsSubdirectoryPath() async {
    await MediaStoreExport.ensureDownloadsSubfolder();

    final Directory? downloads = await getDownloadsDirectory();
    if (downloads == null) {
      return null;
    }

    final Directory preferred = Directory(
      p.join(downloads.path, UserExportPaths.subfolderName),
    );
    try {
      await preferred.create(recursive: true);
      return preferred.path;
    } on Object {
      return null;
    }
  }
}
