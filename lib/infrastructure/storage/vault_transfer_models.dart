import 'dart:io';

import 'package:file_picker/file_picker.dart';

typedef PickPortableFiles =
    Future<FilePickerResult?> Function({
      required String dialogTitle,
      required List<String> allowedExtensions,
    });

enum BackupPersistStatus { success, inspectFailed, cancelled }

final class BackupPersistResult {
  const BackupPersistResult({
    required this.status,
    this.savedPath,
    this.message = '',
  });

  final BackupPersistStatus status;
  final String? savedPath;
  final String message;
}

final class PickedBackupFile {
  const PickedBackupFile({
    required this.file,
    required this.shouldDeleteAfterUse,
  });

  final File file;
  final bool shouldDeleteAfterUse;
}

final class LocalBackupFile {
  const LocalBackupFile({
    required this.name,
    required this.path,
    required this.createdAt,
    required this.sizeBytes,
  });

  final String name;
  final String path;
  final DateTime createdAt;
  final int sizeBytes;
}
