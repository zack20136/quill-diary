import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:quill_diary/domain/attachment/asset_attachment.dart';
import 'package:quill_diary/domain/diary/diary_entry.dart';
import 'package:quill_diary/domain/recovery/kdf_descriptor.dart';
import 'package:quill_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/features/editor/application/editor_actions.dart';
import 'package:quill_diary/features/editor/pages/editor_page.dart';
import 'package:quill_diary/features/editor/presentation/editor_attachment_strip.dart';
import 'package:quill_diary/features/editor/presentation/editor_preview_gallery.dart';
import 'package:quill_diary/features/editor/presentation/editor_top_bar.dart';
import 'package:quill_diary/features/session/providers/session_providers.dart';
import 'package:quill_diary/features/session/state/app_session_state.dart';
import 'package:quill_diary/features/settings/providers/settings_providers.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';
import 'package:quill_diary/l10n/l10n.dart';

import '../../helpers/fake_editor_actions.dart';

void main() {
  final UnlockedVaultSession session = UnlockedVaultSession(
    vaultId: 'vault-1',
    trustedDevice: false,
    recoveryWrapKey: List<int>.generate(32, (int index) => index),
  );
  final RecoveryMetadata recoveryMetadata = RecoveryMetadata(
    vaultId: 'vault-1',
    recoveryEnabled: true,
    recoveryKeyVersion: 1,
    recoveryKeyHint: 'hint',
    createdAt: DateTime(2026, 6, 18, 9),
    kdf: KdfDescriptor.argon2idRecovery(
      saltBytes: List<int>.generate(16, (int index) => index),
    ),
  );

  Widget buildApp(
    Widget child, {
    Size size = const Size(430, 932),
    EdgeInsets viewInsets = EdgeInsets.zero,
  }) {
    return ProviderScope(
      child: MaterialApp(
        locale: appZhLocale,
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        supportedLocales: appSupportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: MediaQuery(
          data: MediaQueryData(size: size, viewInsets: viewInsets),
          child: Scaffold(body: child),
        ),
      ),
    );
  }

  Widget buildEditorPageApp({
    required Widget child,
    required EditorActionPort actions,
    required UnlockedVaultSession session,
    required RecoveryMetadata recoveryMetadata,
    EdgeInsets viewInsets = EdgeInsets.zero,
    bool useRouter = false,
  }) {
    final Widget wrappedChild = MediaQuery(
      data: MediaQueryData(viewInsets: viewInsets),
      child: child,
    );

    return ProviderScope(
      overrides: [
        sessionSupportedPlatformProvider.overrideWith((Ref ref) => true),
        effectiveAppSessionProvider.overrideWith(
          (Ref ref) async =>
              AppSessionState(status: AppLockStatus.unlocked, session: session),
        ),
        recoveryMetadataProvider.overrideWith(
          (Ref ref) async => recoveryMetadata,
        ),
        editorActionsProvider.overrideWith((Ref ref) => actions),
      ],
      child: useRouter
          ? MaterialApp.router(
              locale: appZhLocale,
              theme: ThemeData(splashFactory: NoSplash.splashFactory),
              supportedLocales: appSupportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              routerConfig: GoRouter(
                initialLocation: '/',
                routes: <RouteBase>[
                  GoRoute(path: '/', builder: (_, _) => wrappedChild),
                  GoRoute(
                    path: '/editor/:entryId',
                    builder: (_, _) => wrappedChild,
                  ),
                ],
              ),
            )
          : MaterialApp(
              locale: appZhLocale,
              theme: ThemeData(splashFactory: NoSplash.splashFactory),
              supportedLocales: appSupportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: wrappedChild,
            ),
    );
  }

  testWidgets('預覽工具列在 saving 時保留 edit 並停用 close', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      buildApp(
        const EditorTopBar(
          previewMode: true,
          saving: true,
          canSaveEntry: true,
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

  testWidgets('圖片預覽列點擊後回傳正確 index', (WidgetTester tester) async {
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

  testWidgets('編輯模式鍵盤關閉時顯示附件區', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      buildEditorPageApp(
        child: const EditorPage(entryId: 'entry-1', startInEditMode: true),
        session: session,
        recoveryMetadata: recoveryMetadata,
        actions: FakeEditorActions(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(EditorAttachmentStrip), findsOneWidget);
    expect(
      find.byKey(const Key('editor-attachment-area-visible')),
      findsOneWidget,
    );
    expect(find.text('標籤'), findsOneWidget);
  });

  testWidgets('編輯模式鍵盤開啟時收起附件區', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      buildEditorPageApp(
        child: const EditorPage(entryId: 'entry-1', startInEditMode: true),
        session: session,
        recoveryMetadata: recoveryMetadata,
        actions: FakeEditorActions(),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.pumpWidget(
      buildEditorPageApp(
        child: const EditorPage(entryId: 'entry-1', startInEditMode: true),
        session: session,
        recoveryMetadata: recoveryMetadata,
        actions: FakeEditorActions(),
        viewInsets: const EdgeInsets.only(bottom: 320),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      find.byKey(const Key('editor-attachment-area-visible')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('editor-attachment-area-hidden')),
      findsOneWidget,
    );
    expect(find.text('標籤'), findsNothing);
  });

  testWidgets('唯讀模式即使鍵盤開啟也不收起附件區', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      buildEditorPageApp(
        child: const EditorPage(entryId: 'entry-1'),
        session: session,
        recoveryMetadata: recoveryMetadata,
        actions: FakeEditorActions(),
        viewInsets: const EdgeInsets.only(bottom: 320),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('editor-preview-gallery')), findsOneWidget);
    expect(find.byType(EditorAttachmentStrip), findsOneWidget);
    expect(find.text('標籤'), findsOneWidget);
  });

  testWidgets('大畫面編輯模式鍵盤開啟時也收起附件區', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      buildEditorPageApp(
        child: const EditorPage(entryId: 'entry-1', startInEditMode: true),
        session: session,
        recoveryMetadata: recoveryMetadata,
        actions: FakeEditorActions(),
        viewInsets: const EdgeInsets.only(bottom: 320),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      find.byKey(const Key('editor-attachment-area-visible')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('editor-attachment-area-hidden')),
      findsOneWidget,
    );
    expect(find.byType(EditorAttachmentStrip), findsNothing);
  });

  testWidgets('只有內文也可以儲存', (WidgetTester tester) async {
    final FakeEditorActions actions = FakeEditorActions(
      existingEntry: DiaryEntry(
        id: 'entry-1',
        vaultId: 'vault-1',
        title: null,
        date: DateOnly.parse('2026-06-18'),
        createdAt: DateTime(2026, 6, 18, 8),
        updatedAt: DateTime(2026, 6, 18, 9),
        markdownBody: '',
      ),
    );
    await tester.pumpWidget(
      buildEditorPageApp(
        child: const EditorPage(entryId: 'entry-1', startInEditMode: true),
        session: session,
        recoveryMetadata: recoveryMetadata,
        actions: actions,
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.enterText(find.byType(TextField).at(1), '只有內文');
    await tester.pump();
    await tester.tap(find.byKey(const Key('editor-top-bar-save')));
    await tester.pump();

    expect(actions.saveEntryCallCount, 1);
    expect(actions.savedEntryDraft, isNotNull);
    expect(actions.savedEntryDraft!.title, isNull);
    expect(actions.savedEntryDraft!.markdownBody, '只有內文');
  });

  testWidgets('標題與內容都空時不可儲存並顯示提示', (WidgetTester tester) async {
    final FakeEditorActions actions = FakeEditorActions();
    await tester.pumpWidget(
      buildEditorPageApp(
        child: const EditorPage(),
        session: session,
        recoveryMetadata: recoveryMetadata,
        actions: actions,
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const Key('editor-top-bar-save')));
    await tester.pump();

    expect(actions.savedEntryDraft, isNull);
    final BuildContext context = tester.element(find.byType(EditorPage));
    expect(
      find.text(AppLocalizations.of(context).editorSaveNeedsEntryMessage),
      findsOneWidget,
    );
  });

  testWidgets('文字輸入後會立即觸發草稿寫入', (WidgetTester tester) async {
    final FakeEditorActions actions = FakeEditorActions();
    await tester.pumpWidget(
      buildEditorPageApp(
        child: const EditorPage(),
        session: session,
        recoveryMetadata: recoveryMetadata,
        actions: actions,
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.enterText(find.byType(TextField).at(1), 'a');
    await tester.pump();

    expect(actions.writeDraftCount, 1);
  });

  testWidgets('新建日記輸入後立即儲存會呼叫正式 saveEntry', (WidgetTester tester) async {
    final FakeEditorActions actions = FakeEditorActions();
    await tester.pumpWidget(
      buildEditorPageApp(
        child: const EditorPage(),
        session: session,
        recoveryMetadata: recoveryMetadata,
        actions: actions,
        useRouter: true,
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.enterText(find.byType(TextField).at(1), '立即儲存內容');
    await tester.pump();
    await tester.tap(find.byKey(const Key('editor-top-bar-save')));
    await tester.pump();

    expect(actions.saveEntryCallCount, 1);
    expect(actions.savedEntryDraft, isNotNull);
    expect(actions.savedEntryDraft!.markdownBody, '立即儲存內容');
  });
}
