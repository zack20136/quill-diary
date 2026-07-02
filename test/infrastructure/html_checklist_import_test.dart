import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/infrastructure/storage/portable/html_import_parser.dart';
import 'package:quill_diary/infrastructure/storage/portable/portable_export_io.dart';

void main() {
  test('checklist markdown round-trips through html export and import', () {
    const String markdown = '前言\n- [ ] 買牛奶\n- [x] 回覆信件\n結尾';
    final String html = exportMarkdownBodyToHtml(markdown);
    expect(html, contains('class="task-list"'));
    expect(html, contains('type="checkbox"'));

    final String imported = exportHtmlBodyToMarkdown(html);
    expect(imported, contains('- [ ] 買牛奶'));
    expect(imported, contains('- [x] 回覆信件'));
    expect(imported, contains('前言'));
    expect(imported, contains('結尾'));
    expect(imported, isNot(contains('- 買牛奶')));
  });
}
