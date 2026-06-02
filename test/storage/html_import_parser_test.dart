import 'package:flutter_test/flutter_test.dart';
import 'package:quill_lock_diary/infrastructure/storage/portable/html_import_parser.dart';

void main() {
  test('extractQuillLockDiaryMetaValue 可解析全形與半形冒號', () {
    const String metaHtml = '''
<div class="entry-meta">
  <span>建立：2026-05-30 08:00</span>
  <span>更新:2026-05-31 09:15</span>
  <span>心情：平靜</span>
</div>
''';

    expect(extractQuillLockDiaryMetaValue(metaHtml, '建立'), '2026-05-30 08:00');
    expect(extractQuillLockDiaryMetaValue(metaHtml, '更新'), '2026-05-31 09:15');
    expect(extractQuillLockDiaryMetaValue(metaHtml, '心情'), '平靜');
  });

  test('extractQuillLockDiaryTags 可讀取標籤清單', () {
    const String articleHtml = '''
<ul class="tags">
  <li>工作</li>
  <li>  旅遊 </li>
</ul>
''';

    expect(extractQuillLockDiaryTags(articleHtml), <String>['工作', '旅遊']);
  });
}
