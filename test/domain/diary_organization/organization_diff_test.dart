import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/diary_organization/organization_diff.dart';

void main() {
  test('替換區塊先顯示所有舊行，再顯示所有新行', () {
    final lines = organizationDiffLines('開頭\n舊段一\n舊段二\n結尾', '開頭\n新段一\n新段二\n結尾');
    expect(lines.map((line) => line.kind), [
      OrganizationDiffKind.same,
      OrganizationDiffKind.removed,
      OrganizationDiffKind.removed,
      OrganizationDiffKind.added,
      OrganizationDiffKind.added,
      OrganizationDiffKind.same,
    ]);
    expect(lines[1].text, '舊段一\n');
    expect(lines[3].text, '新段一\n');
    expect(
      lines[1].spans
          .where((s) => s.kind == OrganizationDiffKind.removed)
          .single
          .text,
      '舊',
    );
  });

  test('中文與組合 emoji 差異保留完整字素', () {
    final lines = organizationDiffLines(
      '今天👨‍👩‍👧‍👦散步。\n天氣好',
      '今天👨‍👩‍👧‍👦去散步！\n天氣好',
    );
    expect(
      lines.first.spans.where((s) => s.text.contains('👨')).single.text,
      contains('👨‍👩‍👧‍👦'),
    );
    final added = lines.singleWhere(
      (line) => line.kind == OrganizationDiffKind.added,
    );
    expect(
      added.spans
          .where((s) => s.kind == OrganizationDiffKind.added)
          .map((s) => s.text),
      ['去', '！'],
    );
  });

  for (final pair in [
    ('', '新增\n內容'),
    ('刪除\n內容', ''),
    ('相同\n\n結尾\n', '相同\n\n結尾\n'),
    ('開頭\n刪除行\n結尾', '開頭\n結尾'),
    ('開頭\n結尾', '開頭\n新增行\n結尾'),
    ('段落\n\n結尾', '段落\n結尾\n'),
    ('內容', '內容\n'),
    ('內容\r\n下一行\r', '內容\n下一行\n'),
    ('原文\n' * 600, '改稿\n' * 600),
    ('甲' * 1000, '乙' * 1000),
  ]) {
    test('逐行差異可完整重建兩側內容：案例 ${pair.$1.length}／${pair.$2.length}', () {
      final lines = organizationDiffLines(pair.$1, pair.$2);
      expect(
        lines
            .where((l) => l.kind != OrganizationDiffKind.added)
            .map((l) => l.text)
            .join(),
        pair.$1,
      );
      expect(
        lines
            .where((l) => l.kind != OrganizationDiffKind.removed)
            .map((l) => l.text)
            .join(),
        pair.$2,
      );
      for (final line in lines) {
        expect(line.spans.map((s) => s.text).join(), line.text);
      }
    });
  }
}
