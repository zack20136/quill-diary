import 'dart:io';

import '../../domain/security/unlocked_vault_session.dart';
import '../../domain/shared/value_objects.dart';
import '../database/index_database_manager.dart';
import '../markdown/front_matter_codec.dart';
import 'portable/portable_export_io.dart';
import 'portable/portable_import_io.dart';
import 'portable/vault_backup_io.dart';
import 'shared/portable_import_result.dart';
import 'restore_precheck.dart';
import 'vault_path_strategy.dart';
import 'vault_repository.dart';

export 'shared/portable_import_result.dart';
export 'portable/portable_export_io.dart' show HtmlExportEstimate;
export 'portable/vault_backup_io.dart' show BackupHealthReport, BackupHealthStatusItem;
export 'portable/portable_import_io.dart' show EasyDiaryBackupImporterFactory;

/// Facade for backup, restore, portable export, and portable import I/O.
///
/// UI code depends on this class instead of the source-specific implementations
/// so each format can evolve without widening feature-layer dependencies.
class VaultArchiveIo {
  VaultArchiveIo({
    required VaultPathStrategy pathStrategy,
    required VaultRepository repository,
    required FrontMatterCodec frontMatterCodec,
    required IndexDatabaseManager indexDatabaseManager,
    EasyDiaryBackupImporterFactory? easyDiaryBackupImporterFactory,
  })  : _backup = VaultBackupIo(
          pathStrategy: pathStrategy,
          repository: repository,
          indexDatabaseManager: indexDatabaseManager,
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

  Future<File> writeBackupZip(File target) => _backup.writeBackupZip(target);

  Future<BackupHealthReport> checkBackupHealth(File backupFile) =>
      _backup.checkBackupHealth(backupFile);

  Future<Directory> exportMarkdown({
    required UnlockedVaultSession session,
    required Directory parentDirectory,
  }) =>
      _export.exportMarkdown(
        session: session,
        parentDirectory: parentDirectory,
      );

  Future<File> writePortableExportZip({
    required UnlockedVaultSession session,
    required File target,
  }) =>
      _export.writePortableExportZip(
        session: session,
        target: target,
      );

  Future<HtmlExportEstimate> estimateSelectedHtmlExport({
    required Set<EntryId> entryIds,
  }) =>
      _export.estimateSelectedHtmlExport(entryIds: entryIds);

  Future<File> writeSelectedHtmlExport({
    required UnlockedVaultSession session,
    required Set<EntryId> entryIds,
    required File target,
  }) =>
      _export.writeSelectedHtmlExport(
        session: session,
        entryIds: entryIds,
        target: target,
      );

  Future<PortableImportResult> importDocuments({
    required UnlockedVaultSession session,
    required Directory rootDirectory,
  }) =>
      _import.importDocuments(
        session: session,
        rootDirectory: rootDirectory,
      );

  Future<PortableImportResult> importDocumentsFromZip({
    required UnlockedVaultSession session,
    required File zipFile,
  }) =>
      _import.importDocumentsFromZip(
        session: session,
        zipFile: zipFile,
      );

  Future<void> verifyBackupRecoveryKey(File backupFile, String recoveryKey) =>
      _backup.verifyBackupRecoveryKey(backupFile, recoveryKey);

  Future<BackupRecoveryPreview> peekBackupRecovery(File backupFile) =>
      _backup.peekBackupRecovery(backupFile);

  Future<void> restoreBackupZip(
    File backupFile, {
    bool preserveTrustedDeviceAccess = false,
  }) =>
      _backup.restoreBackupZip(
        backupFile,
        preserveTrustedDeviceAccess: preserveTrustedDeviceAccess,
      );
}
