import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/attachment/asset_attachment.dart';
import 'package:quill_diary/features/editor/presentation/editor_preview_gallery.dart';
import 'package:quill_diary/features/editor/presentation/editor_top_bar.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';
import 'package:quill_diary/l10n/l10n.dart';

void main() {
  Widget buildApp(Widget child) {
    return ProviderScope(
      child: MaterialApp(
        locale: appZhLocale,
        supportedLocales: appSupportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(body: child),
      ),
    );
  }

  testWidgets('EditorTopBar 在 preview 模式顯示 edit，saving 時停用 close', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      buildApp(
        const EditorTopBar(
          previewMode: true,
          saving: true,
          hasTitle: true,
          canDelete: true,
          previewTimestampLabel: '2026/06/17 14:20',
          onClose: null,
          onPickDate: null,
          onPickTime: null,
          onEditTags: null,
          onPickImage: null,
          onPickFile: null,
          onSave: null,
          onDelete: null,
          onEnterEditMode: null,
        ),
      ),
    );

    expect(find.byKey(const Key('editor-top-bar-edit')), findsOneWidget);
    final IconButton closeButton = tester.widget(
      find.byKey(const Key('editor-top-bar-close')),
    );
    expect(closeButton.onPressed, isNull);
  });

  testWidgets('EditorPreviewGallery 點擊縮圖會回傳 index', (
    WidgetTester tester,
  ) async {
    int? openedIndex;
    final PendingAttachment pending = PendingAttachment(
      sourcePath: 'C:/images/pending.jpg',
      mimeType: 'image/jpeg',
      originalFilename: 'pending.jpg',
    );
    await tester.pumpWidget(
      buildApp(
        EditorPreviewGallery(
          savedImages: const <AssetAttachment>[],
          pendingImages: <PendingAttachment>[pending],
          encryptedPathFuture: (AssetAttachment attachment) async =>
              'C:/vault/${attachment.id}.enc',
          onOpenGallery: (int index) => openedIndex = index,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(InkWell).first, warnIfMissed: false);
    await tester.pump();

    expect(openedIndex, 0);
    expect(find.byKey(const Key('editor-preview-gallery')), findsOneWidget);
  });
}
