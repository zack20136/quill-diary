import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/domain/shared/vault_backup_policy.dart';
import 'package:quill_diary/infrastructure/storage/external_directory_store.dart';
import 'package:quill_diary/infrastructure/storage/portable/portable_export_io.dart';
import 'package:quill_diary/infrastructure/storage/portable/portable_import_io.dart';
import 'package:quill_diary/infrastructure/storage/portable/portable_import_preview.dart';
import 'package:quill_diary/infrastructure/storage/shared/external_directory_picker.dart';
import 'package:quill_diary/infrastructure/storage/shared/external_file_delivery.dart';
import 'package:quill_diary/infrastructure/storage/shared/picked_file_materializer.dart';
import 'package:quill_diary/infrastructure/storage/shared/portable_import_result.dart';
import 'package:quill_diary/infrastructure/storage/shared/vault_file_ops.dart';
import 'package:quill_diary/infrastructure/storage/vault_path_strategy.dart';
import 'package:quill_diary/infrastructure/storage/vault_transfer_models.dart';
import 'package:quill_diary/l10n/l10n.dart';

typedef ConfirmPortableImportPreview =
    Future<PortableImportConfirmResult?> Function(
      PortableImportPreview preview,
    );

const _unreadablePickedFiles = PortableImportResult(
  importedEntries: 0,
  skippedFiles: 0,
  failureCode: PortableImportFailureCode.selectedFilesUnreadable,
);

class PortableTransferService {
  PortableTransferService({
    required this._exportIo,
    required this._importIo,
    required this._externalDirectoryStore,
    this._pickPortableFiles,
    ReadPlatformFileBytes? readPlatformFileBytes,
    bool allowBytesFallback = false,
    CopyAndroidUriToPath? copyAndroidUriToPath,
    PickedFileMaterializer? pickedFileMaterializer,
    VaultPathStrategy pathStrategy = const VaultPathStrategy(),
  }) : _pathStrategy = pathStrategy,
       _pickedFileMaterializer =
           pickedFileMaterializer ??
           PickedFileMaterializer(
             copyAndroidUriToPath: copyAndroidUriToPath,
             readPlatformFileBytes: readPlatformFileBytes,
             allowBytesFallback: allowBytesFallback,
             pathStrategy: pathStrategy,
           );

  final PortableExportIo _exportIo;
  final PortableImportIo _importIo;
  final ExternalDirectoryStore _externalDirectoryStore;
  final PickPortableFiles? _pickPortableFiles;
  final PickedFileMaterializer _pickedFileMaterializer;
  final VaultPathStrategy _pathStrategy;

  Future<String?> exportMarkdownToDirectory(
    UnlockedVaultSession session,
    AppLocalizations l10n, {
    Set<EntryId>? entryIds,
    MarkdownExportOptions options = const MarkdownExportOptions(),
  }) async {
    final String fileName = VaultBackupPolicy.markdownPortableFileName(
      DateTime.now(),
    );
    return _writeTempAndDeliver(
      dialogTitle: l10n.vaultTransferPickMarkdownDirectoryTitle,
      fileName: fileName,
      writeTarget: (File target) {
        return _exportIo.writeMarkdownZip(
          session: session,
          target: target,
          entryIds: entryIds,
          options: options,
        );
      },
    );
  }

  Future<HtmlExportEstimate> estimateSelectedHtmlExport(Set<EntryId> entryIds) {
    return _exportIo.estimateSelectedHtmlExport(entryIds: entryIds);
  }

  Future<MarkdownExportEstimate> estimateMarkdownExport() {
    return _exportIo.estimateMarkdownExport();
  }

  Future<String?> exportHtmlToDirectory(
    UnlockedVaultSession session,
    Set<EntryId> entryIds,
    AppLocalizations l10n, {
    HtmlExportOptions options = const HtmlExportOptions(),
  }) async {
    final String fileName = VaultBackupPolicy.htmlPortableFileName(
      DateTime.now(),
    );
    if (options.externalAssets) {
      final work = await createWorkingDirectory(_pathStrategy, 'html_bundle');
      try {
        await _exportIo.writeSelectedHtmlBundle(
          session: session,
          entryIds: entryIds,
          target: work,
          options: options,
        );
        return await deliverToExternalDirectory(
          dialogTitle: l10n.vaultTransferPickHtmlDirectoryTitle,
          fileName: p.basenameWithoutExtension(fileName),
          source: work,
          resolveInitialDirectory:
              _externalDirectoryStore.resolveInitialDirectory,
          rememberDirectory: _externalDirectoryStore.rememberDirectory,
        );
      } finally {
        await deleteWorkingDirectory(work);
      }
    }
    return _writeTempAndDeliver(
      dialogTitle: l10n.vaultTransferPickHtmlDirectoryTitle,
      fileName: fileName,
      writeTarget: (File target) {
        return _exportIo.writeSelectedHtmlExport(
          session: session,
          entryIds: entryIds,
          target: target,
          options: options,
        );
      },
    );
  }

