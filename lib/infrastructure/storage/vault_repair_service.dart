import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:quill_diary/domain/attachment/asset_attachment.dart';
import 'package:quill_diary/domain/diary/diary_draft.dart';
import 'package:quill_diary/domain/diary/diary_entry.dart';
import 'package:quill_diary/domain/diary/diary_entry_summary.dart';
import 'package:quill_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/domain/tag/tag.dart';
import 'package:quill_diary/infrastructure/crypto/crypto_service.dart';
import 'package:quill_diary/infrastructure/database/index_database.dart';
import 'package:quill_diary/infrastructure/database/index_database_manager.dart';
import 'package:quill_diary/infrastructure/markdown/front_matter_codec.dart';
import 'package:quill_diary/infrastructure/markdown/visible_text_from_markdown.dart';
import 'package:quill_diary/infrastructure/storage/pinned_entries_store.dart';
import 'package:quill_diary/infrastructure/storage/shared/media_type_utils.dart';
import 'package:quill_diary/infrastructure/storage/shared/vault_file_ops.dart';
import 'package:quill_diary/infrastructure/storage/tag_styles_store.dart';
import 'package:quill_diary/infrastructure/storage/vault_maintenance_models.dart';
import 'package:quill_diary/infrastructure/storage/vault_path_strategy.dart';
import 'package:quill_diary/infrastructure/storage/vault_people_service.dart';
import 'package:quill_diary/infrastructure/storage/vault_repair_file_operations.dart';
import 'package:quill_diary/infrastructure/storage/vault_salvage_models.dart';
import 'package:quill_diary/infrastructure/storage/vault_state_keys.dart';
import 'package:quill_diary/shared/data_versions.dart';

const String _kLastRepairSummaryKey = 'last_repair_summary';
const String _kLastInspectSummaryKey = 'last_inspect_summary';
final RegExp _strictIsoDateTimePattern = RegExp(
  r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.(\d{1,6}))?(?:(Z)|([+-])(\d{2}):(\d{2}))?$',
);

class _ScannedEntry {
  _ScannedEntry({
    required this.entry,
    required this.filePath,
    required this.markdown,
    required this.attachments,
    required this.attachmentPaths,
    required this.searchFields,
    required this.encryptedFileSize,
    required this.encryptedModifiedAt,
  });

  DiaryEntry entry;
  String filePath;
  String markdown;
  final List<AssetAttachment> attachments;
  final Map<AssetId, String> attachmentPaths;
  EntrySearchFields searchFields;
  int encryptedFileSize;
  DateTime encryptedModifiedAt;
}

class _RawScannedEntry {
  const _RawScannedEntry({
    required this.entry,
    required this.filePath,
    required this.markdown,
    required this.attachmentExtensions,
    required this.searchFields,
    required this.encryptedFileSize,
    required this.encryptedModifiedAt,
    required this.plaintextHash,
    required this.canonicalPath,
  });

  final DiaryEntry entry;
  final String filePath;
  final String markdown;
  final Map<AssetId, String> attachmentExtensions;
  final EntrySearchFields searchFields;
  final int encryptedFileSize;
  final DateTime encryptedModifiedAt;
  final String plaintextHash;
  final String canonicalPath;
}

class _AssetReference {
  const _AssetReference({
    required this.entryId,
    required this.date,
    required this.extension,
  });

  final EntryId entryId;
  final DateOnly date;
  final String extension;
}

class _ValidatedAssetFile {
  const _ValidatedAssetFile({
    required this.id,
    required this.path,
    required this.extension,
    required this.mimeType,
    required this.createdAt,
    required this.modifiedAt,
    required this.byteSize,
    required this.plaintextHash,
  });

  final AssetId id;
  final String path;
  final String extension;
  final String mimeType;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final int byteSize;
  final String plaintextHash;
}

class _RepairCleanupTarget {
  const _RepairCleanupTarget({
    required this.path,
    required this.fileId,
    required this.contentType,
    required this.plaintextHash,
    required this.isAttachment,
    this.countsAsDuplicateEntry = false,
    this.countsAsOrphanAsset = false,
    this.countsAsBadAsset = false,
    this.requiresReferenceRewrite = false,
    this.quarantine = false,
    this.entryTitle,
    this.entryDate,
    this.entryId,
  });

  final String path;
  final String fileId;
  final String contentType;
  final String plaintextHash;
  final bool isAttachment;
  final bool countsAsDuplicateEntry;
  final bool countsAsOrphanAsset;
  final bool countsAsBadAsset;
  final bool requiresReferenceRewrite;
  final bool quarantine;
  final String? entryTitle;
  final DateOnly? entryDate;
  final EntryId? entryId;
}

class _EntryRepairStats {
  const _EntryRepairStats({
    required this.scanned,
    required this.relocatedEntries,
    required this.issues,
    required this.findings,
    required this.cleanupTargets,
    required this.assetReferences,
  });

  final List<_ScannedEntry> scanned;
  final int relocatedEntries;
  final List<VaultRepairIssue> issues;
  final List<VaultFinding> findings;
  final Map<String, _RepairCleanupTarget> cleanupTargets;
  final Map<AssetId, List<_AssetReference>> assetReferences;
}

class _AssetRepairStats {
  const _AssetRepairStats({
    required this.relocatedAssets,
    required this.issues,
    required this.findings,
    required this.cleanupTargets,
    this.sharedAssetIds = const <AssetId>{},
    this.recoveredAssetIds = const <AssetId>{},
  });

  final int relocatedAssets;
  final List<VaultRepairIssue> issues;
  final List<VaultFinding> findings;
  final Map<String, _RepairCleanupTarget> cleanupTargets;
  final Set<AssetId> sharedAssetIds;
  final Set<AssetId> recoveredAssetIds;
}

/// 加密 vault 儲存的主要協調層。
///
/// 此儲存庫負責 Recovery Key 建立／解鎖、可信裝置 session 還原、
/// 加密條目／附件 I/O 與索引同步。

class VaultRepairService {
  VaultRepairService({
    required this._pathStrategy,
    required this._cryptoService,
    required this._frontMatterCodec,
    required this._indexDatabaseManager,
    required this._people,
    required this._requireMetadataForSession,
    required Future<void> Function(UnlockedVaultSession, RecoveryMetadata)
    writeManifest,
    required Future<List<String>> Function({
      required String fromEntryPath,
      required String toEntryPath,
      required UnlockedVaultSession session,
    })
    copyChatFiles,
    this._repairFileOperations = const VaultRepairFileOperations(),
  }) : _writeEncryptedManifest = writeManifest,
       _copyChatFilesBesideEntry = copyChatFiles;
  final VaultPathStrategy _pathStrategy;
  final CryptoService _cryptoService;
  final FrontMatterCodec _frontMatterCodec;
  final IndexDatabaseManager _indexDatabaseManager;
  final VaultPeopleService _people;
  final VaultRepairFileOperations _repairFileOperations;
  final Future<RecoveryMetadata> Function(UnlockedVaultSession)
  _requireMetadataForSession;
  final Future<void> Function(UnlockedVaultSession, RecoveryMetadata)
  _writeEncryptedManifest;
  final Future<List<String>> Function({
    required String fromEntryPath,
    required String toEntryPath,
    required UnlockedVaultSession session,
  })
  _copyChatFilesBesideEntry;
  Future<bool> canSalvageFindings(
    UnlockedVaultSession session,
    List<VaultFinding> findings,
  ) async {
    return await tryCreateSalvageDraft(session, findings: findings) != null;
  }

  Future<VaultSalvageDraft?> tryCreateSalvageDraft(
    UnlockedVaultSession session, {
    required List<VaultFinding> findings,
  }) async {
    if (findings.isEmpty || isAssetOnlyFindingGroup(findings)) return null;
    await _indexDatabaseManager.openForSession(session);
    final EntryId? preferredEntryId = findings
        .map((VaultFinding finding) => finding.entryId)
        .firstWhere((EntryId? id) => id != null, orElse: () => null);
    final List<VaultFinding> sourceFindings = preferredEntryId == null
        ? findings
        : findings
              .where(
                (VaultFinding finding) => finding.entryId == preferredEntryId,
              )
              .toList(growable: false);
    final VaultFinding source = sourceFindings.first;
    final DiaryEntrySummary? indexed = preferredEntryId == null
        ? null
        : await _indexDatabaseManager.requireOpen().getEntryById(
            preferredEntryId,
          );
    final Directory root = await _pathStrategy.vaultRootDirectory();
    String? path;
    final String reference = source.internalReference.trim();
    if (reference.replaceAll('\\', '/').startsWith('entries/')) {
      path = p.join(root.path, reference.replaceAll('\\', '/'));
    } else {
      path = indexed?.filePath;
    }
    if (path == null || !File(path).existsSync()) return null;

    String body = '';
    String? title;
    List<String> tags = const <String>[];
    DateOnly? sourceDate;
    try {
      final ParsedEncryptedDocument parsed = _cryptoService.parseFileBytes(
        await File(path).readAsBytes(),
      );
      final String markdown = await _cryptoService.decryptMarkdown(
        headerBytes: parsed.headerBytes,
        ciphertextBytes: parsed.ciphertextBytes,
        context: vaultDecryptionContext(session),
      );
      try {
        final DecodedFrontMatterDocument decoded = _frontMatterCodec
            .decodeDocument(markdown);
        title = decoded.entry.normalizedTitle;
        body = decoded.body;
        tags = List<String>.from(decoded.entry.tags);
        sourceDate = decoded.entry.date;
      } on Object {
        body = markdown.trim();
      }
    } on Object {
      return null;
    }
    final DateOnly date = sourceDate ?? DateOnly.fromDateTime(DateTime.now());
    final EntryId newEntryId = generateEntryId();
    final DateTime now = DateTime.now();
    final EditorDraftRecord record = EditorDraftRecord(
      title: title,
      dateValue: date.value,
      entryHour: now.hour,
      entryMinute: now.minute,
      tags: tags,
      markdownBody: body,
      attachmentIds: const <AssetId>[],
      pendingAttachments: const <EditorDraftPendingAttachment>[],
      provisionalEntryId: newEntryId,
      createdAt: now,
      updatedAt: now,
      salvageSourceFindings: <Map<String, Object?>>[
        for (final VaultFinding finding in sourceFindings) finding.toJson(),
      ],
    );
    final VaultSalvageDraft draft = VaultSalvageDraft(
      token: newEntryId,
      newEntryId: newEntryId,
      record: record,
      sourceFindings: List<VaultFinding>.from(sourceFindings),
      hasSourceDate: sourceDate != null,
    );
    return draft.hasSalvageableContent ? draft : null;
  }

  Future<VaultRepairSummary?> readLastRepairSummary() async {
    return _readSummary(_kLastRepairSummaryKey, VaultRepairSummary.fromJson);
  }

  Future<VaultInspectSummary?> readLastInspectSummary() async {
    return _readSummary(_kLastInspectSummaryKey, VaultInspectSummary.fromJson);
  }

  Future<int> permanentlyDeleteAbnormalFindings(
    UnlockedVaultSession session, {
    required List<VaultFinding> findings,
    bool salvaged = false,
  }) async {
    if (findings.isEmpty) return 0;
    await _indexDatabaseManager.openForSession(session);
    final Directory vaultRoot = await _pathStrategy.vaultRootDirectory();
    final String normalizedRoot = p.normalize(vaultRoot.path);
    final Set<String> pathsToDelete = <String>{};
    final Set<EntryId> entryIdsToRemove = <EntryId>{};

    for (final VaultFinding finding in findings) {
      final String? entryId = finding.entryId?.trim();
      if (entryId != null && entryId.isNotEmpty) {
        entryIdsToRemove.add(entryId);
      }
      final String reference = finding.internalReference.trim().replaceAll(
        '\\',
        '/',
      );
      if (reference.isEmpty) continue;

      if (_looksLikeVaultRelativePath(reference)) {
        final String absolute = p.normalize(p.join(normalizedRoot, reference));
        if (_isSafeVaultContentPath(absolute, normalizedRoot)) {
          pathsToDelete.add(absolute);
        }
        continue;
      }

      if (_isSafePathSegment(reference)) {
        final List<File> assetFiles = await _findAssetFilesById(
          vaultRoot: vaultRoot,
          assetId: reference,
        );
        for (final File file in assetFiles) {
          if (_isSafeVaultContentPath(file.path, normalizedRoot)) {
            pathsToDelete.add(p.normalize(file.path));
          }
        }
      }
    }

    for (final EntryId entryId in entryIdsToRemove) {
      final DiaryEntrySummary? record = await _indexDatabaseManager
          .requireOpen()
          .getEntryById(entryId);
      if (record == null) continue;
      final List<AssetAttachment> attachments = await _indexDatabaseManager
          .requireOpen()
          .attachmentsForEntry(entryId);
      pathsToDelete.add(p.normalize(record.filePath));
      for (final AssetAttachment attachment in attachments) {
        pathsToDelete.add(
          p.normalize(
            await _pathStrategy.attachmentAbsolutePath(
              date: record.date,
              attachment: attachment,
            ),
          ),
        );
      }
    }

    var deletedCount = 0;
    for (final String path in pathsToDelete) {
      if (!_isSafeVaultContentPath(path, normalizedRoot)) continue;
      if (path.endsWith('.md.enc')) await deleteEntryChatFiles(path);
      final File file = File(path);
      if (!file.existsSync()) continue;
      await deleteFileIfExists(path);
      deletedCount++;
    }

    final IndexDatabase indexDb = _indexDatabaseManager.requireOpen();
    for (final EntryId entryId in entryIdsToRemove) {
      await indexDb.removeEntry(entryId);
      await PinnedEntriesStore(_pathStrategy).remove(entryId);
    }

    final RecoveryMetadata metadata = await _requireMetadataForSession(session);
    await _writeEncryptedManifest(session, metadata);
    await _stripFindingsFromMaintenanceSummaries(findings, salvaged: salvaged);
    return deletedCount;
  }

