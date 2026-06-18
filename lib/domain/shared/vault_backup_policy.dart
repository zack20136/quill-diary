import 'package:path/path.dart' as p;

/// 備份與可攜匯出的檔名規則，供 App 本機與 Google Drive 共用。
abstract final class VaultBackupPolicy {
  static const int retainCount = 5;

  /// 備份封存檔使用 zip 副檔名。
  static const String fileExtension = 'zip';

  /// HTML 匯出使用單一 html 檔案。
  static const String htmlFileExtension = 'html';

  /// 備份封存檔命名為 `backup_YYYY-MM-DD_HH-MM-SS.zip`。
  static String backupFileName(DateTime timestamp) {
    return 'backup_${_formatTimestamp(timestamp)}.$fileExtension';
  }

  /// Markdown 匯出封存檔命名為 `markdown_YYYY-MM-DD_HH-MM-SS.zip`。
  static String markdownPortableFileName(DateTime timestamp) {
    return 'markdown_${_formatTimestamp(timestamp)}.$fileExtension';
  }

  /// HTML 匯出檔命名為 `html_YYYY-MM-DD_HH-MM-SS.html`。
  static String htmlPortableFileName(DateTime timestamp) {
    return 'html_${_formatTimestamp(timestamp)}.$htmlFileExtension';
  }

  static String _formatTimestamp(DateTime timestamp) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${timestamp.year}-${two(timestamp.month)}-${two(timestamp.day)}_'
        '${two(timestamp.hour)}-${two(timestamp.minute)}-${two(timestamp.second)}';
  }

  /// 檢查路徑是否為 vault 備份 zip 檔。
  static bool hasVaultBackupExtension(String path) {
    return p.extension(path).toLowerCase() == '.$fileExtension';
  }
}
