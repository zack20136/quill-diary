/// 卡片、面板、縮圖與版面裝飾共用的圓角 token。
abstract final class PageStyle {
  PageStyle._();

  static const double radiusPanel = 18;
  static const double radiusCard = 20;
  static const double radiusEntry = 22;
  static const double radiusThumbSmall = 12;
  static const double radiusThumb = 14;

  static const double pageHorizontalPadding = 16;
  static const double pageTopPadding = 12;
  static const double pageBottomPadding = 24;
  static const double sectionGap = 16;
  static const double feedbackHorizontalInset = 16;
  static const double feedbackBottomInset = 16;

  /// 達到這個寬度時，自適應面板改以置中對話框呈現。
  static const double wideBreakpoint = 600;
}