  bool _looksLikeVaultRelativePath(String reference) {
    final String normalized = reference.replaceAll('\\', '/');
    return normalized.startsWith('entries/') ||
        normalized.startsWith('assets/') ||
        normalized.contains('/');
  }

  bool _isSafeVaultContentPath(String absolutePath, String normalizedRoot) {
    final String normalized = p.normalize(absolutePath);
    if (!p.isWithin(normalizedRoot, normalized) &&
        normalized != normalizedRoot) {
      return false;
    }
    final String relative = p
        .relative(normalized, from: normalizedRoot)
        .replaceAll('\\', '/');
    return relative.startsWith('entries/') || relative.startsWith('assets/');
  }

  Future<List<File>> _findAssetFilesById({
    required Directory vaultRoot,
    required AssetId assetId,
  }) async {
    final Directory assetsRoot = Directory(p.join(vaultRoot.path, 'assets'));
    if (!assetsRoot.existsSync()) return const <File>[];
    final List<File> files = await _repairFileOperations.snapshotFiles(
      assetsRoot,
      '.enc',
    );
    return <File>[
      for (final File file in files)
        if (p.basenameWithoutExtension(
              p.basename(file.path).replaceFirst('.enc', ''),
            ) ==
            assetId)
          file,
    ];
  }

  Future<void> _stripFindingsFromMaintenanceSummaries(
    List<VaultFinding> removed, {
    bool salvaged = false,
  }) async {
    final Set<String> removedKeys = <String>{
      for (final VaultFinding finding in removed) _findingIdentityKey(finding),
    };
    final VaultInspectSummary? inspect = await readLastInspectSummary();
    if (inspect != null) {
      final List<VaultFinding> nextFindings = <VaultFinding>[
        for (final VaultFinding finding in inspect.findings)
          if (!removedKeys.contains(_findingIdentityKey(finding))) finding,
      ];
      if (nextFindings.length != inspect.findings.length) {
        await _indexDatabaseManager.requireOpen().setAppValue(
          _kLastInspectSummaryKey,
          jsonEncode(
            VaultInspectSummary(
              entryCount: inspect.entryCount,
              finishedAt: inspect.finishedAt,
              findings: nextFindings,
            ).toJson(),
          ),
        );
      }
    }

    final VaultRepairSummary? repair = await readLastRepairSummary();
    if (repair != null) {
      final List<VaultFinding> nextFindings = <VaultFinding>[
        for (final VaultFinding finding in repair.findings)
          if (!removedKeys.contains(_findingIdentityKey(finding))) finding,
      ];
      if (removed.isNotEmpty) {
        final int retiredCount = repair.findings.length - nextFindings.length;
        final Map<VaultRepairIssueKind, int> counts =
            <VaultRepairIssueKind, int>{};
        for (final VaultFinding finding in nextFindings) {
          counts.update(
            finding.kind,
            (int value) => value + 1,
            ifAbsent: () => 1,
          );
        }
        await _indexDatabaseManager.requireOpen().setAppValue(
          _kLastRepairSummaryKey,
          jsonEncode(
            VaultRepairSummary(
              entryCount: repair.entryCount,
              finishedAt: repair.finishedAt,
              issueCounts: counts,
              lastUpdatedAt: DateTime.now(),
              salvagedCount:
                  repair.salvagedCount + (salvaged ? retiredCount : 0),
              permanentlyDeletedCount:
                  repair.permanentlyDeletedCount +
                  (salvaged ? 0 : retiredCount),
              relocatedEntries: repair.relocatedEntries,
              removedDuplicateEntries: repair.removedDuplicateEntries,
              tagsAdded: repair.tagsAdded,
              relocatedAssets: repair.relocatedAssets,
              removedOrphanAssets: repair.removedOrphanAssets,
              quarantinedCount: repair.quarantinedCount,
              purgedBadAssets: repair.purgedBadAssets,
              purgedOldQuarantine: repair.purgedOldQuarantine,
              removedBrokenReferences: repair.removedBrokenReferences,
              splitAttachments: repair.splitAttachments,
              recoveredAttachments: repair.recoveredAttachments,
              backupFileName: repair.backupFileName,
              repairId: repair.repairId,
              findings: nextFindings,
              entryActionLogs: repair.entryActionLogs,
            ).toJson(),
          ),
        );
      }
    }
  }

  String _findingResolutionKey(VaultFinding finding) {
    final String reference = isAutoResolvableAssetIssueKind(finding.kind)
        ? (_assetIdFromFindingReference(finding.internalReference) ??
              finding.internalReference)
        : finding.internalReference;
    return '${finding.kind.name}|$reference|${finding.entryId ?? ''}';
  }

  String _findingIdentityKey(VaultFinding finding) =>
      _findingResolutionKey(finding);

