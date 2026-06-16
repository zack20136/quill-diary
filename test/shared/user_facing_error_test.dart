import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/shared/utils/user_facing_error.dart';

void main() {
  group('userFacingErrorMessage', () {
    test('StateError 回傳 message', () {
      expect(userFacingErrorMessage(StateError('無法讀取備份檔')), '無法讀取備份檔');
    });

    test('FormatException 回傳 message', () {
      expect(
        userFacingErrorMessage(const FormatException('草稿格式不正確。')),
        '草稿格式不正確。',
      );
    });

    test('空 message 使用 fallback', () {
      expect(userFacingErrorMessage(StateError('   ')), '操作失敗，請稍後再試。');
    });

    test('其他型別使用 fallback', () {
      expect(userFacingErrorMessage(Exception('internal')), '操作失敗，請稍後再試。');
      expect(
        userFacingErrorMessage(Exception('internal'), fallback: '自訂錯誤'),
        '自訂錯誤',
      );
    });
  });

  group('stripLocalPathsFromMessage', () {
    test('Windows 路徑替換為本機檔案', () {
      expect(
        stripLocalPathsFromMessage('無法開啟 C:\\Users\\me\\secret.md'),
        '無法開啟 本機檔案',
      );
    });

    test('Unix 風格路徑替換為本機檔案', () {
      expect(stripLocalPathsFromMessage('無法開啟 D:/data/secret.md'), '無法開啟 本機檔案');
    });

    test('一般文字不被誤改', () {
      const String message = '復原金鑰與此備份不相符。';
      expect(stripLocalPathsFromMessage(message), message);
    });
  });
}
