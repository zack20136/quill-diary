import 'package:quill_diary/app/app_identifiers.dart';
import '../../shared/presentation/display_format.dart';

/// 使用者可見的匯出子資料夾（Pictures / Download 共用 `quill-diary`）。
abstract final class UserExportPaths {
  static const String subfolderName = AppIdentifiers.downloadsExportDirectory;

  static String picturesDisplayPath(String fileName) =>
      'Pictures / $subfolderName / $fileName';

  static String downloadsDisplayPath(String fileName) =>
      DisplayFormat.formatDownloadsDisplayPath(fileName);
}
