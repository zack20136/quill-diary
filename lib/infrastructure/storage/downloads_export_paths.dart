import '../../config/app_identifiers.dart';
import '../../shared/presentation/display_format.dart';

/// 使用者可見的匯出 / 備份子資料夾名稱（位於 Downloads 底下）。
abstract final class DownloadsExportPaths {
  static const String subfolderName = AppIdentifiers.downloadsExportDirectory;

  static String displayPath(String fileName) =>
      DisplayFormat.formatDownloadsDisplayPath(fileName);
}
