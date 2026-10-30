import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:quill_diary/application/diary/diary_entry_providers.dart';
import 'package:quill_diary/application/editor/editor_actions.dart';
import 'package:quill_diary/application/editor/editor_attachment_items.dart';
import 'package:quill_diary/application/editor/editor_body_blocks.dart';
import 'package:quill_diary/application/editor/editor_draft_providers.dart';
import 'package:quill_diary/application/editor/editor_draft_snapshot.dart';
import 'package:quill_diary/application/editor/editor_gallery_export.dart';
import 'package:quill_diary/application/session/session_providers.dart';
import 'package:quill_diary/application/session/session_state.dart';
import 'package:quill_diary/application/settings/settings_providers.dart';
import 'package:quill_diary/application/vault/vault_providers.dart';
import 'package:quill_diary/domain/attachment/asset_attachment.dart';
import 'package:quill_diary/domain/diary/diary_draft.dart';
import 'package:quill_diary/domain/diary/diary_entry.dart';
import 'package:quill_diary/domain/preferences/personalization_preferences.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/storage/vault_maintenance_models.dart';

final editorFlowControllerProvider = Provider<EditorFlowController>((Ref ref) {
  return EditorFlowController(ref);
});

enum EditorDraftRestoreKind { noDraft, restored, discarded }

class EditorDraftRestoreDecision {
  const EditorDraftRestoreDecision._({
    required this.kind,
    this.record,
    this.pendingAttachments = const <PendingAttachment>[],
    this.snapshot,
  });

  const EditorDraftRestoreDecision.noDraft()
    : this._(kind: EditorDraftRestoreKind.noDraft);

  const EditorDraftRestoreDecision.discarded()
    : this._(kind: EditorDraftRestoreKind.discarded);

  const EditorDraftRestoreDecision.restored({
    required EditorDraftRecord record,
    required List<PendingAttachment> pendingAttachments,
    required EditorDraftSnapshot snapshot,
  }) : this._(
         kind: EditorDraftRestoreKind.restored,
         record: record,
         pendingAttachments: pendingAttachments,
         snapshot: snapshot,
       );

  final EditorDraftRestoreKind kind;
  final EditorDraftRecord? record;
  final List<PendingAttachment> pendingAttachments;
  final EditorDraftSnapshot? snapshot;
}

class EditorPersistDraftRequest {
  const EditorPersistDraftRequest({
    required this.draftKey,
    required this.snapshot,
    required this.tagsRaw,
    required this.attachmentIds,
    required this.pendingAttachments,
    required this.session,
    required this.createdAt,
    required this.provisionalEntryId,
    required this.existingEntryId,
    this.salvageSourceFindings = const <Map<String, Object?>>[],
  });

  final String draftKey;
  final EditorDraftSnapshot snapshot;
  final String tagsRaw;
  final List<AssetId> attachmentIds;
  final List<PendingAttachment> pendingAttachments;
  final UnlockedVaultSession session;
  final DateTime createdAt;
  final EntryId provisionalEntryId;
  final EntryId? existingEntryId;
  final List<Map<String, Object?>> salvageSourceFindings;
}

class EditorPersistDraftResult {
  const EditorPersistDraftResult({
    required this.record,
    required this.snapshot,
  });

  final EditorDraftRecord record;
  final EditorDraftSnapshot snapshot;
}

class EditorSaveRequest {
  const EditorSaveRequest({
    required this.draftKey,
    required this.session,
    required this.existingEntry,
    required this.titleRaw,
    required this.dateValue,
    required this.entryTime,
    required this.tagsRaw,
    required this.markdownBodyRaw,
    required this.attachmentIds,
    required this.pendingAttachments,
    required this.provisionalEntryId,
    required this.switchToPreview,
    this.retireFindingsAfterSave = const <VaultFinding>[],
  });

  final String draftKey;
  final UnlockedVaultSession session;
  final DiaryEntry? existingEntry;
  final String titleRaw;
  final String dateValue;
  final ({int hour, int minute}) entryTime;
  final String tagsRaw;
  final String markdownBodyRaw;
  final List<AssetId> attachmentIds;
  final List<PendingAttachment> pendingAttachments;
  final EntryId provisionalEntryId;
  final bool switchToPreview;
  final List<VaultFinding> retireFindingsAfterSave;
}

class EditorSaveResult {
  const EditorSaveResult({
    required this.savedEntry,
    required this.routeLocation,
    required this.switchToPreview,
  });

