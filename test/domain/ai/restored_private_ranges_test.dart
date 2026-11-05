import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/ai/restored_private_ranges.dart';

void main() {
  const originals = {'⟦P01⟧': 'QA小明🙂', '⟦S01⟧': '秘密'};

  test('人物與手動隱藏可重複及相鄰出現，普通同名文字不標記', () {
    const text = 'QA小明🙂與QA小明🙂秘密，又見QA小明🙂';
    final ranges = restoredPrivateRanges(
      outboundText: 'QA小明🙂與⟦P01⟧⟦S01⟧，又見⟦P01⟧',
      text: text,
      originals: originals,
    );
    expect(ranges.map((range) => text.substring(range.start, range.end)), [
      'QA小明🙂秘密',
      'QA小明🙂',
    ]);
    expect(ranges.first.start, 'QA小明🙂與'.length);
  });

  for (final suffix in ['⟦P', '⟦P02⟧', '⟦S01⟧']) {
    test('串流或其他分支的未還原代號 $suffix 保持原樣，不影響已還原部分', () {
      final text = 'QA小明🙂 $suffix';
      final ranges = restoredPrivateRanges(
        outboundText: '⟦P01⟧ $suffix',
        text: text,
        originals: originals,
      );
      expect(ranges.map((range) => text.substring(range.start, range.end)), [
        'QA小明🙂',
      ]);
    });
  }

  for (final text in ['前文錯誤QA小明🙂後文', '前文QA小明🙂後文多出字', '前文別名後文']) {
    test('文字無法完整對齊時不猜測隱藏區間：$text', () {
      expect(
        restoredPrivateRanges(
          outboundText: '前文⟦P01⟧後文',
          text: text,
          originals: originals,
        ),
        isEmpty,
      );
    });
  }

  test('沒有代號或對照表缺項時，不用原文搜尋推測隱藏', () {
    expect(
      restoredPrivateRanges(
        outboundText: 'QA小明🙂',
        text: 'QA小明🙂',
        originals: originals,
      ),
      isEmpty,
    );
    expect(
      restoredPrivateRanges(
        outboundText: '⟦P01⟧',
        text: 'QA小明🙂',
        originals: const {},
      ),
      isEmpty,
    );
  });
}
