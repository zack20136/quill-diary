import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/shared/utils/user_facing_error.dart';

import '../helpers/test_l10n.dart';

void main() {
  group('userFacingErrorMessage', () {
    test('returns StateError message when present', () {
      expect(
        userFacingErrorMessage(StateError('無法讀取資料'), l10n: testZhL10n),
        '無法讀取資料',
      );
    });

    test('returns FormatException message when present', () {
      expect(
        userFacingErrorMessage(
          const FormatException('草稿內容格式錯誤'),
          l10n: testZhL10n,
        ),
        '草稿內容格式錯誤',
      );
    });

    test('falls back to localized default when message is blank', () {
      expect(
        userFacingErrorMessage(StateError('   '), l10n: testZhL10n),
        testZhL10n.userFacingErrorDefaultMessage,
      );
    });

    test('falls back to localized default for non-user-facing errors', () {
      expect(
        userFacingErrorMessage(Exception('internal'), l10n: testZhL10n),
        testZhL10n.userFacingErrorDefaultMessage,
      );
    });

    test('uses caller fallback override when provided', () {
      expect(
        userFacingErrorMessage(
          Exception('internal'),
          l10n: testZhL10n,
          fallback: '請稍後重試',
        ),
        '請稍後重試',
      );
    });
  });

  group('stripLocalPathsFromMessage', () {
    test('replaces Windows paths with localized label', () {
      expect(
        stripLocalPathsFromMessage(
          '無法開啟 C:\\Users\\me\\secret.md',
          l10n: testZhL10n,
        ),
        '無法開啟 本機路徑',
      );
    });

    test('replaces POSIX paths with localized label', () {
      expect(
        stripLocalPathsFromMessage(
          '無法讀取 /data/user/0/com.example/files/secret.md',
          l10n: testZhL10n,
        ),
        '無法讀取 本機路徑',
      );
    });

    test('replaces macOS style paths with localized label', () {
      expect(
        stripLocalPathsFromMessage(
          '錯誤位置：/Users/me/Documents/private/diary.md。',
          l10n: testZhL10n,
        ),
        '錯誤位置：本機路徑。',
      );
    });

    test('does not rewrite urls', () {
      const String message = '請參考 https://example.com/docs/path';
      expect(stripLocalPathsFromMessage(message, l10n: testZhL10n), message);
    });

    test('keeps ordinary slash text unchanged', () {
      const String message = '格式應為 標題/分類/日期';
      expect(stripLocalPathsFromMessage(message, l10n: testZhL10n), message);
    });
  });
}