  final DiaryEntry savedEntry;
  final String routeLocation;
  final bool switchToPreview;
}

class PreparedEditorGallery {
  const PreparedEditorGallery({
    required this.items,
    required this.initialIndex,
  });

  final List<GalleryImageItem> items;
  final int initialIndex;
}

class EditorFlowController {
  EditorFlowController(this._ref) : _actions = _ref.read(editorActionsProvider);

  final Ref _ref;
  final EditorActionPort _actions;

  EditorFlowSession startSession({
    required void Function(EditorPersistDraftResult) onDraftPersisted,
  }) => EditorFlowSession._(this, onDraftPersisted);

  Future<EditorPersistDraftResult> persistDraft(
    EditorPersistDraftRequest request,
  ) async {
    final DateTime now = DateTime.now();
    final List<EditorDraftPendingAttachment> pendingAttachments =
        <EditorDraftPendingAttachment>[];
    for (final PendingAttachment attachment in request.pendingAttachments) {
      final String? relativePath = attachment.pendingRelativePath?.trim();
      if (relativePath == null || relativePath.isEmpty) {
        continue;
      }
      pendingAttachments.add(
        EditorDraftPendingAttachment(
          assetId: attachment.assetId,
          relativePath: relativePath,
          mimeType: attachment.mimeType,
          originalFilename: attachment.originalFilename,
        ),
      );
    }

    final EditorDraftRecord record = EditorDraftRecord(
      title: request.snapshot.title,
      dateValue: request.snapshot.dateValue,
      entryHour: request.snapshot.entryHour,
      entryMinute: request.snapshot.entryMinute,
      tags: parseEditorTagsCsv(request.tagsRaw),
      markdownBody: request.snapshot.markdownBody,
      attachmentIds: List<AssetId>.from(request.attachmentIds),
      pendingAttachments: pendingAttachments,
      provisionalEntryId: request.provisionalEntryId,
      createdAt: request.createdAt,
      updatedAt: now,
      salvageSourceFindings: List<Map<String, Object?>>.from(
        request.salvageSourceFindings,
      ),
    );
    await _actions.writeDraft(request.draftKey, record, request.session);
    if (_ref.mounted) _ref.invalidate(editorDraftKeysProvider);
    return EditorPersistDraftResult(record: record, snapshot: request.snapshot);
  }

  Future<void> discardDraft(String draftKey) async {
    await _actions.deleteDraft(draftKey);
    if (_ref.mounted) _ref.invalidate(editorDraftKeysProvider);
  }

  Future<EditorDraftRestoreDecision> restoreDraftIfNeeded({
    required String draftKey,
    required UnlockedVaultSession session,
    required DiaryEntry? existingEntry,
    required Future<bool?> Function(EditorDraftRecord record) decideRestore,
  }) async {
    final EditorDraftRecord? record = await _actions.readDraft(
      draftKey,
      session,
    );
    if (record == null) {
      return const EditorDraftRestoreDecision.noDraft();
    }

    final EditorDraftSnapshot snapshot = editorDraftSnapshotFromRecord(record);
    if (existingEntry == null && editorDraftIsEmpty(snapshot)) {
      await discardDraft(draftKey);
      return const EditorDraftRestoreDecision.discarded();
    }

    final bool? restore = await decideRestore(record);
    if (restore != true) {
      await discardDraft(draftKey);
      return const EditorDraftRestoreDecision.discarded();
    }

    final Map<String, String> previewPaths = <String, String>{};
    for (final EditorDraftPendingAttachment attachment
        in record.pendingAttachments) {
      previewPaths[attachment.relativePath] = await _actions
          .materializePendingFileForPreview(
            draftKey,
            attachment.relativePath,
            session,
          );
    }
    return EditorDraftRestoreDecision.restored(
      record: record,
      pendingAttachments: pendingAttachmentsFromDraftRecord(
        record,
        absolutePathBuilder: (String relativePath) =>
            previewPaths[relativePath] ?? '',
      ),
      snapshot: snapshot,
    );
  }

