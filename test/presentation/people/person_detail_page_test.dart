import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/app/app_colors.dart';
import 'package:quill_diary/application/people/people_providers.dart';
import 'package:quill_diary/domain/people/person.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/database/index_database.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/people/pages/person_detail_page.dart';
import 'package:quill_diary/shared/presentation/person_visual.dart';

import '../../helpers/app_test_theme.dart';

void main() {
  final DateTime timestamp = DateTime.utc(2026, 8, 12);
  final Person person = Person(
    id: 'per_detail_test',
    name: '小明',
    friendliness: FriendlinessLevel(4),
    acquaintanceYear: 2020,
    birthday: PersonBirthday(month: 8, day: 12),
    relationships: const <PersonRelationship>{PersonRelationship.classmate},
    accentArgb: 0xFF54A890,
    createdAt: timestamp,
    updatedAt: timestamp,
  );

  Widget testApp({
    Map<PersonId, PersonMentionStats> stats = const {},
    Brightness brightness = Brightness.light,
  }) {
    return ProviderScope(
      overrides: [
        personDetailProvider(person.id).overrideWith((Ref ref) async => person),
        personRelatedEntriesProvider(
          person.id,
        ).overrideWith((Ref ref) async => const <EntryIndexRecord>[]),
        peopleMentionStatsMapProvider.overrideWith((Ref ref) async => stats),
      ],
      child: MaterialApp(
        theme: appTestTheme(brightness: brightness),
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

  testWidgets('深色模式下提及概況與人物資料沿用相關日記背景色', (WidgetTester tester) async {
    await tester.pumpWidget(
      testApp(
        brightness: Brightness.dark,
        stats: <PersonId, PersonMentionStats>{
          person.id: PersonMentionStats(
            personId: person.id,
            mentionCount: 1,
            recentMentionCount: 1,
          ),
        },
      ),
    );
    await tester.pumpAndSettle();

    final AppColors colors = appTestTheme(
      brightness: Brightness.dark,
    ).extension<AppColors>()!;

    for (final String key in <String>[
      'person-mention-overview-card',
      'person-profile-details-card',
    ]) {
      final Finder material = find.descendant(
        of: find.byKey(ValueKey<String>(key)),
        matching: find.byType(Material),
      );
      expect(tester.widget<Material>(material.first).color, colors.sectionCard);
    }
  });

  testWidgets('深色模式下人物摘要小卡沿用單篇相關日記背景色', (WidgetTester tester) async {
    await tester.pumpWidget(
      testApp(
        brightness: Brightness.dark,
        stats: <PersonId, PersonMentionStats>{
          person.id: PersonMentionStats(
            personId: person.id,
            mentionCount: 1,
            recentMentionCount: 1,
          ),
        },
      ),
    );
    await tester.pumpAndSettle();

    final AppColors colors = appTestTheme(
      brightness: Brightness.dark,
    ).extension<AppColors>()!;
    for (final String key in <String>[
      'person-last-mention-fact',
      'person-friendliness-fact',
    ]) {
      final DecoratedBox box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byKey(ValueKey<String>(key)),
          matching: find.byType(DecoratedBox),
        ),
      );
      expect((box.decoration as BoxDecoration).color, colors.sectionInset);
    }
  });

  for (final Brightness brightness in Brightness.values) {
    testWidgets('${brightness == Brightness.light ? '淺色' : '深色'}模式關係標籤沿用人物頭像配色', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(testApp(brightness: brightness));
      await tester.pumpAndSettle();

      final AppColors colors = appTestTheme(
        brightness: brightness,
      ).extension<AppColors>()!;
      final (Color expectedBackground, Color expectedForeground) =
          personLabelColorPair(person, colors.sectionInset);
      final Finder relationChip = find.byKey(
        const ValueKey<String>('person-relation-chip-classmate'),
      );
      final Container container = tester.widget<Container>(
        find.descendant(
          of: relationChip,
          matching: find.byType(Container),
        ),
      );
      final BoxDecoration decoration = container.decoration! as BoxDecoration;
      final Text label = tester.widget<Text>(
        find.descendant(of: relationChip, matching: find.text('同學')),
      );

      expect(decoration.color, expectedBackground);
      expect(label.style?.color, expectedForeground);
    });
  }
}
