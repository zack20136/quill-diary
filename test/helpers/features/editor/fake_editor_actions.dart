import 'dart:typed_data';

import 'package:quill_diary/domain/attachment/asset_attachment.dart';
import 'package:quill_diary/domain/diary/diary_entry.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/features/editor/application/editor_actions.dart';
import 'package:quill_diary/features/editor/application/editor_draft_models.dart';
import 'package:quill_diary/infrastructure/preferences/user_preferences.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';

class FakeEditorActions implements EditorActionPort {
  FakeEditorActions({this.existingEntry});

  static final DiaryEntry defaultEntry = DiaryEntry(
    id: 'entry-1',
    vaultId: 'vault-1',
    title: '測試標題',
    date: DateOnly.parse('2026-06-18'),
    createdAt: DateTime(2026, 6, 18, 8),
    updatedAt: DateTime(2026, 6, 18, 9),
    markdownBody: '內文',
    tags: const <String>['標籤'],
    attachmentIds: const <AssetId>['image-1', 'file-1'],
  );

  static final List<AssetAttachment> defaultAttachments = <AssetAttachment>[
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

  final DiaryEntry? existingEntry;
  int writeDraftCount = 0;
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
      defaultAttachments;

  @override
  Future<DiaryEntry?> loadEntry(
    UnlockedVaultSession session,
    EntryId entryId,
  ) async => existingEntry ?? defaultEntry;

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
  ) async {
    writeDraftCount++;
  }
}