  Future<T?> _readSummary<T>(
    String key,
    T? Function(Map<String, Object?> json) fromJson,
  ) async {
    final String? raw = await _indexDatabaseManager.requireOpen().getAppValue(
      key,
    );
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return fromJson(decoded.cast<String, Object?>());
    } on FormatException {
      return null;
    }
  }

  Future<VaultInspectReport> inspectVaultWithReport(
    UnlockedVaultSession session, {
    VaultRepairProgressCallback? onProgress,
  }) async {
    final Stopwatch stopwatch = Stopwatch()..start();
    await _indexDatabaseManager.openForSession(session);
    await _people.cancelRebuild();
    final RecoveryMetadata metadata = await _requireMetadataForSession(session);
    final ({List<File> entries, List<File> assets}) inventory =
        await _snapshotRepairInventory();

    onProgress?.call(VaultRepairPhase.scanningEntries);
    final _EntryRepairStats entryStats = await _scanEntries(
      session,
      metadata,
      inventory.entries,
      repair: false,
    );
    onProgress?.call(VaultRepairPhase.checkingAttachments);
    final bool hasEntryIssues = _hasUnresolvedEntryIssues(entryStats.issues);
    final _AssetRepairStats assetStats = await _scanAssets(
      session: session,
      metadata: metadata,
      entries: entryStats.scanned,
      references: entryStats.assetReferences,
      files: inventory.assets,
      hasUnresolvedEntryIssues: hasEntryIssues,
      repair: false,
    );
    final List<_ScannedEntry> indexEntries = _indexableEntries(
      entryStats.scanned,
    );
    onProgress?.call(VaultRepairPhase.rebuildingIndex);
    await _writeRebuiltIndex(indexEntries, prunePinnedEntries: !hasEntryIssues);
    onProgress?.call(VaultRepairPhase.rebuildingPeopleAnalytics);
    await _people.ensurePeopleAnalyticsReady(session);

    final List<VaultFinding> findings = _enrichFindings(<VaultFinding>[
      ...entryStats.findings,
      ...assetStats.findings,
    ], entryStats.scanned);
    stopwatch.stop();
    final VaultInspectReport report = VaultInspectReport(
      entryCount: indexEntries.length,
      duration: stopwatch.elapsed,
      finishedAt: DateTime.now(),
      findings: findings,
    );
    await _storeInspectSummary(report);
    return report;
  }

  Future<void> _writeRebuiltIndex(
    List<_ScannedEntry> entries, {
    required bool prunePinnedEntries,
  }) async {
    final IndexDatabase indexDb = _indexDatabaseManager.requireOpen();
    final Set<String> collectedTagLabels = <String>{};
    await indexDb.transaction(() async {
      await indexDb.rebuild();
      for (final _ScannedEntry scanned in entries) {
        await indexDb.upsertEntry(
          entry: scanned.entry,
          filePath: scanned.filePath,
          previewText: scanned.searchFields.previewText,
          previewMarkdown: scanned.searchFields.previewMarkdown,
          titleSearchText: scanned.searchFields.titleSearchText,
          bodySearchText: scanned.searchFields.bodySearchText,
          bodyVisibleText: scanned.searchFields.bodyVisibleText,
          contentHash: await hashVaultText(scanned.markdown),
          encryptedFileSize: scanned.encryptedFileSize,
          encryptedModifiedAt: scanned.encryptedModifiedAt,
        );
        await indexDb.replaceAttachments(
          scanned.entry.id,
          scanned.attachments,
          scanned.attachmentPaths,
        );
        collectedTagLabels.addAll(scanned.entry.tags);
      }
      await indexDb.setAppValue(
        kLastRebuildAtKey,
        DateTime.now().toIso8601String(),
      );
      await indexDb.setAppValue(
        kIndexGenerationKey,
        DataVersions.entryIndexGeneration.toString(),
      );
    });

    await TagStylesStore(_pathStrategy).read();
    if (collectedTagLabels.isNotEmpty) {
      await TagStylesStore(_pathStrategy).ensureLabels(collectedTagLabels);
    }
    await TagStylesStore(_pathStrategy)
        .applyToIndex(_indexDatabaseManager.requireOpen());
    if (prunePinnedEntries) {
      await PinnedEntriesStore(_pathStrategy)
          .pruneTo(entries.map((_ScannedEntry item) => item.entry.id));
    }
  }

  Future<({List<File> entries, List<File> assets})>
  _snapshotRepairInventory() async {
    final Directory vaultRoot = await _pathStrategy.vaultRootDirectory();
    return (
      entries: await _repairFileOperations.snapshotFiles(
        Directory(p.join(vaultRoot.path, 'entries')),
        '.md.enc',
      ),
      assets: await _repairFileOperations.snapshotFiles(
        Directory(p.join(vaultRoot.path, 'assets')),
        '.enc',
      ),
    );
  }

  bool _hasUnresolvedEntryIssues(List<VaultRepairIssue> issues) {
    return issues.any(
      (VaultRepairIssue issue) => switch (issue.kind) {
        VaultRepairIssueKind.invalidEntryMetadata ||
        VaultRepairIssueKind.unreadableEntry ||
        VaultRepairIssueKind.entryIdentityMismatch ||
        VaultRepairIssueKind.conflictingEntry => true,
        _ => false,
      },
    );
  }

  List<_ScannedEntry> _indexableEntries(List<_ScannedEntry> scannedEntries) {
    return <_ScannedEntry>[
      for (final _ScannedEntry scanned in scannedEntries)
        _ScannedEntry(
          entry: scanned.entry,
          filePath: scanned.filePath,
          markdown: scanned.markdown,
          attachments: <AssetAttachment>[
            for (final AssetId id in scanned.entry.attachmentIds)
              if (scanned.attachments
                      .where((AssetAttachment item) => item.id == id)
                      .firstOrNull
                  case final AssetAttachment attachment)
                attachment,
          ],
          attachmentPaths: <AssetId, String>{
            for (final AssetId id in scanned.entry.attachmentIds)
              if (scanned.attachmentPaths[id] case final String path) id: path,
          },
          searchFields: scanned.searchFields,
          encryptedFileSize: scanned.encryptedFileSize,
          encryptedModifiedAt: scanned.encryptedModifiedAt,
        ),
    ];
  }

  Future<VaultRepairReport> repairVaultWithReport(
    UnlockedVaultSession session, {
    VaultRepairProgressCallback? onProgress,
    String? backupFileName,
  }) async {
    final Stopwatch stopwatch = Stopwatch()..start();
    final String repairId =
        'repair_${DateTime.now().toUtc().millisecondsSinceEpoch}';
    final List<VaultRepairActionEvent> actionEvents =
        <VaultRepairActionEvent>[];
    await _indexDatabaseManager.openForSession(session);
    await _people.cancelRebuild();
    final RecoveryMetadata metadata = await _requireMetadataForSession(session);
    final ({List<File> entries, List<File> assets}) inventory =
        await _snapshotRepairInventory();

    onProgress?.call(VaultRepairPhase.scanningEntries);
    final _EntryRepairStats entryStats = await _scanEntries(
      session,
      metadata,
      inventory.entries,
      repair: true,
      actionEvents: actionEvents,
    );

    final Set<String> catalogNorms = (await TagStylesStore(
      _pathStrategy,
    ).read()).map((TagCatalogItem item) => item.normalized).toSet();
    final Set<String> collectedTagLabels = <String>{};
    for (final _ScannedEntry scanned in entryStats.scanned) {
      collectedTagLabels.addAll(scanned.entry.tags);
    }
    var tagsAdded = 0;
    for (final String raw in collectedTagLabels) {
      final String displayLabel = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
      final String normalized = normalizeText(displayLabel);
      if (normalized.isEmpty || catalogNorms.contains(normalized)) {
        continue;
      }
      tagsAdded++;
      catalogNorms.add(normalized);
    }
    onProgress?.call(VaultRepairPhase.checkingAttachments);
    final bool hasEntryIssues = _hasUnresolvedEntryIssues(entryStats.issues);
    final _AssetRepairStats assetStats = await _scanAssets(
      session: session,
      metadata: metadata,
      entries: entryStats.scanned,
      references: entryStats.assetReferences,
      files: inventory.assets,
      hasUnresolvedEntryIssues: hasEntryIssues,
      repair: true,
    );

    final List<VaultFinding> appliedActions = <VaultFinding>[];
    final List<VaultFinding> unresolvedFindings = <VaultFinding>[];
    var quarantinedCount = 0;

    for (final VaultFinding finding in assetStats.findings) {
      final AssetId? assetId = _assetIdFromFindingReference(
        finding.internalReference,
      );
      if (assetId != null &&
          assetStats.recoveredAssetIds.contains(assetId) &&
          (finding.kind == VaultRepairIssueKind.unreadableAsset ||
              finding.kind == VaultRepairIssueKind.assetIdentityMismatch)) {
        appliedActions.add(
          finding.copyWith(
            plannedAction: VaultPlannedAction.relocateToCanonical,
            manualAction: VaultManualAction.none,
            resolved: true,
          ),
        );
        actionEvents.add(
          VaultRepairActionEvent(
            scope: VaultRepairActionScope.entry,
            type: VaultRepairActionType.recoverAttachment,
            outcome: VaultRepairActionOutcome.succeeded,
            entryTitle: finding.entryTitle,
            entryDate: finding.entryDate,
            internalIdentity: assetId,
          ),
        );
      }
    }

    // 共用附件拆分：先建立新檔，再重寫日記引用。
    final List<VaultFinding> splitFindings = await _splitSharedAttachments(
      session: session,
      metadata: metadata,
      entries: entryStats.scanned,
      sharedAssetIds: assetStats.sharedAssetIds,
      references: entryStats.assetReferences,
    );
    for (final VaultFinding finding in splitFindings) {
      if (finding.resolved) {
        appliedActions.add(finding);
        final List<_AssetReference> owners =
            entryStats.assetReferences[finding.internalReference] ?? const [];
        if (owners.isEmpty || finding.entryId != owners.first.entryId) {
          actionEvents.add(
            VaultRepairActionEvent(
              scope: VaultRepairActionScope.entry,
              type: VaultRepairActionType.splitAttachment,
              outcome: VaultRepairActionOutcome.succeeded,
              entryTitle: finding.entryTitle,
              entryDate: finding.entryDate,
              internalIdentity:
                  '${finding.internalReference}|${finding.entryId}',
            ),
          );
        }
      } else {
        unresolvedFindings.add(finding);
      }
    }

    // 移除失效附件引用並重寫日記。
    final List<VaultFinding> referenceFindings =
        await _removeBrokenAttachmentReferences(
          session: session,
          metadata: metadata,
          entries: entryStats.scanned,
          assetIssues: assetStats.issues,
          recoveredAssetIds: assetStats.recoveredAssetIds,
        );
    for (final VaultFinding finding in referenceFindings) {
      if (finding.resolved) {
        appliedActions.add(finding);
        if (finding.kind == VaultRepairIssueKind.missingAsset) {
          actionEvents.add(
            VaultRepairActionEvent(
              scope: VaultRepairActionScope.entry,
              type: VaultRepairActionType.removeMissingReference,
              outcome: VaultRepairActionOutcome.succeeded,
              entryTitle: finding.entryTitle,
              entryDate: finding.entryDate,
              internalIdentity:
                  '${finding.entryId}|${finding.internalReference}',
            ),
          );
        }
      } else {
        unresolvedFindings.add(finding);
      }
    }
    final Set<AssetId> referenceRewriteSucceeded = <AssetId>{
      ...assetStats.recoveredAssetIds,
      for (final VaultFinding finding in referenceFindings)
        if (finding.resolved)
          if (_assetIdFromFindingReference(finding.internalReference)
              case final AssetId assetId)
            assetId,
    };

    // 隔離標記為 quarantine 的目標（損壞日記／衝突版本／異常附件）。
    final Map<String, _RepairCleanupTarget> cleanupTargets =
        <String, _RepairCleanupTarget>{
          ...entryStats.cleanupTargets,
          ...assetStats.cleanupTargets,
        };
    for (final MapEntry<String, _RepairCleanupTarget> item
        in cleanupTargets.entries.toList()) {
      final _RepairCleanupTarget target = item.value;
      if (!target.isAttachment || target.entryId != null) continue;
      final AssetId? assetId = _assetIdFromFindingReference(
        await _vaultRelativeReference(target.path),
      );
      final VaultFinding? context = assetStats.findings
          .where(
            (VaultFinding finding) =>
                assetId != null &&
                _assetIdFromFindingReference(finding.internalReference) ==
                    assetId &&
                finding.entryId != null,
          )
          .firstOrNull;
      if (context == null) continue;
      cleanupTargets[item.key] = _RepairCleanupTarget(
        path: target.path,
        fileId: target.fileId,
        contentType: target.contentType,
        plaintextHash: target.plaintextHash,
        isAttachment: target.isAttachment,
        countsAsDuplicateEntry: target.countsAsDuplicateEntry,
        countsAsOrphanAsset: target.countsAsOrphanAsset,
        countsAsBadAsset: target.countsAsBadAsset,
        requiresReferenceRewrite: target.requiresReferenceRewrite,
        quarantine: target.quarantine,
        entryTitle: context.entryTitle,
        entryDate: context.entryDate,
        entryId: context.entryId,
      );
    }
    final Set<String> quarantinedReferences = <String>{};
    for (final _RepairCleanupTarget target in cleanupTargets.values.where(
      (_RepairCleanupTarget item) => item.quarantine,
    )) {
      final String reference = await _vaultRelativeReference(target.path);
      final bool quarantined = await _quarantineFile(
        session: session,
        metadata: metadata,
        repairId: repairId,
        target: target,
      );
      if (quarantined) {
        quarantinedCount++;
        actionEvents.add(
          VaultRepairActionEvent(
            scope: target.entryId == null
                ? VaultRepairActionScope.global
                : VaultRepairActionScope.entry,
            type: VaultRepairActionType.quarantine,
            outcome: VaultRepairActionOutcome.succeeded,
            entryTitle: target.entryTitle,
            entryDate: target.entryDate,
            internalIdentity: target.path,
          ),
        );
        quarantinedReferences.add(reference);
        if (target.fileId != 'unknown') {
          quarantinedReferences.add(target.fileId);
        }
      } else {
        actionEvents.add(
          VaultRepairActionEvent(
            scope: target.entryId == null
                ? VaultRepairActionScope.global
                : VaultRepairActionScope.entry,
            type: VaultRepairActionType.cleanupFailure,
            outcome: VaultRepairActionOutcome.failed,
            entryTitle: target.entryTitle,
            entryDate: target.entryDate,
            internalIdentity: target.path,
          ),
        );
        unresolvedFindings.add(
          VaultFinding(
            kind: VaultRepairIssueKind.cleanupFailure,
            plannedAction: VaultPlannedAction.quarantine,
            manualAction: VaultManualAction.none,
            canOpenEntry: false,
            entryId: target.entryId,
            entryTitle: target.entryTitle,
            entryDate: target.entryDate,
            internalReference: reference,
          ),
        );
      }
    }

    final List<_ScannedEntry> indexEntries = _indexableEntries(
      entryStats.scanned,
    );

    onProgress?.call(VaultRepairPhase.rebuildingIndex);
    await _writeRebuiltIndex(indexEntries, prunePinnedEntries: false);
    if (!hasEntryIssues) {
      await PinnedEntriesStore(_pathStrategy)
          .pruneTo(indexEntries.map((_ScannedEntry item) => item.entry.id));
    }
    await _writeEncryptedManifest(session, metadata);
    onProgress?.call(VaultRepairPhase.rebuildingPeopleAnalytics);
    await _people.ensurePeopleAnalyticsReady(session);

    final List<VaultRepairIssue> issues = <VaultRepairIssue>[
      ...entryStats.issues,
      ...assetStats.issues,
    ];
    onProgress?.call(VaultRepairPhase.cleaning);
    for (final _RepairCleanupTarget target in cleanupTargets.values.where(
      (_RepairCleanupTarget item) => !item.quarantine,
    )) {
      AssetId? targetAssetId;
      try {
        targetAssetId = target.isAttachment
            ? _assetIdFromFindingReference(
                await _vaultRelativeReference(target.path),
              )
            : null;
        if (target.requiresReferenceRewrite &&
            (targetAssetId == null ||
                !referenceRewriteSucceeded.contains(targetAssetId))) {
          final String reference = await _vaultRelativeReference(target.path);
          issues.add(
            VaultRepairIssue(
              kind: VaultRepairIssueKind.cleanupFailure,
              reference: reference,
            ),
          );
          unresolvedFindings.add(
            VaultFinding(
              kind: VaultRepairIssueKind.cleanupFailure,
              plannedAction: VaultPlannedAction.deleteDuplicate,
              manualAction: VaultManualAction.none,
              canOpenEntry: false,
              entryId: target.entryId,
              entryTitle: target.entryTitle,
              entryDate: target.entryDate,
              internalReference: reference,
            ),
          );
          continue;
        }
        if (!target.isAttachment && target.countsAsDuplicateEntry) {
          final kept = await _indexDatabaseManager.requireOpen().getEntryById(
            target.fileId,
          );
          if (kept == null) throw StateError('缺少保留的日記');
          await _copyChatFilesBesideEntry(
            fromEntryPath: target.path,
            toEntryPath: kept.filePath,
            session: session,
          );
        }
        final VaultRepairDeleteResult result = await _repairFileOperations
            .deleteIfValid(
              path: target.path,
              validate: (String path) async {
                // 壞附件本來就無法通過內容驗證；只確認仍在 vault 內即可刪除。
                if (target.fileId == 'unknown' || target.countsAsBadAsset) {
                  final Directory root = await _pathStrategy
                      .vaultRootDirectory();
                  return _isSafeVaultContentPath(path, p.normalize(root.path));
                }
                return _validateRepairFile(
                  path,
                  session: session,
                  metadata: metadata,
                  expectedId: target.fileId,
                  expectedContentType: target.contentType,
                  expectedPlaintextHash: target.plaintextHash,
                  validateAttachmentContent: target.isAttachment,
                );
              },
            );
        if (result == VaultRepairDeleteResult.validationFailed) {
          // 日記引用已重寫時，殘留壞檔改記全域失敗，不讓該篇繼續顯示「仍需處理」。
          final bool entryAlreadyRewritten =
              target.countsAsBadAsset &&
              targetAssetId != null &&
              referenceRewriteSucceeded.contains(targetAssetId);
          actionEvents.add(
            VaultRepairActionEvent(
              scope: entryAlreadyRewritten
                  ? VaultRepairActionScope.global
                  : (target.entryId == null
                        ? VaultRepairActionScope.global
                        : VaultRepairActionScope.entry),
              type: VaultRepairActionType.cleanupFailure,
              outcome: VaultRepairActionOutcome.failed,
              entryTitle: entryAlreadyRewritten ? null : target.entryTitle,
              entryDate: entryAlreadyRewritten ? null : target.entryDate,
              internalIdentity: target.path,
            ),
          );
          issues.add(
            VaultRepairIssue(
              kind: VaultRepairIssueKind.cleanupFailure,
              reference: await _vaultRelativeReference(target.path),
            ),
          );
          unresolvedFindings.add(
            VaultFinding(
              kind: VaultRepairIssueKind.cleanupFailure,
              plannedAction: VaultPlannedAction.deleteDuplicate,
              manualAction: VaultManualAction.none,
              canOpenEntry: false,
              entryId: entryAlreadyRewritten ? null : target.entryId,
              entryTitle: entryAlreadyRewritten ? null : target.entryTitle,
              entryDate: entryAlreadyRewritten ? null : target.entryDate,
              internalReference: await _vaultRelativeReference(target.path),
            ),
          );
          continue;
        }
        if (result != VaultRepairDeleteResult.deleted &&
            result != VaultRepairDeleteResult.missing) {
          continue;
        }
        if (!target.isAttachment) {
          await deleteEntryChatFiles(target.path);
        }
        if (target.countsAsDuplicateEntry &&
            result == VaultRepairDeleteResult.deleted) {
          actionEvents.add(
            VaultRepairActionEvent(
              scope: VaultRepairActionScope.entry,
              type: VaultRepairActionType.removeDuplicate,
              outcome: VaultRepairActionOutcome.succeeded,
              entryTitle: target.entryTitle,
              entryDate: target.entryDate,
              internalIdentity: target.path,
            ),
          );
        }
        if (target.countsAsOrphanAsset &&
            result == VaultRepairDeleteResult.deleted) {
          actionEvents.add(
            VaultRepairActionEvent(
              scope: target.entryId == null
                  ? VaultRepairActionScope.global
                  : VaultRepairActionScope.entry,
              type: VaultRepairActionType.purgeOrphan,
              outcome: VaultRepairActionOutcome.succeeded,
              entryTitle: target.entryTitle,
              entryDate: target.entryDate,
              internalIdentity: target.path,
            ),
          );
        }
        if (target.countsAsBadAsset) {
          actionEvents.add(
            VaultRepairActionEvent(
              scope: target.entryId == null
                  ? VaultRepairActionScope.global
                  : VaultRepairActionScope.entry,
              type: VaultRepairActionType.purgeBadAttachment,
              outcome: VaultRepairActionOutcome.succeeded,
              entryTitle: target.entryTitle,
              entryDate: target.entryDate,
              internalIdentity: target.path,
            ),
          );
        }
      } on Object {
        final bool entryAlreadyRewritten =
            target.countsAsBadAsset &&
            targetAssetId != null &&
            referenceRewriteSucceeded.contains(targetAssetId);
        actionEvents.add(
          VaultRepairActionEvent(
            scope: entryAlreadyRewritten || target.entryId == null
                ? VaultRepairActionScope.global
                : VaultRepairActionScope.entry,
            type: VaultRepairActionType.cleanupFailure,
            outcome: VaultRepairActionOutcome.failed,
            entryTitle: entryAlreadyRewritten ? null : target.entryTitle,
            entryDate: entryAlreadyRewritten ? null : target.entryDate,
            internalIdentity: target.path,
          ),
        );
        issues.add(
          VaultRepairIssue(
            kind: VaultRepairIssueKind.cleanupFailure,
            reference: await _vaultRelativeReference(target.path),
          ),
        );
        unresolvedFindings.add(
          VaultFinding(
            kind: VaultRepairIssueKind.cleanupFailure,
            plannedAction: VaultPlannedAction.deleteDuplicate,
            manualAction: VaultManualAction.none,
            canOpenEntry: false,
            entryId: entryAlreadyRewritten ? null : target.entryId,
            entryTitle: entryAlreadyRewritten ? null : target.entryTitle,
            entryDate: entryAlreadyRewritten ? null : target.entryDate,
            internalReference: await _vaultRelativeReference(target.path),
          ),
        );
      }
    }
    // 仍有日記本體未解決時保留舊隔離檔，避免誤刪可能的回復來源。
    final ({int purgedDirs, List<VaultFinding> failures}) quarantinePurge =
        await _purgeOldQuarantine(
          currentRepairId: repairId,
          retainBecauseUnresolvedEntries: hasEntryIssues,
        );
    for (final VaultFinding failure in quarantinePurge.failures) {
      unresolvedFindings.add(failure);
      actionEvents.add(
        VaultRepairActionEvent(
          scope: VaultRepairActionScope.global,
          type: VaultRepairActionType.cleanupFailure,
          outcome: VaultRepairActionOutcome.failed,
          internalIdentity: failure.internalReference,
        ),
      );
    }
    if (quarantinePurge.purgedDirs > 0) {
      actionEvents.add(
        VaultRepairActionEvent(
          scope: VaultRepairActionScope.global,
          type: VaultRepairActionType.purgeOldQuarantine,
          outcome: VaultRepairActionOutcome.succeeded,
          internalIdentity: 'quarantine_dirs:${quarantinePurge.purgedDirs}',
        ),
      );
    }

    final List<VaultFinding> allFindings = _enrichFindings(<VaultFinding>[
      ...entryStats.findings,
      ...assetStats.findings,
      ...appliedActions,
      ...unresolvedFindings,
    ], entryStats.scanned);
    final Set<String> resolvedKeys = <String>{
      for (final VaultFinding finding in appliedActions)
        if (finding.resolved) _findingResolutionKey(finding),
    };
    // 只把實際隔離成功的項目標為已解決，不要因任一成功而批次推斷。
    for (final VaultFinding finding in allFindings) {
      if (finding.plannedAction != VaultPlannedAction.quarantine) {
        continue;
      }
      if (!quarantinedReferences.contains(finding.internalReference) &&
          (finding.entryId == null ||
              !quarantinedReferences.contains(finding.entryId!))) {
        continue;
      }
      resolvedKeys.add(_findingResolutionKey(finding));
    }
    final List<VaultFinding> finalUnresolved = <VaultFinding>[
      for (final VaultFinding finding in allFindings)
        if (!finding.resolved &&
            !resolvedKeys.contains(_findingResolutionKey(finding)))
          finding,
    ];

    await _writeQuarantineMetadata(
      repairId: repairId,
      quarantinedCount: quarantinedCount,
      appliedActions: appliedActions,
      unresolvedFindings: finalUnresolved,
    );

    stopwatch.stop();
    final VaultRepairActionAggregation actionSummary =
        aggregateVaultRepairActionEvents(actionEvents);
    var report = VaultRepairReport(
      entryCount: indexEntries.length,
      duration: stopwatch.elapsed,
      finishedAt: DateTime.now(),
      relocatedEntries: actionSummary.relocatedEntries,
      removedDuplicateEntries: actionSummary.removedDuplicateEntries,
      tagsAdded: tagsAdded,
      relocatedAssets: actionSummary.relocatedAssets,
      removedOrphanAssets: actionSummary.removedOrphanAssets,
      issues: <VaultRepairIssue>[
        for (final VaultFinding finding in finalUnresolved)
          VaultRepairIssue(
            kind: finding.kind,
            reference: finding.internalReference,
          ),
      ],
      findings: allFindings,
      appliedActions: appliedActions,
      unresolvedFindings: finalUnresolved,
      entryActionLogs: actionSummary.entryActionLogs,
      quarantinedCount: quarantinedCount,
      purgedBadAssets: actionSummary.purgedBadAssets,
      removedBrokenReferences: actionSummary.removedBrokenReferences,
      splitAttachments: actionSummary.splitAttachments,
      recoveredAttachments: actionSummary.recoveredAttachments,
      purgedOldQuarantine: actionSummary.purgedOldQuarantine,
      backupFileName: backupFileName,
      repairId: repairId,
    );
    if (!await _storeRepairSummary(report)) {
      report = report.copyWith(
        issues: <VaultRepairIssue>[
          ...report.issues,
          const VaultRepairIssue(
            kind: VaultRepairIssueKind.cleanupFailure,
            reference: 'index/last_repair_summary',
          ),
        ],
        unresolvedFindings: <VaultFinding>[
          ...report.unresolvedFindings,
          const VaultFinding(
            kind: VaultRepairIssueKind.cleanupFailure,
            plannedAction: VaultPlannedAction.none,
            manualAction: VaultManualAction.none,
            canOpenEntry: false,
            internalReference: 'index/last_repair_summary',
          ),
        ],
      );
    }
    // 修復後同步更新 inspect summary，讓異常日記入口反映最新狀態。
    await _storeInspectSummary(
      VaultInspectReport(
        entryCount: report.entryCount,
        duration: report.duration,
        finishedAt: report.finishedAt,
        findings: report.unresolvedFindings,
      ),
    );
    return report;
  }

  Future<_EntryRepairStats> _scanEntries(
    UnlockedVaultSession session,
    RecoveryMetadata metadata,
    List<File> files, {
    required bool repair,
    List<VaultRepairActionEvent>? actionEvents,
  }) async {
    final Directory vaultRoot = await _pathStrategy.vaultRootDirectory();
    final Directory entriesDirectory = Directory(
      p.join(vaultRoot.path, 'entries'),
    );
    if (files.isEmpty) {
      return const _EntryRepairStats(
        scanned: <_ScannedEntry>[],
        relocatedEntries: 0,
        issues: <VaultRepairIssue>[],
        findings: <VaultFinding>[],
        cleanupTargets: <String, _RepairCleanupTarget>{},
        assetReferences: <AssetId, List<_AssetReference>>{},
      );
    }

    final List<_RawScannedEntry> rawScans = <_RawScannedEntry>[];
    final List<VaultRepairIssue> issues = <VaultRepairIssue>[];
    final List<VaultFinding> findings = <VaultFinding>[];
    final Map<String, _RepairCleanupTarget> cleanupTargets =
        <String, _RepairCleanupTarget>{};
    final String normalizedEntriesRoot = p.normalize(entriesDirectory.path);

    void addEntryIssue({
      required VaultRepairIssueKind kind,
      required String reference,
      EntryId? entryId,
      String? entryTitle,
      DateOnly? entryDate,
      String? quarantinePath,
      String? quarantineFileId,
      String? quarantineHash,
    }) {
      issues.add(VaultRepairIssue(kind: kind, reference: reference));
      findings.add(
        VaultFinding(
          kind: kind,
          plannedAction: plannedActionForIssue(kind, forRepair: repair),
          manualAction: manualActionForIssue(kind),
          canOpenEntry: canOpenEntryForIssue(kind) && entryId != null,
          entryId: entryId,
          entryTitle: entryTitle,
          entryDate: entryDate,
          internalReference: reference,
        ),
      );
      if (repair &&
          quarantinePath != null &&
          quarantineFileId != null &&
          quarantineHash != null) {
        cleanupTargets[quarantinePath] = _RepairCleanupTarget(
          path: quarantinePath,
          fileId: quarantineFileId,
          contentType: 'text/markdown',
          plaintextHash: quarantineHash,
          isAttachment: false,
          quarantine: true,
          entryTitle: entryTitle,
          entryDate: entryDate,
          entryId: entryId,
        );
      }
    }

    for (final File entity in files) {
      final String reference = await _vaultRelativeReference(entity.path);
      try {
        final ParsedEncryptedDocument parsed = _cryptoService.parseFileBytes(
          await entity.readAsBytes(),
        );
        if (parsed.header.vaultId != metadata.vaultId ||
            parsed.header.contentType != 'text/markdown') {
          // 無法可靠解密為明文時跳過內容驗證，避免用加密檔 hash 誤判。
          addEntryIssue(
            kind: VaultRepairIssueKind.entryIdentityMismatch,
            reference: reference,
            quarantinePath: entity.path,
            quarantineFileId: 'unknown',
            quarantineHash: 'unknown',
          );
          continue;
        }
        final String markdown = await _cryptoService.decryptMarkdown(
          headerBytes: parsed.headerBytes,
          ciphertextBytes: parsed.ciphertextBytes,
          context: vaultDecryptionContext(session),
        );
        final DecodedFrontMatterDocument decoded = _frontMatterCodec
            .decodeDocument(markdown);
        final String rawId = '${decoded.frontMatter['id'] ?? ''}'.trim();
        final String rawDate = '${decoded.frontMatter['date'] ?? ''}'.trim();
        final String rawCreatedAt = '${decoded.frontMatter['created_at'] ?? ''}'
            .trim();
        final String rawUpdatedAt = '${decoded.frontMatter['updated_at'] ?? ''}'
            .trim();
        final DateOnly? date = DateOnly.tryParse(rawDate);
        final List<AssetId> attachmentIds = decoded.entry.attachmentIds;
        if (!_isSafePathSegment(rawId) ||
            date == null ||
            _tryParseStrictIsoDateTime(rawCreatedAt) == null ||
            _tryParseStrictIsoDateTime(rawUpdatedAt) == null ||
            attachmentIds.toSet().length != attachmentIds.length ||
            attachmentIds.any((AssetId id) => !_isSafePathSegment(id))) {
          addEntryIssue(
            kind: VaultRepairIssueKind.invalidEntryMetadata,
            reference: reference,
            quarantinePath: entity.path,
            quarantineFileId: parsed.header.fileId,
            quarantineHash: await hashVaultText(markdown),
          );
          continue;
        }
        if (parsed.header.fileId != rawId) {
          addEntryIssue(
            kind: VaultRepairIssueKind.entryIdentityMismatch,
            reference: reference,
            entryId: rawId,
            entryTitle: decoded.entry.normalizedTitle,
            entryDate: date,
            quarantinePath: entity.path,
            quarantineFileId: parsed.header.fileId,
            quarantineHash: await hashVaultText(markdown),
          );
          continue;
        }
        final DiaryEntry entry = decoded.entry.copyWith(
          vaultId: metadata.vaultId,
        );
        final String canonicalPath = p.normalize(
          await _pathStrategy.entryAbsolutePath(date: date, entryId: rawId),
        );
        if (!p.isWithin(normalizedEntriesRoot, canonicalPath)) {
          addEntryIssue(
            kind: VaultRepairIssueKind.invalidEntryMetadata,
            reference: reference,
            entryId: rawId,
            entryTitle: entry.normalizedTitle,
            entryDate: date,
            quarantinePath: entity.path,
            quarantineFileId: rawId,
            quarantineHash: await hashVaultText(markdown),
          );
          continue;
        }
        final Map<AssetId, String> attachmentExtensions = <AssetId, String>{};
        for (var index = 0; index < attachmentIds.length; index++) {
          final String path = index < decoded.attachmentPaths.length
              ? decoded.attachmentPaths[index]
              : '';
          attachmentExtensions[attachmentIds[index]] = p
              .extension(path)
              .replaceFirst('.', '')
              .toLowerCase();
        }
        rawScans.add(
          _RawScannedEntry(
            entry: entry,
            filePath: entity.path,
            markdown: markdown,
            attachmentExtensions: attachmentExtensions,
            searchFields: entrySearchFields(entry),
            encryptedFileSize: await entity.length(),
            encryptedModifiedAt: await entity.lastModified(),
            plaintextHash: await hashVaultText(markdown),
            canonicalPath: canonicalPath,
          ),
        );
      } on Object {
        addEntryIssue(
          kind: VaultRepairIssueKind.unreadableEntry,
          reference: reference,
          quarantinePath: entity.path,
          quarantineFileId: 'unknown',
          quarantineHash: 'unknown',
        );
      }
    }

    final Map<String, List<_RawScannedEntry>> entriesById =
        <String, List<_RawScannedEntry>>{};
    for (final _RawScannedEntry raw in rawScans) {
      entriesById
          .putIfAbsent(raw.entry.id, () => <_RawScannedEntry>[])
          .add(raw);
    }

    final Set<EntryId> conflictingEntryIds = <EntryId>{};
    final List<_RawScannedEntry> authoritative = <_RawScannedEntry>[];
    for (final List<_RawScannedEntry> group in entriesById.values) {
      group.sort((_RawScannedEntry a, _RawScannedEntry b) {
        final int updated = b.entry.updatedAt.compareTo(a.entry.updatedAt);
        if (updated != 0) return updated;
        final bool aCanonical = p.normalize(a.filePath) == a.canonicalPath;
        final bool bCanonical = p.normalize(b.filePath) == b.canonicalPath;
        if (aCanonical != bCanonical) return aCanonical ? -1 : 1;
        final int modified = b.encryptedModifiedAt.compareTo(
          a.encryptedModifiedAt,
        );
        return modified != 0 ? modified : a.filePath.compareTo(b.filePath);
      });
      final Set<String> hashes = group
          .map((_RawScannedEntry entry) => entry.plaintextHash)
          .toSet();
      if (hashes.length > 1) {
        authoritative.add(group.first);
        conflictingEntryIds.add(group.first.entry.id);
        findings.add(
          VaultFinding(
            kind: VaultRepairIssueKind.conflictingEntry,
            plannedAction: plannedActionForIssue(
              VaultRepairIssueKind.conflictingEntry,
              forRepair: repair,
            ),
            manualAction: manualActionForIssue(
              VaultRepairIssueKind.conflictingEntry,
            ),
            canOpenEntry: true,
            entryId: group.first.entry.id,
            entryTitle: group.first.entry.normalizedTitle,
            entryDate: group.first.entry.date,
            internalReference: group.first.entry.id,
          ),
        );
        issues.add(
          VaultRepairIssue(
            kind: VaultRepairIssueKind.conflictingEntry,
            reference: group.first.entry.id,
          ),
        );
        // 修復時隔離非最新版本。
        if (repair) {
          for (final _RawScannedEntry duplicate in group.skip(1)) {
            cleanupTargets[duplicate.filePath] = _RepairCleanupTarget(
              path: duplicate.filePath,
              fileId: duplicate.entry.id,
              contentType: 'text/markdown',
              plaintextHash: duplicate.plaintextHash,
              isAttachment: false,
              quarantine: true,
              entryTitle: duplicate.entry.normalizedTitle,
              entryDate: duplicate.entry.date,
              entryId: duplicate.entry.id,
            );
          }
        }
        continue;
      }
      final _RawScannedEntry canonical = group.firstWhere(
        (_RawScannedEntry entry) =>
            p.normalize(entry.filePath) == entry.canonicalPath,
        orElse: () => group.first,
      );
      authoritative.add(canonical);
      for (final _RawScannedEntry duplicate in group.where(
        (_RawScannedEntry entry) => !identical(entry, canonical),
      )) {
        cleanupTargets[duplicate.filePath] = _RepairCleanupTarget(
          path: duplicate.filePath,
          fileId: duplicate.entry.id,
          contentType: 'text/markdown',
          plaintextHash: duplicate.plaintextHash,
          isAttachment: false,
          countsAsDuplicateEntry: true,
          entryTitle: duplicate.entry.normalizedTitle,
          entryDate: duplicate.entry.date,
          entryId: duplicate.entry.id,
        );
      }
    }

    var relocatedEntries = 0;
    final List<_ScannedEntry> scanned = <_ScannedEntry>[];
    for (final _RawScannedEntry raw in authoritative) {
      final String canonicalPath = await _pathStrategy.entryAbsolutePath(
        date: raw.entry.date,
        entryId: raw.entry.id,
      );
      final String currentPath = p.normalize(raw.filePath);
      final String normalizedCanonical = p.normalize(canonicalPath);
      var finalPath = currentPath;
      final String finalMarkdown = raw.markdown;
      var finalSize = raw.encryptedFileSize;
      var finalModified = raw.encryptedModifiedAt;

      if (repair &&
          currentPath != normalizedCanonical &&
          !conflictingEntryIds.contains(raw.entry.id)) {
        try {
          final VaultRepairCopyResult result = await _repairFileOperations
              .copyAtomicallyIfAbsent(
                sourcePath: currentPath,
                targetPath: normalizedCanonical,
                validate: (String copiedPath) => _validateRepairFile(
                  copiedPath,
                  session: session,
                  metadata: metadata,
                  expectedId: raw.entry.id,
                  expectedContentType: 'text/markdown',
                  expectedPlaintextHash: raw.plaintextHash,
                  validateAttachmentContent: false,
                ),
              );
          if (result == VaultRepairCopyResult.targetExists) {
            issues.add(
              VaultRepairIssue(
                kind: VaultRepairIssueKind.conflictingEntry,
                reference: raw.entry.id,
              ),
            );
            findings.add(
              VaultFinding(
                kind: VaultRepairIssueKind.conflictingEntry,
                plannedAction: VaultPlannedAction.quarantine,
                manualAction: VaultManualAction.none,
                canOpenEntry: true,
                entryId: raw.entry.id,
                entryTitle: raw.entry.normalizedTitle,
                entryDate: raw.entry.date,
                internalReference: raw.entry.id,
              ),
            );
          } else {
            await _copyChatFilesBesideEntry(
              fromEntryPath: currentPath,
              toEntryPath: normalizedCanonical,
              session: session,
            );
            final File target = File(normalizedCanonical);
            cleanupTargets[currentPath] = _RepairCleanupTarget(
              path: currentPath,
              fileId: raw.entry.id,
              contentType: 'text/markdown',
              plaintextHash: raw.plaintextHash,
              isAttachment: false,
              entryTitle: raw.entry.normalizedTitle,
              entryDate: raw.entry.date,
              entryId: raw.entry.id,
            );
            actionEvents?.add(
              VaultRepairActionEvent(
                scope: VaultRepairActionScope.entry,
                type: VaultRepairActionType.relocateEntry,
                outcome: VaultRepairActionOutcome.succeeded,
                entryTitle: raw.entry.normalizedTitle,
                entryDate: raw.entry.date,
                internalIdentity: raw.entry.id,
              ),
            );
            finalPath = normalizedCanonical;
            finalSize = await target.length();
            finalModified = await target.lastModified();
            relocatedEntries++;
          }
        } on Object {
          issues.add(
            VaultRepairIssue(
              kind: VaultRepairIssueKind.cleanupFailure,
              reference: await _vaultRelativeReference(normalizedCanonical),
            ),
          );
          findings.add(
            VaultFinding(
              kind: VaultRepairIssueKind.cleanupFailure,
              plannedAction: VaultPlannedAction.relocateToCanonical,
              manualAction: VaultManualAction.none,
              canOpenEntry: true,
              entryId: raw.entry.id,
              entryTitle: raw.entry.normalizedTitle,
              entryDate: raw.entry.date,
              internalReference: await _vaultRelativeReference(
                normalizedCanonical,
              ),
            ),
          );
        }
      }

      scanned.add(
        _ScannedEntry(
          entry: raw.entry,
          filePath: finalPath,
          markdown: finalMarkdown,
          attachments: <AssetAttachment>[],
          attachmentPaths: <AssetId, String>{},
          searchFields: raw.searchFields,
          encryptedFileSize: finalSize,
          encryptedModifiedAt: finalModified,
        ),
      );
    }

    final Map<AssetId, List<_AssetReference>> assetReferences =
        <AssetId, List<_AssetReference>>{};
    for (final _RawScannedEntry raw in authoritative) {
      for (final AssetId assetId in raw.entry.attachmentIds) {
        assetReferences
            .putIfAbsent(assetId, () => <_AssetReference>[])
            .add(
              _AssetReference(
                entryId: raw.entry.id,
                date: raw.entry.date,
                extension: raw.attachmentExtensions[assetId] ?? '',
              ),
            );
      }
    }

    return _EntryRepairStats(
      scanned: scanned,
      relocatedEntries: relocatedEntries,
      issues: issues,
      findings: findings,
      cleanupTargets: cleanupTargets,
      assetReferences: assetReferences,
    );
  }

  Future<_AssetRepairStats> _scanAssets({
    required UnlockedVaultSession session,
    required RecoveryMetadata metadata,
    required List<_ScannedEntry> entries,
    required Map<AssetId, List<_AssetReference>> references,
    required List<File> files,
    required bool hasUnresolvedEntryIssues,
    required bool repair,
  }) async {
    final List<VaultRepairIssue> issues = <VaultRepairIssue>[];
    final List<VaultFinding> findings = <VaultFinding>[];
    final Map<String, _RepairCleanupTarget> cleanupTargets =
        <String, _RepairCleanupTarget>{};
    final Set<AssetId> sharedAssetIds = <AssetId>{};
    final Set<AssetId> recoveredAssetIds = <AssetId>{};
    final Map<EntryId, _ScannedEntry> entriesById = <EntryId, _ScannedEntry>{
      for (final _ScannedEntry entry in entries) entry.entry.id: entry,
    };

    void addAssetFinding({
      required VaultRepairIssueKind kind,
      required String reference,
      EntryId? entryId,
      String? mimeType,
      bool resolved = false,
    }) {
      final _ScannedEntry? scanned = entryId == null
          ? null
          : entriesById[entryId];
      issues.add(VaultRepairIssue(kind: kind, reference: reference));
      findings.add(
        VaultFinding(
          kind: kind,
          plannedAction: plannedActionForIssue(kind, forRepair: repair),
          manualAction: manualActionForIssue(kind),
          canOpenEntry: canOpenEntryForIssue(kind) && scanned != null,
          entryId: scanned?.entry.id ?? entryId,
          entryTitle: scanned?.entry.normalizedTitle,
          entryDate: scanned?.entry.date,
          attachmentCategory: attachmentCategoryForMimeType(mimeType),
          internalReference: reference,
          resolved: resolved,
        ),
      );
    }

    if (files.isEmpty) {
      for (final MapEntry<AssetId, List<_AssetReference>> item
          in references.entries) {
        for (final _AssetReference reference in item.value) {
          addAssetFinding(
            kind: VaultRepairIssueKind.missingAsset,
            reference: item.key,
            entryId: reference.entryId,
          );
        }
      }
      return _AssetRepairStats(
        relocatedAssets: 0,
        issues: issues,
        findings: findings,
        cleanupTargets: cleanupTargets,
        sharedAssetIds: sharedAssetIds,
        recoveredAssetIds: recoveredAssetIds,
      );
    }

    final Map<AssetId, List<_ValidatedAssetFile>> filesById =
        <AssetId, List<_ValidatedAssetFile>>{};
    final Map<AssetId, List<String>> invalidPathsById =
        <AssetId, List<String>>{};
    var relocatedAssets = 0;
    for (final File entity in files) {
      final String fileName = p.basename(entity.path).replaceFirst('.enc', '');
      final String assetId = p.basenameWithoutExtension(fileName);
      final String reference = await _vaultRelativeReference(entity.path);
      if (!_isSafePathSegment(assetId)) {
        addAssetFinding(
          kind: VaultRepairIssueKind.assetIdentityMismatch,
          reference: reference,
        );
        if (repair) {
          cleanupTargets[entity.path] = _RepairCleanupTarget(
            path: entity.path,
            fileId: 'unknown',
            contentType: 'application/octet-stream',
            plaintextHash: 'unknown',
            isAttachment: true,
            countsAsBadAsset: true,
            requiresReferenceRewrite: references.containsKey(assetId),
            quarantine: hasUnresolvedEntryIssues,
          );
        }
        continue;
      }
      try {
        final ParsedEncryptedDocument parsed = _cryptoService.parseFileBytes(
          await entity.readAsBytes(),
        );
        final String fileExtension = p
            .extension(fileName)
            .replaceFirst('.', '')
            .toLowerCase();
        if (parsed.header.fileId != assetId ||
            parsed.header.vaultId != metadata.vaultId ||
            parsed.header.contentType.trim().isEmpty ||
            parsed.header.createdAt.millisecondsSinceEpoch <= 0 ||
            !contentTypeMatchesExtension(
              parsed.header.contentType,
              fileExtension,
            )) {
          invalidPathsById
              .putIfAbsent(assetId, () => <String>[])
              .add(entity.path);
          addAssetFinding(
            kind: VaultRepairIssueKind.assetIdentityMismatch,
            reference: reference,
            entryId: references[assetId]?.firstOrNull?.entryId,
            mimeType: parsed.header.contentType,
          );
          if (repair) {
            // header 不符時尚未取得明文，跳過內容驗證。
            cleanupTargets[entity.path] = _RepairCleanupTarget(
              path: entity.path,
              fileId: 'unknown',
              contentType: parsed.header.contentType.isEmpty
                  ? 'application/octet-stream'
                  : parsed.header.contentType,
              plaintextHash: 'unknown',
              isAttachment: true,
              countsAsBadAsset: true,
              requiresReferenceRewrite: references.containsKey(assetId),
              quarantine: hasUnresolvedEntryIssues,
            );
          }
          continue;
        }
        final List<int> plaintext = await _cryptoService.decryptBytes(
          headerBytes: parsed.headerBytes,
          ciphertextBytes: parsed.ciphertextBytes,
          context: vaultDecryptionContext(session),
        );
        if (!attachmentContentMatchesMimeType(
          plaintext,
          parsed.header.contentType,
        )) {
          invalidPathsById
              .putIfAbsent(assetId, () => <String>[])
              .add(entity.path);
          addAssetFinding(
            kind: VaultRepairIssueKind.assetIdentityMismatch,
            reference: reference,
            entryId: references[assetId]?.firstOrNull?.entryId,
            mimeType: parsed.header.contentType,
          );
          if (repair) {
            cleanupTargets[entity.path] = _RepairCleanupTarget(
              path: entity.path,
              fileId: assetId,
              contentType: parsed.header.contentType,
              plaintextHash: await hashVaultBytes(plaintext),
              isAttachment: true,
              countsAsBadAsset: true,
              requiresReferenceRewrite: references.containsKey(assetId),
              quarantine: hasUnresolvedEntryIssues,
            );
          }
          continue;
        }
        filesById
            .putIfAbsent(assetId, () => <_ValidatedAssetFile>[])
            .add(
              _ValidatedAssetFile(
                id: assetId,
                path: entity.path,
                extension: fileExtension,
                mimeType: parsed.header.contentType,
                createdAt: parsed.header.createdAt,
                modifiedAt: await entity.lastModified(),
                byteSize: plaintext.length,
                plaintextHash: await hashVaultBytes(plaintext),
              ),
            );
      } on Object {
        invalidPathsById
            .putIfAbsent(assetId, () => <String>[])
            .add(entity.path);
        addAssetFinding(
          kind: VaultRepairIssueKind.unreadableAsset,
          reference: reference,
          entryId: references[assetId]?.firstOrNull?.entryId,
        );
        if (repair) {
          cleanupTargets[entity.path] = _RepairCleanupTarget(
            path: entity.path,
            fileId: 'unknown',
            contentType: 'application/octet-stream',
            plaintextHash: 'unknown',
            isAttachment: true,
            countsAsBadAsset: true,
            requiresReferenceRewrite: references.containsKey(assetId),
            quarantine: hasUnresolvedEntryIssues,
          );
        }
      }
    }

    for (final MapEntry<AssetId, List<_ValidatedAssetFile>> group
        in filesById.entries) {
      final AssetId assetId = group.key;
      group.value.sort((_ValidatedAssetFile a, _ValidatedAssetFile b) {
        final int created = a.createdAt.compareTo(b.createdAt);
        if (created != 0) return created;
        final int modified = a.modifiedAt.compareTo(b.modifiedAt);
        return modified != 0
            ? modified
            : p.normalize(a.path).compareTo(p.normalize(b.path));
      });
      final List<_AssetReference>? assetReferences = references[assetId];
      if (assetReferences == null || assetReferences.isEmpty) {
        for (final _ValidatedAssetFile file in group.value) {
          if (hasUnresolvedEntryIssues) {
            addAssetFinding(
              kind: VaultRepairIssueKind.unverifiedOrphanAsset,
              reference: await _vaultRelativeReference(file.path),
              mimeType: file.mimeType,
            );
            if (repair) {
              cleanupTargets[file.path] = _RepairCleanupTarget(
                path: file.path,
                fileId: file.id,
                contentType: file.mimeType,
                plaintextHash: file.plaintextHash,
                isAttachment: true,
                quarantine: true,
              );
            }
          } else if (repair) {
            cleanupTargets[file.path] = _RepairCleanupTarget(
              path: file.path,
              fileId: file.id,
              contentType: file.mimeType,
              plaintextHash: file.plaintextHash,
              isAttachment: true,
              countsAsOrphanAsset: true,
            );
          }
        }
        continue;
      }
      final Set<String> owners = assetReferences
          .map((_AssetReference item) => '${item.entryId}:${item.date.value}')
          .toSet();
      if (owners.length != 1) {
        sharedAssetIds.add(assetId);
        for (final _AssetReference reference in assetReferences) {
          addAssetFinding(
            kind: VaultRepairIssueKind.conflictingAsset,
            reference: assetId,
            entryId: reference.entryId,
            mimeType: group.value.first.mimeType,
          );
        }
        // 先掛上目前可驗證版本，後續拆分會重寫其他日記。
        _attachResolvedAsset(entries, assetReferences.first, group.value.first);
        if (invalidPathsById.containsKey(assetId)) {
          recoveredAssetIds.add(assetId);
        }
        continue;
      }
      if (assetReferences.any(
        (_AssetReference reference) => !contentTypeMatchesExtension(
          group.value.first.mimeType,
          reference.extension,
        ),
      )) {
        addAssetFinding(
          kind: VaultRepairIssueKind.assetIdentityMismatch,
          reference: assetId,
          entryId: assetReferences.first.entryId,
          mimeType: group.value.first.mimeType,
          resolved: true,
        );
        _attachResolvedAsset(entries, assetReferences.first, group.value.first);
        continue;
      }
      final Set<String> contents = group.value
          .map(
            (_ValidatedAssetFile file) =>
                '${file.mimeType}:${file.plaintextHash}',
          )
          .toSet();
      String extension = assetReferences
          .map((_AssetReference item) => item.extension)
          .firstWhere((String value) => value.isNotEmpty, orElse: () => '');
      extension = extension.isEmpty
          ? extensionFromMimeType(group.value.first.mimeType)
          : extension;
      if (extension.isEmpty) extension = group.value.first.extension;
      final DateOnly date = assetReferences.first.date;
      final String canonicalPath = await _pathStrategy.assetAbsolutePath(
        date: date,
        assetId: assetId,
        extension: extension.isEmpty ? 'bin' : extension,
      );
      group.value.sort((_ValidatedAssetFile a, _ValidatedAssetFile b) {
        final bool aCanonical =
            p.normalize(a.path) == p.normalize(canonicalPath);
        final bool bCanonical =
            p.normalize(b.path) == p.normalize(canonicalPath);
        if (aCanonical != bCanonical) return aCanonical ? -1 : 1;
        final int created = a.createdAt.compareTo(b.createdAt);
        if (created != 0) return created;
        final int modified = a.modifiedAt.compareTo(b.modifiedAt);
        return modified != 0
            ? modified
            : p.normalize(a.path).compareTo(p.normalize(b.path));
      });
      final _ValidatedAssetFile? canonical = group.value
          .where(
            (_ValidatedAssetFile file) =>
                p.normalize(file.path) == p.normalize(canonicalPath),
          )
          .firstOrNull;
      if (contents.length > 1) {
        addAssetFinding(
          kind: VaultRepairIssueKind.conflictingAsset,
          reference: assetId,
          entryId: assetReferences.first.entryId,
          mimeType: group.value.first.mimeType,
        );
        if (canonical != null) {
          _attachResolvedAsset(entries, assetReferences.first, canonical);
          if (invalidPathsById.containsKey(assetId)) {
            recoveredAssetIds.add(assetId);
          }
          if (repair) {
            for (final _ValidatedAssetFile duplicate in group.value.where(
              (_ValidatedAssetFile file) =>
                  p.normalize(file.path) != p.normalize(canonical.path),
            )) {
              cleanupTargets[duplicate.path] = _RepairCleanupTarget(
                path: duplicate.path,
                fileId: duplicate.id,
                contentType: duplicate.mimeType,
                plaintextHash: duplicate.plaintextHash,
                isAttachment: true,
                quarantine: true,
              );
            }
          }
        }
        continue;
      }
      _ValidatedAssetFile selected = canonical ?? group.value.first;
      if (repair && canonical == null) {
        try {
          final VaultRepairCopyResult result = await _repairFileOperations
              .copyAtomicallyIfAbsent(
                sourcePath: selected.path,
                targetPath: canonicalPath,
                validate: (String copiedPath) => _validateRepairFile(
                  copiedPath,
                  session: session,
                  metadata: metadata,
                  expectedId: selected.id,
                  expectedContentType: selected.mimeType,
                  expectedPlaintextHash: selected.plaintextHash,
                  validateAttachmentContent: true,
                ),
              );
          if (result == VaultRepairCopyResult.targetExists) {
            addAssetFinding(
              kind: VaultRepairIssueKind.conflictingAsset,
              reference: assetId,
              entryId: assetReferences.first.entryId,
              mimeType: selected.mimeType,
            );
            continue;
          }
          selected = _ValidatedAssetFile(
            id: selected.id,
            path: canonicalPath,
            extension: extension,
            mimeType: selected.mimeType,
            createdAt: selected.createdAt,
            modifiedAt: await File(canonicalPath).lastModified(),
            byteSize: selected.byteSize,
            plaintextHash: selected.plaintextHash,
          );
          relocatedAssets++;
        } on Object {
          addAssetFinding(
            kind: VaultRepairIssueKind.cleanupFailure,
            reference: await _vaultRelativeReference(canonicalPath),
            entryId: assetReferences.first.entryId,
            mimeType: selected.mimeType,
          );
          _attachResolvedAsset(entries, assetReferences.first, selected);
          if (invalidPathsById.containsKey(assetId)) {
            recoveredAssetIds.add(assetId);
          }
          continue;
        }
      }
      _attachResolvedAsset(entries, assetReferences.first, selected);
      if (invalidPathsById.containsKey(assetId)) {
        recoveredAssetIds.add(assetId);
      }
      if (repair) {
        for (final _ValidatedAssetFile duplicate in group.value.where(
          (_ValidatedAssetFile file) =>
              p.normalize(file.path) != p.normalize(selected.path),
        )) {
          cleanupTargets[duplicate.path] = _RepairCleanupTarget(
            path: duplicate.path,
            fileId: duplicate.id,
            contentType: duplicate.mimeType,
            plaintextHash: duplicate.plaintextHash,
            isAttachment: true,
          );
        }
      }
    }

    for (final MapEntry<AssetId, List<_AssetReference>> item
        in references.entries) {
      final AssetId id = item.key;
      if (!filesById.containsKey(id) && !invalidPathsById.containsKey(id)) {
        for (final _AssetReference reference in item.value) {
          addAssetFinding(
            kind: VaultRepairIssueKind.missingAsset,
            reference: id,
            entryId: reference.entryId,
          );
        }
      } else if (invalidPathsById.containsKey(id) &&
          !filesById.containsKey(id)) {
        // 已有 identity / unreadable finding；仍需讓引用修正階段知道要移除。
      }
    }
    return _AssetRepairStats(
      relocatedAssets: relocatedAssets,
      issues: issues,
      findings: findings,
      cleanupTargets: cleanupTargets,
      sharedAssetIds: sharedAssetIds,
      recoveredAssetIds: recoveredAssetIds,
    );
  }

  void _attachResolvedAsset(
    List<_ScannedEntry> entries,
    _AssetReference reference,
    _ValidatedAssetFile file,
  ) {
    final _ScannedEntry entry = entries.firstWhere(
      (_ScannedEntry item) => item.entry.id == reference.entryId,
    );
    entry.attachments.add(
      AssetAttachment(
        id: file.id,
        entryId: reference.entryId,
        mimeType: file.mimeType,
        safeFilename: '${file.id}.${file.extension}',
        byteSize: file.byteSize,
        createdAt: file.createdAt,
        sha256: file.plaintextHash,
      ),
    );
    entry.attachmentPaths[file.id] = file.path;
  }

  bool _isSafePathSegment(String value) {
    final String trimmed = value.trim();
    final String windowsStem = trimmed.split('.').first.toUpperCase();
    final bool isWindowsDeviceName =
        <String>{'CON', 'PRN', 'AUX', 'NUL'}.contains(windowsStem) ||
        RegExp(r'^(COM|LPT)[1-9]$').hasMatch(windowsStem);
    return trimmed.isNotEmpty &&
        trimmed != '.' &&
        trimmed != '..' &&
        !isWindowsDeviceName &&
        !trimmed.contains(RegExp(r'[/\\<>:"|?*\x00-\x1F]')) &&
        !trimmed.endsWith('.') &&
        !trimmed.endsWith(' ');
  }

  DateTime? _tryParseStrictIsoDateTime(String value) {
    final RegExpMatch? match = _strictIsoDateTimePattern.firstMatch(value);
    if (match == null ||
        DateOnly.tryParse(value.substring(0, 10)) == null ||
        int.parse(match.group(4)!) > 23 ||
        int.parse(match.group(5)!) > 59 ||
        int.parse(match.group(6)!) > 59 ||
        (match.group(10) != null && int.parse(match.group(10)!) > 23) ||
        (match.group(11) != null && int.parse(match.group(11)!) > 59)) {
      return null;
    }
    return DateTime.tryParse(value);
  }

  Future<bool> _validateRepairFile(
    String path, {
    required UnlockedVaultSession session,
    required RecoveryMetadata metadata,
    required String expectedId,
    required String expectedContentType,
    required String expectedPlaintextHash,
    required bool validateAttachmentContent,
  }) async {
    final ParsedEncryptedDocument parsed = _cryptoService.parseFileBytes(
      await File(path).readAsBytes(),
    );
    if (parsed.header.fileId != expectedId ||
        parsed.header.vaultId != metadata.vaultId ||
        parsed.header.contentType != expectedContentType) {
      return false;
    }
    final List<int> plaintext = await _cryptoService.decryptBytes(
      headerBytes: parsed.headerBytes,
      ciphertextBytes: parsed.ciphertextBytes,
      context: vaultDecryptionContext(session),
    );
    if (validateAttachmentContent &&
        !attachmentContentMatchesMimeType(plaintext, expectedContentType)) {
      return false;
    }
    return await hashVaultBytes(plaintext) == expectedPlaintextHash;
  }

  Future<String> _vaultRelativeReference(String absolutePath) async {
    final Directory root = await _pathStrategy.vaultRootDirectory();
    return p
        .relative(p.normalize(absolutePath), from: p.normalize(root.path))
        .replaceAll('\\', '/');
  }

  AssetId? _assetIdFromFindingReference(String reference) {
    final String normalized = reference.trim().replaceAll('\\', '/');
    if (normalized.isEmpty) return null;
    final RegExpMatch? match = RegExp(r'(att_[A-Za-z0-9_-]+)')
        .firstMatch(normalized);
    if (match != null) return match.group(1);
    if (!normalized.contains('/')) {
      return _isSafePathSegment(normalized) ? normalized : null;
    }
    final String fileName = p
        .basename(normalized)
        .replaceFirst(RegExp(r'\.enc$', caseSensitive: false), '');
    final String assetId = p.basenameWithoutExtension(fileName);
    return _isSafePathSegment(assetId) ? assetId : null;
  }

  List<VaultFinding> _enrichFindings(
    List<VaultFinding> findings,
    List<_ScannedEntry> scanned,
  ) {
    final Map<EntryId, _ScannedEntry> byId = <EntryId, _ScannedEntry>{
      for (final _ScannedEntry item in scanned) item.entry.id: item,
    };
    final List<VaultFinding> enriched = <VaultFinding>[];
    final Set<String> seen = <String>{};
    for (final VaultFinding finding in findings) {
      final String key = _findingResolutionKey(finding);
      if (!seen.add(key)) continue;
      final _ScannedEntry? scannedEntry = finding.entryId == null
          ? null
          : byId[finding.entryId!];
      enriched.add(
        VaultFinding(
          kind: finding.kind,
          plannedAction: finding.plannedAction,
          manualAction: finding.manualAction,
          canOpenEntry: finding.canOpenEntry && scannedEntry != null,
          entryId: finding.entryId ?? scannedEntry?.entry.id,
          entryTitle: finding.entryTitle ?? scannedEntry?.entry.normalizedTitle,
          entryDate: finding.entryDate ?? scannedEntry?.entry.date,
          attachmentCategory: finding.attachmentCategory,
          internalReference: finding.internalReference,
          resolved: finding.resolved,
        ),
      );
    }
    return enriched;
  }

  Future<bool> _quarantineFile({
    required UnlockedVaultSession session,
    required RecoveryMetadata metadata,
    required String repairId,
    required _RepairCleanupTarget target,
  }) async {
    try {
      final Directory vaultRoot = await _pathStrategy.vaultRootDirectory();
      final String relative = await _vaultRelativeReference(target.path);
      final String destination = p.join(
        vaultRoot.path,
        'quarantine',
        repairId,
        relative,
      );
      Future<bool> validatePath(String path) async {
        if (!File(path).existsSync()) return false;
        if (target.fileId == 'unknown') {
          // 無法解密時比對原始檔 bytes，避免 targetExists 誤刪來源。
          return _sameFileBytes(path, target.path);
        }
        return _validateRepairFile(
          path,
          session: session,
          metadata: metadata,
          expectedId: target.fileId,
          expectedContentType: target.contentType,
          expectedPlaintextHash: target.plaintextHash,
          validateAttachmentContent: target.isAttachment,
        );
      }

      final VaultRepairCopyResult copyResult = await _repairFileOperations
          .copyAtomicallyIfAbsent(
            sourcePath: target.path,
            targetPath: destination,
            validate: validatePath,
          );
      if (copyResult == VaultRepairCopyResult.targetExists) {
        // 目標已存在時必須先驗證內容，通過後才可刪來源。
        if (!await validatePath(destination)) {
          return false;
        }
      } else if (copyResult != VaultRepairCopyResult.copied) {
        return false;
      } else if (!await validatePath(destination)) {
        return false;
      }

      if (!target.isAttachment) {
        await _copyChatFilesBesideEntry(
          fromEntryPath: target.path,
          toEntryPath: destination,
          session: session,
        );
      }
      final VaultRepairDeleteResult deleteResult = await _repairFileOperations
          .deleteIfValid(path: target.path, validate: validatePath);
      final deleted =
          deleteResult == VaultRepairDeleteResult.deleted ||
          deleteResult == VaultRepairDeleteResult.missing;
      if (deleted && !target.isAttachment) {
        await deleteEntryChatFiles(target.path);
      }
      return deleted;
    } on Object {
      return false;
    }
  }

  Future<({int purgedDirs, List<VaultFinding> failures})> _purgeOldQuarantine({
    required String currentRepairId,
    required bool retainBecauseUnresolvedEntries,
  }) async {
    if (retainBecauseUnresolvedEntries) {
      return (purgedDirs: 0, failures: const <VaultFinding>[]);
    }
    final List<VaultFinding> failures = <VaultFinding>[];
    var purgedDirs = 0;
    try {
      final Directory root = await _pathStrategy.vaultRootDirectory();
      final String normalizedRoot = p.normalize(root.path);
      final Directory quarantine = Directory(p.join(root.path, 'quarantine'));
      if (!quarantine.existsSync()) {
        return (purgedDirs: 0, failures: const <VaultFinding>[]);
      }
      await for (final FileSystemEntity entity in quarantine.list(
        followLinks: false,
      )) {
        if (entity is! Directory ||
            p.basename(entity.path) == currentRepairId) {
          continue;
        }
        final String relative = p
            .relative(p.normalize(entity.path), from: normalizedRoot)
            .replaceAll('\\', '/');
        if (!relative.startsWith('quarantine/') || relative.contains('..')) {
          continue;
        }
        try {
          await entity.delete(recursive: true);
          purgedDirs++;
        } on Object {
          failures.add(
            VaultFinding(
              kind: VaultRepairIssueKind.cleanupFailure,
              plannedAction: VaultPlannedAction.none,
              manualAction: VaultManualAction.none,
              canOpenEntry: false,
              internalReference: relative,
            ),
          );
        }
      }
      if (quarantine.existsSync() && quarantine.listSync().isEmpty) {
        await quarantine.delete();
      }
    } on Object {
      failures.add(
        const VaultFinding(
          kind: VaultRepairIssueKind.cleanupFailure,
          plannedAction: VaultPlannedAction.none,
          manualAction: VaultManualAction.none,
          canOpenEntry: false,
          internalReference: 'quarantine/',
        ),
      );
    }
    return (purgedDirs: purgedDirs, failures: failures);
  }

  Future<bool> _sameFileBytes(String leftPath, String rightPath) async {
    try {
      final File left = File(leftPath);
      final File right = File(rightPath);
      if (!left.existsSync() || !right.existsSync()) return false;
      if (p.normalize(left.path) == p.normalize(right.path)) return true;
      final List<int> leftBytes = await left.readAsBytes();
      final List<int> rightBytes = await right.readAsBytes();
      if (leftBytes.length != rightBytes.length) return false;
      for (var index = 0; index < leftBytes.length; index++) {
        if (leftBytes[index] != rightBytes[index]) return false;
      }
      return true;
    } on Object {
      return false;
    }
  }

  Future<void> _writeQuarantineMetadata({
    required String repairId,
    required int quarantinedCount,
    required List<VaultFinding> appliedActions,
    required List<VaultFinding> unresolvedFindings,
  }) async {
    // 沒有隔離內容時不建立空的 repair metadata 目錄。
    if (quarantinedCount <= 0) return;
    try {
      final Directory vaultRoot = await _pathStrategy.vaultRootDirectory();
      final File metadataFile = File(
        p.join(vaultRoot.path, 'quarantine', repairId, 'metadata.json'),
      );
      await metadataFile.parent.create(recursive: true);
      await metadataFile.writeAsString(
        jsonEncode(<String, Object?>{
          'repair_id': repairId,
          'finished_at': DateTime.now().toIso8601String(),
          'quarantined_count': quarantinedCount,
          'applied_actions': <Map<String, Object?>>[
            for (final VaultFinding finding in appliedActions) finding.toJson(),
          ],
          'unresolved_findings': <Map<String, Object?>>[
            for (final VaultFinding finding in unresolvedFindings)
              finding.toJson(),
          ],
        }),
        flush: true,
      );
    } on Object {
      // metadata 寫入失敗不阻斷修復本體。
    }
  }

  Future<List<VaultFinding>> _splitSharedAttachments({
    required UnlockedVaultSession session,
    required RecoveryMetadata metadata,
    required List<_ScannedEntry> entries,
    required Set<AssetId> sharedAssetIds,
    required Map<AssetId, List<_AssetReference>> references,
  }) async {
    final List<VaultFinding> results = <VaultFinding>[];
    if (sharedAssetIds.isEmpty) return results;
    final Map<EntryId, _ScannedEntry> entriesById = <EntryId, _ScannedEntry>{
      for (final _ScannedEntry item in entries) item.entry.id: item,
    };
    final List<int> recoveryWrapKey = requireRecoveryWrapKey(session);

    for (final AssetId sharedId in sharedAssetIds) {
      final List<_AssetReference> owners = references[sharedId] ?? const [];
      if (owners.length < 2) continue;
      final _ScannedEntry? primaryEntry = entriesById[owners.first.entryId];
      final String? sourcePath = primaryEntry?.attachmentPaths[sharedId];
      if (primaryEntry == null || sourcePath == null) {
        for (final _AssetReference owner in owners) {
          results.add(
            VaultFinding(
              kind: VaultRepairIssueKind.conflictingAsset,
              plannedAction: VaultPlannedAction.splitAttachment,
              manualAction: VaultManualAction.openAndReuploadAttachment,
              canOpenEntry: entriesById.containsKey(owner.entryId),
              entryId: owner.entryId,
              entryTitle: entriesById[owner.entryId]?.entry.normalizedTitle,
              entryDate: entriesById[owner.entryId]?.entry.date,
              internalReference: sharedId,
            ),
          );
        }
        continue;
      }
      List<int>? plaintext;
      String? mimeType;
      try {
        final ParsedEncryptedDocument parsed = _cryptoService.parseFileBytes(
          await File(sourcePath).readAsBytes(),
        );
        mimeType = parsed.header.contentType;
        plaintext = await _cryptoService.decryptBytes(
          headerBytes: parsed.headerBytes,
          ciphertextBytes: parsed.ciphertextBytes,
          context: vaultDecryptionContext(session),
        );
      } on Object {
        for (final _AssetReference owner in owners) {
          results.add(
            VaultFinding(
              kind: VaultRepairIssueKind.conflictingAsset,
              plannedAction: VaultPlannedAction.splitAttachment,
              manualAction: VaultManualAction.openAndReuploadAttachment,
              canOpenEntry: entriesById.containsKey(owner.entryId),
              entryId: owner.entryId,
              entryTitle: entriesById[owner.entryId]?.entry.normalizedTitle,
              entryDate: entriesById[owner.entryId]?.entry.date,
              attachmentCategory: attachmentCategoryForMimeType(mimeType),
              internalReference: sharedId,
            ),
          );
        }
        continue;
      }
      final List<int> sharedPlaintext = plaintext;
      final String sharedMimeType = mimeType;

      // 第一個 owner 保留原 ID；其餘重新加密成獨立附件。
      for (final _AssetReference owner in owners.skip(1)) {
        final _ScannedEntry? scanned = entriesById[owner.entryId];
        if (scanned == null) continue;
        try {
          final AssetId newId = generateAssetId();
          String extension = owner.extension;
          if (extension.isEmpty) {
            extension = extensionFromMimeType(sharedMimeType);
          }
          if (extension.isEmpty) {
            extension = 'bin';
          }
          final EncryptionResult encrypted = await _cryptoService.encryptBytes(
            documentId: newId,
            vaultId: metadata.vaultId,
            plaintextBytes: Uint8List.fromList(sharedPlaintext),
            contentType: sharedMimeType,
            recoveryWrapKey: recoveryWrapKey,
            recoverySlotKdf: metadata.kdf,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          final String newPath = await _pathStrategy.assetAbsolutePath(
            date: scanned.entry.date,
            assetId: newId,
            extension: extension,
          );
          await atomicWriteBytes(File(newPath), encrypted.toFileBytes());
          final List<AssetId> nextIds = <AssetId>[
            for (final AssetId id in scanned.entry.attachmentIds)
              if (id == sharedId) newId else id,
          ];
          final bool rewritten = await _rewriteScannedEntryAttachments(
            session: session,
            metadata: metadata,
            scanned: scanned,
            nextAttachmentIds: nextIds,
            extraAttachments: <AssetAttachment>[
              AssetAttachment(
                id: newId,
                entryId: scanned.entry.id,
                mimeType: sharedMimeType,
                safeFilename: '$newId.$extension',
                byteSize: sharedPlaintext.length,
                createdAt: DateTime.now(),
                sha256: await hashVaultBytes(sharedPlaintext),
              ),
            ],
            extraPaths: <AssetId, String>{newId: newPath},
            removeAttachmentIds: <AssetId>{sharedId},
          );
          if (!rewritten) {
            // 日記重寫失敗時刪掉剛建立的新附件，避免 orphan。
            try {
              await File(newPath).delete();
            } on Object {
              // 盡力清理即可。
            }
          }
          results.add(
            VaultFinding(
              kind: VaultRepairIssueKind.conflictingAsset,
              plannedAction: VaultPlannedAction.splitAttachment,
              manualAction: rewritten
                  ? VaultManualAction.none
                  : VaultManualAction.openAndReuploadAttachment,
              canOpenEntry: true,
              entryId: scanned.entry.id,
              entryTitle: scanned.entry.normalizedTitle,
              entryDate: scanned.entry.date,
              attachmentCategory: attachmentCategoryForMimeType(sharedMimeType),
              internalReference: sharedId,
              resolved: rewritten,
            ),
          );
        } on Object {
          results.add(
            VaultFinding(
              kind: VaultRepairIssueKind.conflictingAsset,
              plannedAction: VaultPlannedAction.splitAttachment,
              manualAction: VaultManualAction.openAndReuploadAttachment,
              canOpenEntry: true,
              entryId: scanned.entry.id,
              entryTitle: scanned.entry.normalizedTitle,
              entryDate: scanned.entry.date,
              attachmentCategory: attachmentCategoryForMimeType(sharedMimeType),
              internalReference: sharedId,
            ),
          );
        }
      }
      results.add(
        VaultFinding(
          kind: VaultRepairIssueKind.conflictingAsset,
          plannedAction: VaultPlannedAction.splitAttachment,
          manualAction: VaultManualAction.none,
          canOpenEntry: true,
          entryId: primaryEntry.entry.id,
          entryTitle: primaryEntry.entry.normalizedTitle,
          entryDate: primaryEntry.entry.date,
          attachmentCategory: attachmentCategoryForMimeType(sharedMimeType),
          internalReference: sharedId,
          resolved: true,
        ),
      );
    }
    return results;
  }

  Future<List<VaultFinding>> _removeBrokenAttachmentReferences({
    required UnlockedVaultSession session,
    required RecoveryMetadata metadata,
    required List<_ScannedEntry> entries,
    required List<VaultRepairIssue> assetIssues,
    required Set<AssetId> recoveredAssetIds,
  }) async {
    final List<VaultFinding> results = <VaultFinding>[];
    final Map<AssetId, VaultRepairIssueKind> brokenKinds =
        <AssetId, VaultRepairIssueKind>{};
    for (final VaultRepairIssue issue in assetIssues) {
      if (issue.kind != VaultRepairIssueKind.missingAsset &&
          issue.kind != VaultRepairIssueKind.unreadableAsset &&
          issue.kind != VaultRepairIssueKind.assetIdentityMismatch) {
        continue;
      }
      final AssetId? assetId = _assetIdFromFindingReference(issue.reference);
      if (assetId != null && !recoveredAssetIds.contains(assetId)) {
        brokenKinds.putIfAbsent(assetId, () => issue.kind);
      }
    }

    for (final _ScannedEntry scanned in entries) {
      final Map<AssetId, VaultRepairIssueKind> removeKinds =
          <AssetId, VaultRepairIssueKind>{};
      for (final AssetId id in scanned.entry.attachmentIds) {
        final VaultRepairIssueKind? kind = brokenKinds[id];
        if (recoveredAssetIds.contains(id) ||
            scanned.attachmentPaths.containsKey(id)) {
          continue;
        }
        if (kind != null) {
          removeKinds[id] = kind;
        } else {
          removeKinds[id] = VaultRepairIssueKind.missingAsset;
        }
      }
      if (removeKinds.isEmpty) continue;
      final List<AssetId> nextIds = <AssetId>[
        for (final AssetId id in scanned.entry.attachmentIds)
          if (!removeKinds.containsKey(id)) id,
      ];
      try {
        final bool rewritten = await _rewriteScannedEntryAttachments(
          session: session,
          metadata: metadata,
          scanned: scanned,
          nextAttachmentIds: nextIds,
          removeAttachmentIds: removeKinds.keys.toSet(),
        );
        for (final MapEntry<AssetId, VaultRepairIssueKind> removed
            in removeKinds.entries) {
          results.add(
            VaultFinding(
              kind: removed.value,
              plannedAction: VaultPlannedAction.removeReference,
              manualAction: rewritten
                  ? VaultManualAction.none
                  : VaultManualAction.openAndReuploadAttachment,
              canOpenEntry: true,
              entryId: scanned.entry.id,
              entryTitle: scanned.entry.normalizedTitle,
              entryDate: scanned.entry.date,
              internalReference: removed.key,
              resolved: rewritten,
            ),
          );
        }
      } on Object {
        for (final MapEntry<AssetId, VaultRepairIssueKind> removed
            in removeKinds.entries) {
          results.add(
            VaultFinding(
              kind: removed.value,
              plannedAction: VaultPlannedAction.removeReference,
              manualAction: VaultManualAction.openAndReuploadAttachment,
              canOpenEntry: true,
              entryId: scanned.entry.id,
              entryTitle: scanned.entry.normalizedTitle,
              entryDate: scanned.entry.date,
              internalReference: removed.key,
            ),
          );
        }
      }
    }
    return results;
  }

  Future<bool> _rewriteScannedEntryAttachments({
    required UnlockedVaultSession session,
    required RecoveryMetadata metadata,
    required _ScannedEntry scanned,
    required List<AssetId> nextAttachmentIds,
    List<AssetAttachment> extraAttachments = const <AssetAttachment>[],
    Map<AssetId, String> extraPaths = const <AssetId, String>{},
    Set<AssetId> removeAttachmentIds = const <AssetId>{},
  }) async {
    final List<int> recoveryWrapKey = requireRecoveryWrapKey(session);
    final List<AssetAttachment> orderedAttachments = <AssetAttachment>[
      for (final AssetId id in nextAttachmentIds)
        if (extraAttachments
                .where((AssetAttachment item) => item.id == id)
                .firstOrNull
            case final AssetAttachment attachment)
          attachment
        else if (scanned.attachments
                .where((AssetAttachment item) => item.id == id)
                .firstOrNull
            case final AssetAttachment attachment)
          attachment,
    ];
    if (orderedAttachments.length != nextAttachmentIds.length) {
      // 缺完整 metadata 時仍更新 front matter 的 attachment_ids。
    }
    final DiaryEntry updated = scanned.entry.copyWith(
      attachmentIds: nextAttachmentIds,
      updatedAt: DateTime.now(),
    );
    final String markdown = _frontMatterCodec.encode(
      updated,
      attachments: orderedAttachments.isEmpty
          ? <AssetAttachment>[
              for (final AssetId id in nextAttachmentIds)
                AssetAttachment(
                  id: id,
                  entryId: updated.id,
                  mimeType: 'application/octet-stream',
                  safeFilename: '$id.bin',
                  byteSize: 0,
                  createdAt: updated.updatedAt,
                  sha256: '',
                ),
            ]
          : orderedAttachments,
    );
    final EncryptionResult encryption = await _cryptoService.encryptMarkdown(
      documentId: updated.id,
      vaultId: metadata.vaultId,
      markdown: markdown,
      recoveryWrapKey: recoveryWrapKey,
      recoverySlotKdf: metadata.kdf,
      createdAt: updated.createdAt,
      updatedAt: updated.updatedAt,
    );
    final String filePath = await _pathStrategy.entryAbsolutePath(
      date: updated.date,
      entryId: updated.id,
    );
    final Uint8List fileBytes = encryption.toFileBytes();
    await atomicWriteBytes(File(filePath), fileBytes);

    scanned.entry = updated;
    scanned.markdown = markdown;
    scanned.filePath = filePath;
    scanned.searchFields = entrySearchFields(updated);
    scanned.encryptedFileSize = fileBytes.lengthInBytes;
    scanned.encryptedModifiedAt = DateTime.now();
    scanned.attachments
      ..removeWhere(
        (AssetAttachment item) => removeAttachmentIds.contains(item.id),
      )
      ..addAll(extraAttachments);
    for (final AssetId removed in removeAttachmentIds) {
      scanned.attachmentPaths.remove(removed);
    }
    scanned.attachmentPaths.addAll(extraPaths);
    return true;
  }

  Future<bool> _storeInspectSummary(VaultInspectReport report) async {
    final VaultInspectSummary summary = VaultInspectSummary.fromReport(report);
    try {
      await _indexDatabaseManager.requireOpen().setAppValue(
        _kLastInspectSummaryKey,
        jsonEncode(summary.toJson()),
      );
      return true;
    } on Object {
      return false;
    }
  }

  Future<bool> _storeRepairSummary(VaultRepairReport report) async {
    final VaultRepairSummary summary = VaultRepairSummary.fromReport(report);
    try {
      await _indexDatabaseManager.requireOpen().setAppValue(
        _kLastRepairSummaryKey,
        jsonEncode(summary.toJson()),
      );
      return true;
    } on Object {
      return false;
    }
  }
}
