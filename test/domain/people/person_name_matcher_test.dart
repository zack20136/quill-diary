import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/people/person.dart';
import 'package:quill_diary/domain/people/person_name_matcher.dart';

Person _person({
  required String id,
  required String name,
  List<String> aliases = const <String>[],
}) {
  final DateTime now = DateTime(2026, 1, 1);
  return Person(
    id: id,
    name: name,
    aliases: aliases,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('PersonNameMatcher', () {
    test('同篇多次與多別名只算一人一次', () {
      final PersonNameMatcher matcher = PersonNameMatcher(<Person>[
        _person(id: 'p1', name: '小明', aliases: <String>['阿明']),
      ]);
      final Set<String> hits = matcher.matchTitleAndBody(
        title: '和小明吃飯',
        body: '阿明說下次再約小明',
      );
      expect(hits, <String>{'p1'});
    });

    test('一篇可同時命中多人', () {
      final PersonNameMatcher matcher = PersonNameMatcher(<Person>[
        _person(id: 'p1', name: '小明'),
        _person(id: 'p2', name: '小華'),
      ]);
      expect(matcher.match('今天小明與小華碰面'), <String>{'p1', 'p2'});
    });

    test('最長名稱優先', () {
      final PersonNameMatcher matcher = PersonNameMatcher(<Person>[
        _person(id: 'short', name: '王'),
        _person(id: 'long', name: '王小明'),
      ]);
      expect(matcher.match('見到王小明'), <String>{'long'});
    });

    test('中文、英數與混合姓名在中文、空白及標點旁皆可命中', () {
      final PersonNameMatcher matcher = PersonNameMatcher(<Person>[
        _person(id: 'test', name: 'test'),
        _person(id: 'xiaoming', name: '小明'),
        _person(id: 'mixed', name: '張1a'),
      ]);
      final Map<String, Set<String>> cases = <String, Set<String>>{
        '今天跟test去哪': <String>{'test'},
        '今天跟小明去哪': <String>{'xiaoming'},
        '今天跟小明、test去哪': <String>{'xiaoming', 'test'},
        '今天跟小明 test去哪': <String>{'xiaoming', 'test'},
        '今天跟 test 去哪': <String>{'test'},
        '今天跟張1a去哪': <String>{'mixed'},
        '今天跟小明test去哪': <String>{'xiaoming', 'test'},
      };

      for (final MapEntry<String, Set<String>> testCase in cases.entries) {
        expect(
          matcher.match(testCase.key),
          testCase.value,
          reason: testCase.key,
        );
      }
    });

    test('姓名首尾與其他 ASCII 英數相連時不誤命中', () {
      final PersonNameMatcher matcher = PersonNameMatcher(<Person>[
        _person(id: 'test', name: 'test'),
        _person(id: 'number', name: '65485'),
        _person(id: 'mixed', name: '張1a'),
      ]);
      expect(matcher.match('testing'), isEmpty);
      expect(matcher.match('latest'), isEmpty);
      expect(matcher.match('contest'), isEmpty);
      expect(matcher.match('test123'), isEmpty);
      expect(matcher.match('test65485'), isEmpty);
      expect(matcher.match('atest'), isEmpty);
      expect(matcher.match('張1abc'), isEmpty);
      expect(matcher.match('met test today'), <String>{'test'});
      expect(matcher.match('TEST去哪'), <String>{'test'});
    });

    test('標題與正文命中結果取聯集', () {
      final PersonNameMatcher matcher = PersonNameMatcher(<Person>[
        _person(id: 'test', name: 'test'),
        _person(id: 'mixed', name: '張1a'),
      ]);

      expect(
        matcher.matchTitleAndBody(title: '和 TEST 見面', body: '後來張1a也到了'),
        <String>{'test', 'mixed'},
      );
    });

    test('findSpans 回傳原文區間且最長優先', () {
      final PersonNameMatcher matcher = PersonNameMatcher(<Person>[
        _person(id: 'short', name: '王'),
        _person(id: 'long', name: '王小明'),
      ]);
      final List<PersonNameSpan> spans = matcher.findSpans('見到王小明與王');
      expect(spans, hasLength(2));
      expect(spans[0].personId, 'long');
      expect(spans[0].start, '見到'.length);
      expect(spans[0].end, '見到王小明'.length);
      expect(spans[1].personId, 'short');
    });

    test('findSpans 與 match 同樣合併空白並映射原文區間', () {
      final PersonNameMatcher matcher = PersonNameMatcher(<Person>[
        _person(id: 'js', name: 'John Smith'),
      ]);
      const String text = '見到 John  Smith 今天';
      expect(matcher.match(text), <String>{'js'});
      final List<PersonNameSpan> spans = matcher.findSpans(text);
      expect(spans, hasLength(1));
      expect(spans.single.personId, 'js');
      expect(text.substring(spans.single.start, spans.single.end), 'John  Smith');
    });
  });
}
