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

    test('拉丁名稱緊連也可分別命中', () {
      final PersonNameMatcher matcher = PersonNameMatcher(<Person>[
        _person(id: 'p1', name: 'test'),
        _person(id: 'p2', name: '65485'),
      ]);
      expect(matcher.match('test65485'), <String>{'p1', 'p2'});
      expect(matcher.match('test gsdfgsdfg te test test65485'), <String>{
        'p1',
        'p2',
      });
    });

    test('拉丁名稱不在 alnum run 中間誤命中', () {
      final PersonNameMatcher matcher = PersonNameMatcher(<Person>[
        _person(id: 'p1', name: 'test'),
      ]);
      expect(matcher.match('latest'), isEmpty);
      expect(matcher.match('contest'), isEmpty);
      expect(matcher.match('met test today'), <String>{'p1'});
    });
  });
}
