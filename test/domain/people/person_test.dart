import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/people/person.dart';

void main() {
  test('人物關係固定為七類且合作夥伴可往返 JSON', () {
    expect(PersonRelationship.values, <PersonRelationship>[
      PersonRelationship.family,
      PersonRelationship.partner,
      PersonRelationship.friend,
      PersonRelationship.classmate,
      PersonRelationship.colleague,
      PersonRelationship.collaborator,
      PersonRelationship.other,
    ]);
    expect(
      PersonRelationship.tryParse('collaborator'),
      PersonRelationship.collaborator,
    );
    expect(PersonRelationship.tryParse('acquaintance'), isNull);

    final DateTime now = DateTime(2026);
    final Person person = Person(
      id: 'p1',
      name: '小明',
      relationships: const <PersonRelationship>{
        PersonRelationship.collaborator,
      },
      createdAt: now,
      updatedAt: now,
    );
    expect(person.toJson()['relationships'], <String>['collaborator']);
    expect(
      Person.fromJson(person.toJson())!.relationships,
      <PersonRelationship>{PersonRelationship.collaborator},
    );
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
    final Set<PersonRelationship> relationships = <PersonRelationship>{
      PersonRelationship.friend,
    };
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
    expect(person.relationships, <PersonRelationship>{
      PersonRelationship.friend,
    });
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
}
