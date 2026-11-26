import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/people/people_providers.dart';
import 'package:quill_diary/domain/diary/diary_entry_summary.dart';
import 'package:quill_diary/domain/people/person.dart';
import 'package:quill_diary/domain/people/relationship_type.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/people/pages/person_detail_page.dart';

import '../../helpers/shared/entry_index_fixtures.dart';
import '../../helpers/shared/test_l10n.dart';
import '../../helpers/shared/widget_test_app.dart';

void main() {
  final DateTime timestamp = DateTime.utc(2026, 8, 12);
  final Person person = Person(
    id: 'per_detail_test',
    name: '小明',
    friendliness: FriendlinessLevel(4),
    acquaintanceYear: 2020,
    birthday: PersonBirthday(month: 8, day: 12),
    relationships: const <String>{BuiltinRelationshipIds.classmate},
    accentArgb: 0xFF54A890,
    createdAt: timestamp,
    updatedAt: timestamp,
  );

  Widget testApp({
    Map<PersonId, PersonMentionStats> stats = const {},
    Locale locale = appZhLocale,
    List<DiaryEntrySummary> relatedEntries = const <DiaryEntrySummary>[],
    Person? detail,
  }) {
    final Person current = detail ?? person;
    return widgetTestApp(
      locale: locale,
      center: false,
      overrides: [
        peopleCatalogProvider.overrideWith(
          (Ref ref) async => PeopleCatalog(
            relationshipTypes: defaultBuiltinRelationshipTypes(),
            people: <Person>[current],
          ),
        ),
        personDetailProvider(current.id)
            .overrideWith((Ref ref) async => current),
        personRelatedEntriesProvider(current.id)
            .overrideWith((Ref ref) async => relatedEntries),
        peopleMentionStatsMapProvider.overrideWith((Ref ref) async => stats),
      ],
      child: PersonDetailPage(personId: current.id),
    );
  }

  testWidgets('頂部直接顯示刪除按鈕且不再提供更多操作選單', (WidgetTester tester) async {
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();

    expect(find.byTooltip('刪除人物'), findsOneWidget);
    expect(find.byTooltip('更多操作'), findsNothing);
    expect(find.byType(PopupMenuButton<Object>), findsNothing);
  });

  testWidgets('人物基本資料維持單一水平列', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();

    final Finder strip = find.byKey(
      const ValueKey<String>('person-profile-facts-strip'),
    );
    final Finder friendliness = find.text(testL10n.peopleFieldFriendliness);
    final Finder year = find.text(testL10n.peopleFieldAcquaintanceYear);
    final Finder birthday = find.text(testL10n.peopleFieldBirthday);

    expect(tester.getCenter(friendliness).dy, tester.getCenter(year).dy);
    expect(tester.getCenter(year).dy, tester.getCenter(birthday).dy);

    final Finder scrollable = find.descendant(
      of: strip,
      matching: find.byType(Scrollable),
    );
    if (scrollable.evaluate().isEmpty) {
      double slotWidth(String label) {
        final Finder row = find
            .ancestor(of: find.text(label), matching: find.byType(Row))
            .first;
        return tester.getSize(row).width;
      }

      final double friendlinessWidth = slotWidth(
        testL10n.peopleFieldFriendliness,
      );
      final double yearWidth = slotWidth(testL10n.peopleFieldAcquaintanceYear);
      final double birthdayWidth = slotWidth(testL10n.peopleFieldBirthday);
      expect((yearWidth - friendlinessWidth).abs(), lessThan(1));
      expect((birthdayWidth - yearWidth).abs(), lessThan(1));
      return;
    }

    final double initialOffset = tester
        .state<ScrollableState>(scrollable)
        .position
        .pixels;
    await tester.drag(strip, const Offset(-180, 0));
    await tester.pumpAndSettle();
    expect(
      tester.state<ScrollableState>(scrollable).position.pixels,
      greaterThan(initialOffset),
    );
  });

  testWidgets('提及摘要以日記篇數與最近提及日期呈現中英文', (WidgetTester tester) async {
    final stats = <PersonId, PersonMentionStats>{
      person.id: PersonMentionStats(
        personId: person.id,
        mentionedEntryCount: 3,
        recentMentionedEntryCount: 2,
        lastMentionDate: const DateOnly('2026-08-10'),
      ),
    };
    await tester.pumpWidget(testApp(stats: stats));
    await tester.pumpAndSettle();

    expect(
      tester.getCenter(find.text('最近提及')).dx,
      lessThan(tester.getCenter(find.text('近 30 天')).dx),
    );
    expect(find.text('提及篇數'), findsOneWidget);
    expect(find.text('3 篇'), findsOneWidget);

    await tester.pumpWidget(testApp(stats: stats, locale: const Locale('en')));
    await tester.pumpAndSettle();

    expect(find.text('Latest'), findsOneWidget);
    expect(find.text('30 days'), findsOneWidget);
    expect(find.text('Entries'), findsOneWidget);
    expect(find.text('3 entries'), findsOneWidget);
  });

  testWidgets('無相關日記時匯出回顧停用', (WidgetTester tester) async {
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();

    final Finder exportButton = find.byKey(
      const ValueKey<String>('person-export-recap'),
    );
    expect(exportButton, findsOneWidget);
    expect(tester.widget<TextButton>(exportButton).onPressed, isNull);
  });

  testWidgets('有相關日記時顯示可用的匯出回顧', (WidgetTester tester) async {
    await tester.pumpWidget(
      testApp(relatedEntries: <DiaryEntrySummary>[buildDiaryEntrySummary()]),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();

    final Finder exportButton = find.byKey(
      const ValueKey<String>('person-export-recap'),
    );
    expect(exportButton, findsOneWidget);
    expect(find.text('匯出回顧'), findsOneWidget);
    expect(tester.widget<TextButton>(exportButton).onPressed, isNotNull);
  });

  testWidgets('空白的關係描述與備註不顯示', (WidgetTester tester) async {
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();

    final Finder card = find.byKey(
      const ValueKey<String>('person-profile-details-card'),
    );
    expect(
      find.descendant(
        of: card,
        matching: find.text(testL10n.peopleFieldRelationshipDescription),
      ),
      findsNothing,
    );
    expect(
      find.descendant(of: card, matching: find.text(testL10n.peopleFieldNotes)),
      findsNothing,
    );
  });

  testWidgets('有內容的關係描述與備註顯示在詳情卡內', (WidgetTester tester) async {
    await tester.pumpWidget(
      testApp(
        detail: Person(
          id: person.id,
          name: person.name,
          friendliness: person.friendliness,
          acquaintanceYear: person.acquaintanceYear,
          birthday: person.birthday,
          relationships: person.relationships,
          relationshipDescription: '大學同學',
          notes: '記得帶書',
          accentArgb: person.accentArgb,
          createdAt: person.createdAt,
          updatedAt: person.updatedAt,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder card = find.byKey(
      const ValueKey<String>('person-profile-details-card'),
    );
    expect(
      find.descendant(of: card, matching: find.text('大學同學')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('記得帶書')),
      findsOneWidget,
    );
  });
}
