import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/people/person.dart';
import 'package:quill_diary/infrastructure/storage/portable/html_export_person_anonymizer.dart';

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
  test('同一人別名對應同一代號，依首次出現編號', () {
    final HtmlExportPersonAnonymizer anonymizer = HtmlExportPersonAnonymizer(
      people: <Person>[
        _person(id: 'p1', name: '王小明', aliases: <String>['阿明']),
        _person(id: 'p2', name: '小華'),
      ],
      useEnglishLabels: false,
    );

    expect(anonymizer.anonymizePlainText('阿明與小華'), '人物A與人物B');
    expect(anonymizer.anonymizePlainText('王小明又來了'), '人物A又來了');
  });

  test('英文代號與略過 code／URL', () {
    final HtmlExportPersonAnonymizer anonymizer = HtmlExportPersonAnonymizer(
      people: <Person>[_person(id: 'p1', name: '小明')],
      useEnglishLabels: true,
    );

    expect(
      anonymizer.anonymizeMarkdownBody(
        '見小明\n```\n小明\n```\n`小明` 與 [文](https://小明.example)',
      ),
      '見Person A\n```\n小明\n```\n`小明` 與 [文](https://小明.example)',
    );
  });

  test('合併空白的英文姓名也能匿名化', () {
    final HtmlExportPersonAnonymizer anonymizer = HtmlExportPersonAnonymizer(
      people: <Person>[_person(id: 'p1', name: 'John Smith')],
      useEnglishLabels: false,
    );

    expect(anonymizer.anonymizePlainText('見到 John  Smith'), '見到 人物A');
  });
}
