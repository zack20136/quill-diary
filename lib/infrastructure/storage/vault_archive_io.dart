import 'dart:io';

import '../../domain/security/unlocked_vault_session.dart';
import '../../domain/shared/value_objects.dart';
import '../database/index_database_manager.dart';
import '../markdown/front_matter_codec.dart';
import 'editor_draft_store.dart';
import 'portable/portable_export_io.dart';
import 'portable/portable_import_io.dart';
import 'portable/portable_import_preview.dart';
import 'portable/vault_backup_io.dart';
import 'shared/portable_import_result.dart';
import 'restore_precheck.dart';
import 'backup_task_progress.dart';
import 'vault_path_strategy.dart';
import 'vault_repository.dart';

export 'shared/portable_import_result.dart';
export 'portable/portable_export_io.dart'
    show
        HtmlExportEntrySummary,
        HtmlExportEstimate,
        HtmlExportOptions,
        MarkdownExportEntrySummary,
        MarkdownExportEstimate,
        MarkdownExportOptions;
export 'portable/vault_backup_io.dart' show BackupInspectResult;
export 'portable/backup_archive_inspection.dart' show VaultBackupLayout;
export 'portable/portable_import_io.dart' show EasyDiaryBackupImporterFactory;
export 'portable/portable_import_preview.dart'
    show
        AnalyzedPortableImport,
        PortableImportConfirmResult,
        PortableImportPreview,
        PortableImportPreviewEntry;

/// 備份、還原、可攜式匯出與匯入 I/O 的門面。
///
/// UI 依賴此類而非各來源實作，讓各格式可獨立演進而不擴大功能層依賴。
class VaultArchiveIo {
  VaultArchiveIo({
    required VaultPathStrategy pathStrategy,
    required VaultRepository repository,
    required FrontMatterCodec frontMatterCodec,
    required IndexDatabaseManager indexDatabaseManager,
    required EditorDraftStore editorDraftStore,
    EasyDiaryBackupImporterFactory? easyDiaryBackupImporterFactory,
  }) : _backup = VaultBackupIo(
         pathStrategy: pathStrategy,
         repository: repository,
         indexDatabaseManager: indexDatabaseManager,
         editorDraftStore: editorDraftStore,
       ),
       _export = PortableExportIo(
         pathStrategy: pathStrategy,
         repository: repository,
         frontMatterCodec: frontMatterCodec,
       ),
       _import = PortableImportIo(
         pathStrategy: pathStrategy,
         repository: repository,
         frontMatterCodec: frontMatterCodec,
         easyDiaryBackupImporterFactory: easyDiaryBackupImporterFactory,
       );

  final VaultBackupIo _backup;
  final PortableExportIo _export;
  final PortableImportIo _import;

  Future<File> writeBackupZip(
    File target, {
    BackupTaskProgressListener? onProgress,
  }) => _backup.writeBackupZip(target, onProgress: onProgress);

  Future<BackupInspectResult> inspectBackup(File backupFile) =>
      _backup.inspectBackup(backupFile);

  Future<BackupRecoveryPreview> prepareRestorePreview(File backupFile) =>
      _backup.prepareRestorePreview(backupFile);

  Future<Directory> exportMarkdown({
    required UnlockedVaultSession session,
    required Directory parentDirectory,
    Set<EntryId>? entryIds,
    MarkdownExportOptions options = const MarkdownExportOptions(),
  }) => _export.exportMarkdown(
    session: session,
    parentDirectory: parentDirectory,
    entryIds: entryIds,
    options: options,
  );

  Future<File> writeMarkdownZip({
    required UnlockedVaultSession session,
    required File target,
    Set<EntryId>? entryIds,
    MarkdownExportOptions options = const MarkdownExportOptions(),
  }) => _export.writeMarkdownZip(
    session: session,
    target: target,
    entryIds: entryIds,
    options: options,
  );

  Future<HtmlExportEstimate> estimateSelectedHtmlExport({
    required Set<EntryId> entryIds,
  }) => _export.estimateSelectedHtmlExport(entryIds: entryIds);

  Future<MarkdownExportEstimate> estimateMarkdownExport() =>
      _export.estimateMarkdownExport();

  Future<File> writeSelectedHtmlExport({
    required UnlockedVaultSession session,
    required Set<EntryId> entryIds,
    required File target,
    HtmlExportOptions options = const HtmlExportOptions(),
  }) => _export.writeSelectedHtmlExport(
    session: session,
    entryIds: entryIds,
    target: target,
    options: options,
  );

  Future<AnalyzedPortableImport> analyzeDocuments({
    required UnlockedVaultSession session,
    required Directory rootDirectory,
  }) => _import.analyzeDocuments(
    session: session,
    rootDirectory: rootDirectory,
  );

  Future<({AnalyzedPortableImport analyzed, Directory ownedTempRoot})>
  analyzeDocumentsFromZip({
    required UnlockedVaultSession session,
    required File zipFile,
  }) => _import.analyzeDocumentsFromZip(session: session, zipFile: zipFile);

  Future<PortableImportResult> persistAnalyzedImport({
    required UnlockedVaultSession session,
    required AnalyzedPortableImport analyzed,
    required Set<int> selectedPreviewIndices,
  }) => _import.persistAnalyzedImport(
    session: session,
    analyzed: analyzed,
    selectedPreviewIndices: selectedPreviewIndices,
  );

  Future<PortableImportResult> importDocuments({
    required UnlockedVaultSession session,
    required Directory rootDirectory,
  }) => _import.importDocuments(session: session, rootDirectory: rootDirectory);

  Future<PortableImportResult> importDocumentsFromZip({
    required UnlockedVaultSession session,
    required File zipFile,
  }) => _import.importDocumentsFromZip(session: session, zipFile: zipFile);

  Future<void> verifyBackupRecoveryKey(File backupFile, String recoveryKey) =>
      _backup.verifyBackupRecoveryKey(backupFile, recoveryKey);

  Future<BackupRecoveryPreview> peekBackupRecovery(File backupFile) =>
      _backup.peekBackupRecovery(backupFile);

  Future<void> restoreBackupZip(
    File backupFile, {
    bool preserveTrustedDeviceAccess = false,
    BackupTaskProgressListener? onProgress,
  }) => _backup.restoreBackupZip(
    backupFile,
    preserveTrustedDeviceAccess: preserveTrustedDeviceAccess,
    onProgress: onProgress,
  );
}
