import 'package:url_launcher/url_launcher.dart';

/// 在外部瀏覽器開啟 [url]。成功回傳 true；無法開啟回傳 false。
Future<bool> launchExternalUrl(String url) async {
  final Uri uri = Uri.parse(url);
  if (!await canLaunchUrl(uri)) {
    return false;
  }
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
