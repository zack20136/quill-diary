import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../domain/attachment/asset_attachment.dart';
import '../../../domain/diary/diary_entry.dart';
import '../../../domain/security/unlocked_vault_session.dart';
import '../../../domain/shared/value_objects.dart';
import '../../../infrastructure/preferences/user_preferences.dart';
import '../../../infrastructure/storage/vault_repository.dart';
import '../../home/providers/home_providers.dart';
import '../gallery_image_download.dart';
import '../providers/editor_draft_providers.dart';
import '../providers/editor_providers.dart';
import 'editor_actions.dart';
import 'editor_body_blocks.dart';
import 'editor_draft_models.dart';

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
    required this.keptAttachmentIds,
    required this.pendingAttachments,
    required this.session,
    required this.createdAt,
    required this.provisionalEntryId,
    required this.existingEntryId,
  });

  final String draftKey;
  final EditorDraftSnapshot snapshot;
  final String tagsRaw;
  final List<AssetId> keptAttachmentIds;
  final List<PendingAttachment> pendingAttachments;
  final UnlockedVaultSession session;
  final DateTime createdAt;
  final EntryId provisionalEntryId;
  final EntryId? existingEntryId;
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
    required this.keptAttachmentIds,
    required this.pendingAttachments,
    required this.provisionalEntryId,
    required this.switchToPreview,
  });

  final String draftKey;
  final UnlockedVaultSession session;
  final DiaryEntry? existingEntry;
  final String titleRaw;
  final String dateValue;
  final TimeOfDay entryTime;
  final String tagsRaw;
  final String markdownBodyRaw;
  final List<AssetId> keptAttachmentIds;
  final List<PendingAttachment> pendingAttachments;
  final EntryId provisionalEntryId;
  final bool switchToPreview;
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
  const EditorFlowController(this._ref);

  final Ref _ref;

  EditorActionPort get _actions => _ref.read(editorActionsProvider);

  Future<EditorPersistDraftResult> persistDraft(
    EditorPersistDraftRequest request,
  ) async {
    final DateTime now = DateTime.now();
    final List<EditorDraftPendingAttachment> pendingAttachments =
        <EditorDraftPendingAttachment>[];
    for (final PendingAttachment attachment in request.pendingAttachments) {
      final String sourcePath = attachment.sourcePath?.trim() ?? '';
      if (sourcePath.isEmpty) {
        continue;
      }
      pendingAttachments.add(
        EditorDraftPendingAttachment(
          relativePath: await _actions.pendingRelativePath(
            request.draftKey,
            sourcePath,
          ),
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
      keptAttachmentIds: List<AssetId>.from(request.keptAttachmentIds),
      pendingAttachments: pendingAttachments,
      provisionalEntryId: request.provisionalEntryId,
      createdAt: request.createdAt,
      updatedAt: now,
    );
    await _actions.writeDraft(request.draftKey, record, request.session);
    _ref.invalidate(editorDraftKeysProvider);
    return EditorPersistDraftResult(record: record, snapshot: request.snapshot);
  }

  Future<void> discardDraft(String draftKey) async {
    await _actions.deleteDraft(draftKey);
    _ref.invalidate(editorDraftKeysProvider);
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

    final Map<String, String> absolutePaths = <String, String>{};
    for (final EditorDraftPendingAttachment attachment
        in record.pendingAttachments) {
      absolutePaths[attachment.relativePath] = await _actions
          .pendingAbsolutePath(draftKey, attachment.relativePath);
    }
    return EditorDraftRestoreDecision.restored(
      record: record,
      pendingAttachments: pendingAttachmentsFromDraftRecord(
        record,
        absolutePathBuilder: (String relativePath) =>
            absolutePaths[relativePath] ?? '',
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
      attachmentIds: List<AssetId>.from(request.keptAttachmentIds),
    );
    final DiaryEntry saved = await _actions.saveEntry(
      request.session,
      draft,
      pendingAttachments: List<PendingAttachment>.from(
        request.pendingAttachments,
      ),
    );
    await discardDraft(request.draftKey);
    _refreshCaches(editedEntryId: saved.id);
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
  }) async {
    final String trimmed = path.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final String relativePath = await _actions.stagePendingFile(
      draftKey,
      trimmed,
    );
    final String stagedPath = await _actions.pendingAbsolutePath(
      draftKey,
      relativePath,
    );
    return PendingAttachment(
      sourcePath: stagedPath,
      mimeType: _mimeTypeFromPath(trimmed),
      originalFilename: displayName,
    );
  }

  Future<String> assetEncryptedPath({
    required String dateValue,
    required AssetAttachment attachment,
  }) async {
    DateOnly date;
    try {
      date = DateOnly.parse(dateValue.trim());
    } catch (_) {
      date = DateOnly.fromDateTime(DateTime.now());
    }
    return _actions.assetAbsolutePath(date: date, attachment: attachment);
  }

  Future<PreparedEditorGallery> preparePreviewGalleryItems({
    required String dateValue,
    required List<AssetAttachment> savedImages,
    required List<PendingAttachment> pendingImages,
    required int initialIndex,
  }) async {
    final List<GalleryImageItem> items = <GalleryImageItem>[];
    for (final AssetAttachment attachment in savedImages) {
      final String path = await assetEncryptedPath(
        dateValue: dateValue,
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
    }
    for (final PendingAttachment attachment in pendingImages) {
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
    return PreparedEditorGallery(
      items: items,
      initialIndex: items.isEmpty ? 0 : initialIndex.clamp(0, items.length - 1),
    );
  }

  DateTime _composeEntryCreatedAt({
    required DateOnly date,
    required DiaryEntry? existing,
    required TimeOfDay entryTime,
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

  void _refreshCaches({EntryId? editedEntryId}) {
    _ref
      ..invalidate(homeEntryIndexListProvider)
      ..invalidate(calendarMonthEntryDatesProvider)
      ..invalidate(calendarMonthEntriesProvider)
      ..invalidate(calendarEntriesProvider)
      ..invalidate(allEntryIndexRecordsProvider)
      ..invalidate(editorDraftKeysProvider);
    _ref.read(entryIndexRevisionProvider.notifier).bump();
    final EntryId? id = editedEntryId?.trim();
    if (id != null && id.isNotEmpty) {
      _ref.invalidate(entryProvider(id));
      _ref.invalidate(entryAttachmentsProvider(id));
    }
  }
}
