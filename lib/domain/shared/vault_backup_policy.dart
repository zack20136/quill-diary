import 'package:path/path.dart' as p;

/// 日記庫完整備份（本機 App 內、外部匯出、Google Drive）的檔名與保留策略。
abstract final class VaultBackupPolicy {
  static const int retainCount = 5;

  /// 完整備份 zip 副檔名（不含點）。
  static const String fileExtension = 'zip';

  /// HTML 可攜式匯出副檔名（不含點）。
  static const String htmlFileExtension = 'html';

  /// 外部備份 zip 檔案選擇對話框標題。
  static const String pickBackupFileDialogTitle = '選擇備份 zip';

  /// 完整備份交付至外部資料夾的選擇對話框標題。
  static const String pickBackupDirectoryTitle = '選擇匯出備份的資料夾';

  /// Markdown 可攜式匯出交付資料夾的選擇對話框標題。
  static const String pickMarkdownDirectoryTitle = '選擇匯出日記的資料夾';

  /// HTML 可攜式匯出交付資料夾的選擇對話框標題。
  static const String pickHtmlDirectoryTitle = '選擇匯出 HTML 的資料夾';

  /// 完整備份檔名：`backup_YYYY-MM-DD_HH-MM-SS.zip`。
  static String backupFileName(DateTime timestamp) {
    return 'backup_${_formatTimestamp(timestamp)}.$fileExtension';
  }

  /// Markdown 可攜式匯出 zip 檔名：`markdown_YYYY-MM-DD_HH-MM-SS.zip`。
  static String markdownPortableFileName(DateTime timestamp) {
    return 'markdown_${_formatTimestamp(timestamp)}.$fileExtension';
  }

  /// HTML 可攜式匯出檔名：`html_YYYY-MM-DD_HH-MM-SS.html`。
  static String htmlPortableFileName(DateTime timestamp) {
    return 'html_${_formatTimestamp(timestamp)}.$htmlFileExtension';
  }

  static String _formatTimestamp(DateTime timestamp) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${timestamp.year}-${two(timestamp.month)}-${two(timestamp.day)}_'
        '${two(timestamp.hour)}-${two(timestamp.minute)}-${two(timestamp.second)}';
  }

  /// 是否為完整備份 zip 副檔名。
  static bool hasVaultBackupExtension(String path) {
    return p.extension(path).toLowerCase() == '.$fileExtension';
  }
}
