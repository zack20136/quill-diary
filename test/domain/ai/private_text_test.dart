import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/ai/private_text.dart';

void main() {
  test('插入刪除與取代保持私密區間', () {
    var ranges = [const PrivateTextRange(2, 4)];
    ranges = updatePrivateRanges('前言秘密結尾', '新前言秘密結尾', ranges);
    expect(ranges.single.start, 3);
    expect(ranges.single.end, 5);
    ranges = updatePrivateRanges('新前言秘密結尾', '新前言新秘密結尾', ranges);
    expect(ranges.single.start, 3);
    expect(ranges.single.end, 6);
    ranges = updatePrivateRanges('新前言新秘密結尾', '新前言結尾', ranges);
    expect(ranges, isEmpty);
  });

  test('部分取消隱藏會拆成兩段且重疊標記會合併', () {
    final ranges = mergePrivateRanges([
      const PrivateTextRange(0, 4),
      const PrivateTextRange(2, 8),
    ], 10);
    final parts = removePrivateRange(ranges, 3, 5);
    expect(parts.map((r) => (r.start, r.end)), [(0, 3), (5, 8)]);
  });

  test('整段貼上取代不會解除原本的保護', () {
    final ranges = updatePrivateRanges('公開秘密文字', '重新貼上的內容', [
      const PrivateTextRange(2, 4),
    ]);
    expect(ranges.single.start, 0);
    expect(ranges.single.end, 7);
  });
}
