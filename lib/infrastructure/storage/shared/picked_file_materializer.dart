import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../l10n/l10n.dart';
import 'android_content_uri_import.dart';
import 'archive_extract.dart';
import 'portable_import_result.dart';

typedef ReadPlatformFileBytes = Future<Uint8List?> Function(PlatformFile file);

typedef CopyAndroidUriToPath =
    Future<void> Function({
      required String sourceUri,
      required File destinationFile,
    });

/// 僅測試用 bytes 保底上限；非產品檔案大小限制。
///
/// Android 匯入/還原應走本機 path 或 content:// URI 串流複製。
@visibleForTesting
const int kPickedFileBytesFallbackMaxBytes = 64 * 1024 * 1024;

enum PickedFileSourceKind { localPath, androidContentUri, bytesFallback }

enum PickedFileMaterializationFailure { unreadable, tooLargeForBytesFallback }

final class PickedFileMaterializationException implements Exception {
  const PickedFileMaterializationException(this.failure);

  final PickedFileMaterializationFailure failure;
}

final class MaterializedPickedFile {
  const MaterializedPickedFile({
    required this.file,
    required this.shouldDeleteAfterUse,
    required this.sourceKind,
  });

  final File file;
  final bool shouldDeleteAfterUse;
  final PickedFileSourceKind sourceKind;
}

String materializationFailureMessage(
  PickedFileMaterializationFailure failure,
  AppLocalizations l10n,
) {
  return switch (failure) {
    PickedFileMaterializationFailure.unreadable =>
      l10n.vaultTransferPickedFileUnreadable,
    PickedFileMaterializationFailure.tooLargeForBytesFallback =>
      l10n.vaultTransferPickedFileUnreadable,
  };
}

PortableImportResult importResultForMaterializationFailure(
  PickedFileMaterializationFailure _,
) {
  return const PortableImportResult(
    importedEntries: 0,
    skippedFiles: 0,
    failureCode: PortableImportFailureCode.selectedFilesUnreadable,
  );
}

/// 將 file_picker 回傳的 [PlatformFile] 物化為可讀的本機 [File]。
class PickedFileMaterializer {
  PickedFileMaterializer({
    CopyAndroidUriToPath? copyAndroidUriToPath,
    ReadPlatformFileBytes? readPlatformFileBytes,
    this.allowBytesFallback = false,
  }) : _copyAndroidUriToPathOverride = copyAndroidUriToPath,
       _readPlatformFileBytesOverride = readPlatformFileBytes;

  final bool allowBytesFallback;

  final CopyAndroidUriToPath? _copyAndroidUriToPathOverride;
  final ReadPlatformFileBytes? _readPlatformFileBytesOverride;

  Future<MaterializedPickedFile> materialize(
    PlatformFile file, {
    required String fallbackBaseName,
    required bool alwaysCopyToTemp,
    File? importDestination,
  }) async {
    if (_isCachedLocalPath(file)) {
      final File sourceFile = File(file.path!);
      if (!alwaysCopyToTemp) {
        return MaterializedPickedFile(
          file: sourceFile,
          shouldDeleteAfterUse: false,
          sourceKind: PickedFileSourceKind.localPath,
        );
      }

      final File destination =
          importDestination ?? await _createTempFile(fallbackBaseName);
      await copyFileToPath(sourceFile, destination.path);
      return MaterializedPickedFile(
        file: destination,
        shouldDeleteAfterUse: true,
        sourceKind: PickedFileSourceKind.localPath,
      );
    }

    final String? contentUri = _resolveContentUri(file);
    if (contentUri != null) {
      final File destination =
          importDestination ?? await _createTempFile(fallbackBaseName);
      try {
        await _copyAndroidUriToPath(
          sourceUri: contentUri,
          destinationFile: destination,
        );
        return MaterializedPickedFile(
          file: destination,
          shouldDeleteAfterUse: true,
          sourceKind: PickedFileSourceKind.androidContentUri,
        );
      } on Object {
        await _deleteIfExists(destination);
        throw const PickedFileMaterializationException(
          PickedFileMaterializationFailure.unreadable,
        );
      } finally {
        if (file is AndroidPlatformFile) {
          try {
            await file.safHandle.releaseGrant();
          } on Object {
            // SAF grant 釋放失敗不應覆蓋 materialize 成敗。
          }
        }
      }
    }

    if (!allowBytesFallback) {
      throw const PickedFileMaterializationException(
        PickedFileMaterializationFailure.unreadable,
      );
    }

    if (file.size > kPickedFileBytesFallbackMaxBytes) {
      throw const PickedFileMaterializationException(
        PickedFileMaterializationFailure.tooLargeForBytesFallback,
      );
    }

    final Uint8List? bytes = await _readPlatformFileBytes(file);
    if (bytes == null) {
      throw const PickedFileMaterializationException(
        PickedFileMaterializationFailure.unreadable,
      );
    }

    final File destination =
        importDestination ?? await _createTempFile(fallbackBaseName);
    await destination.writeAsBytes(bytes, flush: true);
    return MaterializedPickedFile(
      file: destination,
      shouldDeleteAfterUse: true,
      sourceKind: PickedFileSourceKind.bytesFallback,
    );
  }

  bool _isCachedLocalPath(PlatformFile file) {
    final String? path = file.path;
    if (path == null || path.isEmpty || path.startsWith('content://')) {
      return false;
    }
    try {
      return File(path).existsSync();
    } on Object {
      return false;
    }
  }

  String? _resolveContentUri(PlatformFile file) {
    for (final String? candidate in <String?>[file.path, file.identifier]) {
      if (candidate != null &&
          candidate.isNotEmpty &&
          candidate.startsWith('content://')) {
        return candidate;
      }
    }
    if (file is AndroidPlatformFile && file.safHandle.uri.scheme == 'content') {
      return file.safHandle.uri.toString();
    }
    return null;
  }

  Future<void> _copyAndroidUriToPath({
    required String sourceUri,
    required File destinationFile,
  }) async {
    final CopyAndroidUriToPath? override = _copyAndroidUriToPathOverride;
    if (override != null) {
      await override(sourceUri: sourceUri, destinationFile: destinationFile);
      return;
    }
    await AndroidContentUriImport.copyUriToPath(
      sourceUri: sourceUri,
      destinationFile: destinationFile,
    );
  }

  Future<Uint8List?> _readPlatformFileBytes(PlatformFile file) async {
    final ReadPlatformFileBytes? override = _readPlatformFileBytesOverride;
    if (override != null) {
      return override(file);
    }

    try {
      final Uint8List bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        return null;
      }
      return bytes;
    } on Object {
      return null;
    }
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

  Future<void> _deleteIfExists(File file) async {
    if (file.existsSync()) {
      await file.delete();
    }
  }
}