  Future<EditorSaveResult> saveEntry(EditorSaveRequest request) async {
    final DateOnly parsedDate = DateOnly.parse(request.dateValue.trim());
    final DateTime now = DateTime.now();
    final DiaryEntry draft = DiaryEntry(
      id: request.existingEntry?.id ?? request.provisionalEntryId,
      vaultId: request.existingEntry?.vaultId ?? request.session.vaultId,
      title: request.titleRaw.trim().isEmpty ? null : request.titleRaw.trim(),
      date: parsedDate,
      createdAt: _composeEntryCreatedAt(
        date: parsedDate,
        existing: request.existingEntry,
        entryTime: request.entryTime,
      ),
      updatedAt: now,
      tags: parseEditorTagsCsv(request.tagsRaw),
      markdownBody: normalizeEditorBodyMarkdownForSave(request.markdownBodyRaw),
      attachmentIds: List<AssetId>.from(request.attachmentIds),
    );
    final DiaryEntry saved = await _actions.saveEntry(
      request.session,
      draft,
      pendingAttachments: List<PendingAttachment>.from(
        request.pendingAttachments,
      ),
      retireFindingsAfterSave: List<VaultFinding>.from(
        request.retireFindingsAfterSave,
      ),
    );
    await discardDraft(request.draftKey);
    _refreshCaches(
      editedEntryId: saved.id,
      refreshVaultMaintenance: request.retireFindingsAfterSave.isNotEmpty,
    );
    return EditorSaveResult(
      savedEntry: saved,
      routeLocation: request.switchToPreview
          ? '/editor/${saved.id}'
          : '/editor/${saved.id}?edit=1',
      switchToPreview: request.switchToPreview,
    );
  }

  Future<void> deleteEntry({
    required UnlockedVaultSession session,
    required EntryId entryId,
  }) async {
    await _actions.deleteEntry(session, entryId);
    _refreshCaches(editedEntryId: entryId);
  }

  Future<List<PendingAttachment>> stagePickedImages({
    required ImageCompressPreset preset,
    required String draftKey,
    required Iterable<String> sourcePaths,
    required UnlockedVaultSession session,
  }) async {
    final Set<String> seenPaths = <String>{};
    final List<PendingAttachment> staged = <PendingAttachment>[];
    for (final String rawPath in sourcePaths) {
      final String path = rawPath.trim();
      if (path.isEmpty || !seenPaths.add(path)) {
        continue;
      }
      final PendingAttachment? attachment = await _actions.stagePickedImage(
        preset: preset,
        draftKey: draftKey,
        sourcePath: path,
        displayName: p.basename(path),
        session: session,
      );
      if (attachment != null) {
        staged.add(attachment);
      }
    }
    return staged;
  }

  Future<PendingAttachment?> stagePickedFile({
    required String draftKey,
    required String path,
    required String displayName,
    required UnlockedVaultSession session,
  }) async {
    final String trimmed = path.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final String relativePath = await _actions.stagePendingFile(
      draftKey,
      trimmed,
      session,
    );
    final String previewPath = await _actions.materializePendingFileForPreview(
      draftKey,
      relativePath,
      session,
    );
    return PendingAttachment(
      assetId: generateAssetId(),
      sourcePath: previewPath,
      pendingRelativePath: relativePath,
      mimeType: _mimeTypeFromPath(trimmed),
      originalFilename: displayName,
    );
  }

  Future<String> assetEncryptedPath({
    required String savedAttachmentDateValue,
    required AssetAttachment attachment,
  }) async {
    DateOnly date;
    try {
      date = DateOnly.parse(savedAttachmentDateValue.trim());
    } catch (_) {
      date = DateOnly.fromDateTime(DateTime.now());
    }
    return _actions.assetAbsolutePath(date: date, attachment: attachment);
  }

  Future<PreparedEditorGallery> preparePreviewGalleryItems({
    required String savedAttachmentDateValue,
    required List<EditorAttachmentItem> images,
    required int initialIndex,
  }) async {
    final List<GalleryImageItem> items = <GalleryImageItem>[];
    for (final EditorAttachmentItem item in images) {
      switch (item) {
        case SavedEditorAttachmentItem(:final attachment):
          final String path = await assetEncryptedPath(
            savedAttachmentDateValue: savedAttachmentDateValue,
            attachment: attachment,
          );
          if (path.trim().isEmpty) {
            continue;
          }
          items.add(
            GalleryImageItem.encrypted(
              path: path,
              fileName: galleryDownloadFileName(
                attachment.originalFilename ?? attachment.safeFilename,
                attachment.mimeType,
              ),
              mimeType: attachment.mimeType,
            ),
          );
        case PendingEditorAttachmentItem(:final attachment):
          final String? path = attachment.sourcePath?.trim();
          if (path == null || path.isEmpty) {
            continue;
          }
          items.add(
            GalleryImageItem.local(
              path: path,
              fileName: galleryDownloadFileName(
                attachment.originalFilename,
                attachment.mimeType,
              ),
              mimeType: attachment.mimeType,
            ),
          );
      }
    }
    return PreparedEditorGallery(
      items: items,
      initialIndex: items.isEmpty ? 0 : initialIndex.clamp(0, items.length - 1),
    );
  }