  Future<PortableImportResult?> importDocumentsWithPicker(
    UnlockedVaultSession session, {
    required AppLocalizations l10n,
    required ConfirmPortableImportPreview confirmPreview,
  }) async {
    final PortableImportResult? pickedResult = await _tryImportFromPickedFiles(
      session,
      l10n: l10n,
      confirmPreview: confirmPreview,
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

    final AnalyzedPortableImport analyzed = await _importIo.analyzeDocuments(
      session: session,
      rootDirectory: Directory(sourceDirectory),
    );
    return _confirmAndPersist(
      session: session,
      analyzed: analyzed,
      confirmPreview: confirmPreview,
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
    required ConfirmPortableImportPreview confirmPreview,
  }) async {
    final List<PlatformFile> picked =
        await (_pickPortableFiles ?? _pickPortableFilesFromSystem)(
          dialogTitle: l10n.vaultTransferImportDocumentsFileTitle,
          allowedExtensions: const <String>['zip', 'md', 'html', 'htm'],
        );
    if (picked.isEmpty) {
      return null;
    }

    final List<PlatformFile> zipFiles = picked
        .where((PlatformFile file) => _extensionOf(file) == '.zip')
        .toList(growable: false);
    if (zipFiles.isNotEmpty) {
      return _importZipFile(session, zipFiles.first, confirmPreview);
    }

    final List<PlatformFile> documentFiles = picked
        .where(
          (PlatformFile file) =>
              _isPortableDocumentExtension(_extensionOf(file)),
        )
        .toList(growable: false);
    if (documentFiles.isEmpty) {
      return null;
    }

    return _importPickedDocumentFiles(session, documentFiles, confirmPreview);
  }

  Future<List<PlatformFile>> _pickPortableFilesFromSystem({
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
    ConfirmPortableImportPreview confirmPreview,
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
    } on PickedFileMaterializationException {
      return _unreadablePickedFiles;
    }

    Directory? ownedTempRoot;
    try {
      final ({AnalyzedPortableImport analyzed, Directory ownedTempRoot})
      prepared = await _importIo.analyzeDocumentsFromZip(
        session: session,
        zipFile: materialized.file,
      );
      ownedTempRoot = prepared.ownedTempRoot;
      return await _confirmAndPersist(
        session: session,
        analyzed: prepared.analyzed,
        confirmPreview: confirmPreview,
      );
    } finally {
      if (ownedTempRoot != null) {
        await deleteWorkingDirectory(ownedTempRoot);
      }
      if (materialized.shouldDeleteAfterUse) {
        await deleteFileIfExists(materialized.file.path);
      }
    }
  }

  Future<PortableImportResult?> _importPickedDocumentFiles(
    UnlockedVaultSession session,
    List<PlatformFile> documentFiles,
    ConfirmPortableImportPreview confirmPreview,
  ) async {
    final Directory tempRoot = await createWorkingDirectory(
      _pathStrategy,
      'import_picked',
    );
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
        return _unreadablePickedFiles;
      }

      final AnalyzedPortableImport analyzed = await _importIo.analyzeDocuments(
        session: session,
        rootDirectory: tempRoot,
      );
      return await _confirmAndPersist(
        session: session,
        analyzed: analyzed,
        confirmPreview: confirmPreview,
      );
    } finally {
      await deleteWorkingDirectory(tempRoot);
    }
  }

  Future<PortableImportResult?> _confirmAndPersist({
    required UnlockedVaultSession session,
    required AnalyzedPortableImport analyzed,
    required ConfirmPortableImportPreview confirmPreview,
  }) async {
    if (analyzed.failureCode != null && !analyzed.hasImportableEntries) {
      return PortableImportResult(
        importedEntries: 0,
        skippedFiles: analyzed.preview.skippedFiles == 0
            ? 1
            : analyzed.preview.skippedFiles,
        skippedAttachments: analyzed.preview.skippedAttachments,
        failureCode: analyzed.failureCode,
      );
    }

    if (!analyzed.hasImportableEntries) {
      return PortableImportResult(
        importedEntries: 0,
        skippedFiles: analyzed.preview.skippedFiles,
        skippedAttachments: analyzed.preview.skippedAttachments,
      );
    }

    final PortableImportConfirmResult? confirmation = await confirmPreview(
      analyzed.preview,
    );
    if (confirmation == null || !confirmation.confirmed) {
      return null;
    }

    return _importIo.persistAnalyzedImport(
      session: session,
      analyzed: analyzed,
      selectedPreviewIndices: confirmation.selectedPreviewIndices,
    );
  }

  Future<String?> _writeTempAndDeliver({
    required String dialogTitle,
    required String fileName,
    required Future<void> Function(File target) writeTarget,
  }) async {
    final Directory workDirectory = await _pathStrategy.transferWorkDirectory();
    final File tempFile = await File(
      p.join(
        workDirectory.path,
        '${DateTime.now().microsecondsSinceEpoch}_$fileName',
      ),
    ).create(recursive: true, exclusive: true);
    try {
      await writeTarget(tempFile);
      return await deliverToExternalDirectory(
        dialogTitle: dialogTitle,
        fileName: fileName,
        source: tempFile,
        resolveInitialDirectory:
            _externalDirectoryStore.resolveInitialDirectory,
        rememberDirectory: _externalDirectoryStore.rememberDirectory,
      );
    } finally {
      await deleteFileIfExists(tempFile.path);
    }
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
}
