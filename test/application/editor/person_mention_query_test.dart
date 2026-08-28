import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/application/editor/person_mention_query.dart';

void main() {
  group('findActivePersonMentionQuery', () {
    test('偵測游標前的 @查詢', () {
      const String input = '今天和 @小';
      final ActivePersonMentionQuery? q = findActivePersonMentionQuery(
        text: input,
        cursor: input.length,
      );
      expect(q, isNotNull);
      expect(q!.atIndex, 4);
      expect(q.query, '小');
    });

    test('行首單獨 @ 即可觸發', () {
      const String input = '@';
      final ActivePersonMentionQuery? q = findActivePersonMentionQuery(
        text: input,
        cursor: input.length,
      );
      expect(q, isNotNull);
      expect(q!.atIndex, 0);
      expect(q.query, isEmpty);
    });

    test('緊接在文字後面的 @ 也可觸發', () {
      const String input = '今天和@小';
      final ActivePersonMentionQuery? q = findActivePersonMentionQuery(
        text: input,
        cursor: input.length,
      );
      expect(q, isNotNull);
      expect(q!.atIndex, 3);
      expect(q.query, '小');
    });

    test('ASCII 字元後的 @ 也可觸發', () {
      const String input = 'hello@';
      final ActivePersonMentionQuery? q = findActivePersonMentionQuery(
        text: input,
        cursor: input.length,
      );
      expect(q, isNotNull);
      expect(q!.atIndex, 5);
      expect(q.query, isEmpty);
    });

    test('全形 ＠ 也可觸發', () {
      const String input = '見到＠阿';
      final ActivePersonMentionQuery? q = findActivePersonMentionQuery(
        text: input,
        cursor: input.length,
      );
      expect(q, isNotNull);
      expect(q!.atIndex, 2);
      expect(q.query, '阿');
    });

    test('query 含網域點號不觸發', () {
      const String input = 'a@b.com';
      expect(
        findActivePersonMentionQuery(text: input, cursor: input.length),
        isNull,
      );
    });

    test('query 超過 40 字元關閉', () {
      final String query = 'a' * 41;
      final String input = '@$query';
      expect(
        findActivePersonMentionQuery(text: input, cursor: input.length),
        isNull,
      );
    });
  });

  group('replacePersonMentionWithName', () {
    test('以指定名稱取代 @查詢且不留 @', () {
      const String input = '見到 @阿明 了';
      final ActivePersonMentionQuery mention = findActivePersonMentionQuery(
        text: input,
        cursor: 6,
      )!;
      final result = replacePersonMentionWithName(
        text: input,
        mention: mention,
        mentionLabel: '陳小明',
      );
      expect(result.text, '見到 陳小明 了');
      expect(result.cursor, 6);
    });

    test('可插入別名文字', () {
      const String input = '@小';
      final ActivePersonMentionQuery mention = findActivePersonMentionQuery(
        text: input,
        cursor: input.length,
      )!;
      final result = replacePersonMentionWithName(
        text: input,
        mention: mention,
        mentionLabel: '阿明',
      );
      expect(result.text, '阿明');
      expect(result.cursor, 2);
    });
  });
}
