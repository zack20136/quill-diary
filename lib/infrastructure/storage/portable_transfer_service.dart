import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/security/unlocked_vault_session.dart';
import '../../domain/shared/value_objects.dart';
import '../../domain/shared/vault_backup_policy.dart';
import '../../l10n/l10n.dart';
import 'external_directory_store.dart';
import 'shared/external_directory_picker.dart';
import 'shared/external_file_delivery.dart';
import 'shared/picked_file_materializer.dart';
import 'vault_archive_io.dart';
import 'vault_transfer_models.dart';

class PortableTransferService {
  PortableTransferService({
    required VaultArchiveIo archiveIo,
    required ExternalDirectoryStore externalDirectoryStore,
    PickPortableFiles? pickPortableFiles,
    ReadPlatformFileBytes? readPlatformFileBytes,
    bool allowBytesFallback = false,
    CopyAndroidUriToPath? copyAndroidUriToPath,
    PickedFileMaterializer? pickedFileMaterializer,
  }) : _archiveIo = archiveIo,
       _externalDirectoryStore = externalDirectoryStore,
       _pickPortableFiles = pickPortableFiles,
       _pickedFileMaterializer =
           pickedFileMaterializer ??
           PickedFileMaterializer(
             copyAndroidUriToPath: copyAndroidUriToPath,
             readPlatformFileBytes: readPlatformFileBytes,
             allowBytesFallback: allowBytesFallback,
           );

  final VaultArchiveIo _archiveIo;
  final ExternalDirectoryStore _externalDirectoryStore;
  final PickPortableFiles? _pickPortableFiles;
  final PickedFileMaterializer _pickedFileMaterializer;

  Future<String?> exportMarkdownToDirectory(
    UnlockedVaultSession session,
    AppLocalizations l10n,
  ) async {
    final String fileName = VaultBackupPolicy.markdownPortableFileName(
      DateTime.now(),
    );
    return _writeTempAndDeliver(
      dialogTitle: l10n.vaultTransferPickMarkdownDirectoryTitle,
      fileName: fileName,
      l10n: l10n,
      writeTarget: (File target) {
        return _archiveIo.writeMarkdownZip(session: session, target: target);
      },
    );
  }

  Future<HtmlExportEstimate> estimateSelectedHtmlExport(Set<EntryId> entryIds) {
    return _archiveIo.estimateSelectedHtmlExport(entryIds: entryIds);
  }

  Future<String?> exportHtmlToDirectory(
    UnlockedVaultSession session,
    Set<EntryId> entryIds,
    AppLocalizations l10n,
  ) async {
    final String fileName = VaultBackupPolicy.htmlPortableFileName(
      DateTime.now(),
    );
    return _writeTempAndDeliver(
      dialogTitle: l10n.vaultTransferPickHtmlDirectoryTitle,
      fileName: fileName,
      l10n: l10n,
      writeTarget: (File target) {
        return _archiveIo.writeSelectedHtmlExport(
          session: session,
          entryIds: entryIds,
          target: target,
        );
      },
    );
  }

  Future<PortableImportResult?> importDocumentsWithPicker(
    UnlockedVaultSession session, {
    required AppLocalizations l10n,
  }) async {
    final PortableImportResult? pickedResult = await _tryImportFromPickedFiles(
      session,
      l10n: l10n,
    );
    if (pickedResult != null) {
      return pickedResult;
    }

    final String? sourceDirectory =
        await ExternalDirectoryPicker.pickExternalDirectory(
          prompt: l10n.vaultTransferImportDocumentsDirectoryPrompt,
          initialDirectory: await _externalDirectoryStore
              .resolveInitialDirectory(),
        );
    if (sourceDirectory == null) {
      return null;
    }

    await _externalDirectoryStore.rememberDirectory(sourceDirectory);

    return _archiveIo.importDocuments(
      session: session,
      rootDirectory: Directory(sourceDirectory),
    );
  }

  @visibleForTesting
  static String uniqueImportedDocumentFileName({
    required String sourceName,
    required String extension,
    required int index,
  }) {
    final String normalizedExtension = extension.isNotEmpty
        ? extension
        : p.extension(sourceName).toLowerCase();
    final String fallbackName = normalizedExtension.isNotEmpty
        ? 'imported_entry$index$normalizedExtension'
        : 'imported_entry$index';
    final String baseName = sourceName.trim().isNotEmpty
        ? p.basename(sourceName.trim())
        : fallbackName;
    return '${(index + 1).toString().padLeft(4, '0')}_$baseName';
  }

