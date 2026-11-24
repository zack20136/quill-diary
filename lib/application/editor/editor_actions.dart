import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:quill_diary/application/editor/editor_image_staging.dart'
    as editor_image_staging;
import 'package:quill_diary/application/vault/vault_providers.dart';
import 'package:quill_diary/domain/attachment/asset_attachment.dart';
import 'package:quill_diary/domain/diary/diary_entry.dart';
import 'package:quill_diary/domain/diary/editor_draft.dart';
import 'package:quill_diary/domain/preferences/personalization_preferences.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/domain/vault_maintenance_models.dart';
import 'package:quill_diary/infrastructure/storage/editor_draft_store.dart';

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

  Future<String> pendingAbsolutePath(String draftKey, String relativePath);

  Future<String> stagePendingBytes(
    String draftKey,
    Uint8List bytes,
    String fileName,
    UnlockedVaultSession session,
  );

  Future<Uint8List> readPendingAttachment(
    ({String draftKey, String path}) source,
    UnlockedVaultSession session,
  );

  Future<PendingAttachment> stagePickedImage({
    required ImageCompressPreset preset,
    required String draftKey,
    required String sourcePath,
    required UnlockedVaultSession session,
  });

  Future<void> deleteEntry(UnlockedVaultSession session, EntryId entryId);

  Future<DiaryEntry> saveEntry(
    UnlockedVaultSession session,
    DiaryEntry draft, {
    required List<PendingAttachment> pendingAttachments,
    List<VaultFinding> retireFindingsAfterSave = const <VaultFinding>[],
  });

  Future<String> assetAbsolutePath({
    required DateOnly date,
    required AssetAttachment attachment,
  });
}

class EditorActions implements EditorActionPort {
  EditorActions(this._ref) : _draftStore = _ref.read(editorDraftStoreProvider);

  final Ref _ref;
  final EditorDraftStore _draftStore;

  @override
  Future<EditorDraftRecord?> readDraft(
    String draftKey,
    UnlockedVaultSession session,
  ) {
    return _draftStore.read(draftKey, session);
  }

  @override
  Future<void> writeDraft(
    String draftKey,
    EditorDraftRecord record,
    UnlockedVaultSession session,
  ) {
    return _draftStore.write(draftKey, record, session);
  }

  @override
  Future<void> deleteDraft(String draftKey) {
    return _draftStore.delete(draftKey);
  }

  @override
  Future<Set<String>> listDraftKeys() {
    return _draftStore.listDraftKeys();
  }

  @override
  Future<String> pendingAbsolutePath(String draftKey, String relativePath) {
    return _draftStore.pendingAbsolutePath(draftKey, relativePath);
  }

  @override
  Future<String> stagePendingBytes(
    String draftKey,
    Uint8List bytes,
    String fileName,
    UnlockedVaultSession session,
  ) {
    return _draftStore.stagePendingBytes(draftKey, bytes, fileName, session);
  }

  @override
  Future<Uint8List> readPendingAttachment(
    ({String draftKey, String path}) source,
    UnlockedVaultSession session,
  ) {
    return _draftStore.readPendingAttachment(source, session);
  }

  @override
  Future<PendingAttachment> stagePickedImage({
    required ImageCompressPreset preset,
    required String draftKey,
    required String sourcePath,
    required UnlockedVaultSession session,
  }) {
    return editor_image_staging.stagePickedImage(
      draftStore: _draftStore,
      preset: preset,
      draftKey: draftKey,
      sourcePath: sourcePath,
      session: session,
    );
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
    List<VaultFinding> retireFindingsAfterSave = const <VaultFinding>[],
  }) {
    return _ref
        .read(vaultRepositoryProvider)
        .saveEntry(
          session,
          draft,
          pendingAttachments: pendingAttachments,
          retireFindingsAfterSave: retireFindingsAfterSave,
        );
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
