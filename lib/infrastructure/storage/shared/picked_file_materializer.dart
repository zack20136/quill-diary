import 'dart:io';

import 'package:android_file_picker/android_file_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:quill_diary/infrastructure/storage/shared/vault_file_ops.dart';
import 'package:quill_diary/infrastructure/storage/vault_path_strategy.dart';
import 'package:quill_diary/shared/app_identifiers.dart';

typedef ReadPlatformFileBytes = Future<Uint8List?> Function(PlatformFile file);

typedef CopyAndroidUriToPath = Future<void> Function({
  required String sourceUri,
  required File destinationFile,
});

/// 測試用整檔讀取上限。實際選檔使用檔案或 URI 串流。
@visibleForTesting
const int kPickedFileBytesFallbackMaxBytes = 64 * 1024 * 1024;

enum PickedFileMaterializationFailure { unreadable, tooLargeForBytesFallback }

final class PickedFileMaterializationException implements Exception {
  const PickedFileMaterializationException(this.failure, {this.cause});

  final PickedFileMaterializationFailure failure;
  final Object? cause;
}

final class MaterializedPickedFile {
  const MaterializedPickedFile({
    required this.file,
    required this.shouldDeleteAfterUse,
  });

  final File file;
  final bool shouldDeleteAfterUse;
}

class PickedFileMaterializer {
  PickedFileMaterializer({
    CopyAndroidUriToPath? copyAndroidUriToPath,
    ReadPlatformFileBytes? readPlatformFileBytes,
    this.allowBytesFallback = false,
    this._pathStrategy = const VaultPathStrategy(),
  }) : _copyUri = copyAndroidUriToPath ?? _copyAndroidUriToPath,
       _readPlatformFileBytesOverride = readPlatformFileBytes;

  final bool allowBytesFallback;

  static const MethodChannel _contentUriChannel = MethodChannel(
    AppIdentifiers.contentUriImportChannel,
  );

  final CopyAndroidUriToPath _copyUri;
  final ReadPlatformFileBytes? _readPlatformFileBytesOverride;
  final VaultPathStrategy _pathStrategy;

  Future<MaterializedPickedFile> materialize(
    PlatformFile file, {
    required String fallbackBaseName,
    required bool alwaysCopyToTemp,
    File? importDestination,
  }) async {
    final File? localFile = _cachedLocalFile(file);
    if (localFile != null) {
      if (!alwaysCopyToTemp) {
        return MaterializedPickedFile(
          file: localFile,
          shouldDeleteAfterUse: false,
        );
      }
      return _writeTemporary(
        importDestination ?? await _createTempFile(fallbackBaseName),
        (File destination) => copyFileToPath(localFile, destination.path),
      );
    }

    final String? contentUri = _resolveContentUri(file);
    if (contentUri != null) {
      try {
        return await _writeTemporary(
          importDestination ?? await _createTempFile(fallbackBaseName),
          (File destination) =>
              _copyUri(sourceUri: contentUri, destinationFile: destination),
        );
      } on Object catch (error, stackTrace) {
        Error.throwWithStackTrace(
          PickedFileMaterializationException(
            PickedFileMaterializationFailure.unreadable,
            cause: error,
          ),
          stackTrace,
        );
      } finally {
        if (file is AndroidPlatformFile) {
          try {
            await file.safHandle?.releaseGrant();
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

    final int? knownLength = file.lengthSync() ?? await file.length();
    if (knownLength == null) {
      throw const PickedFileMaterializationException(
        PickedFileMaterializationFailure.unreadable,
      );
    }
    if (knownLength > kPickedFileBytesFallbackMaxBytes) {
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

    if (bytes.length > kPickedFileBytesFallbackMaxBytes) {
      throw const PickedFileMaterializationException(
        PickedFileMaterializationFailure.tooLargeForBytesFallback,
      );
    }
    return _writeTemporary(
      importDestination ?? await _createTempFile(fallbackBaseName),
      (File destination) => destination.writeAsBytes(bytes, flush: true),
    );
  }

  Future<MaterializedPickedFile> _writeTemporary(
    File destination,
    Future<void> Function(File destination) write,
  ) async {
    // 先取得暫存檔所有權，避免失敗時清除既有檔案。
    await destination.create(recursive: true, exclusive: true);
    try {
      await write(destination);
    } on Object {
      try {
        await destination.delete();
      } on FileSystemException {
        // 清理失敗不能蓋掉原始錯誤。
      }
      rethrow;
    }
    return MaterializedPickedFile(
      file: destination,
      shouldDeleteAfterUse: true,
    );
  }

  File? _cachedLocalFile(PlatformFile file) {
    final String? path = file.path;
    if (path == null || path.isEmpty) return null;
    try {
      final File candidate = File(path);
      return candidate.existsSync() ? candidate : null;
    } on FileSystemException {
      return null;
    }
  }

  String? _resolveContentUri(PlatformFile file) {
    if (file.uri.scheme == 'content') {
      return file.uri.toString();
    }
    final Uri? safUri = file is AndroidPlatformFile
        ? file.safHandle?.uri
        : null;
    if (safUri != null && safUri.scheme == 'content') {
      return safUri.toString();
    }
    return null;
  }

  static Future<void> _copyAndroidUriToPath({
    required String sourceUri,
    required File destinationFile,
  }) => _contentUriChannel.invokeMethod<void>('copyUriToPath', <String, String>{
    'sourceUri': sourceUri,
    'destinationPath': destinationFile.absolute.path,
  });

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
    final Directory tempDirectory = await _pathStrategy.transferWorkDirectory();
    return File(
      p.join(
        tempDirectory.path,
        '${DateTime.now().microsecondsSinceEpoch}_${p.posix.basename(fileName.replaceAll('\\', '/'))}',
      ),
    );
  }
}
