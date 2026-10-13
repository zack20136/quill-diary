import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/editor/editor_actions.dart';
import 'package:quill_diary/application/editor/editor_entry_providers.dart';
import 'package:quill_diary/application/session/providers/session_providers.dart';
import 'package:quill_diary/application/session/state/app_session_state.dart';
import 'package:quill_diary/application/settings/settings_providers.dart';
import 'package:quill_diary/domain/attachment/asset_attachment.dart';
import 'package:quill_diary/domain/diary/diary_entry.dart';
import 'package:quill_diary/domain/recovery/kdf_descriptor.dart';
import 'package:quill_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/presentation/editor/pages/editor_page.dart';
import 'package:quill_diary/presentation/editor/widgets/editor_markdown_preview.dart';
import 'package:quill_diary/shared/presentation/widgets/app_loading_state.dart';
import 'package:quill_diary/shared/presentation/widgets/entry_cover_thumbnail.dart';

import '../../helpers/presentation/editor/editor_test_scope.dart';
import '../../helpers/presentation/editor/fake_editor_actions.dart';

void main() {
  const UnlockedVaultSession session = UnlockedVaultSession(
    vaultId: 'vault-1',
    trustedDevice: true,
  );

  final DiaryEntry entryWithTasks = DiaryEntry(
    id: 'entry-1',
    vaultId: 'vault-1',
    title: '任務清單',
    date: DateOnly.parse('2026-06-18'),
    createdAt: DateTime(2026, 6, 18, 8),
    updatedAt: DateTime(2026, 6, 18, 9),
    markdownBody: '- [ ] 任務甲\n- [ ] 很長的任務乙內容用來確認版面',
    tags: const <String>['筆記'],
    attachmentIds: const <AssetId>[],
  );

  testWidgets('entryProvider reload 時預覽畫面不換成整頁 loading', (
    WidgetTester tester,
  ) async {
    final Completer<DiaryEntry?> reloadHang = Completer<DiaryEntry?>();
    final _ReloadAwareEditorActions actions = _ReloadAwareEditorActions(
      existingEntry: entryWithTasks,
      hangAfterFirstLoad: reloadHang,
    );

    final ProviderContainer container = ProviderContainer(
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
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: editorTestApp(
          child: const EditorPage(entryId: 'entry-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(EditorMarkdownPreview), findsOneWidget);
    expect(find.text('任務甲'), findsOneWidget);
    expect(find.byType(AppLoadingState), findsNothing);

    // 模擬預覽勾選存檔後 invalidate entryProvider 的 reload。
    container.invalidate(entryProvider('entry-1'));
    await tester.pump();

    expect(find.byType(AppLoadingState), findsNothing);
    expect(find.byType(EditorMarkdownPreview), findsOneWidget);
    expect(find.text('任務甲'), findsOneWidget);

    reloadHang.complete(entryWithTasks);
    await tester.pumpAndSettle();
    expect(find.text('任務甲'), findsOneWidget);
  });

  testWidgets('有圖片時預覽勾選重讀不會讓圖片列或縮圖先消失', (
    WidgetTester tester,
  ) async {
    final AssetAttachment image = AssetAttachment(
      id: 'image-1',
      entryId: 'entry-1',
      mimeType: 'image/jpeg',
      safeFilename: 'image-1.jpg',
      originalFilename: 'photo.jpg',
      byteSize: 4,
      createdAt: DateTime(2026, 6, 18, 8),
      sha256: 'sha-image',
      width: 1200,
      height: 800,
    );
    final DiaryEntry entryWithImage = DiaryEntry(
      id: entryWithTasks.id,
      vaultId: entryWithTasks.vaultId,
      title: entryWithTasks.title,
      date: entryWithTasks.date,
      createdAt: entryWithTasks.createdAt,
      updatedAt: entryWithTasks.updatedAt,
      markdownBody: entryWithTasks.markdownBody,
      tags: entryWithTasks.tags,
      attachmentIds: const <AssetId>['image-1'],
    );
    final Completer<DiaryEntry?> reloadHang = Completer<DiaryEntry?>();
    final Completer<List<AssetAttachment>> attachmentsReload =
        Completer<List<AssetAttachment>>();
    final Completer<Uint8List?> bytesReload = Completer<Uint8List?>();
    final _ReloadAwareEditorActions actions = _ReloadAwareEditorActions(
      existingEntry: entryWithImage,
      hangAfterFirstLoad: reloadHang,
      attachments: <AssetAttachment>[image],
      attachmentsReload: attachmentsReload,
      bytesReload: bytesReload,
    );

    final ProviderContainer container = ProviderContainer(
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
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: editorTestApp(
          child: const EditorPage(entryId: 'entry-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('editor-preview-gallery')), findsOneWidget);
    expect(find.byType(EntryCoverThumbnail), findsOneWidget);
    expect(find.byType(EntryCoverThumbnailLoading), findsNothing);

    actions.holdReloads = true;
    container.read(entryIndexRevisionProvider.notifier).bump();
    container
      ..invalidate(entryProvider('entry-1'))
      ..invalidate(entryAttachmentsProvider('entry-1'));
    await tester.pump();

    expect(find.byKey(const Key('editor-preview-gallery')), findsOneWidget);
    expect(find.byType(EntryCoverThumbnail), findsOneWidget);
    expect(find.byType(EntryCoverThumbnailLoading), findsNothing);
    expect(find.byType(AppLoadingState), findsNothing);

    reloadHang.complete(entryWithImage);
    attachmentsReload.complete(<AssetAttachment>[image]);
    bytesReload.complete(Uint8List.fromList(const <int>[1, 2, 3, 4]));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('editor-preview-gallery')), findsOneWidget);
  });
}

class _ReloadAwareEditorActions extends FakeEditorActions {
  _ReloadAwareEditorActions({
    required DiaryEntry existingEntry,
    required this.hangAfterFirstLoad,
    List<AssetAttachment>? attachments,
    this.attachmentsReload,
    this.bytesReload,
  }) : super(
         existingEntry: existingEntry,
         attachments: attachments ?? const [],
       );

  final Completer<DiaryEntry?> hangAfterFirstLoad;
  final Completer<List<AssetAttachment>>? attachmentsReload;
  final Completer<Uint8List?>? bytesReload;
  bool holdReloads = false;

  @override
  Future<DiaryEntry?> loadEntry(
    UnlockedVaultSession session,
    EntryId entryId,
  ) async {
    loadEntryCallCount++;
    if (loadEntryCallCount == 1) {
      return existingEntry ?? FakeEditorActions.defaultEntry;
    }
    return hangAfterFirstLoad.future;
  }

  @override
  Future<List<AssetAttachment>> loadAttachments(EntryId entryId) async {
    if (holdReloads && attachmentsReload != null) {
      return attachmentsReload!.future;
    }
    return attachments;
  }

  @override
  Future<Uint8List?> readDecryptedAssetBytes(
    UnlockedVaultSession session,
    String encryptedPath,
  ) async {
    if (holdReloads && bytesReload != null) {
      return bytesReload!.future;
    }
    return Uint8List.fromList(const <int>[1, 2, 3, 4]);
  }
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
