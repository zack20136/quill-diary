/// 標籤編輯對話框的繁體中文 UI 文案。
abstract final class TagCopy {
  static const String addTitle = '新增標籤';
  static const String editTitle = '編輯標籤';
  static const String saveButton = '儲存';
  static const String nameHint = '標籤名稱';
  static const String nameRequiredMessage = '請輸入標籤名稱';
  static const String deleteLabel = '刪除標籤';

  static String saveFailure(String message) => '儲存標籤失敗：$message';
  static String deleteFailure(String message) => '刪除標籤失敗：$message';
}
