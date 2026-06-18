import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/attachment/asset_attachment.dart';
import 'package:quill_diary/domain/diary/diary_entry.dart';
import 'package:quill_diary/domain/recovery/kdf_descriptor.dart';
import 'package:quill_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/features/editor/application/editor_actions.dart';
import 'package:quill_diary/features/editor/application/editor_draft_models.dart';
import 'package:quill_diary/features/editor/pages/editor_page.dart';
import 'package:quill_diary/features/editor/presentation/editor_attachment_strip.dart';
import 'package:quill_diary/features/editor/presentation/editor_preview_gallery.dart';
import 'package:quill_diary/features/editor/presentation/editor_top_bar.dart';
import 'package:quill_diary/features/session/providers/session_providers.dart';
import 'package:quill_diary/features/session/state/app_session_state.dart';
import 'package:quill_diary/features/settings/providers/settings_providers.dart';
import 'package:quill_diary/infrastructure/preferences/user_preferences.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';
import 'package:quill_diary/l10n/l10n.dart';

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
  }) {
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
      child: MaterialApp(
        locale: appZhLocale,
        supportedLocales: appSupportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: MediaQuery(
          data: MediaQueryData(viewInsets: viewInsets),
          child: child,
        ),
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
        actions: _FakeEditorActions(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(EditorAttachmentStrip), findsOneWidget);
    expect(
      find.byKey(const Key('editor-attachment-area-visible')),
      findsOneWidget,
    );
    expect(find.text('旅行'), findsOneWidget);
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
        actions: _FakeEditorActions(),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.pumpWidget(
      buildEditorPageApp(
        child: const EditorPage(entryId: 'entry-1', startInEditMode: true),
        session: session,
        recoveryMetadata: recoveryMetadata,
        actions: _FakeEditorActions(),
        viewInsets: const EdgeInsets.only(bottom: 320),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.byKey(const Key('editor-attachment-area-visible')), findsNothing);
    expect(
      find.byKey(const Key('editor-attachment-area-hidden')),
      findsOneWidget,
    );
    expect(find.text('旅行'), findsNothing);
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
        actions: _FakeEditorActions(),
        viewInsets: const EdgeInsets.only(bottom: 320),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('editor-preview-gallery')), findsOneWidget);
    expect(find.byType(EditorAttachmentStrip), findsOneWidget);
    expect(find.text('旅行'), findsOneWidget);
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
        actions: _FakeEditorActions(),
        viewInsets: const EdgeInsets.only(bottom: 320),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('editor-attachment-area-visible')), findsNothing);
    expect(
      find.byKey(const Key('editor-attachment-area-hidden')),
      findsOneWidget,
    );
    expect(find.byType(EditorAttachmentStrip), findsNothing);
  });
}

class _FakeEditorActions implements EditorActionPort {
  static final DiaryEntry _entry = DiaryEntry(
    id: 'entry-1',
    vaultId: 'vault-1',
    title: '測試日記',
    date: DateOnly.parse('2026-06-18'),
    createdAt: DateTime(2026, 6, 18, 8),
    updatedAt: DateTime(2026, 6, 18, 9),
    markdownBody: '內文',
    tags: const <String>['旅行'],
    attachmentIds: const <AssetId>['image-1', 'file-1'],
  );

  static final List<AssetAttachment> _attachments = <AssetAttachment>[
    AssetAttachment(
      id: 'image-1',
      entryId: 'entry-1',
      mimeType: 'image/jpeg',
      safeFilename: 'image-1.jpg',
      originalFilename: 'photo.jpg',
      byteSize: 1024,
      createdAt: DateTime(2026, 6, 18, 8),
      sha256: 'sha-image',
      width: 1200,
      height: 800,
    ),
    AssetAttachment(
      id: 'file-1',
      entryId: 'entry-1',
      mimeType: 'application/pdf',
      safeFilename: 'file-1.pdf',
      originalFilename: 'doc.pdf',
      byteSize: 2048,
      createdAt: DateTime(2026, 6, 18, 8, 30),
      sha256: 'sha-file',
    ),
  ];

  @override
  Future<String> assetAbsolutePath({
    required DateOnly date,
    required AssetAttachment attachment,
  }) async => 'C:/vault/${attachment.id}';

  @override
  Future<void> deleteDraft(String draftKey) async {}

  @override
  Future<void> deleteEntry(
    UnlockedVaultSession session,
    EntryId entryId,
  ) async {}

  @override
  Future<Set<String>> listDraftKeys() async => <String>{};

  @override
  Future<List<AssetAttachment>> loadAttachments(EntryId entryId) async =>
      _attachments;

  @override
  Future<DiaryEntry?> loadEntry(
    UnlockedVaultSession session,
    EntryId entryId,
  ) async => _entry;

  @override
  Future<String> pendingAbsolutePath(String draftKey, String relativePath) async =>
      'C:/drafts/$relativePath';

  @override
  Future<String> pendingRelativePath(String draftKey, String sourcePath) async =>
      'pending/file';

  @override
  Future<EditorDraftRecord?> readDraft(
    String draftKey,
    UnlockedVaultSession session,
  ) async => null;

  @override
  Future<Uint8List?> readDecryptedAssetBytes(
    UnlockedVaultSession session,
    String encryptedPath,
  ) async => null;

  @override
  Future<DiaryEntry> saveEntry(
    UnlockedVaultSession session,
    DiaryEntry draft, {
    required List<PendingAttachment> pendingAttachments,
  }) async => draft;

  @override
  Future<PendingAttachment?> stagePickedImage({
    required ImageCompressPreset preset,
    required String draftKey,
    required String sourcePath,
    required String displayName,
  }) async => null;

  @override
  Future<String> stagePendingFile(String draftKey, String sourcePath) async =>
      sourcePath;

  @override
  Future<void> writeDraft(
    String draftKey,
    EditorDraftRecord record,
    UnlockedVaultSession session,
  ) async {}
}
