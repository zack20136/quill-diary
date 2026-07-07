import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/application/editor/editor_actions.dart';
import 'package:quill_diary/application/editor/editor_draft_models.dart';
import 'package:quill_diary/application/editor/editor_flow_controller.dart';
import 'package:quill_diary/domain/attachment/asset_attachment.dart';
import 'package:quill_diary/domain/diary/diary_entry.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/preferences/user_preferences.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';

void main() {
  test('儲存日記前會正規化任務清單 markdown', () async {
    final _InlineFakeEditorActions actions = _InlineFakeEditorActions();
    final ProviderContainer container = ProviderContainer(
      overrides: [editorActionsProvider.overrideWithValue(actions)],
    );
    addTearDown(container.dispose);

    final EditorFlowController controller = container.read(
      editorFlowControllerProvider,
    );
    final UnlockedVaultSession session = UnlockedVaultSession(
      vaultId: 'vault-1',
      trustedDevice: true,
    );

    await controller.saveEntry(
      EditorSaveRequest(
        draftKey: 'draft-1',
        session: session,
        existingEntry: null,
        titleRaw: '標題',
        dateValue: '2026-06-18',
        entryTime: const TimeOfDay(hour: 8, minute: 0),
        tagsRaw: '標籤',
        markdownBodyRaw: '前言\n- [ ] 任務三',
        keptAttachmentIds: const <AssetId>[],
        pendingAttachments: const <PendingAttachment>[],
        provisionalEntryId: 'entry-new',
        switchToPreview: true,
      ),
    );

    expect(actions.saveEntryCallCount, 1);
    expect(actions.savedEntryDraft?.markdownBody, '前言\n- [ ] 任務三\n');
  });
}

class _InlineFakeEditorActions implements EditorActionPort {
  int saveEntryCallCount = 0;
  DiaryEntry? savedEntryDraft;

  @override
  Future<String> assetAbsolutePath({
    required DateOnly date,
    required AssetAttachment attachment,
  }) async => 'C:/vault/${attachment.id}';

  @override
  Future<void> clearAllMaterializedPendingFiles() async {}

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
      <AssetAttachment>[];

  @override
  Future<DiaryEntry?> loadEntry(
    UnlockedVaultSession session,
    EntryId entryId,
  ) async => null;

  @override
  Future<String> materializePendingFileForPreview(
    String draftKey,
    String relativePath,
    UnlockedVaultSession session,
  ) async => 'C:/drafts/preview/$relativePath';

  @override
  Future<String> pendingAbsolutePath(
    String draftKey,
    String relativePath,
  ) async => 'C:/drafts/$relativePath';

  @override
  Future<String> pendingRelativePath(
    String draftKey,
    String sourcePath,
  ) async => 'pending/file';

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
  }) async {
    saveEntryCallCount++;
    savedEntryDraft = draft;
    return draft;
  }

  @override
  Future<PendingAttachment?> stagePickedImage({
    required ImageCompressPreset preset,
    required String draftKey,
    required String sourcePath,
    required String displayName,
    required UnlockedVaultSession session,
  }) async => null;

  @override
  Future<String> stagePendingFile(
    String draftKey,
    String sourcePath,
    UnlockedVaultSession session,
  ) async => 'pending/file.enc';

  @override
  Future<void> writeDraft(
    String draftKey,
    EditorDraftRecord record,
    UnlockedVaultSession session,
  ) async {}
}
