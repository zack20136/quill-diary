import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/application/people/people_providers.dart';
import 'package:quill_diary/domain/people/person.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/database/index_database.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/people/pages/person_detail_page.dart';

import '../../helpers/app_test_theme.dart';

void main() {
  final DateTime timestamp = DateTime.utc(2026, 8, 12);
  final Person person = Person(
    id: 'per_detail_test',
    name: '小明',
    friendliness: FriendlinessLevel(4),
    acquaintanceYear: 2020,
    birthday: PersonBirthday(month: 8, day: 12),
    createdAt: timestamp,
    updatedAt: timestamp,
  );

  Widget testApp({Map<PersonId, PersonMentionStats> stats = const {}}) {
    return ProviderScope(
      overrides: [
        personDetailProvider(person.id).overrideWith((Ref ref) async => person),
        personRelatedEntriesProvider(
          person.id,
        ).overrideWith((Ref ref) async => const <EntryIndexRecord>[]),
        peopleMentionStatsMapProvider.overrideWith((Ref ref) async => stats),
      ],
      child: MaterialApp(
        theme: appTestTheme(),
        locale: appZhLocale,
        supportedLocales: appSupportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: PersonDetailPage(personId: person.id),
      ),
    );
  }

  testWidgets('頂部直接顯示刪除按鈕且不再提供更多操作選單', (WidgetTester tester) async {
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();

    expect(find.byTooltip('刪除人物'), findsOneWidget);
    expect(find.byTooltip('更多操作'), findsNothing);
    expect(find.byType(PopupMenuButton<Object>), findsNothing);
  });

  testWidgets('人物基本資料維持單一水平列並可左右滑動', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();

    final Finder strip = find.byKey(
      const ValueKey<String>('person-profile-facts-strip'),
    );
    final Finder scrollable = find.descendant(
      of: strip,
      matching: find.byType(Scrollable),
    );
    final double initialOffset = tester
        .state<ScrollableState>(scrollable)
        .position
        .pixels;

    expect(
      tester.getCenter(find.text('熟悉程度')).dy,
      tester.getCenter(find.text('認識年份')).dy,
    );
    expect(
      tester.getCenter(find.text('認識年份')).dy,
      tester.getCenter(find.text('生日')).dy,
    );

    await tester.drag(strip, const Offset(-180, 0));
    await tester.pumpAndSettle();

    expect(
      tester.state<ScrollableState>(scrollable).position.pixels,
      greaterThan(initialOffset),
    );
  });

  testWidgets('提及摘要將上次提及顯示在近三十天之前', (WidgetTester tester) async {
    await tester.pumpWidget(
      testApp(
        stats: <PersonId, PersonMentionStats>{
          person.id: PersonMentionStats(
            personId: person.id,
            mentionCount: 3,
            recentMentionCount: 2,
            lastMentionDate: const DateOnly('2026-08-10'),
          ),
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getCenter(find.text('上次提及')).dx,
      lessThan(tester.getCenter(find.text('近 30 天')).dx),
    );
  });
}
