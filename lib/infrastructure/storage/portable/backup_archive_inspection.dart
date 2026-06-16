import 'dart:convert';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../../domain/recovery/recovery_metadata.dart';
import '../shared/archive_extract.dart';

/// 完整日記庫備份 zip 的內部結構檢查結果。
final class VaultBackupLayout {
  const VaultBackupLayout({
    required this.safePaths,
    required this.hasRecovery,
    required this.hasManifest,
    required this.entrySampleFound,
    required this.hasVaultPayload,
    required this.hasMarkdownPortableLayout,
  });

  static const VaultBackupLayout empty = VaultBackupLayout(
    safePaths: true,
    hasRecovery: false,
    hasManifest: false,
    entrySampleFound: false,
    hasVaultPayload: false,
    hasMarkdownPortableLayout: false,
  );

  final bool safePaths;
  final bool hasRecovery;
  final bool hasManifest;
  final bool entrySampleFound;
  final bool hasVaultPayload;

  /// 是否為可攜式 Markdown 匯出 zip（`{YYYY-MM-DD}/{標題}/index.md`）。
  final bool hasMarkdownPortableLayout;

  bool get isRestorable =>
      safePaths &&
      !hasMarkdownPortableLayout &&
      hasRecovery &&
      (hasManifest || entrySampleFound);

  /// 第一個未通過條件的使用者可讀說明。
  String get failureMessage {
    if (!safePaths) {
      return '備份內含不安全路徑。';
    }
    if (hasMarkdownPortableLayout) {
      return '此 zip 為日記匯出檔，不是完整備份。';
    }
    if (!hasRecovery) {
      return '缺少復原金鑰資訊。';
    }
    if (!hasManifest && !entrySampleFound) {
      return '缺少加密資料。';
    }
    return '備份檔內容不完整，缺少必要的加密資料。';
  }

  static const String invalidRecoveryJsonMessage = 'recovery.json 格式無法解析。';
  static const String invalidZipMessage = '備份檔不是有效的 zip 備份，請重新建立備份。';
  static const String missingFileMessage = '找不到備份檔案，請重新建立一次備份。';
}

/// 依 zip 內 entry 路徑掃描完整備份結構（不解壓內容）。
VaultBackupLayout inspectZipEntryNames(Iterable<String> rawNames) {
  var safePaths = true;
  var hasRecovery = false;
  var hasManifest = false;
  var entrySampleFound = false;
  var hasVaultPayload = false;
  var hasMarkdownPortableLayout = false;

  for (final String rawName in rawNames) {
    final String normalized = p.posix.normalize(rawName.replaceAll('\\', '/'));
    if (_isPortableMarkdownExportPath(normalized)) {
      hasMarkdownPortableLayout = true;
    }
    try {
      ensureSafeArchivePath(rawName);
    } on FormatException {
      safePaths = false;
    }
    if (normalized == 'recovery.json' ||
        normalized.endsWith('/recovery.json')) {
      hasRecovery = true;
    }
    if (normalized == 'manifest.json.enc' ||
        normalized.endsWith('/manifest.json.enc')) {
      hasManifest = true;
    }
    if (normalized.startsWith('entries/') && normalized.endsWith('.md.enc')) {
      entrySampleFound = true;
    }
    if (normalized.startsWith('entries/') || normalized.startsWith('assets/')) {
      hasVaultPayload = true;
    }
  }

  return VaultBackupLayout(
    safePaths: safePaths,
    hasRecovery: hasRecovery,
    hasManifest: hasManifest,
    entrySampleFound: entrySampleFound,
    hasVaultPayload: hasVaultPayload,
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
