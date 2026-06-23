import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/infrastructure/storage/portable/html_import_parser.dart';

void main() {
  test('extractQuillDiaryTags 可讀取標籤清單', () {
    const String articleHtml = '''
<ul class="tags">
  <li>工作</li>
  <li>  旅遊 </li>
</ul>
''';

    expect(extractQuillDiaryTags(articleHtml), <String>['工作', '旅遊']);
  });
}
