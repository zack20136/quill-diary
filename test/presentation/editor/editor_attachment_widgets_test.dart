import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/application/editor/editor_actions.dart';
import 'package:quill_diary/application/editor/editor_attachment_items.dart';
import 'package:quill_diary/application/editor/editor_draft_models.dart';
import 'package:quill_diary/application/session/providers/session_providers.dart';
import 'package:quill_diary/application/session/state/app_session_state.dart';
import 'package:quill_diary/application/settings/settings_providers.dart';
import 'package:quill_diary/domain/attachment/asset_attachment.dart';
import 'package:quill_diary/domain/recovery/kdf_descriptor.dart';
import 'package:quill_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';
import 'package:quill_diary/presentation/editor/pages/editor_page.dart';
import 'package:quill_diary/presentation/editor/widgets/editor_preview_gallery.dart';

import '../../helpers/app_test_theme.dart';
import '../../helpers/presentation/editor/editor_test_scope.dart';
import '../../helpers/presentation/editor/fake_editor_actions.dart';

void main() {
  late Directory tempDir;
  late PendingAttachment pendingAttachment;
  late AssetAttachment savedAttachment;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('qld_editor_attachment_');
    final File imageFile = File('${tempDir.path}/pending.png')
      ..writeAsBytesSync(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
        ),
      );
    pendingAttachment = PendingAttachment(
      assetId: 'pending-image',
      sourcePath: imageFile.path,
      mimeType: 'image/png',
      originalFilename: 'pending.png',
    );
    savedAttachment = AssetAttachment(
      id: 'saved-image',
      entryId: 'entry-1',
      mimeType: 'image/jpeg',
      safeFilename: 'saved.jpg',
      byteSize: 1,
      createdAt: DateTime(2026, 8, 18),
      sha256: 'sha',
    );
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  testWidgets('編輯頁將新圖片拖到舊圖片前方後重建與草稿皆維持順序', (tester) async {
    final EditorDraftRecord draft = EditorDraftRecord(
      title: '測試日記',
      dateValue: '2026-06-18',
      entryHour: 9,
      entryMinute: 0,
      tags: const <String>[],
      markdownBody: '內容\n',
      attachmentIds: const <AssetId>[
        'image-1',
        'file-1',
        'pending-image',
      ],
      pendingAttachments: const <EditorDraftPendingAttachment>[
        EditorDraftPendingAttachment(
          assetId: 'pending-image',
          relativePath: 'pending/pending.png.enc',
          mimeType: 'image/png',
          originalFilename: 'pending.png',
        ),
      ],
      provisionalEntryId: 'entry-1',
      createdAt: DateTime(2026, 6, 18, 8),
      updatedAt: DateTime(2026, 6, 18, 9),
    );
    final FakeEditorActions actions = FakeEditorActions(
      draft: draft,
      materializedPreviewPath: pendingAttachment.sourcePath,
    );
    const UnlockedVaultSession session = UnlockedVaultSession(
      vaultId: 'vault-1',
      trustedDevice: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          editorActionsProvider.overrideWithValue(actions),
          effectiveAppSessionProvider.overrideWith(
            (Ref ref) async => const AppSessionState(
              status: AppLockStatus.unlocked,
              session: session,
            ),
          ),
          recoveryMetadataProvider.overrideWith(
            (Ref ref) async => _recoveryMetadata,
          ),
        ],
        child: editorTestApp(
          viewport: const Size(1200, 800),
          child: const EditorPage(
            entryId: 'entry-1',
            startInEditMode: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('還原草稿'));
    await tester.pumpAndSettle();

    final ReorderableListView list = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView),
    );
    list.onReorderItem!(1, 0);
    await tester.pumpAndSettle();

    final Offset pendingPosition = tester.getTopLeft(
      find.byKey(const ValueKey<String>('editor-image-pending-image')),
    );
    final Offset savedPosition = tester.getTopLeft(
      find.byKey(const ValueKey<String>('editor-image-image-1')),
    );
    expect(pendingPosition.dx, lessThan(savedPosition.dx));
    expect(actions.writeDraftCount, greaterThan(0));
    expect(actions.writtenDraft?.attachmentIds, const <AssetId>[
      'pending-image',
      'file-1',
      'image-1',
    ]);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('預覽圖庫會依統一圖片順序顯示新圖與舊圖', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: appTestTheme(),
          home: Scaffold(
            body: EditorPreviewGallery(
              images: <EditorAttachmentItem>[
                PendingEditorAttachmentItem(pendingAttachment),
                SavedEditorAttachmentItem(savedAttachment),
              ],
              encryptedPathFuture: (_) async => '',
              onOpenGallery: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final Offset pendingPosition = tester.getTopLeft(
      find.byKey(const ValueKey<String>('editor-preview-image-pending-image')),
    );
    final Offset savedPosition = tester.getTopLeft(
      find.byKey(const ValueKey<String>('editor-preview-image-saved-image')),
    );
    expect(pendingPosition.dx, lessThan(savedPosition.dx));
  });
}

final RecoveryMetadata _recoveryMetadata = RecoveryMetadata(
  vaultId: 'vault-1',
  recoveryEnabled: true,
  recoveryKeyVersion: 1,
  recoveryKeyHint: 'hint',
  createdAt: DateTime(2026, 6, 18),
  kdf: KdfDescriptor.argon2idRecovery(
    saltBytes: List<int>.generate(16, (int index) => index),
  ),
);
