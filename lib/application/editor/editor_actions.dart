import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'package:quill_diary/domain/attachment/asset_attachment.dart';
import 'package:quill_diary/domain/diary/diary_entry.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/preferences/user_preferences.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';
import 'package:quill_diary/infrastructure/storage/storage_path_providers.dart';
import 'package:quill_diary/infrastructure/storage/storage_providers.dart';
import 'package:quill_diary/application/editor/editor_image_staging.dart'
    as editor_image_staging;
import 'editor_draft_models.dart';

final editorActionsProvider = Provider<EditorActionPort>((Ref ref) {
  return EditorActions(ref);
});

abstract interface class EditorActionPort {
  Future<EditorDraftRecord?> readDraft(
    String draftKey,
    UnlockedVaultSession session,
  );

  Future<void> writeDraft(
    String draftKey,
    EditorDraftRecord record,
    UnlockedVaultSession session,
  );

  Future<void> deleteDraft(String draftKey);

  Future<Set<String>> listDraftKeys();

  Future<String> pendingRelativePath(String draftKey, String sourcePath);

  Future<String> pendingAbsolutePath(String draftKey, String relativePath);

  Future<String> stagePendingFile(
    String draftKey,
    String sourcePath,
    UnlockedVaultSession session,
  );

  Future<String> materializePendingFileForPreview(
    String draftKey,
    String relativePath,
    UnlockedVaultSession session,
  );

  Future<void> clearAllMaterializedPendingFiles();

  Future<PendingAttachment?> stagePickedImage({
    required ImageCompressPreset preset,
    required String draftKey,
    required String sourcePath,
    required String displayName,
    required UnlockedVaultSession session,
  });

  Future<Uint8List?> readDecryptedAssetBytes(
    UnlockedVaultSession session,
    String encryptedPath,
  );

  Future<DiaryEntry?> loadEntry(UnlockedVaultSession session, EntryId entryId);

  Future<List<AssetAttachment>> loadAttachments(EntryId entryId);

  Future<void> deleteEntry(UnlockedVaultSession session, EntryId entryId);

  Future<DiaryEntry> saveEntry(
    UnlockedVaultSession session,
    DiaryEntry draft, {
    required List<PendingAttachment> pendingAttachments,
  });

  Future<String> assetAbsolutePath({
    required DateOnly date,
    required AssetAttachment attachment,
  });
}

class EditorActions implements EditorActionPort {
  const EditorActions(this._ref);

  final Ref _ref;

  @override
  Future<EditorDraftRecord?> readDraft(
    String draftKey,
    UnlockedVaultSession session,
  ) {
    return _ref.read(editorDraftStoreProvider).read(draftKey, session);
  }

  @override
  Future<void> writeDraft(
    String draftKey,
    EditorDraftRecord record,
    UnlockedVaultSession session,
  ) {
    return _ref.read(editorDraftStoreProvider).write(draftKey, record, session);
  }

  @override
  Future<void> deleteDraft(String draftKey) {
    return _ref.read(editorDraftStoreProvider).delete(draftKey);
  }

  @override
  Future<Set<String>> listDraftKeys() {
    return _ref.read(editorDraftStoreProvider).listDraftKeys();
  }

  @override
  Future<String> pendingRelativePath(String draftKey, String sourcePath) {
    return _ref
        .read(editorDraftStoreProvider)
        .pendingRelativePath(draftKey, sourcePath);
  }

  @override
  Future<String> pendingAbsolutePath(String draftKey, String relativePath) {
    return _ref
        .read(editorDraftStoreProvider)
        .pendingAbsolutePath(draftKey, relativePath);
  }

  @override
  Future<String> stagePendingFile(
    String draftKey,
    String sourcePath,
    UnlockedVaultSession session,
  ) {
    return _ref
        .read(editorDraftStoreProvider)
        .stagePendingFile(draftKey, sourcePath, session);
  }

  @override
  Future<String> materializePendingFileForPreview(
    String draftKey,
    String relativePath,
    UnlockedVaultSession session,
  ) {
    return _ref
        .read(editorDraftStoreProvider)
        .materializePendingFileForPreview(draftKey, relativePath, session);
  }

  @override
  Future<void> clearAllMaterializedPendingFiles() {
    return _ref
        .read(editorDraftStoreProvider)
        .clearAllMaterializedPendingFiles();
  }

  @override
  Future<PendingAttachment?> stagePickedImage({
    required ImageCompressPreset preset,
    required String draftKey,
    required String sourcePath,
    required String displayName,
    required UnlockedVaultSession session,
  }) {
    return editor_image_staging.stagePickedImage(
      draftStore: _ref.read(editorDraftStoreProvider),
      preset: preset,
      draftKey: draftKey,
      sourcePath: sourcePath,
      displayName: displayName,
      session: session,
    );
  }

  @override
  Future<Uint8List?> readDecryptedAssetBytes(
    UnlockedVaultSession session,
    String encryptedPath,
  ) {
    return _ref
        .read(vaultRepositoryProvider)
        .readDecryptedAssetBytes(session, encryptedPath);
  }

  @override
  Future<DiaryEntry?> loadEntry(UnlockedVaultSession session, EntryId entryId) {
    return _ref.read(vaultRepositoryProvider).loadEntry(session, entryId);
  }

  @override
  Future<List<AssetAttachment>> loadAttachments(EntryId entryId) {
    return _ref.read(vaultRepositoryProvider).loadAttachments(entryId);
  }

  @override
  Future<void> deleteEntry(UnlockedVaultSession session, EntryId entryId) {
    return _ref.read(vaultRepositoryProvider).deleteEntry(session, entryId);
  }

  @override
  Future<DiaryEntry> saveEntry(
    UnlockedVaultSession session,
    DiaryEntry draft, {
    required List<PendingAttachment> pendingAttachments,
  }) {
    return _ref
        .read(vaultRepositoryProvider)
        .saveEntry(session, draft, pendingAttachments: pendingAttachments);
  }

  @override
  Future<String> assetAbsolutePath({
    required DateOnly date,
    required AssetAttachment attachment,
  }) {
    String ext = p.extension(attachment.safeFilename).replaceFirst('.', '');
    if (ext.isEmpty) {
      ext = 'bin';
    }
    return _ref
        .read(vaultPathStrategyProvider)
        .assetAbsolutePath(date: date, assetId: attachment.id, extension: ext);
  }
}
