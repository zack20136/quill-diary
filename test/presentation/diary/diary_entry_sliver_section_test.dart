import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/application/editor/editor_entry_providers.dart';
import 'package:quill_diary/infrastructure/database/index_database.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/diary/widgets/diary_entry_sliver_section.dart';
import 'package:quill_diary/shared/presentation/widgets/entry_cover_thumbnail.dart';
import 'package:quill_diary/shared/presentation/widgets/entry_preview_image_strip.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../helpers/app_test_theme.dart';
import '../../helpers/shared/entry_index_fixtures.dart';

void main() {
  setUp(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  tearDown(() {
    VisibilityDetectorController.instance.updateInterval =
        const Duration(milliseconds: 500);
  });

  Widget host(List<EntryIndexRecord> entries) {
    return ProviderScope(
      overrides: [
        entryCoverPreviewBytesProvider.overrideWith(
          (Ref ref, String path) async => null,
        ),
      ],
      child: MaterialApp(
        theme: appTestTheme(),
        locale: appZhLocale,
        supportedLocales: appSupportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: CustomScrollView(
            slivers: <Widget>[
              DiaryEntrySliverSection(title: '相關日記', entries: entries),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('有 previewImagePaths 時顯示 lazy 預覽圖 strip', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      host(<EntryIndexRecord>[
        buildEntryIndexRecord(
          previewImagePaths: const <String>[
            '/tmp/cover_a.enc',
            '/tmp/cover_b.enc',
          ],
        ),
      ]),
    );
    await tester.pump();

    expect(find.byType(EntryPreviewImageStrip), findsOneWidget);
    expect(find.byType(LazyEntryCoverThumbnail), findsNWidgets(2));

    // 清掉 lazy 預取與 VisibilityDetector 排程，避免測畢留下 pending timer。
    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets('沒有 previewImagePaths 時不顯示預覽圖 strip', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      host(<EntryIndexRecord>[buildEntryIndexRecord()]),
    );
    await tester.pump();

    expect(find.byType(EntryPreviewImageStrip), findsNothing);
    expect(find.byType(LazyEntryCoverThumbnail), findsNothing);
  });
}