  Future<Uint8List?> loadGalleryImageBytes(GalleryImageItem item) async {
    switch (item.source) {
      case GalleryImageSource.local:
        final File file = File(item.path);
        if (!file.existsSync()) {
          return null;
        }
        return file.readAsBytes();
      case GalleryImageSource.encrypted:
        final AppSessionState sessionState = await _ref.read(
          effectiveAppSessionProvider.future,
        );
        if (!sessionState.isUnlocked || sessionState.session == null) {
          return null;
        }
        return _ref
            .read(vaultRepositoryProvider)
            .readDecryptedAssetBytes(sessionState.session!, item.path);
    }
  }

  DateTime _composeEntryCreatedAt({
    required DateOnly date,
    required DiaryEntry? existing,
    required ({int hour, int minute}) entryTime,
  }) {
    final DateTime base = date.toDateTime();
    if (existing != null) {
      return DateTime(
        base.year,
        base.month,
        base.day,
        entryTime.hour,
        entryTime.minute,
        existing.createdAt.second,
        existing.createdAt.millisecond,
        existing.createdAt.microsecond,
      );
    }
    final DateTime now = DateTime.now();
    return DateTime(
      base.year,
      base.month,
      base.day,
      entryTime.hour,
      entryTime.minute,
      now.second,
      now.millisecond,
      now.microsecond,
    );
  }

  String _mimeTypeFromPath(String pathValue) {
    switch (p.extension(pathValue).toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.gif':
        return 'image/gif';
      case '.md':
        return 'text/markdown';
      default:
        return 'application/octet-stream';
    }
  }

  void _refreshCaches({
    EntryId? editedEntryId,
    bool refreshVaultMaintenance = false,
  }) {
    if (!_ref.mounted) return;
    _ref.invalidate(editorDraftKeysProvider);
    if (refreshVaultMaintenance) {
      _ref
        ..invalidate(vaultRepairSummaryProvider)
        ..invalidate(vaultInspectSummaryProvider);
    }
    _ref.read(diaryRevisionProvider.notifier).bump();
    final EntryId? id = editedEntryId?.trim();
    if (id != null && id.isNotEmpty) {
      _ref.invalidate(entryProvider(id));
      _ref.invalidate(entryAttachmentsProvider(id));
    }
  }
}

/// 每個編輯器各自管理保存排程，寫入使用操作當下的欄位快照。
class EditorFlowSession {
  EditorFlowSession._(this._flow, this._onDraftPersisted);
  final EditorFlowController _flow;
  final void Function(EditorPersistDraftResult) _onDraftPersisted;
  EditorPersistDraftRequest? _pendingDraft;
  Future<void>? _draftWrite;
  int _stateVersion = 0;
  int _previewVersion = 0;
  bool _closed = false;

  Future<void> persistDraft(EditorPersistDraftRequest request) {
    _pendingDraft = request;
    final current = _draftWrite;
    if (current != null) return current;
    final completion = Completer<void>();
    _draftWrite = completion.future;
    unawaited(_drainDrafts(completion));
    return completion.future;
  }

  Future<void> _drainDrafts(Completer<void> completion) async {
    try {
      while (_pendingDraft != null) {
        final request = _pendingDraft!;
        _pendingDraft = null;
        final version = _stateVersion;
        final result = await _flow.persistDraft(request);
        if (!_closed && version == _stateVersion) _onDraftPersisted(result);
      }
      completion.complete();
    } on Object catch (error, stackTrace) {
      _pendingDraft = null;
      completion.completeError(error, stackTrace);
    } finally {
      _draftWrite = null;
    }
  }

  Future<void> flushDrafts() => _draftWrite ?? Future<void>.value();

  Future<EditorSaveResult?> savePreview(EditorSaveRequest request) async {
    final version = ++_previewVersion;
    final result = await _flow.saveEntry(request);
    return !_closed && version == _previewVersion ? result : null;
  }

  void reset() {
    _stateVersion++;
    _previewVersion++;
    _pendingDraft = null;
  }

  void close() {
    _closed = true;
    _stateVersion++;
    _previewVersion++;
  }
}
