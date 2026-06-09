/// 跨功能共用的繁體中文 UI 文案。
abstract final class CommonCopy {
  static const String actionCancel = '取消';
  static const String actionDelete = '刪除';
  static const String actionApply = '套用';
  static const String actionClose = '關閉';

  static const String readFailureTitle = '讀取失敗';
  static const String confirmDeleteTitle = '確認刪除';
  static const String noTagSearchResults = '沒有符合的標籤';

  static const String closeTooltip = '關閉';
  static const String clearSearchTooltip = '清除搜尋';

  static String confirmDeleteEntries(int count) =>
      '確定要刪除 $count 篇日記嗎？刪除後無法復原。';
}
