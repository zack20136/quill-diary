/// 使用者可見的匯出／備份子資料夾名稱（位於 Downloads 底下）。
abstract final class DownloadsExportPaths {
  static const String subfolderName = 'quill-lock-diary';

  static String displayPath(String fileName) =>
      'Downloads/$subfolderName/$fileName';
}
