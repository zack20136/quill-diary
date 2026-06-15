import '../../infrastructure/preferences/personalization_preferences.dart';
import '../../infrastructure/preferences/user_preferences.dart';

/// 個人化設定頁文案（單一來源）。
abstract final class PersonalizationCopy {
  static const String navButtonLabel = '個人化';
  static const String pageTitle = '個人化';
  static const String loadErrorMessage = '無法載入個人化設定。';

  static const String typographyResetButton = '還原預設';
  static const String typographyResetConfirmTitle = '還原日記排版預設？';
  static const String typographyResetConfirmBody =
      '標題、內文字體大小、行距與段落間距都會恢復為預設值。';
  static const String typographyResetConfirmAction = '還原預設';
  static const String typographyResetSuccess = '已還原日記排版預設。';

  static const String languageSectionTitle = '語言';
  static const String languageSectionDescription = '選擇介面顯示語言。';
  static const String languageZhTwLabel = '繁體中文';
  static const String languageEnLabel = 'English';
  static const String languageComingSoonHint = 'English 即將推出。';

  static const String sessionTimeoutSectionTitle = '自動鎖定';
  static const String sessionTimeoutSectionDescription =
      'App 進入背景超過選定時間後，再次開啟需重新解鎖。';
  static String sessionTimeoutSegmentLabel(SessionBackgroundTimeoutMinutes value) {
    return '${value.minutes} 分鐘';
  }

  static const String imageCompressSectionTitle = '圖片品質';
  static const String imageCompressSectionDescription =
      '從相簿新選取的圖片，插入日記前的壓縮方式。';
  static const String imageCompressOriginalLabel = '原圖';
  static const String imageCompressStandardLabel = '標準';
  static const String imageCompressHighLabel = '高畫質';

  static String imageCompressDescription(ImageCompressPreset preset) {
    return switch (preset) {
      ImageCompressPreset.original =>
        '不壓縮，保留原始解析度與檔案大小。適合需要最高畫質、可接受較大日記庫時使用。',
      ImageCompressPreset.standard =>
        '長邊縮至 1280 px、JPEG 品質 70。在清晰度與儲存空間之間取得平衡（預設）。',
      ImageCompressPreset.high =>
        '長邊縮至 1920 px、JPEG 品質 85。檔案較大，但細節保留較多。',
    };
  }

  static const String appearanceSectionTitle = '主題顏色';
  static const String appearanceSectionDescription =
      '選擇淺色、深色或跟隨系統主題。';
  static const String appearanceSystemLabel = '跟隨系統';
  static const String appearanceLightLabel = '淺色';
  static const String appearanceDarkLabel = '深色';

  static const String typographySectionTitle = '日記排版';
  static const String typographySectionDescription =
      '調整編輯器與預覽中的標題、內文字體大小、行距與段落間距。';
  static const String titleFontSizeLabel = '標題字體大小';
  static const String titleLineHeightLabel = '標題行距';
  static const String bodyFontSizeLabel = '內文字體大小';
  static const String bodyLineHeightLabel = '內文行距';
  static const String bodyParagraphSpacingLabel = '內文段落間距';
  static String fontSizeValue(double size) => '${_formatNumber(size)} 點';
  static String lineHeightValue(double height) => '${_formatNumber(height)} 倍';
  static String paragraphSpacingValue(double spacing) =>
      '${_formatNumber(spacing)} 像素';

  static const List<String> typographyPreviewTitleParagraphs = <String>[
    '今日的小確幸，陽光剛好落在書桌上。值得記住的一刻，先寫下來再說。',
  ];

  static const List<String> typographyPreviewBodyParagraphs = <String>[
    '記錄下此刻的心情，讓文字替記憶保溫。記錄下此刻的心情，讓文字替記憶保溫。',
    '段落之間的間距，也會反映在預覽裡。段落之間的間距，也會反映在預覽裡。',
  ];

  static String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }
}
