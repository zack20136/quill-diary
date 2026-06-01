import 'package:flutter_test/flutter_test.dart';
import 'package:quill_lock_diary/domain/shared/value_objects.dart';

void main() {
  test('normalizeText trims lowercases and collapses whitespace', () {
    expect(normalizeText('  Hello   World  '), 'hello world');
    expect(normalizeText('TAG'), 'tag');
  });

  test('previewTextFromMarkdown strips markdown and truncates', () {
    const String markdown = '# Title\n\nBody **bold** and `code` with extra words';
    final String preview = previewTextFromMarkdown(markdown, maxLength: 20);
    expect(preview.length, lessThanOrEqualTo(23));
    expect(preview, contains('...'));
    expect(preview, isNot(contains('#')));
  });

  test('previewTextFromMarkdown keeps short plain text', () {
    expect(previewTextFromMarkdown('short body'), 'short body');
  });

  test('searchableTextFromMarkdown keeps full searchable body', () {
    expect(
      searchableTextFromMarkdown('# Size\n\npanel 60x30x3 with `x30` marker'),
      'Size panel 60x30x3 with x30 marker',
    );
  });

  test('DateOnly parses and exposes fields', () {
    const DateOnly date = DateOnly('2026-05-13');
    expect(date.year, 2026);
    expect(date.monthPadded, '05');
    expect(date.yearString, '2026');
    expect(date.toString(), '2026-05-13');
    expect(
      DateOnly.fromDateTime(DateTime.parse('2026-05-13T15:00:00Z')).value,
      '2026-05-13',
    );
  });
}
