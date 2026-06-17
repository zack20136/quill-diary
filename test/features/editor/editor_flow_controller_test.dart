import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/attachment/asset_attachment.dart';
import 'package:quill_diary/domain/diary/diary_entry.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/features/editor/application/editor_actions.dart';
import 'package:quill_diary/features/editor/application/editor_draft_models.dart';
import 'package:quill_diary/features/editor/application/editor_flow_controller.dart';
import 'package:quill_diary/infrastructure/preferences/user_preferences.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';

void main() {
  final UnlockedVaultSession session = UnlockedVaultSession(
    vaultId: 'vault_1',
    trustedDevice: true,
    recoveryWrapKey: const <int>[1, 2, 3],
  );

  ProviderContainer buildContainer(FakeEditorActionPort actions) {
    final ProviderContainer container = ProviderContainer(
      overrides: [editorActionsProvider.overrideWithValue(actions)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('restoreDraftIfNeeded 會回傳還原結果並解析 pending 路徑', () async {
    final EditorDraftRecord record = EditorDraftRecord(
      title: '草稿',
      dateValue: '2026-06-17',
      entryHour: 9,
      entryMinute: 30,
      tags: <String>['旅行'],
      markdownBody: 'body',
      keptAttachmentIds: <AssetId>['asset_saved'],
      pendingAttachments: <EditorDraftPendingAttachment>[
        const EditorDraftPendingAttachment(
          relativePath: 'pending/photo.jpg',
          mimeType: 'image/jpeg',
          originalFilename: 'photo.jpg',
        ),
      ],
      provisionalEntryId: 'entry_draft',
      createdAt: DateTime(2026, 6, 17, 9),
      updatedAt: DateTime(2026, 6, 17, 10),
    );
    final FakeEditorActionPort actions = FakeEditorActionPort(
      draftRecord: record,
      pendingAbsolutePathBuilder:
          (String _, String relativePath) => 'C:/drafts/$relativePath',
    );
    final ProviderContainer container = buildContainer(actions);
    final EditorFlowController controller = container.read(
      editorFlowControllerProvider,
    );

    final EditorDraftRestoreDecision decision =
        await controller.restoreDraftIfNeeded(
      draftKey: 'entry_draft',
      session: session,
      existingEntry: null,
      decideRestore: (_) async => true,
    );

    expect(decision.kind, EditorDraftRestoreKind.restored);
    expect(decision.record, same(record));
    expect(decision.pendingAttachments.single.sourcePath, 'C:/drafts/pending/photo.jpg');
    expect(actions.deletedDraftKeys, isEmpty);
  });

  test('saveEntry 會保存條目、清掉草稿並回傳 preview route', () async {
    final DiaryEntry savedEntry = DiaryEntry(
      id: 'entry_saved',
      vaultId: session.vaultId,
      title: '新條目',
      date: DateOnly.parse('2026-06-17'),
      createdAt: DateTime(2026, 6, 17, 14, 20),
      updatedAt: DateTime(2026, 6, 17, 14, 30),
      tags: const <String>['tag'],
      markdownBody: 'hello',
      attachmentIds: const <AssetId>['asset_saved'],
    );
    final FakeEditorActionPort actions = FakeEditorActionPort(
      savedEntry: savedEntry,
    );
    final ProviderContainer container = buildContainer(actions);
    final EditorFlowController controller = container.read(
      editorFlowControllerProvider,
    );

    final EditorSaveResult result = await controller.saveEntry(
      EditorSaveRequest(
        draftKey: 'entry_saved',
        session: session,
        existingEntry: null,
        titleRaw: '  新條目  ',
        dateValue: '2026-06-17',
        entryTime: const TimeOfDay(hour: 14, minute: 20),
        tagsRaw: 'tag',
        markdownBodyRaw: 'hello',
        keptAttachmentIds: const <AssetId>['asset_saved'],
        pendingAttachments: const <PendingAttachment>[],
        provisionalEntryId: 'entry_saved',
        switchToPreview: true,
      ),
    );

    expect(actions.savedDraft?.title, '新條目');
    expect(actions.deletedDraftKeys, contains('entry_saved'));
    expect(result.savedEntry.id, 'entry_saved');
    expect(result.routeLocation, '/editor/entry_saved');
    expect(result.switchToPreview, isTrue);
  });

  test('stagePickedImages 會去重複路徑，stagePickedFile 會補上 mime', () async {
    final FakeEditorActionPort actions = FakeEditorActionPort(
      stagedImageFactory: (String path) => PendingAttachment(
        sourcePath: 'C:/staged/${path.split('/').last}',
        mimeType: 'image/jpeg',
        originalFilename: path.split('/').last,
      ),
      stagedFileRelativePath: 'pending/file.md',
      pendingAbsolutePathBuilder:
          (String _, String relativePath) => 'C:/drafts/$relativePath',
    );
    final ProviderContainer container = buildContainer(actions);
    final EditorFlowController controller = container.read(
      editorFlowControllerProvider,
    );

    final List<PendingAttachment> images = await controller.stagePickedImages(
      preset: ImageCompressPreset.standard,
      draftKey: 'draft_1',
      sourcePaths: const <String>[
        'C:/images/a.jpg',
        'C:/images/a.jpg',
        'C:/images/b.jpg',
      ],
    );
    final PendingAttachment? file = await controller.stagePickedFile(
      draftKey: 'draft_1',
      path: 'C:/docs/readme.md',
      displayName: 'readme.md',
    );

    expect(images, hasLength(2));
    expect(actions.stagedImagePaths, <String>['C:/images/a.jpg', 'C:/images/b.jpg']);
    expect(file, isNotNull);
    expect(file!.sourcePath, 'C:/drafts/pending/file.md');
    expect(file.mimeType, 'text/markdown');
  });
}

class FakeEditorActionPort implements EditorActionPort {
  FakeEditorActionPort({
    this.draftRecord,
    this.savedEntry,
    this.pendingAbsolutePathBuilder,
    this.stagedImageFactory,
    this.stagedFileRelativePath = 'pending/file.bin',
  });

  final EditorDraftRecord? draftRecord;
  final DiaryEntry? savedEntry;
  final String Function(String draftKey, String relativePath)?
  pendingAbsolutePathBuilder;
  final PendingAttachment? Function(String path)? stagedImageFactory;
  final String stagedFileRelativePath;

  final List<String> deletedDraftKeys = <String>[];
  final List<String> stagedImagePaths = <String>[];
  DiaryEntry? savedDraft;

  @override
  Future<String> assetAbsolutePath({
    required DateOnly date,
    required AssetAttachment attachment,
  }) async {
    return 'C:/vault/${date.value}/${attachment.id}.enc';
  }

  @override
  Future<void> deleteDraft(String draftKey) async {
    deletedDraftKeys.add(draftKey);
  }

  @override
  Future<void> deleteEntry(UnlockedVaultSession session, EntryId entryId) async {}

  @override
  Future<List<AssetAttachment>> loadAttachments(EntryId entryId) async {
    return const <AssetAttachment>[];
  }

  @override
  Future<DiaryEntry?> loadEntry(
    UnlockedVaultSession session,
    EntryId entryId,
  ) async {
    return savedEntry;
  }

  @override
  Future<Set<String>> listDraftKeys() async => <String>{};

  @override
  Future<String> pendingAbsolutePath(String draftKey, String relativePath) async {
    return pendingAbsolutePathBuilder?.call(draftKey, relativePath) ??
        'C:/drafts/$relativePath';
  }

  @override
  Future<String> pendingRelativePath(String draftKey, String sourcePath) async {
    return 'pending/${sourcePath.split('/').last}';
  }

  @override
  Future<EditorDraftRecord?> readDraft(
    String draftKey,
    UnlockedVaultSession session,
  ) async {
    return draftRecord;
  }

  @override
  Future<Uint8List?> readDecryptedAssetBytes(
    UnlockedVaultSession session,
    String encryptedPath,
  ) async {
    return null;
  }

  @override
  Future<DiaryEntry> saveEntry(
    UnlockedVaultSession session,
    DiaryEntry draft, {
    required List<PendingAttachment> pendingAttachments,
  }) async {
    savedDraft = draft;
    return savedEntry ?? draft;
  }

  @override
  Future<PendingAttachment?> stagePickedImage({
    required ImageCompressPreset preset,
    required String draftKey,
    required String sourcePath,
    required String displayName,
  }) async {
    stagedImagePaths.add(sourcePath);
    return stagedImageFactory?.call(sourcePath);
  }

  @override
  Future<String> stagePendingFile(String draftKey, String sourcePath) async {
    return stagedFileRelativePath;
  }

  @override
  Future<void> writeDraft(
    String draftKey,
    EditorDraftRecord record,
    UnlockedVaultSession session,
  ) async {}
}
