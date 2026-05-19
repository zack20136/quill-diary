import 'package:flutter_test/flutter_test.dart';
import 'package:quill_lock_diary/domain/shared/value_objects.dart';

void main() {
  test('normalizeText 折疊空白並轉小寫', () {
    expect(normalizeText('  Hello   World  '), 'hello world');
    expect(normalizeText('TAG'), 'tag');
  });

  test('previewTextFromMarkdown 移除標記並截斷', () {
    const String markdown = '# 標題\n\n這是一段 **粗體** 與 `code` 的文字內容，用來測試預覽截斷行為。';
    final String preview = previewTextFromMarkdown(markdown, maxLength: 20);
    expect(preview.length, lessThanOrEqualTo(23));
    expect(preview, contains('...'));
    expect(preview, isNot(contains('#')));
  });

  test('previewTextFromMarkdown 短文字不截斷', () {
    expect(previewTextFromMarkdown('短內容'), '短內容');
  });

  test('DateOnly 解析與欄位', () {
    const DateOnly date = DateOnly('2026-05-13');
    expect(date.year, 2026);
    expect(date.monthPadded, '05');
    expect(date.yearString, '2026');
    expect(date.toString(), '2026-05-13');
    expect(DateOnly.fromDateTime(DateTime.parse('2026-05-13T15:00:00Z')).value, '2026-05-13');
  });
}
