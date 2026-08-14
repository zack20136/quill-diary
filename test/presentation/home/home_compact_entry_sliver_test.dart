import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/application/editor/editor_draft_providers.dart';
import 'package:quill_diary/application/tag/tag_providers.dart';
import 'package:quill_diary/infrastructure/database/index_database.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/home/widgets/entry_widgets.dart';
import 'package:quill_diary/presentation/home/widgets/home_shared_widgets.dart';
import 'package:quill_diary/shared/presentation/page_style.dart';

import '../../helpers/app_test_theme.dart';
import '../../helpers/shared/entry_index_fixtures.dart';

void main() {
  testWidgets('大量摘要日記只建立可見範圍並可捲動到最後一筆', (
    WidgetTester tester,
  ) async {
    final List<EntryIndexRecord> entries = List<EntryIndexRecord>.generate(
      100,
      (int index) => buildEntryIndexRecord(
        id: 'entry_$index',
        title: 'Entry $index',
        previewText: 'Preview $index',
        tags: const <String>[],
      ),
    );
    final ProviderContainer container = ProviderContainer(
      overrides: [
        tagAccentArgbMapProvider.overrideWith(
          (Ref ref) async => const <String, int>{},
        ),
        editorDraftKeysProvider.overrideWith(
          (Ref ref) async => const <String>{},
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: appTestTheme(),
          locale: appZhLocale,
          supportedLocales: appSupportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: CustomScrollView(
              slivers: <Widget>[
                HomeDiarySliverSection(title: '日記', entries: entries),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final SliverPadding sectionPadding = tester.widget<SliverPadding>(
      find.descendant(
        of: find.byType(HomeDiarySliverSection),
        matching: find.byType(SliverPadding),
      ),
    );
    expect(
      sectionPadding.padding,
      const EdgeInsets.fromLTRB(16, 16, 16, 14),
    );

    final DecoratedSliver decoratedSection = tester.widget<DecoratedSliver>(
      find.descendant(
        of: find.byType(HomeDiarySliverSection),
        matching: find.byType(DecoratedSliver),
      ),
    );
    final BoxDecoration decoration = decoratedSection.decoration as BoxDecoration;
    expect(decoration.borderRadius, BorderRadius.circular(PageStyle.radiusCard));
    expect(decoration.boxShadow, hasLength(1));
    expect(decoration.boxShadow!.single.blurRadius, 2);
    expect(decoration.boxShadow!.single.offset, const Offset(0, 1));
    expect(decoration.boxShadow!.single.color.a, closeTo(0.08, 0.001));

    final int initiallyBuilt = find.byType(HomeTimelineEntryShell).evaluate().length;
    expect(initiallyBuilt, greaterThan(0));
    expect(initiallyBuilt, lessThan(entries.length));

    await tester.scrollUntilVisible(
      find.text('Entry 99'),
      600,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Entry 99'), findsOneWidget);
  });
}
