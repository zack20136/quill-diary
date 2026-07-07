import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:quill_diary/app/app_identifiers.dart';
import '../../domain/shared/value_objects.dart';

/// 計算 vault、索引與本機備份儲存使用的所有本機路徑。
///
/// 路徑建構集中於此，便於稽核命名空間變更。
class VaultPathStrategy {
  const VaultPathStrategy();

  Future<Directory> appRootDirectory() async {
    final Directory supportDirectory = await getApplicationSupportDirectory();
    return Directory(
      p.join(supportDirectory.path, AppIdentifiers.appStorageDirectory),
    );
  }

  Future<Directory> vaultRootDirectory() async {
    final Directory root = await appRootDirectory();
    return Directory(p.join(root.path, 'vault'));
  }

  /// 與日記內容目錄分開，否則還原備份刪除整個 vault 時會讓仍開啟的索引庫變成唯讀。
  Future<Directory> indexRootDirectory() async {
    final Directory root = await appRootDirectory();
    return Directory(p.join(root.path, 'index'));
  }

  Future<Directory> localBackupsDirectory() async {
    final Directory root = await appRootDirectory();
    return Directory(p.join(root.path, 'backups'));
  }

  Future<Directory> editorDraftsRootDirectory() async {
    final Directory root = await appRootDirectory();
    return Directory(p.join(root.path, 'drafts'));
  }

  Future<String> indexDatabasePath() async {
    final Directory indexRoot = await indexRootDirectory();
    return p.join(indexRoot.path, 'journal_index.sqlite');
  }

  Future<String> recoveryMetadataPath() async {
    final Directory vaultRoot = await vaultRootDirectory();
    return p.join(vaultRoot.path, 'recovery.json');
  }

  Future<String> tagStylesPath() async {
    final Directory vaultRoot = await vaultRootDirectory();
    return p.join(vaultRoot.path, 'tag_styles.json');
  }

  Future<String> pinnedEntriesPath() async {
    final Directory vaultRoot = await vaultRootDirectory();
    return p.join(vaultRoot.path, 'pinned_entries.json');
  }

  Future<String> manifestPath() async {
    final Directory vaultRoot = await vaultRootDirectory();
    return p.join(vaultRoot.path, 'manifest.json.enc');
  }

  Future<Directory> editorDraftDirectory(String draftKey) async {
    final Directory draftsRoot = await editorDraftsRootDirectory();
    return Directory(p.join(draftsRoot.path, draftKey));
  }

  Future<String> editorDraftFilePath(String draftKey) async {
    final Directory draftDir = await editorDraftDirectory(draftKey);
    return p.join(draftDir.path, 'draft.json.enc');
  }

  Future<Directory> editorDraftPendingDirectory(String draftKey) async {
    final Directory draftDir = await editorDraftDirectory(draftKey);
    return Directory(p.join(draftDir.path, 'pending'));
  }

  String entryRelativePath({required DateOnly date, required EntryId entryId}) {
    return p.join(
      'entries',
      date.yearString,
      date.monthPadded,
      '$entryId.md.enc',
    );
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
    return p.join(
      vaultRoot.path,
      entryRelativePath(date: date, entryId: entryId),
    );
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
    final Directory indexRoot = await indexRootDirectory();
    await indexRoot.create(recursive: true);
    final Directory backupsRoot = await localBackupsDirectory();
    await backupsRoot.create(recursive: true);
    final Directory draftsRoot = await editorDraftsRootDirectory();
    await draftsRoot.create(recursive: true);
  }
}
