import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import 'package:quill_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/storage/shared/archive_extract.dart';

enum VaultBackupIssue {
  passed,
  unsafePath,
  markdownExportNotBackup,
  missingRecovery,
  missingEncryptedData,
  incomplete,
  invalidRecoveryJson,
  invalidZip,
  missingFile,
  invalidArchive,
  recoveryKeyMismatch,
  noEncryptedSample,
  recoveryInfoMissing,
  missingVaultPayload,
  invalidBackupIntegrity,
  invalidBackupContent,
  extractionLimitExceeded,
}

class VaultBackupException implements Exception {
  const VaultBackupException(this.issue);

  final VaultBackupIssue issue;
}

/// 完整日記庫備份 zip 的內部結構檢查結果。
final class VaultBackupLayout {
  const VaultBackupLayout({
    required this.safePaths,
    required this.hasRecovery,
    required this.hasManifest,
    required this.entrySampleFound,
    required this.hasMarkdownPortableLayout,
  });

  static const VaultBackupLayout empty = VaultBackupLayout(
    safePaths: true,
    hasRecovery: false,
    hasManifest: false,
    entrySampleFound: false,
    hasMarkdownPortableLayout: false,
  );

  final bool safePaths;
  final bool hasRecovery;
  final bool hasManifest;
  final bool entrySampleFound;

  /// 是否為可攜式 Markdown 匯出 zip（`{YYYY-MM-DD}/{標題}/index.md`）。
  final bool hasMarkdownPortableLayout;

  bool get isRestorable =>
      safePaths &&
      !hasMarkdownPortableLayout &&
      hasRecovery &&
      (hasManifest || entrySampleFound);

  /// 第一個未通過條件。
  VaultBackupIssue get issue {
    if (!safePaths) {
      return VaultBackupIssue.unsafePath;
    }
    if (hasMarkdownPortableLayout) {
      return VaultBackupIssue.markdownExportNotBackup;
    }
    if (!hasRecovery) {
      return VaultBackupIssue.missingRecovery;
    }
    if (!hasManifest && !entrySampleFound) {
      return VaultBackupIssue.missingEncryptedData;
    }
    return VaultBackupIssue.incomplete;
  }
}

VaultBackupLayout inspectBackupLayout(Archive archive) {
  var safePaths = true;
  var hasRecovery = false;
  var hasManifest = false;
  var entrySampleFound = false;
  var hasMarkdownPortableLayout = false;

  for (final ArchiveFile entry in archive.files) {
    final String rawName = entry.name;
    try {
      ensureSafeArchivePath(rawName);
    } on FormatException {
      safePaths = false;
      continue;
    }
    final String normalized = p.posix.normalize(rawName.replaceAll('\\', '/'));
    final segments = p.posix.split(normalized);
    if (segments.isNotEmpty && segments.first.toLowerCase() == 'personas') {
      if (segments.first != 'personas' ||
          segments.length > 3 ||
          entry.isFile && segments.length != 3 ||
          segments.length >= 2 && !isPrefixedId(segments[1], 'per') ||
          segments.length == 3 && segments[2] != 'state.json.enc') {
        safePaths = false;
      }
    }
    if (!entry.isFile) continue;
    if (_isPortableMarkdownExportPath(normalized)) {
      hasMarkdownPortableLayout = true;
    }
    if (normalized == 'recovery.json') {
      hasRecovery = true;
    }
    if (normalized == 'manifest.json.enc') {
      hasManifest = true;
    }
    if (normalized.startsWith('entries/') && normalized.endsWith('.md.enc')) {
      entrySampleFound = true;
    }
  }

  return VaultBackupLayout(
    safePaths: safePaths,
    hasRecovery: hasRecovery,
    hasManifest: hasManifest,
    entrySampleFound: entrySampleFound,
    hasMarkdownPortableLayout: hasMarkdownPortableLayout,
  );
}

final RegExp _portableMarkdownExportDatePattern = RegExp(
  r'^\d{4}-\d{2}-\d{2}$',
);

/// 可攜式 Markdown 匯出路徑：`{YYYY-MM-DD}/{標題}/index.md`。
bool _isPortableMarkdownExportPath(String normalizedPath) {
  if (!normalizedPath.endsWith('/index.md')) {
    return false;
  }
  if (normalizedPath.startsWith('entries/')) {
    return false;
  }

  final List<String> segments = p.posix.split(normalizedPath);
  if (segments.length < 3 || segments.last != 'index.md') {
    return false;
  }

  final String dateSegment = segments[segments.length - 3];
  return _portableMarkdownExportDatePattern.hasMatch(dateSegment);
}

/// 解析 recovery.json 內容；格式錯誤回傳 null。
RecoveryMetadata? parseRecoveryMetadataBytes(Uint8List bytes) {
  try {
    final Object? decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, Object?>) {
      return null;
    }
    return RecoveryMetadata.fromJson(decoded);
  } on Object {
    return null;
  }
}
