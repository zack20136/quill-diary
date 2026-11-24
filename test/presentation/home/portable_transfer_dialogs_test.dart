import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/storage/portable/portable_export_io.dart';
import 'package:quill_diary/presentation/transfer/portable_export_confirm.dart';
import 'package:quill_diary/presentation/transfer/portable_transfer_dialogs.dart';

import '../../helpers/shared/test_l10n.dart';
import '../../helpers/shared/widget_test_app.dart';

void main() {
  testWidgets('HTML 僅在實際匯出圖片時允許圖片資料夾', (tester) async {
    HtmlExportConfirmResult? result;
    final l10n = testL10n;
    const String photoEntry = '有圖片的日記';

    await tester.pumpWidget(
      widgetTestApp(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await confirmHtmlExport(
                context: context,
                estimate: const HtmlExportEstimate(
                  entries: [
                    HtmlExportEntrySummary(
                      id: 'with-image',
                      date: DateOnly('2026-11-23'),
                      title: photoEntry,
                      imageCount: 1,
                      imageBytes: 1024,
                      textBytes: 128,
                    ),
                    HtmlExportEntrySummary(
                      id: 'text-only',
                      date: DateOnly('2026-11-23'),
                      title: '純文字日記',
                      imageCount: 0,
                      imageBytes: 0,
                      textBytes: 128,
                    ),
                  ],
                ),
              );
            },
            child: const Text('開啟'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('開啟'));
    await tester.pumpAndSettle();

    final Finder folder = find.widgetWithText(
      SwitchListTile,
      l10n.portableExportHtmlAssetsLabel,
    );
    final Finder images = find.widgetWithText(
      SwitchListTile,
      l10n.portableExportIncludeImagesLabel,
    );
    SwitchListTile folderTile() => tester.widget<SwitchListTile>(folder);

    await tester.ensureVisible(folder);
    await tester.tap(folder);
    await tester.pumpAndSettle();
    expect(folderTile().value, isTrue);

    await tester.tap(images);
    await tester.pumpAndSettle();
    expect(folderTile().value, isFalse);
    expect(folderTile().onChanged, isNull);

    await tester.tap(images);
    await tester.pumpAndSettle();
    expect(folderTile().value, isFalse);
    await tester.tap(folder);
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.portableExportSelectEntriesLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.text(photoEntry));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.commonActionConfirm));
    await tester.pumpAndSettle();
    expect(folderTile().value, isFalse);
    expect(folderTile().onChanged, isNull);

    await tester.tap(find.text(l10n.portableExportConfirmAction));
    await tester.pumpAndSettle();
    expect(result?.options.externalAssets, isFalse);
    expect(result?.selectedEntryIds, {'text-only'});
  });

  testWidgets('選擇篇目回傳原始識別值，全不選時停用確認且不修改原集合', (tester) async {
    final selected = {7};
    Set<int>? result;
    await tester.pumpWidget(
      widgetTestApp(
        child: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () async {
                result = await showPortableEntrySelectionDialog<int>(
                  context: context,
                  entries: const [
                    PortableEntryOption(
                      id: 7,
                      title: '第一篇',
                      subtitle: '2026-10-29',
                    ),
                    PortableEntryOption(
                      id: 42,
                      title: '',
                      subtitle: '2026-10-30 · 可能重複',
                    ),
                  ],
                  initiallySelected: selected,
                );
              },
              child: const Text('開啟'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('開啟'));
    await tester.pumpAndSettle();
    expect(find.text('2026-10-30 · 可能重複'), findsOneWidget);
    await tester.tap(find.text('取消全選'));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '確定'))
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('全選'));
    await tester.pump();
    await tester.tap(find.text('第一篇'));
    await tester.pump();
    await tester.tap(find.text('確定'));
    await tester.pumpAndSettle();
    expect(result, {42});
    expect(selected, {7});
  });

  testWidgets('取消篇目選擇回傳空結果，保留原本字串 ID 選取', (tester) async {
    final selected = {'entry-b'};
    Set<String>? result = {};
    await tester.pumpWidget(
      widgetTestApp(
        child: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () async {
                result = await showPortableEntrySelectionDialog<String>(
                  context: context,
                  entries: const [
                    PortableEntryOption(
                      id: 'entry-b',
                      title: '原篇目',
                      subtitle: '2026-10-30',
                    ),
                  ],
                  initiallySelected: selected,
                );
              },
              child: const Text('開啟'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('開啟'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消全選'));
    await tester.pump();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(selected, {'entry-b'});
  });
}
