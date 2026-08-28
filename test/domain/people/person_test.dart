import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/people/person.dart';
import 'package:quill_diary/domain/people/relationship_type.dart';

void main() {
  test('內建關係 id 固定七種且字串關係可往返 JSON', () {
    expect(BuiltinRelationshipIds.all, <String>[
      'family',
      'partner',
      'friend',
      'classmate',
      'colleague',
      'collaborator',
      'other',
    ]);

    final DateTime now = DateTime(2026);
    final Person person = Person(
      id: 'p1',
      name: '小明',
      relationships: const <String>{BuiltinRelationshipIds.collaborator},
      createdAt: now,
      updatedAt: now,
    );
    expect(person.toJson()['relationships'], <String>['collaborator']);
    expect(
      Person.fromJson(person.toJson())!.relationships,
      <String>{BuiltinRelationshipIds.collaborator},
    );
  });

  test('RelationshipType 依語系選字並可往返 JSON', () {
    const RelationshipType type = RelationshipType(
      id: 'a3f9k2mx',
      labelZh: '導師',
      labelEn: 'Mentor',
    );
    expect(type.labelForLanguageCode('zh'), '導師');
    expect(type.labelForLanguageCode('en'), 'Mentor');
    expect(RelationshipType.fromJson(type.toJson()), type);
  });

  test('自訂關係 id 為 8 碼亂數且避開既有 id', () {
    final String id = generateRelationshipTypeId(
      existingIds: <String>{'aaaaaaaa'},
    );
    expect(id, matches(RegExp(r'^[a-z0-9]{8}$')));
    expect(id, isNot('aaaaaaaa'));
    expect(BuiltinRelationshipIds.isBuiltin(id), isFalse);
  });

  group('PersonBirthday', () {
    test('只保存月日且允許 2 月 29 日', () {
      final PersonBirthday b = PersonBirthday(month: 2, day: 29);
      expect(b.toJson(), <String, Object?>{'month': 2, 'day': 29});
      expect(PersonBirthday.tryParse(month: 2, day: 30), isNull);
    });

    test('JSON 包含生日年份時拒絕解析', () {
      final PersonBirthday? birthday = PersonBirthday.fromJson(
        <String, Object?>{'month': 8, 'day': 10, 'year': 2024},
      );
      expect(birthday, isNull);
    });
  });

  group('collectPersonNameIssues', () {
    test('重複姓名為衝突', () {
      final DateTime now = DateTime(2026);
      final List<PersonNameIssue> issues = collectPersonNameIssues(
        name: '小明',
        aliases: const <String>[],
        existingPeople: <Person>[
          Person(id: 'p1', name: '小明', createdAt: now, updatedAt: now),
        ],
      );
      expect(
        issues.any(
          (PersonNameIssue i) => i.kind == PersonNameIssueKind.duplicate,
        ),
        isTrue,
      );
    });
  });

  test('Person 會防止外部集合修改名冊內容', () {
    final List<String> aliases = <String>['小明'];
    final Set<String> relationships = <String>{BuiltinRelationshipIds.friend};
    final Person person = Person(
      id: 'p1',
      name: '王小明',
      aliases: aliases,
      relationships: relationships,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    aliases.add('阿明');
    relationships.clear();

    expect(person.aliases, <String>['小明']);
    expect(person.relationships, <String>{BuiltinRelationshipIds.friend});
    expect(() => person.aliases.add('不可修改'), throwsUnsupportedError);
  });

  test('Person 與 PersonDraft 的熟悉程度預設為第 3 級', () {
    final DateTime now = DateTime(2026);
    final Person person = Person(
      id: 'p1',
      name: '小明',
      createdAt: now,
      updatedAt: now,
    );
    final PersonDraft draft = PersonDraft(name: '小華');

    expect(person.friendliness, FriendlinessLevel.normal);
    expect(draft.friendliness, FriendlinessLevel.normal);
    expect(person.toJson()['friendliness'], 3);
  });

  test('人物顏色預設為自動配色，自訂色可完整往返 JSON', () {
    final DateTime now = DateTime(2026);
    final Person automatic = Person(
      id: 'p1',
      name: '小華',
      createdAt: now,
      updatedAt: now,
    );
    final Person custom = Person(
      id: 'p2',
      name: '小明',
      accentArgb: 0xFF5480B0,
      createdAt: now,
      updatedAt: now,
    );

    expect(automatic.accentArgb, isNull);
    expect(automatic.toJson(), isNot(contains('accentArgb')));
    expect(Person.fromJson(custom.toJson())!.accentArgb, 0xFF5480B0);
    expect(PersonDraft.fromPerson(custom).accentArgb, 0xFF5480B0);
  });

  group('mentionName', () {
    test('省略時預設以姓名作為日記 @ 名稱', () {
      final DateTime now = DateTime(2026);
      final Person person = Person(
        id: 'p1',
        name: '王小明',
        aliases: const <String>['阿明'],
        createdAt: now,
        updatedAt: now,
      );
      expect(person.mentionName, isNull);
      expect(person.toJson(), isNot(contains('mentionName')));
      expect(person.diaryMentionLabel, '王小明');
      expect(Person.fromJson(person.toJson())!.mentionName, isNull);
    });

    test('有效別名可完整往返 JSON 並作為日記 @ 名稱', () {
      final DateTime now = DateTime(2026);
      final Person person = Person(
        id: 'p1',
        name: '王小明',
        aliases: const <String>['阿明', '明哥'],
        mentionName: '阿明',
        createdAt: now,
        updatedAt: now,
      );
      expect(person.diaryMentionLabel, '阿明');
      expect(person.toJson()['mentionName'], '阿明');
      final Person restored = Person.fromJson(person.toJson())!;
      expect(restored.mentionName, '阿明');
      expect(restored.diaryMentionLabel, '阿明');
      expect(PersonDraft.fromPerson(person).mentionName, '阿明');
    });

    test('無效或空的 mentionName 會拒絕解析', () {
      final DateTime now = DateTime(2026);
      final Map<String, Object?> base = Person(
        id: 'p1',
        name: '王小明',
        aliases: const <String>['阿明'],
        createdAt: now,
        updatedAt: now,
      ).toJson();
      expect(
        Person.fromJson(<String, Object?>{...base, 'mentionName': '不存在'}),
        isNull,
      );
      expect(
        Person.fromJson(<String, Object?>{...base, 'mentionName': ''}),
        isNull,
      );
      expect(
        Person.fromJson(<String, Object?>{...base, 'mentionName': 1}),
        isNull,
      );
    });

    test('正規化可把選名稱與失效別名回退為 null', () {
      expect(
        normalizePersonMentionName(
          mentionName: '王小明',
          name: '王小明',
          aliases: const <String>['阿明'],
        ),
        isNull,
      );
      expect(
        normalizePersonMentionName(
          mentionName: '阿明',
          name: '王小明',
          aliases: const <String>['阿明'],
        ),
        '阿明',
      );
      expect(
        normalizePersonMentionName(
          mentionName: '阿明',
          name: '王小明',
          aliases: const <String>[],
        ),
        isNull,
      );
    });
  });
}
