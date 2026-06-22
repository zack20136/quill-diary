import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/features/editor/providers/editor_draft_providers.dart';
import 'package:quill_diary/features/editor/providers/editor_providers.dart';
import 'package:quill_diary/features/home/pages/home_page.dart';
import 'package:quill_diary/features/home/state/home_state.dart';
import 'package:quill_diary/features/home/widgets/calendar/calendar_pane.dart';
import 'package:quill_diary/features/home/widgets/overview_pane.dart';
import 'package:quill_diary/features/home/widgets/tags_pane.dart';
import 'package:quill_diary/shared/presentation/display_format.dart';
import 'package:quill_diary/features/session/providers/session_providers.dart';
import 'package:quill_diary/features/session/state/app_session_state.dart';
import 'package:quill_diary/infrastructure/database/index_database.dart';
import 'package:quill_diary/infrastructure/storage/tag_styles_store.dart';
import 'package:quill_diary/shared/providers/core_providers.dart';
import 'package:quill_diary/shared/providers/tag_providers.dart';

import '../../helpers/entry_index_fixtures.dart';
import '../../helpers/fake_entry_index_vault_repository.dart';

void main() {
  final AppLocalizations zhL10n = lookupAppLocalizations(appZhLocale);

  ProviderContainer buildContainer(
    FakeEntryIndexVaultRepository repository, {
    Future<Uint8List?> Function(String path)? coverPreviewLoader,
  }) {
    final UnlockedVaultSession session = UnlockedVaultSession(
      vaultId: 'vlt_home_page_test',
      trustedDevice: true,
      recoveryWrapKey: const <int>[1, 2, 3],
    );

    return ProviderContainer(
      overrides: [
        supportedPlatformProvider.overrideWith((Ref ref) => true),
        vaultRepositoryProvider.overrideWithValue(repository),
        effectiveAppSessionProvider.overrideWith(
          (Ref ref) async =>
              AppSessionState(status: AppLockStatus.unlocked, session: session),
        ),
        tagCatalogProvider.overrideWith(
          (Ref ref) async => repository.tagCatalog,
        ),
        tagAccentArgbMapProvider.overrideWith(
          (Ref ref) async => TagStylesStore.toAccentMap(repository.tagCatalog),
        ),
        editorDraftKeysProvider.overrideWith((Ref ref) async => <String>{}),
        if (coverPreviewLoader != null)
          entryCoverPreviewBytesProvider.overrideWith(
            (Ref ref, String path) => coverPreviewLoader(path),
          ),
      ],
    );
  }

  Future<void> pumpHomePage(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: appZhLocale,
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          supportedLocales: appSupportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const HomePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('overview export stays enabled for all scope', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = buildContainer(
      FakeEntryIndexVaultRepository(
        allEntries: <EntryIndexRecord>[
          buildEntryIndexRecord(id: 'jrn_1', title: 'entry one'),
          buildEntryIndexRecord(id: 'jrn_2', title: 'entry two'),
        ],
      ),
    );

    container.read(homeTabProvider.notifier).set(HomeTab.overview);
    container.read(memoryScopeProvider.notifier).set(MemoryScope.all);

    await pumpHomePage(tester, container);

    final Finder overviewPane = find.byType(OverviewPane);
    final Finder exportButton = find.descendant(
      of: overviewPane,
      matching: find.widgetWithText(FilledButton, zhL10n.homeExportRecapLabel),
    );
    expect(tester.widget<FilledButton>(exportButton).onPressed, isNotNull);
  });

  testWidgets('calendar tab renders calendar and daily entries', (
    WidgetTester tester,
  ) async {
    final EntryIndexRecord calendarEntry = buildEntryIndexRecord(
      id: 'jrn_calendar_1',
      title: 'calendar note',
      date: const DateOnly('2026-05-20'),
    );
    final ProviderContainer container = buildContainer(
      FakeEntryIndexVaultRepository(
        entriesByDate: <DateOnly, List<EntryIndexRecord>>{
          const DateOnly('2026-05-20'): <EntryIndexRecord>[calendarEntry],
        },
        entriesByMonth: <DateTime, List<EntryIndexRecord>>{
          DateTime(2026, 5): <EntryIndexRecord>[calendarEntry],
        },
      ),
    );

    container.read(homeTabProvider.notifier).set(HomeTab.calendar);
    container
        .read(calendarVisibleMonthProvider.notifier)
        .set(DateTime(2026, 5));
    container
        .read(calendarSelectedDateProvider.notifier)
        .set(const DateOnly('2026-05-20'));

    await pumpHomePage(tester, container);

    final String dateLabel = DisplayFormat.formatDateOnly(
      zhL10n,
      const DateOnly('2026-05-20'),
    );
    expect(
      find.text(
        zhL10n.homeDiarySectionTitleForDate(dateLabel),
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(CalendarPane),
        matching: find.text('calendar note'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('IndexedStack keeps calendar mounted after tab switch', (
    WidgetTester tester,
  ) async {
    final EntryIndexRecord calendarEntry = buildEntryIndexRecord(
      id: 'jrn_calendar_keepalive',
      title: 'keepalive note',
      date: const DateOnly('2026-05-20'),
    );
    final ProviderContainer container = buildContainer(
      FakeEntryIndexVaultRepository(
        entriesByDate: <DateOnly, List<EntryIndexRecord>>{
          const DateOnly('2026-05-20'): <EntryIndexRecord>[calendarEntry],
        },
        entriesByMonth: <DateTime, List<EntryIndexRecord>>{
          DateTime(2026, 5): <EntryIndexRecord>[calendarEntry],
        },
      ),
    );

    container.read(homeTabProvider.notifier).set(HomeTab.calendar);
    container
        .read(calendarVisibleMonthProvider.notifier)
        .set(DateTime(2026, 5));
    container
        .read(calendarSelectedDateProvider.notifier)
        .set(const DateOnly('2026-05-20'));

    await pumpHomePage(tester, container);
    expect(find.byType(TableCalendar<Object>), findsOneWidget);

    container.read(homeTabProvider.notifier).set(HomeTab.home);
    await tester.pumpAndSettle();

    container.read(homeTabProvider.notifier).set(HomeTab.calendar);
    await tester.pumpAndSettle();

    expect(find.byType(TableCalendar<Object>), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(CalendarPane),
        matching: find.text('keepalive note'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('tags tab shows selected tag preview in the same scroll flow', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = buildContainer(
      FakeEntryIndexVaultRepository(
        allEntries: <EntryIndexRecord>[
          buildEntryIndexRecord(
            id: 'jrn_trip',
            title: 'trip note',
            tags: const <String>['travel'],
          ),
          buildEntryIndexRecord(
            id: 'jrn_work',
            title: 'work note',
            tags: const <String>['work'],
          ),
        ],
        tagCatalog: const <TagCatalogItem>[
          TagCatalogItem(label: 'travel'),
          TagCatalogItem(label: 'work'),
        ],
      ),
    );

    container.read(homeTabProvider.notifier).set(HomeTab.tags);

    await pumpHomePage(tester, container);

    final Finder tagsPane = find.byType(TagsManagePane);
    final Finder tagsScroll = find.descendant(
      of: tagsPane,
      matching: find.byType(CustomScrollView),
    );
    final Finder travelRow = find.descendant(
      of: tagsPane,
      matching: find.widgetWithText(ListTile, 'travel'),
    );

    await tester.ensureVisible(travelRow);
    await tester.tap(travelRow);
    await tester.pumpAndSettle();

    expect(tagsScroll, findsOneWidget);
    expect(
      find.descendant(
        of: tagsPane,
        matching: find.text(zhL10n.homeDiarySectionTag('travel')),
      ),
      findsOneWidget,
    );

    await tester.drag(tagsScroll, const Offset(0, -420));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: tagsPane, matching: find.text('trip note')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: tagsPane, matching: find.text('work note')),
      findsNothing,
    );
  });

  testWidgets('overview compact cards do not overflow on narrow screens', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final ProviderContainer container = buildContainer(
      FakeEntryIndexVaultRepository(
        allEntries: <EntryIndexRecord>[
          buildEntryIndexRecord(
            id: 'jrn_overflow',
            title:
                'very long overview card title used to verify compact layouts on narrow screens',
            previewText:
                'A longer preview body is included here to exercise title, tags, dates, and image strip layout without render overflows.',
            tags: const <String>[
              'very-long-tag-name-alpha',
              'very-long-tag-name-beta',
            ],
            previewImagePaths: const <String>['/encrypted/img-1'],
            attachmentCount: 1,
            imageAttachmentCount: 1,
          ),
        ],
      ),
      coverPreviewLoader: (String path) async => Uint8List(0),
    );

    container.read(homeTabProvider.notifier).set(HomeTab.overview);
    container.read(memoryScopeProvider.notifier).set(MemoryScope.all);

    await pumpHomePage(tester, container);

    expect(tester.takeException(), isNull);
  });
}
