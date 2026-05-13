import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/shared/value_objects.dart';

class VaultPathStrategy {
  const VaultPathStrategy();

  Future<Directory> appRootDirectory() async {
    final Directory supportDirectory = await getApplicationSupportDirectory();
    return Directory(p.join(supportDirectory.path, 'quill_lock_diary'));
  }

  Future<Directory> vaultRootDirectory() async {
    final Directory root = await appRootDirectory();
    return Directory(p.join(root.path, 'vault'));
  }

  Future<Directory> exportsDirectory() async {
    final Directory root = await appRootDirectory();
    return Directory(p.join(root.path, 'exports'));
  }

  Future<Directory> backupsDirectory() async {
    final Directory root = await appRootDirectory();
    return Directory(p.join(root.path, 'backups'));
  }

  Future<String> indexDatabasePath() async {
    final Directory vaultRoot = await vaultRootDirectory();
    return p.join(vaultRoot.path, 'index', 'journal_index.sqlite');
  }

  Future<String> recoveryMetadataPath() async {
    final Directory vaultRoot = await vaultRootDirectory();
    return p.join(vaultRoot.path, 'recovery.json');
  }

  Future<String> manifestPath() async {
    final Directory vaultRoot = await vaultRootDirectory();
    return p.join(vaultRoot.path, 'manifest.json.enc');
  }

  String entryRelativePath({
    required DateOnly date,
    required EntryId entryId,
  }) {
    return p.join('entries', date.yearString, date.monthPadded, '$entryId.md.enc');
  }

  String assetRelativePath({
    required DateOnly date,
    required AssetId assetId,
    required String extension,
  }) {
    return p.join(
      'assets',
      date.yearString,
      date.monthPadded,
      '$assetId.$extension.enc',
    );
  }

  Future<String> entryAbsolutePath({
    required DateOnly date,
    required EntryId entryId,
  }) async {
    final Directory vaultRoot = await vaultRootDirectory();
    return p.join(vaultRoot.path, entryRelativePath(date: date, entryId: entryId));
  }

  Future<String> assetAbsolutePath({
    required DateOnly date,
    required AssetId assetId,
    required String extension,
  }) async {
    final Directory vaultRoot = await vaultRootDirectory();
    return p.join(
      vaultRoot.path,
      assetRelativePath(date: date, assetId: assetId, extension: extension),
    );
  }

  Future<void> ensureBaseDirectories() async {
    final Directory vaultRoot = await vaultRootDirectory();
    await Directory(p.join(vaultRoot.path, 'entries')).create(recursive: true);
    await Directory(p.join(vaultRoot.path, 'assets')).create(recursive: true);
    await Directory(p.join(vaultRoot.path, 'index')).create(recursive: true);
    await exportsDirectory().then((Directory dir) => dir.create(recursive: true));
    await backupsDirectory().then((Directory dir) => dir.create(recursive: true));
  }
}