  Future<PortableImportResult?> _tryImportFromPickedFiles(
    UnlockedVaultSession session, {
    required AppLocalizations l10n,
  }) async {
    final FilePickerResult? picked =
        await (_pickPortableFiles ?? _pickPortableFilesFromSystem)(
          dialogTitle: l10n.vaultTransferImportDocumentsFileTitle,
          allowedExtensions: const <String>['zip', 'md', 'html', 'htm'],
        );
    if (picked == null || picked.files.isEmpty) {
      return null;
    }

    final List<PlatformFile> zipFiles = picked.files
        .where((PlatformFile file) => _extensionOf(file) == '.zip')
        .toList(growable: false);
    if (zipFiles.isNotEmpty) {
      return _importZipFile(session, zipFiles.first);
    }

    final List<PlatformFile> documentFiles = picked.files
        .where(
          (PlatformFile file) =>
              _isPortableDocumentExtension(_extensionOf(file)),
        )
        .toList(growable: false);
    if (documentFiles.isEmpty) {
      return null;
    }

    return _importPickedDocumentFiles(session, documentFiles);
  }

  Future<FilePickerResult?> _pickPortableFilesFromSystem({
    required String dialogTitle,
    required List<String> allowedExtensions,
  }) {
    return FilePicker.pickFiles(
      dialogTitle: dialogTitle,
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
    );
  }

  Future<PortableImportResult?> _importZipFile(
    UnlockedVaultSession session,
    PlatformFile zipFile,
  ) async {
    final String baseName = zipFile.name.isNotEmpty
        ? zipFile.name
        : 'portable_import.zip';
    final MaterializedPickedFile materialized;
    try {
      materialized = await _pickedFileMaterializer.materialize(
        zipFile,
        fallbackBaseName: baseName,
        alwaysCopyToTemp: true,
      );
    } on PickedFileMaterializationException catch (error) {
      return importResultForMaterializationFailure(error.failure);
    }

    try {
      return await _archiveIo.importDocumentsFromZip(
        session: session,
        zipFile: materialized.file,
      );
    } finally {
      if (materialized.shouldDeleteAfterUse) {
        await _deleteIfExists(materialized.file);
      }
    }
  }

  Future<PortableImportResult?> _importPickedDocumentFiles(
    UnlockedVaultSession session,
    List<PlatformFile> documentFiles,
  ) async {
    final Directory tempRoot = await _createTempDirectory('import_picked');
    try {
      var copiedFiles = 0;
      for (final PlatformFile file in documentFiles) {
        final String extension = _extensionOf(file);
        if (!_isPortableDocumentExtension(extension)) {
          continue;
        }

        final String fileName = uniqueImportedDocumentFileName(
          sourceName: file.name,
          extension: extension,
          index: copiedFiles,
        );
        final File destination = File(p.join(tempRoot.path, fileName));

        try {
          await _pickedFileMaterializer.materialize(
            file,
            fallbackBaseName: fileName,
            alwaysCopyToTemp: true,
            importDestination: destination,
          );
          copiedFiles++;
        } on PickedFileMaterializationException {
          continue;
        }
      }

      if (copiedFiles == 0) {
        return const PortableImportResult(
          importedEntries: 0,
          skippedFiles: 0,
          failureCode: PortableImportFailureCode.selectedFilesUnreadable,
        );
      }

      return await _archiveIo.importDocuments(
        session: session,
        rootDirectory: tempRoot,
      );
    } finally {
      if (tempRoot.existsSync()) {
        await tempRoot.delete(recursive: true);
      }
    }
  }

  Future<String?> _writeTempAndDeliver({
    required String dialogTitle,
    required String fileName,
    required AppLocalizations l10n,
    required Future<void> Function(File target) writeTarget,
  }) async {
    final File tempFile = await _createTempFile(fileName);
    try {
      await writeTarget(tempFile);
      return await deliverToExternalDirectory(
        dialogTitle: dialogTitle,
        fileName: fileName,
        sourceFile: tempFile,
        l10n: l10n,
        resolveInitialDirectory:
            _externalDirectoryStore.resolveInitialDirectory,
        rememberDirectory: _externalDirectoryStore.rememberDirectory,
      );
    } finally {
      await _deleteIfExists(tempFile);
    }
  }

  Future<Directory> _createTempDirectory(String prefix) async {
    final Directory tempDirectory = await getTemporaryDirectory();
    final Directory directory = Directory(
      p.join(
        tempDirectory.path,
        '${DateTime.now().microsecondsSinceEpoch}_$prefix',
      ),
    );
    await directory.create(recursive: true);
    return directory;
  }

  Future<File> _createTempFile(String fileName) async {
    final Directory tempDirectory = await getTemporaryDirectory();
    return File(
      p.join(
        tempDirectory.path,
        '${DateTime.now().microsecondsSinceEpoch}_$fileName',
      ),
    );
  }

  String _extensionOf(PlatformFile file) {
    final String fromName = p.extension(file.name).toLowerCase();
    if (fromName.isNotEmpty) {
      return fromName;
    }
    final String? path = file.path;
    if (path == null || path.isEmpty) {
      return '';
    }
    return p.extension(path).toLowerCase();
  }

  bool _isPortableDocumentExtension(String extension) {
    return extension == '.md' || extension == '.html' || extension == '.htm';
  }

  Future<void> _deleteIfExists(File file) async {
    if (file.existsSync()) {
      await file.delete();
    }
  }
}
