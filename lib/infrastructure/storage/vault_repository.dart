import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:ui';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../domain/attachment/asset_attachment.dart';
import '../../domain/diary/diary_entry.dart';
import '../../domain/people/person.dart';
import '../../domain/people/person_name_matcher.dart';
import '../../domain/recovery/kdf_descriptor.dart';
import '../../domain/recovery/recovery_metadata.dart';
import '../../domain/security/unlocked_vault_session.dart';
import '../../domain/shared/value_objects.dart';
import '../crypto/crypto_service.dart';
import '../database/index_database.dart';
import '../database/index_database_manager.dart';
import '../markdown/front_matter_codec.dart';
import '../markdown/visible_text_from_markdown.dart';
import '../security/app_lock_service.dart';
import '../security/app_unlock_mode.dart';
import '../security/device_key_manager.dart';
import '../security/keystore_unlock_policy.dart';
import '../security/unlock_mode_policy.dart';
import 'restore_precheck.dart';
import 'people_store.dart';
import 'pinned_entries_store.dart';
import 'tag_styles_store.dart';
import 'shared/media_type_utils.dart';
import 'shared/vault_file_ops.dart';
import 'vault_path_strategy.dart';
import 'vault_repair_file_operations.dart';
import 'vault_state_keys.dart';

const String _kLastRepairSummaryKey = 'last_repair_summary';
final RegExp _strictIsoDateTimePattern = RegExp(
  r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.(\d{1,6}))?(?:(Z)|([+-])(\d{2}):(\d{2}))?$',
);

/// UI 中已選取但尚未寫入加密 vault 的附件。
class PendingAttachment {
  PendingAttachment({
    required this.assetId,
    this.bytes,
    this.sourcePath,
    this.pendingRelativePath,
    required this.mimeType,
    required this.originalFilename,
  }) : assert(
         (bytes != null && bytes.isNotEmpty) ||
             (sourcePath != null && sourcePath.trim().isNotEmpty),
         'PendingAttachment 需要 bytes 或 sourcePath',
       );

  final AssetId assetId;

  /// 內嵌或已讀入記憶體的附件（例如 HTML 資料 URI）。
  final Uint8List? bytes;

  /// 暫時明文路徑（materialize 後供預覽與正式儲存讀取）。
  final String? sourcePath;

  /// 加密 pending 附件在草稿目錄下的相對路徑（例如 `pending/*.enc`）。
  final String? pendingRelativePath;
  final String mimeType;
  final String originalFilename;
}

/// 同流程建立新 Recovery Key 並完成可信裝置存取時回傳的結果。
class RecoverySetupResult {
  const RecoverySetupResult({required this.recoveryKey, required this.session});

  final String recoveryKey;
  final UnlockedVaultSession session;
}

enum VaultRepairIssueKind {
  invalidEntryMetadata,
  unreadableEntry,
  entryIdentityMismatch,
  conflictingEntry,
  missingAsset,
  unreadableAsset,
  assetIdentityMismatch,
  conflictingAsset,
  unverifiedOrphanAsset,
  cleanupFailure,
}

enum VaultRepairPhase {
  scanningEntries,
  checkingAttachments,
  rebuildingIndex,
  rebuildingPeopleAnalytics,
  cleaning,
}

typedef VaultRepairProgressCallback = void Function(VaultRepairPhase phase);

class VaultRepairIssue {
  const VaultRepairIssue({required this.kind, required this.reference});

  final VaultRepairIssueKind kind;
  final String reference;
}

class VaultRepairReport {
  const VaultRepairReport({
    required this.entryCount,
    required this.duration,
    required this.finishedAt,
    required this.relocatedEntries,
    required this.removedDuplicateEntries,
    required this.tagsAdded,
    required this.relocatedAssets,
    required this.removedOrphanAssets,
    this.issues = const <VaultRepairIssue>[],
  });

  final int entryCount;
  final Duration duration;
  final DateTime finishedAt;
  final int relocatedEntries;
  final int removedDuplicateEntries;
  final int tagsAdded;
  final int relocatedAssets;
  final int removedOrphanAssets;
  final List<VaultRepairIssue> issues;

  bool get hasUnresolvedIssues => issues.isNotEmpty;

  int issueCount(VaultRepairIssueKind kind) =>
      issues.where((VaultRepairIssue issue) => issue.kind == kind).length;
}

class VaultRepairSummary {
  const VaultRepairSummary({
    required this.entryCount,
    required this.finishedAt,
    required this.issueCounts,
    this.relocatedEntries = 0,
    this.removedDuplicateEntries = 0,
    this.tagsAdded = 0,
    this.relocatedAssets = 0,
    this.removedOrphanAssets = 0,
  });

  final int entryCount;
  final DateTime finishedAt;
  final Map<VaultRepairIssueKind, int> issueCounts;
  final int relocatedEntries;
  final int removedDuplicateEntries;
  final int tagsAdded;
  final int relocatedAssets;
  final int removedOrphanAssets;

  bool get hasUnresolvedIssues =>
      issueCounts.values.any((int count) => count > 0);

  factory VaultRepairSummary.fromReport(VaultRepairReport report) {
    final Map<VaultRepairIssueKind, int> counts = <VaultRepairIssueKind, int>{};
    for (final VaultRepairIssue issue in report.issues) {
      counts.update(issue.kind, (int value) => value + 1, ifAbsent: () => 1);
    }
    return VaultRepairSummary(
      entryCount: report.entryCount,
      finishedAt: report.finishedAt,
      issueCounts: counts,
      relocatedEntries: report.relocatedEntries,
      removedDuplicateEntries: report.removedDuplicateEntries,
      tagsAdded: report.tagsAdded,
      relocatedAssets: report.relocatedAssets,
      removedOrphanAssets: report.removedOrphanAssets,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'entry_count': entryCount,
    'finished_at': finishedAt.toIso8601String(),
    'relocated_entries': relocatedEntries,
    'removed_duplicate_entries': removedDuplicateEntries,
    'tags_added': tagsAdded,
    'relocated_assets': relocatedAssets,
    'removed_orphan_assets': removedOrphanAssets,
    'issue_counts': <String, int>{
      for (final MapEntry<VaultRepairIssueKind, int> item
          in issueCounts.entries)
        item.key.name: item.value,
    },
  };

  static VaultRepairSummary? fromJson(Map<String, Object?> json) {
    final DateTime? finishedAt = DateTime.tryParse(
      '${json['finished_at'] ?? ''}',
    );
    final Object? rawCounts = json['issue_counts'];
    if (finishedAt == null || rawCounts is! Map<Object?, Object?>) return null;
    final Map<VaultRepairIssueKind, int> counts = <VaultRepairIssueKind, int>{};
    for (final MapEntry<Object?, Object?> item in rawCounts.entries) {
      final VaultRepairIssueKind? kind = VaultRepairIssueKind.values
          .where((VaultRepairIssueKind value) => value.name == '${item.key}')
          .firstOrNull;
      final int? count = int.tryParse('${item.value}');
      if (kind != null && count != null && count >= 0) counts[kind] = count;
    }
    return VaultRepairSummary(
      entryCount: int.tryParse('${json['entry_count'] ?? 0}') ?? 0,
      finishedAt: finishedAt,
      issueCounts: counts,
      relocatedEntries: int.tryParse('${json['relocated_entries'] ?? 0}') ?? 0,
      removedDuplicateEntries:
          int.tryParse('${json['removed_duplicate_entries'] ?? 0}') ?? 0,
      tagsAdded: int.tryParse('${json['tags_added'] ?? 0}') ?? 0,
      relocatedAssets: int.tryParse('${json['relocated_assets'] ?? 0}') ?? 0,
      removedOrphanAssets:
          int.tryParse('${json['removed_orphan_assets'] ?? 0}') ?? 0,
    );
  }
}

class _EntrySearchFields {
  const _EntrySearchFields({
    required this.previewText,
    required this.previewMarkdown,
    required this.titleSearchText,
    required this.bodySearchText,
    required this.bodyVisibleText,
  });

  final String previewText;
  final String previewMarkdown;
  final String titleSearchText;
  final String bodySearchText;
  final String bodyVisibleText;
}

final class _PeopleAnalyticsCancelled implements Exception {
  const _PeopleAnalyticsCancelled();
}

void _peopleAnalysisWorkerMain(SendPort readyPort) {
  PersonNameMatcher? matcher;
  final ReceivePort requests = ReceivePort();
  readyPort.send(requests.sendPort);
  requests.listen((Object? message) {
    if (message == null) {
      requests.close();
      Isolate.exit();
    }
    final List<Object?> request = (message as List).cast<Object?>();
    final SendPort replyPort = request[0]! as SendPort;
    try {
      final String operation = request[1]! as String;
      if (operation == 'configure') {
        final List<Map<String, Object?>> serializedPeople =
            (request[2]! as List).cast<Map<String, Object?>>();
        matcher = PersonNameMatcher(<Person>[
          for (final Map<String, Object?> raw in serializedPeople)
            if (Person.fromJson(raw) case final Person person) person,
        ]);
        replyPort.send(<Object?>['ok', true]);
        return;
      }
      final List<Map<String, String>> documents = (request[2]! as List)
          .cast<Map<String, String>>();
      if (operation == 'visible') {
        replyPort.send(<Object?>[
          'ok',
          <String, String>{
            for (final Map<String, String> document in documents)
              document['id']!: EntryIndexText.fromMarkdown(
                const FrontMatterCodec()
                    .decode(document['markdown'] ?? '')
                    .markdownBody,
              ).visibleText,
          },
        ]);
        return;
      }
      final PersonNameMatcher configuredMatcher =
          matcher ?? (throw StateError('人物姓名 matcher 尚未初始化。'));
      replyPort.send(<Object?>[
        'ok',
        <String, List<String>>{
          for (final Map<String, String> document in documents)
            document['id']!: configuredMatcher
                .matchTitleAndBody(
                  title: document['title'] ?? '',
                  body: document['body'] ?? '',
                )
                .toList(growable: false),
        },
      ]);
    } on Object catch (error) {
      replyPort.send(<Object?>['error', error.toString()]);
    }
  });
}

final class _PeopleAnalysisWorker {
  _PeopleAnalysisWorker._(this._isolate, this._sendPort);

  final Isolate _isolate;
  final SendPort _sendPort;
  bool _closed = false;
  ReceivePort? _pendingReply;
  Completer<Object?>? _pendingCompleter;

  static Future<_PeopleAnalysisWorker> start() async {
    final ReceivePort ready = ReceivePort();
    final Isolate isolate = await Isolate.spawn(
      _peopleAnalysisWorkerMain,
      ready.sendPort,
    );
    final SendPort sendPort = await ready.first as SendPort;
    ready.close();
    return _PeopleAnalysisWorker._(isolate, sendPort);
  }

  Future<void> configurePeople(List<Person> people) async {
    final Object? result = await _request(<Object?>[
      'configure',
      people.map((Person person) => person.toJson()).toList(growable: false),
    ]);
    if (result != true) {
      throw StateError('人物姓名 matcher 初始化失敗。');
    }
  }

  Future<Map<String, String>> extractVisibleText(
    Map<String, String> markdownByEntryId,
  ) async {
    final Object? result = await _request(<Object?>[
      'visible',
      <Map<String, String>>[
        for (final MapEntry<String, String> entry in markdownByEntryId.entries)
          <String, String>{'id': entry.key, 'markdown': entry.value},
      ],
    ]);
    return (result! as Map).cast<String, String>();
  }

  Future<Map<String, List<String>>> match(
    List<PeopleAnalysisSourceDocument> documents,
  ) async {
    final Object? result = await _request(<Object?>[
      'match',
      <Map<String, String>>[
        for (final PeopleAnalysisSourceDocument document in documents)
          <String, String>{
            'id': document.entryId,
            'title': document.titleText,
            'body': document.bodyVisibleText,
          },
      ],
    ]);
    return (result! as Map).cast<String, List<String>>();
  }

  Future<Object?> _request(List<Object?> payload) async {
    if (_closed) {
      throw StateError('人物分析 worker 已關閉。');
    }
    final ReceivePort reply = ReceivePort();
    final Completer<Object?> completer = Completer<Object?>();
    _pendingReply = reply;
    _pendingCompleter = completer;
    reply.listen((Object? message) {
      if (!completer.isCompleted) {
        final List<Object?> envelope = (message! as List).cast<Object?>();
        if (envelope.first == 'ok') {
          completer.complete(envelope[1]);
        } else {
          completer.completeError(StateError(envelope[1]! as String));
        }
      }
      reply.close();
      if (identical(_pendingReply, reply)) {
        _pendingReply = null;
        _pendingCompleter = null;
      }
    });
    _sendPort.send(<Object?>[reply.sendPort, ...payload]);
    return completer.future;
  }

  void close() {
    if (_closed) {
      return;
    }
    _closed = true;
    final Completer<Object?>? pending = _pendingCompleter;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(const _PeopleAnalyticsCancelled());
    }
    _pendingReply?.close();
    _pendingReply = null;
    _pendingCompleter = null;
    _sendPort.send(null);
    _isolate.kill(priority: Isolate.immediate);
  }
}

enum PeopleAnalyticsProgressState { idle, analyzing, ready }

enum PeopleAnalyticsProgressPhase { preparingIndex, analyzingMentions }

final class PeopleAnalyticsProgress {
  const PeopleAnalyticsProgress({
    required this.state,
    this.phase = PeopleAnalyticsProgressPhase.analyzingMentions,
    this.processedDocuments = 0,
    this.totalDocuments = 0,
  });

  const PeopleAnalyticsProgress.idle()
    : this(state: PeopleAnalyticsProgressState.idle);

  final PeopleAnalyticsProgressState state;
  final PeopleAnalyticsProgressPhase phase;
  final int processedDocuments;
  final int totalDocuments;
}

@visibleForTesting
final class PeopleAnalyticsDebugMetrics {
  const PeopleAnalyticsDebugMetrics({
    required this.scannedDocuments,
    required this.batchWrites,
    required this.workerStarts,
  });

  final int scannedDocuments;
  final int batchWrites;
  final int workerStarts;
}

final class _PeopleAnalyticsJob {
  _PeopleAnalyticsJob(this.vaultId);

  final VaultId vaultId;
  bool cancelled = false;
  bool matcherConfigured = false;
  _PeopleAnalysisWorker? worker;

  void cancel() {
    cancelled = true;
    worker?.close();
    worker = null;
  }
}

class _ScannedEntry {
  const _ScannedEntry({
    required this.entry,
    required this.filePath,
    required this.markdown,
    required this.attachments,
    required this.attachmentPaths,
    required this.searchFields,
    required this.encryptedFileSize,
    required this.encryptedModifiedAt,
  });

  final DiaryEntry entry;
  final String filePath;
  final String markdown;
  final List<AssetAttachment> attachments;
  final Map<AssetId, String> attachmentPaths;
  final _EntrySearchFields searchFields;
  final int encryptedFileSize;
  final DateTime encryptedModifiedAt;
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
  final _EntrySearchFields searchFields;
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
  });

  final String path;
  final String fileId;
  final String contentType;
  final String plaintextHash;
  final bool isAttachment;
  final bool countsAsDuplicateEntry;
  final bool countsAsOrphanAsset;
}

class _EntryRepairStats {
  const _EntryRepairStats({
    required this.scanned,
    required this.relocatedEntries,
    required this.issues,
    required this.cleanupTargets,
    required this.assetReferences,
  });

  final List<_ScannedEntry> scanned;
  final int relocatedEntries;
  final List<VaultRepairIssue> issues;
  final Map<String, _RepairCleanupTarget> cleanupTargets;
  final Map<AssetId, List<_AssetReference>> assetReferences;
}

class _AssetRepairStats {
  const _AssetRepairStats({
    required this.relocatedAssets,
    required this.issues,
    required this.cleanupTargets,
  });

  final int relocatedAssets;
  final List<VaultRepairIssue> issues;
  final Map<String, _RepairCleanupTarget> cleanupTargets;
}

/// 加密 vault 儲存的主要協調層。
///
/// 此儲存庫負責 Recovery Key 建立／解鎖、可信裝置 session 還原、
/// 加密條目／附件 I/O 與索引同步。
class VaultRepository {
  VaultRepository({
    required VaultPathStrategy pathStrategy,
    required FrontMatterCodec frontMatterCodec,
    required CryptoService cryptoService,
    required IndexDatabaseManager indexDatabaseManager,
    required DeviceKeyManager deviceKeyManager,
    required AppLockService appLockService,
    VaultRepairFileOperations repairFileOperations =
        const VaultRepairFileOperations(),
  }) : _pathStrategy = pathStrategy,
       _frontMatterCodec = frontMatterCodec,
       _cryptoService = cryptoService,
       _indexDatabaseManager = indexDatabaseManager,
       _deviceKeyManager = deviceKeyManager,
       _appLockService = appLockService,
       _repairFileOperations = repairFileOperations;

  final VaultPathStrategy _pathStrategy;
  final FrontMatterCodec _frontMatterCodec;
  final CryptoService _cryptoService;
  final IndexDatabaseManager _indexDatabaseManager;
  final DeviceKeyManager _deviceKeyManager;
  final AppLockService _appLockService;
  final VaultRepairFileOperations _repairFileOperations;
  Future<void> _mutationTail = Future<void>.value();

  RecoveryMetadata? _cachedRecoveryMetadata;

  /// 解鎖後首次讀取名冊才填入；避免解鎖熱路徑解密。
  List<Person>? _peopleCatalogCache;
  VaultId? _peopleCatalogVaultId;
  Future<void>? _peopleAnalyticsRebuildInFlight;
  _PeopleAnalyticsJob? _peopleAnalyticsJob;
  final StreamController<PeopleAnalyticsProgress>
  _peopleAnalyticsProgressController =
      StreamController<PeopleAnalyticsProgress>.broadcast();
  int _peopleAnalysisScannedDocuments = 0;
  int _peopleAnalysisBatchWrites = 0;
  int _peopleAnalysisWorkerStarts = 0;

  Stream<PeopleAnalyticsProgress> get peopleAnalyticsProgress =>
      _peopleAnalyticsProgressController.stream;

  @visibleForTesting
  PeopleAnalyticsDebugMetrics get peopleAnalyticsDebugMetrics =>
      PeopleAnalyticsDebugMetrics(
        scannedDocuments: _peopleAnalysisScannedDocuments,
        batchWrites: _peopleAnalysisBatchWrites,
        workerStarts: _peopleAnalysisWorkerStarts,
      );

  Future<void> initialize() async {
    await _pathStrategy.ensureBaseDirectories();
    _cachedRecoveryMetadata = await readRecoveryMetadata();
  }

  Future<bool> hasTrustedDeviceAccess() async {
    final RecoveryMetadata? metadata = await readRecoveryMetadata();
    if (metadata == null) {
      return false;
    }
    return _deviceKeyManager.hasTrustedKey(metadata.vaultId);
  }

  Future<bool> hasVault() async {
    return await readRecoveryMetadata() != null;
  }

  Future<UnlockedVaultSession> openTrustedSession() async {
    final RecoveryMetadata metadata =
        await readRecoveryMetadata() ?? (throw StateError('尚未建立復原金鑰。'));
    if (!await _deviceKeyManager.hasTrustedKey(metadata.vaultId)) {
      throw StateError('這台裝置尚未註冊，請使用復原金鑰解鎖。');
    }

    final WrappedRecoveryKeyRecord record =
        await _deviceKeyManager.readWrappedRecoveryKey(metadata.vaultId) ??
        (throw StateError('找不到可信裝置的 Recovery 金鑰資料。'));
    final TrustedDeviceInfo deviceInfo =
        await _deviceKeyManager.readDeviceInfo(metadata.vaultId) ??
        (throw StateError('找不到可信裝置資訊。'));
    if (record.slotId != deviceInfo.slotId) {
      await _deviceKeyManager.clearTrustedKey(metadata.vaultId);
      throw StateError('可信裝置資料不一致，請使用復原金鑰重新建立。');
    }

    final List<int> recoveryWrapKey;
    try {
      recoveryWrapKey = await _deviceKeyManager.unwrapWithDeviceKey(
        vaultId: metadata.vaultId,
        slotId: record.slotId,
        nonceBase64: record.nonceBase64,
        ciphertextBase64: record.ciphertextBase64,
      );
    } on DeviceKeyException {
      rethrow;
    } on Object catch (_, stackTrace) {
      await _deviceKeyManager.clearTrustedKey(metadata.vaultId);
      Error.throwWithStackTrace(
        StateError('可信裝置資料已失效，請重新使用復原金鑰解鎖。'),
        stackTrace,
      );
    }

    await _verifyRecoveryKey(metadata, recoveryWrapKey);

    return _openVerifiedTrustedSession(
      metadata: metadata,
      recoveryWrapKey: recoveryWrapKey,
      trustedDevice: true,
      deviceSlotId: deviceInfo.slotId,
    );
  }

  /// 在 unwrap 前比對 Keystore 與解鎖模式是否一致（不需 [UnlockedVaultSession]）。
  Future<bool> needsKeystoreMigrationForVault() async {
    final RecoveryMetadata? metadata = await readRecoveryMetadata();
    if (metadata == null) {
      return false;
    }
    final WrappedRecoveryKeyRecord? wrappedRecord = await _deviceKeyManager
        .readWrappedRecoveryKey(metadata.vaultId);
    if (wrappedRecord == null) {
      return true;
    }
    final KeystoreAuthKind expected = await _requireCurrentKeystoreAuthKind();
    final UnlockedVaultSession probe = UnlockedVaultSession(
      vaultId: metadata.vaultId,
      trustedDevice: true,
      recoveryWrapKey: const <int>[],
      deviceSlotId: wrappedRecord.slotId,
    );
    String? syncedSuffix;
    try {
      syncedSuffix = await _requireOpenIndex().getAppValue(
        kKeystoreWrapModeKey,
      );
    } on StateError {
      return !keystoreSlotsMatchExpected(
        session: probe,
        expected: expected,
        wrappedRecord: wrappedRecord,
      );
    }
    return !trustedProtectionMatches(
      session: probe,
      expected: expected,
      syncedSuffix: syncedSuffix,
      wrappedRecord: wrappedRecord,
    );
  }

  /// 可信裝置解鎖並同步 Keystore、準備索引。
  Future<UnlockedVaultSession> openTrustedSessionEnsuringKeystore() async {
    final RecoveryMetadata metadata =
        await readRecoveryMetadata() ?? (throw StateError('尚未建立復原金鑰。'));
    final WrappedRecoveryKeyRecord record =
        await _deviceKeyManager.readWrappedRecoveryKey(metadata.vaultId) ??
        (throw StateError('找不到可信裝置的 Recovery 金鑰資料。'));
    final KeystoreAuthKind expected = await _requireCurrentKeystoreAuthKind();
    final UnlockedVaultSession probe = UnlockedVaultSession(
      vaultId: metadata.vaultId,
      trustedDevice: true,
      recoveryWrapKey: const <int>[],
      deviceSlotId: record.slotId,
    );

    final UnlockedVaultSession session;
    if (keystoreSlotsMatchExpected(
      session: probe,
      expected: expected,
      wrappedRecord: record,
    )) {
      session = await openTrustedSession();
      await ensureKeystoreMatchesUnlockMode(session);
    } else {
      session = await _openTrustedSessionViaRewrap(
        metadata: metadata,
        record: record,
        expected: expected,
      );
    }
    await ensureIndexReady(session);
    return session;
  }

  /// 槽位與解鎖模式不一致時，以單次原生驗證完成 unwrap + re-wrap。
  Future<UnlockedVaultSession> _openTrustedSessionViaRewrap({
    required RecoveryMetadata metadata,
    required WrappedRecoveryKeyRecord record,
    required KeystoreAuthKind expected,
  }) async {
    final RewrapTrustedRecoveryKeyResult rewrap = await _deviceKeyManager
        .rewrapTrustedRecoveryKey(
          vaultId: metadata.vaultId,
          sourceSlotId: record.slotId,
          nonceBase64: record.nonceBase64,
          ciphertextBase64: record.ciphertextBase64,
          targetAuthKind: expected,
        );
    await _deviceKeyManager.storeWrappedRecoveryKey(
      vaultId: metadata.vaultId,
      record: WrappedRecoveryKeyRecord(
        slotId: rewrap.payload.slotId,
        nonceBase64: rewrap.payload.nonceBase64,
        ciphertextBase64: rewrap.payload.ciphertextBase64,
        wrappedAt: DateTime.now(),
        formatVersion:
            WrappedRecoveryKeyRecord.kWrappedRecoveryKeyFormatVersion,
        platform: rewrap.payload.platform,
      ),
    );
    await _deviceKeyManager.purgeInactiveDeviceKeys(
      metadata.vaultId,
      activeAuthKind: expected,
    );
    await _verifyRecoveryKey(metadata, rewrap.recoveryWrapKey);
    final UnlockedVaultSession session = await _openVerifiedTrustedSession(
      metadata: metadata,
      recoveryWrapKey: rewrap.recoveryWrapKey,
      trustedDevice: true,
      deviceSlotId: rewrap.payload.slotId,
    );
    await _openIndexForSession(session);
    await _requireOpenIndex().setAppValue(
      kKeystoreWrapModeKey,
      expected.storageSuffix,
    );
    return session;
  }

  /// 還原同 vault 後沿用還原前 session 的包裝金鑰，不再觸發裝置驗證。
  Future<UnlockedVaultSession> resumeUnlockedSessionAfterRestore(
    UnlockedVaultSession priorSession,
  ) async {
    final RecoveryMetadata metadata =
        await readRecoveryMetadata() ?? (throw StateError('尚未建立復原金鑰。'));
    if (priorSession.vaultId != metadata.vaultId) {
      throw StateError('還原後的日記庫與解鎖 session 不一致，請使用復原金鑰解鎖。');
    }

    final List<int> recoveryWrapKey = _requireRecoveryWrapKey(priorSession);
    await _verifyRecoveryKey(metadata, recoveryWrapKey);

    return _openVerifiedTrustedSession(
      metadata: metadata,
      recoveryWrapKey: recoveryWrapKey,
      trustedDevice: priorSession.trustedDevice,
      deviceSlotId: priorSession.deviceSlotId,
    );
  }

  Future<UnlockedVaultSession> _openVerifiedTrustedSession({
    required RecoveryMetadata metadata,
    required List<int> recoveryWrapKey,
    required bool trustedDevice,
    DeviceSlotId? deviceSlotId,
  }) async {
    final UnlockedVaultSession session = UnlockedVaultSession(
      vaultId: metadata.vaultId,
      trustedDevice: trustedDevice,
      recoveryWrapKey: recoveryWrapKey,
      deviceSlotId: deviceSlotId,
    );
    await _openIndexForSession(session);
    try {
      await _resumeRewrapIfNeeded(session, metadata);
    } on Object catch (_, stackTrace) {
      Error.throwWithStackTrace(
        StateError('日記庫重新包裝未完成，下次啟動會自動繼續。若問題持續，請檢查加密檔是否毀損。'),
        stackTrace,
      );
    }
    return session;
  }

  /// 在從備份還原並覆寫 vault 目錄後呼叫，避免仍沿用記憶體內舊的復原中繼資料。
  void clearRecoveryMetadataCache() {
    _cachedRecoveryMetadata = null;
  }

  Future<RecoveryMetadata?> readRecoveryMetadata() async {
    if (_cachedRecoveryMetadata != null) {
      return _cachedRecoveryMetadata;
    }

    final File file = File(await _pathStrategy.recoveryMetadataPath());
    if (!file.existsSync()) {
      return null;
    }

    final Object? decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Recovery metadata 格式不正確。');
    }

    _cachedRecoveryMetadata = RecoveryMetadata.fromJson(decoded);
    return _cachedRecoveryMetadata;
  }

  Future<RecoverySetupResult> setupRecoveryKey() async {
    if (await readRecoveryMetadata() != null) {
      throw StateError('復原金鑰已存在。');
    }

    final String recoveryKey = _generateRecoveryKey();
    final KdfDescriptor recoveryKdf = KdfDescriptor.argon2idRecovery(
      saltBytes: List<int>.generate(16, (_) => Random.secure().nextInt(256)),
    );
    final List<int> recoveryWrapKey = await _cryptoService
        .deriveRecoveryWrapKey(recoveryKey: recoveryKey, kdf: recoveryKdf);

    final RecoveryMetadata metadata = RecoveryMetadata(
      vaultId: generateVaultId(),
      recoveryEnabled: true,
      recoveryKeyVersion: 1,
      recoveryKeyHint: recoveryKey.substring(recoveryKey.length - 4),
      createdAt: DateTime.now(),
      kdf: recoveryKdf,
    );

    final KeystoreAuthKind authKind = await _requireCurrentKeystoreAuthKind();
    final TrustedDeviceInfo deviceInfo = await _deviceKeyManager
        .ensureDeviceKey(metadata.vaultId, authKind: authKind);

    final File file = File(await _pathStrategy.recoveryMetadataPath());
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(metadata.toJson()),
      flush: true,
    );
    _cachedRecoveryMetadata = metadata;

    await _storeWrappedRecoveryKey(
      vaultId: metadata.vaultId,
      recoveryWrapKey: recoveryWrapKey,
      authKind: authKind,
    );

    final UnlockedVaultSession session = UnlockedVaultSession(
      vaultId: metadata.vaultId,
      trustedDevice: true,
      recoveryWrapKey: recoveryWrapKey,
      deviceSlotId: deviceInfo.slotId,
    );
    await _openIndexForSession(session);
    await _writeEncryptedManifest(session, metadata);
    await _requireOpenIndex().setAppValue(
      kKeystoreWrapModeKey,
      authKind.storageSuffix,
    );

    return RecoverySetupResult(recoveryKey: recoveryKey, session: session);
  }

  /// 輪替復原金鑰：先重加密 vault，最後才更新 [recovery.json]。
  Future<RecoverySetupResult> rotateRecoveryKey(
    UnlockedVaultSession session,
  ) async {
    final RecoveryMetadata oldMetadata = await _requireMetadataForSession(
      session,
    );
    final List<int> oldWrapKey = _requireRecoveryWrapKey(session);
    final KeystoreAuthKind authKind = await _requireCurrentKeystoreAuthKind();

    await _openIndexForSession(session);
    await _setRewrapState(inProgress: true);
    try {
      final String recoveryKey = _generateRecoveryKey();
      final KdfDescriptor newKdf = KdfDescriptor.argon2idRecovery(
        saltBytes: List<int>.generate(16, (_) => Random.secure().nextInt(256)),
      );
      final List<int> newWrapKey = await _cryptoService.deriveRecoveryWrapKey(
        recoveryKey: recoveryKey,
        kdf: newKdf,
      );
      final RecoveryMetadata newMetadata = RecoveryMetadata(
        vaultId: oldMetadata.vaultId,
        recoveryEnabled: true,
        recoveryKeyVersion: oldMetadata.recoveryKeyVersion,
        recoveryKeyHint: recoveryKey.substring(recoveryKey.length - 4),
        createdAt: DateTime.now(),
        kdf: newKdf,
      );

      await _rewrapVaultRecoveryKey(
        vaultId: session.vaultId,
        oldRecoveryWrapKey: oldWrapKey,
        newRecoveryWrapKey: newWrapKey,
        newMetadata: newMetadata,
      );

      final File file = File(await _pathStrategy.recoveryMetadataPath());
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(newMetadata.toJson()),
        flush: true,
      );
      _cachedRecoveryMetadata = newMetadata;

      UnlockedVaultSession updatedSession = session.copyWith(
        recoveryWrapKey: newWrapKey,
      );
      await _storeWrappedRecoveryKey(
        vaultId: oldMetadata.vaultId,
        recoveryWrapKey: newWrapKey,
        authKind: authKind,
      );
      updatedSession = await ensureKeystoreMatchesUnlockMode(updatedSession);
      await rebuildIndex(updatedSession);
      await _setRewrapState(inProgress: false);

      return RecoverySetupResult(
        recoveryKey: recoveryKey,
        session: updatedSession,
      );
    } catch (_, stackTrace) {
      Error.throwWithStackTrace(
        StateError('復原金鑰輪替失敗，已保留進行中旗標以便下次自動續跑。'),
        stackTrace,
      );
    }
  }

  /// 還原前驗證復原金鑰能否解密備份內的加密檔（不寫入本機 vault）。
  Future<void> verifyRecoveryKeyAgainstBackupBytes({
    required RecoveryMetadata metadata,
    required String recoveryKey,
    required List<int> encryptedDocumentBytes,
  }) async {
    final List<int> recoveryWrapKey = await _cryptoService
        .deriveRecoveryWrapKey(recoveryKey: recoveryKey, kdf: metadata.kdf);
    final ParsedEncryptedDocument parsed = _cryptoService.parseFileBytes(
      encryptedDocumentBytes,
    );
    try {
      await _cryptoService.decryptBytes(
        headerBytes: parsed.headerBytes,
        ciphertextBytes: parsed.ciphertextBytes,
        context: DecryptionContext.recovery(
          recoveryWrapKey: recoveryWrapKey,
          vaultId: metadata.vaultId,
        ),
      );
    } on SecretBoxAuthenticationError {
      throw StateError(kBackupRecoveryKeyMismatchMessage);
    }
  }

  Future<UnlockedVaultSession> unlockWithRecoveryKey(String recoveryKey) async {
    final RecoveryMetadata metadata =
        await readRecoveryMetadata() ??
        (throw StateError('找不到 Recovery metadata。'));
    final List<int> recoveryWrapKey = await _cryptoService
        .deriveRecoveryWrapKey(recoveryKey: recoveryKey, kdf: metadata.kdf);
    await _verifyRecoveryKey(metadata, recoveryWrapKey);

    final AppUnlockMode unlockMode = await _appLockService.getUnlockMode();
    final UnlockModeCapabilityFailure? wrapFailure =
        await precheckUnlockModeChange(
          appLock: _appLockService,
          mode: unlockMode,
        );
    if (wrapFailure != null) {
      throw StateError(wrapFailure.message);
    }
    final KeystoreAuthKind authKind = keystoreAuthFor(unlockMode);
    final TrustedDeviceInfo deviceInfo = await _deviceKeyManager
        .ensureDeviceKey(metadata.vaultId, authKind: authKind);

    final UnlockedVaultSession session = UnlockedVaultSession(
      vaultId: metadata.vaultId,
      trustedDevice: true,
      recoveryWrapKey: recoveryWrapKey,
      deviceSlotId: deviceInfo.slotId,
    );

    await _openIndexForSession(session);
    await _setRewrapState(inProgress: true);
    try {
      await _rewrapVaultForTrustedDevice(session, metadata);
    } on Object catch (_, stackTrace) {
      Error.throwWithStackTrace(
        StateError('日記庫重新包裝失敗，已保留進行中旗標以便下次自動續跑。'),
        stackTrace,
      );
    }

    await _storeWrappedRecoveryKey(
      vaultId: metadata.vaultId,
      recoveryWrapKey: recoveryWrapKey,
      authKind: authKind,
    );
    await _requireOpenIndex().setAppValue(
      kKeystoreWrapModeKey,
      authKind.storageSuffix,
    );
    await rebuildIndex(session);
    await _setRewrapState(inProgress: false);
    return session;
  }

  Future<List<EntryIndexRecord>> listEntries({
    String? searchQuery,
    DateOnly? date,
  }) {
    return _requireOpenIndex().listEntries(
      searchQuery: searchQuery,
      date: date,
    );
  }

  Future<List<EntryIndexRecord>> listEntriesForMonth(DateTime month) {
    return _requireOpenIndex().listEntriesForMonth(month);
  }

  Future<List<EntryIndexRecord>> listEntriesForDateRange({
    required DateOnly firstDate,
    required DateOnly lastDate,
  }) {
    return _requireOpenIndex().listEntriesForDateRange(
      firstDate: firstDate,
      lastDate: lastDate,
    );
  }

  Future<({DateOnly earliest, DateOnly latest})?> entryDateBounds() {
    return _requireOpenIndex().entryDateBounds();
  }

  Future<DiaryEntry?> loadEntry(
    UnlockedVaultSession session,
    EntryId entryId,
  ) async {
    final EntryIndexRecord? indexRecord = await _requireOpenIndex()
        .getEntryById(entryId);
    if (indexRecord == null) {
      return null;
    }

    final File file = File(indexRecord.filePath);
    if (!file.existsSync()) {
      return null;
    }

    final ParsedEncryptedDocument parsed = _cryptoService.parseFileBytes(
      await file.readAsBytes(),
    );
    final String markdown = await _cryptoService.decryptMarkdown(
      headerBytes: parsed.headerBytes,
      ciphertextBytes: parsed.ciphertextBytes,
      context: _decryptionContext(session),
    );
    final DiaryEntry entry = _frontMatterCodec
        .decode(markdown)
        .copyWith(vaultId: indexRecord.vaultId);
    return _entryWithIndexedAttachmentIds(entry);
  }

  Future<DiaryEntry> _entryWithIndexedAttachmentIds(DiaryEntry entry) async {
    final List<AssetAttachment> attachments = await _requireOpenIndex()
        .attachmentsForEntry(entry.id);
    if (attachments.isEmpty) {
      return entry;
    }

    final List<AssetId> indexedIds = attachments
        .map((AssetAttachment attachment) => attachment.id)
        .toList(growable: false);
    if (_sameStringLists(entry.attachmentIds, indexedIds)) {
      return entry;
    }

    return entry.copyWith(attachmentIds: indexedIds);
  }

  Future<List<AssetAttachment>> loadAttachments(EntryId entryId) {
    return _requireOpenIndex().attachmentsForEntry(entryId);
  }

  Future<List<TagCatalogItem>> listTagCatalog() {
    return TagStylesStore(_pathStrategy).read();
  }

  Future<Set<EntryId>> listPinnedEntryIds() {
    return PinnedEntriesStore(_pathStrategy).readIds();
  }

  Future<void> setEntriesPinned(
    Iterable<EntryId> entryIds, {
    required bool pinned,
  }) {
    return PinnedEntriesStore(
      _pathStrategy,
    ).setPinnedMany(entryIds, pinned: pinned);
  }

  Future<void> _prunePinnedEntriesToExisting(Iterable<EntryId> existingIds) {
    return PinnedEntriesStore(_pathStrategy).pruneTo(existingIds);
  }

  Future<void> upsertTagCatalogItem(
    String label, {
    int? accentArgb,
    bool? accentIsCustom,
  }) async {
    final String displayLabel = label.trim().replaceAll(RegExp(r'\s+'), ' ');
    final String normalized = normalizeText(displayLabel);
    if (normalized.isEmpty) {
      throw ArgumentError.value(label, 'label', '標籤名稱不可為空白');
    }

    final List<TagCatalogItem> catalog = await listTagCatalog();
    final List<TagCatalogItem> merged =
        TagStylesStore.merge(catalog, <TagCatalogItem>[
          TagCatalogItem(
            label: displayLabel,
            accentArgb: accentArgb,
            accentIsCustom: accentIsCustom,
          ),
        ]);
    await _persistTagCatalogToVault(merged);
    final TagCatalogItem saved = merged.firstWhere(
      (TagCatalogItem item) => item.normalized == normalized,
    );
    if (saved.accentArgb != null) {
      await _requireOpenIndex().upsertTagAccentArgb(
        saved.label,
        saved.accentArgb!,
      );
    }
  }

  Future<void> ensureTagCatalogLabels(Iterable<String> labels) async {
    final Set<String> seenNormalized = <String>{};
    final List<TagCatalogItem> overlay = <TagCatalogItem>[];
    for (final String raw in labels) {
      final String displayLabel = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
      final String normalized = normalizeText(displayLabel);
      if (normalized.isEmpty || !seenNormalized.add(normalized)) {
        continue;
      }
      overlay.add(TagCatalogItem(label: displayLabel));
    }
    if (overlay.isEmpty) {
      return;
    }
    final List<TagCatalogItem> catalog = await listTagCatalog();
    await _persistTagCatalogToVault(TagStylesStore.merge(catalog, overlay));
  }

  Future<void> deleteTagCatalogItem(String label) async {
    final String normalized = normalizeText(label);
    if (normalized.isEmpty) {
      return;
    }
    final List<TagCatalogItem> catalog = await listTagCatalog();
    final List<TagCatalogItem> next = catalog
        .where((TagCatalogItem item) => item.normalized != normalized)
        .toList(growable: false);
    await _persistTagCatalogToVault(next);
    await _requireOpenIndex().deleteTagAccentArgb(label);
  }

  Future<void> upsertTagAccentArgb(
    String tag,
    int accentArgb, {
    bool? accentIsCustom,
  }) async {
    await upsertTagCatalogItem(
      tag,
      accentArgb: accentArgb,
      accentIsCustom: accentIsCustom,
    );
  }

  Future<void> deleteTagAccentArgb(String tag) async {
    await deleteTagCatalogItem(tag);
  }

  /// 重新命名標籤並同步更新 catalog、索引與所有日記條目。
  /// 若 [toLabel] 的正規化鍵已存在，會合併到該標籤。
  Future<int> renameTagCatalogItem(
    UnlockedVaultSession session, {
    required String fromLabel,
    required String toLabel,
    int? accentArgb,
    bool? accentIsCustom,
  }) async {
    final String fromDisplay = fromLabel.trim().replaceAll(RegExp(r'\s+'), ' ');
    final String toDisplay = toLabel.trim().replaceAll(RegExp(r'\s+'), ' ');
    final String fromNorm = normalizeText(fromDisplay);
    final String toNorm = normalizeText(toDisplay);
    if (fromNorm.isEmpty || toNorm.isEmpty) {
      throw ArgumentError.value(toLabel, 'toLabel', '標籤名稱不可為空白');
    }

    final List<TagCatalogItem> catalog = await listTagCatalog();
    int? resolvedAccent = accentArgb;
    bool? resolvedIsCustom = accentIsCustom;
    for (final TagCatalogItem item in catalog) {
      if (item.normalized == fromNorm) {
        resolvedAccent ??= item.accentArgb;
        resolvedIsCustom ??= item.accentIsCustom;
      }
    }

    final int updatedCount = fromNorm != toNorm || fromDisplay != toDisplay
        ? await _rewriteTagInAllEntries(
            session,
            fromNorm: fromNorm,
            toDisplay: toDisplay,
          )
        : 0;

    final List<TagCatalogItem> base = catalog
        .where((TagCatalogItem item) => item.normalized != fromNorm)
        .toList(growable: false);
    final List<TagCatalogItem> merged =
        TagStylesStore.merge(base, <TagCatalogItem>[
          TagCatalogItem(
            label: toDisplay,
            accentArgb: resolvedAccent,
            accentIsCustom: resolvedIsCustom,
          ),
        ]);
    await _persistTagCatalogToVault(merged);

    final IndexDatabase indexDb = _requireOpenIndex();
    if (fromNorm != toNorm) {
      await indexDb.deleteTagAccentArgb(fromDisplay);
    }
    if (resolvedAccent != null) {
      await indexDb.upsertTagAccentArgb(toDisplay, resolvedAccent);
    }

    return updatedCount;
  }

  Future<int> _rewriteTagInAllEntries(
    UnlockedVaultSession session, {
    required String fromNorm,
    required String toDisplay,
  }) async {
    final String toNorm = normalizeText(toDisplay);
    final List<EntryIndexRecord> records = await listEntries();
    int updatedCount = 0;
    for (final EntryIndexRecord record in records) {
      if (!record.tags.any((String t) => normalizeText(t) == fromNorm)) {
        continue;
      }

      final DiaryEntry? entry = await loadEntry(session, record.id);
      if (entry == null) {
        continue;
      }

      final List<String> nextTags = <String>[];
      final Set<String> seenNorm = <String>{};
      for (final String tag in entry.tags) {
        final String norm = normalizeText(tag);
        if (norm == fromNorm) {
          if (seenNorm.add(toNorm)) {
            nextTags.add(toDisplay);
          }
          continue;
        }
        if (seenNorm.add(norm)) {
          nextTags.add(tag);
        }
      }

      if (_entryTagsEqual(entry.tags, nextTags)) {
        continue;
      }

      await saveEntry(session, entry.copyWith(tags: nextTags));
      updatedCount++;
    }
    return updatedCount;
  }

  bool _entryTagsEqual(List<String> left, List<String> right) {
    if (left.length != right.length) {
      return false;
    }
    for (int i = 0; i < left.length; i++) {
      if (left[i] != right[i]) {
        return false;
      }
    }
    return true;
  }

  /// 從所有日記條目移除 [tag]，並清除已儲存的強調色。
  Future<int> removeTagFromAllEntries(
    UnlockedVaultSession session,
    String tag,
  ) async {
    final String normalized = normalizeText(tag);
    if (normalized.isEmpty) {
      return 0;
    }

    final List<EntryIndexRecord> records = await listEntries();
    int updatedCount = 0;
    for (final EntryIndexRecord record in records) {
      final bool hasTag = record.tags.any(
        (String t) => normalizeText(t) == normalized,
      );
      if (!hasTag) {
        continue;
      }

      final DiaryEntry? entry = await loadEntry(session, record.id);
      if (entry == null) {
        continue;
      }

      final List<String> nextTags = entry.tags
          .where((String t) => normalizeText(t) != normalized)
          .toList(growable: false);
      if (nextTags.length == entry.tags.length) {
        continue;
      }

      await saveEntry(session, entry.copyWith(tags: nextTags));
      updatedCount++;
    }

    await deleteTagCatalogItem(tag);
    return updatedCount;
  }

  Future<void> _persistTagCatalogToVault(List<TagCatalogItem> catalog) {
    return TagStylesStore(_pathStrategy).write(catalog);
  }

  Future<void> _applyTagCatalogFromVaultToIndex() async {
    final List<TagCatalogItem> catalog = await TagStylesStore(
      _pathStrategy,
    ).read();
    if (catalog.isEmpty) {
      return;
    }
    final IndexDatabase indexDb = _requireOpenIndex();
    for (final TagCatalogItem item in catalog) {
      if (item.accentArgb == null) {
        continue;
      }
      await indexDb.upsertTagAccentArgb(item.label, item.accentArgb!);
    }
  }

  /// 重建或還原後保持 vault 檔案與索引同步。
  Future<void> syncTagStylesBetweenVaultAndIndex() async {
    await _applyTagCatalogFromVaultToIndex();
  }

  Future<DiaryEntry> saveEntry(
    UnlockedVaultSession session,
    DiaryEntry draft, {
    List<PendingAttachment> pendingAttachments = const <PendingAttachment>[],
  }) => _serializeVaultMutation(
    () => _saveEntry(session, draft, pendingAttachments: pendingAttachments),
  );

  Future<DiaryEntry> _saveEntry(
    UnlockedVaultSession session,
    DiaryEntry draft, {
    required List<PendingAttachment> pendingAttachments,
  }) async {
    final RecoveryMetadata metadata = await _requireMetadataForSession(session);
    final List<int> recoveryWrapKey = _requireRecoveryWrapKey(session);
    final IndexDatabase indexDb = _requireOpenIndex();
    final EntryIndexRecord? previousRecord = await indexDb.getEntryById(
      draft.id,
    );
    final DateOnly previousDate = previousRecord?.date ?? draft.date;
    final List<AssetAttachment> existingFromDb = await indexDb
        .attachmentsForEntry(draft.id);
    final Set<AssetId> keepExistingIds = draft.attachmentIds.toSet();
    final Map<AssetId, AssetAttachment> existingById =
        <AssetId, AssetAttachment>{
          for (final AssetAttachment attachment in existingFromDb)
            attachment.id: attachment,
        };
    final Set<AssetId> pendingIds = <AssetId>{};
    for (final PendingAttachment pending in pendingAttachments) {
      if (pending.assetId.trim().isEmpty) {
        throw ArgumentError('暫存附件 ID 不可為空白');
      }
      if (!pendingIds.add(pending.assetId)) {
        throw ArgumentError('暫存附件 ID 不可重複：${pending.assetId}');
      }
      if (existingById.containsKey(pending.assetId)) {
        throw ArgumentError('暫存附件 ID 不可與既有附件重複：${pending.assetId}');
      }
    }
    final Set<AssetId> seenKeptIds = <AssetId>{};
    final List<AssetAttachment> existingKept = <AssetAttachment>[];
    for (final AssetId id in draft.attachmentIds) {
      if (!seenKeptIds.add(id)) {
        continue;
      }
      final AssetAttachment? attachment = existingById[id];
      if (attachment != null) {
        existingKept.add(attachment);
      }
    }
    final List<AssetAttachment> removedAttachments = existingFromDb
        .where((AssetAttachment a) => !keepExistingIds.contains(a.id))
        .toList(growable: false);
    final Set<String> obsoletePathsAfterSave = <String>{};
    for (final AssetAttachment attachment in removedAttachments) {
      obsoletePathsAfterSave.add(
        await _assetAbsolutePathFor(date: previousDate, attachment: attachment),
      );
    }

    final List<AssetAttachment> newAttachments = await _storePendingAttachments(
      entry: draft,
      pendingAttachments: pendingAttachments,
      recoveryWrapKey: recoveryWrapKey,
      recoverySlotKdf: metadata.kdf,
      vaultId: metadata.vaultId,
    );

    final Map<AssetId, AssetAttachment> availableById =
        <AssetId, AssetAttachment>{
          for (final AssetAttachment attachment in existingKept)
            attachment.id: attachment,
          for (final AssetAttachment attachment in newAttachments)
            attachment.id: attachment,
        };
    final Set<AssetId> seenOrderedIds = <AssetId>{};
    final List<AssetAttachment> allAttachments = <AssetAttachment>[];
    for (final AssetId id in draft.attachmentIds) {
      final AssetAttachment? attachment = availableById[id];
      if (attachment != null && seenOrderedIds.add(id)) {
        allAttachments.add(attachment);
      }
    }
    // 匯入流程不一定預先知道新附件 ID，未列入順序的新附件依輸入順序附加。
    for (final AssetAttachment attachment in newAttachments) {
      if (seenOrderedIds.add(attachment.id)) {
        allAttachments.add(attachment);
      }
    }
    final List<AssetAttachment> orderedAttachments = allAttachments;
    final DiaryEntry normalized = draft.copyWith(
      vaultId: metadata.vaultId,
      attachmentIds: orderedAttachments
          .map((AssetAttachment asset) => asset.id)
          .toList(),
      updatedAt: DateTime.now(),
    );

    if (previousRecord != null && previousRecord.date != normalized.date) {
      for (final AssetAttachment attachment in existingKept) {
        final String oldPath = await _assetAbsolutePathFor(
          date: previousRecord.date,
          attachment: attachment,
        );
        final bool copied = await _copyAssetFileIfNeeded(
          date: normalized.date,
          attachment: attachment,
          currentPath: oldPath,
        );
        if (copied) {
          obsoletePathsAfterSave.add(oldPath);
        }
      }
    }

    final String markdown = _frontMatterCodec.encode(
      normalized,
      attachments: orderedAttachments,
    );
    final EncryptionResult encryption = await _cryptoService.encryptMarkdown(
      documentId: normalized.id,
      vaultId: metadata.vaultId,
      markdown: markdown,
      recoveryWrapKey: recoveryWrapKey,
      recoverySlotKdf: metadata.kdf,
      createdAt: normalized.createdAt,
      updatedAt: normalized.updatedAt,
    );

    final String filePath = await _pathStrategy.entryAbsolutePath(
      date: normalized.date,
      entryId: normalized.id,
    );
    final Uint8List fileBytes = encryption.toFileBytes();
    await _atomicWriteBytes(File(filePath), fileBytes);
    if (previousRecord != null && previousRecord.filePath != filePath) {
      obsoletePathsAfterSave.add(previousRecord.filePath);
    }

    final _EntrySearchFields searchFields = _buildEntrySearchFields(normalized);

    await indexDb.upsertEntry(
      entry: normalized,
      filePath: filePath,
      previewText: searchFields.previewText,
      previewMarkdown: searchFields.previewMarkdown,
      titleSearchText: searchFields.titleSearchText,
      bodySearchText: searchFields.bodySearchText,
      bodyVisibleText: searchFields.bodyVisibleText,
      contentHash: await _hashString(markdown),
      encryptedFileSize: fileBytes.lengthInBytes,
      encryptedModifiedAt: DateTime.now(),
    );
    await indexDb.replaceAttachments(
      normalized.id,
      orderedAttachments,
      <AssetId, String>{
        for (final AssetAttachment attachment in orderedAttachments)
          attachment.id: await _assetAbsolutePathFor(
            date: normalized.date,
            attachment: attachment,
          ),
      },
    );
    await _writeEncryptedManifest(session, metadata);
    await ensureTagCatalogLabels(normalized.tags);
    await _deleteObsoleteFilesAfterSave(obsoletePathsAfterSave);
    return normalized;
  }

  Future<void> deleteEntry(UnlockedVaultSession session, EntryId entryId) =>
      _serializeVaultMutation(() => _deleteEntry(session, entryId));

  Future<void> _deleteEntry(
    UnlockedVaultSession session,
    EntryId entryId,
  ) async {
    final IndexDatabase indexDb = _requireOpenIndex();
    final EntryIndexRecord? record = await indexDb.getEntryById(entryId);
    if (record == null) {
      return;
    }

    final List<AssetAttachment> attachments = await indexDb.attachmentsForEntry(
      entryId,
    );
    await _deleteEntryFilesOnDisk(record: record, attachments: attachments);
    await indexDb.removeEntry(entryId);
    await PinnedEntriesStore(_pathStrategy).remove(entryId);

    final RecoveryMetadata metadata = await _requireMetadataForSession(session);
    await _writeEncryptedManifest(session, metadata);
  }

  Future<List<EntryIndexRecord>> searchEntries(String query) {
    return _requireOpenIndex().searchEntries(query);
  }

  Future<VaultRepairSummary?> readLastRepairSummary() async {
    final String? raw = await _requireOpenIndex().getAppValue(
      _kLastRepairSummaryKey,
    );
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) return null;
      return VaultRepairSummary.fromJson(decoded);
    } on FormatException {
      return null;
    }
  }

  Future<void> rebuildIndex(UnlockedVaultSession session) =>
      _serializeVaultMutation(() => _rebuildIndexFromVault(session));

  Future<void> _rebuildIndexFromVault(UnlockedVaultSession session) async {
    await _openIndexForSession(session);
    final RecoveryMetadata metadata = await _requireMetadataForSession(session);
    final ({List<File> entries, List<File> assets}) inventory =
        await _snapshotRepairInventory();
    final _EntryRepairStats entryStats = await _scanEntries(
      session,
      metadata,
      inventory.entries,
      repair: false,
    );
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
    await _writeRebuiltIndex(indexEntries, prunePinnedEntries: !hasEntryIssues);
    final List<VaultRepairIssue> issues = <VaultRepairIssue>[
      ...entryStats.issues,
      ...assetStats.issues,
    ];
    if (issues.isNotEmpty) {
      await _storeRepairSummary(
        VaultRepairReport(
          entryCount: indexEntries.length,
          duration: Duration.zero,
          finishedAt: DateTime.now(),
          relocatedEntries: 0,
          removedDuplicateEntries: 0,
          tagsAdded: 0,
          relocatedAssets: 0,
          removedOrphanAssets: 0,
          issues: issues,
        ),
      );
    }
  }

  Future<void> _writeRebuiltIndex(
    List<_ScannedEntry> entries, {
    required bool prunePinnedEntries,
  }) async {
    final IndexDatabase indexDb = _requireOpenIndex();
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
          contentHash: await _hashString(scanned.markdown),
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
        IndexDatabase.indexGeneration.toString(),
      );
    });

    await listTagCatalog();
    if (collectedTagLabels.isNotEmpty) {
      await ensureTagCatalogLabels(collectedTagLabels);
    }
    await syncTagStylesBetweenVaultAndIndex();
    if (prunePinnedEntries) {
      await _prunePinnedEntriesToExisting(
        entries.map((_ScannedEntry item) => item.entry.id),
      );
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
  }) => _serializeVaultMutation(
    () => _repairVaultWithReport(session, onProgress: onProgress),
  );

  Future<VaultRepairReport> _repairVaultWithReport(
    UnlockedVaultSession session, {
    VaultRepairProgressCallback? onProgress,
  }) async {
    final Stopwatch stopwatch = Stopwatch()..start();
    await _openIndexForSession(session);
    await _cancelPeopleAnalyticsRebuild();
    final RecoveryMetadata metadata = await _requireMetadataForSession(session);
    final ({List<File> entries, List<File> assets}) inventory =
        await _snapshotRepairInventory();

    onProgress?.call(VaultRepairPhase.scanningEntries);
    final _EntryRepairStats entryStats = await _scanEntries(
      session,
      metadata,
      inventory.entries,
      repair: true,
    );

    final Set<String> catalogNorms = (await listTagCatalog())
        .map((TagCatalogItem item) => item.normalized)
        .toSet();
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

    final List<_ScannedEntry> indexEntries = _indexableEntries(
      entryStats.scanned,
    );

    onProgress?.call(VaultRepairPhase.rebuildingIndex);
    await _writeRebuiltIndex(indexEntries, prunePinnedEntries: false);
    if (!hasEntryIssues) {
      await _prunePinnedEntriesToExisting(
        indexEntries.map((_ScannedEntry item) => item.entry.id),
      );
    }
    await _writeEncryptedManifest(session, metadata);
    onProgress?.call(VaultRepairPhase.rebuildingPeopleAnalytics);
    await ensurePeopleAnalyticsReady(session);

    final List<VaultRepairIssue> issues = <VaultRepairIssue>[
      ...entryStats.issues,
      ...assetStats.issues,
    ];
    onProgress?.call(VaultRepairPhase.cleaning);
    var removedDuplicateEntries = 0;
    var removedOrphanAssets = 0;
    final Map<String, _RepairCleanupTarget> cleanupTargets =
        <String, _RepairCleanupTarget>{
          ...entryStats.cleanupTargets,
          ...assetStats.cleanupTargets,
        };
    for (final _RepairCleanupTarget target in cleanupTargets.values) {
      try {
        final VaultRepairDeleteResult result = await _repairFileOperations
            .deleteIfValid(
              path: target.path,
              validate: (String path) => _validateRepairFile(
                path,
                session: session,
                metadata: metadata,
                expectedId: target.fileId,
                expectedContentType: target.contentType,
                expectedPlaintextHash: target.plaintextHash,
                validateAttachmentContent: target.isAttachment,
              ),
            );
        if (result == VaultRepairDeleteResult.validationFailed) {
          issues.add(
            VaultRepairIssue(
              kind: VaultRepairIssueKind.cleanupFailure,
              reference: await _vaultRelativeReference(target.path),
            ),
          );
          continue;
        }
        if (result != VaultRepairDeleteResult.deleted) continue;
        if (target.countsAsDuplicateEntry) {
          removedDuplicateEntries++;
        }
        if (target.countsAsOrphanAsset) removedOrphanAssets++;
      } on Object {
        issues.add(
          VaultRepairIssue(
            kind: VaultRepairIssueKind.cleanupFailure,
            reference: await _vaultRelativeReference(target.path),
          ),
        );
      }
    }

    stopwatch.stop();
    var report = VaultRepairReport(
      entryCount: indexEntries.length,
      duration: stopwatch.elapsed,
      finishedAt: DateTime.now(),
      relocatedEntries: entryStats.relocatedEntries,
      removedDuplicateEntries: removedDuplicateEntries,
      tagsAdded: tagsAdded,
      relocatedAssets: assetStats.relocatedAssets,
      removedOrphanAssets: removedOrphanAssets,
      issues: issues,
    );
    if (!await _storeRepairSummary(report)) {
      report = VaultRepairReport(
        entryCount: report.entryCount,
        duration: report.duration,
        finishedAt: report.finishedAt,
        relocatedEntries: report.relocatedEntries,
        removedDuplicateEntries: report.removedDuplicateEntries,
        tagsAdded: report.tagsAdded,
        relocatedAssets: report.relocatedAssets,
        removedOrphanAssets: report.removedOrphanAssets,
        issues: <VaultRepairIssue>[
          ...report.issues,
          const VaultRepairIssue(
            kind: VaultRepairIssueKind.cleanupFailure,
            reference: 'index/last_repair_summary',
          ),
        ],
      );
    }
    return report;
  }

  Future<_EntryRepairStats> _scanEntries(
    UnlockedVaultSession session,
    RecoveryMetadata metadata,
    List<File> files, {
    required bool repair,
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
        cleanupTargets: <String, _RepairCleanupTarget>{},
        assetReferences: <AssetId, List<_AssetReference>>{},
      );
    }

    final List<_RawScannedEntry> rawScans = <_RawScannedEntry>[];
    final List<VaultRepairIssue> issues = <VaultRepairIssue>[];
    final String normalizedEntriesRoot = p.normalize(entriesDirectory.path);

    for (final File entity in files) {
      final String reference = await _vaultRelativeReference(entity.path);
      try {
        final ParsedEncryptedDocument parsed = _cryptoService.parseFileBytes(
          await entity.readAsBytes(),
        );
        if (parsed.header.vaultId != metadata.vaultId ||
            parsed.header.contentType != 'text/markdown') {
          issues.add(
            VaultRepairIssue(
              kind: VaultRepairIssueKind.entryIdentityMismatch,
              reference: reference,
            ),
          );
          continue;
        }
        final String markdown = await _cryptoService.decryptMarkdown(
          headerBytes: parsed.headerBytes,
          ciphertextBytes: parsed.ciphertextBytes,
          context: _decryptionContext(session),
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
          issues.add(
            VaultRepairIssue(
              kind: VaultRepairIssueKind.invalidEntryMetadata,
              reference: reference,
            ),
          );
          continue;
        }
        if (parsed.header.fileId != rawId) {
          issues.add(
            VaultRepairIssue(
              kind: VaultRepairIssueKind.entryIdentityMismatch,
              reference: reference,
            ),
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
          issues.add(
            VaultRepairIssue(
              kind: VaultRepairIssueKind.invalidEntryMetadata,
              reference: reference,
            ),
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
            searchFields: _buildEntrySearchFields(entry),
            encryptedFileSize: await entity.length(),
            encryptedModifiedAt: await entity.lastModified(),
            plaintextHash: await _hashString(markdown),
            canonicalPath: canonicalPath,
          ),
        );
      } on Object {
        issues.add(
          VaultRepairIssue(
            kind: VaultRepairIssueKind.unreadableEntry,
            reference: reference,
          ),
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

    final Map<String, _RepairCleanupTarget> cleanupTargets =
        <String, _RepairCleanupTarget>{};
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
        issues.add(
          VaultRepairIssue(
            kind: VaultRepairIssueKind.conflictingEntry,
            reference: group.first.entry.id,
          ),
        );
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
          } else {
            final File target = File(normalizedCanonical);
            cleanupTargets[currentPath] = _RepairCleanupTarget(
              path: currentPath,
              fileId: raw.entry.id,
              contentType: 'text/markdown',
              plaintextHash: raw.plaintextHash,
              isAttachment: false,
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
    final Map<String, _RepairCleanupTarget> cleanupTargets =
        <String, _RepairCleanupTarget>{};
    if (files.isEmpty) {
      for (final AssetId id in references.keys) {
        issues.add(
          VaultRepairIssue(
            kind: VaultRepairIssueKind.missingAsset,
            reference: id,
          ),
        );
      }
      return _AssetRepairStats(
        relocatedAssets: 0,
        issues: issues,
        cleanupTargets: cleanupTargets,
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
        issues.add(
          VaultRepairIssue(
            kind: VaultRepairIssueKind.assetIdentityMismatch,
            reference: reference,
          ),
        );
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
          issues.add(
            VaultRepairIssue(
              kind: VaultRepairIssueKind.assetIdentityMismatch,
              reference: reference,
            ),
          );
          continue;
        }
        final List<int> plaintext = await _cryptoService.decryptBytes(
          headerBytes: parsed.headerBytes,
          ciphertextBytes: parsed.ciphertextBytes,
          context: _decryptionContext(session),
        );
        if (!attachmentContentMatchesMimeType(
          plaintext,
          parsed.header.contentType,
        )) {
          invalidPathsById
              .putIfAbsent(assetId, () => <String>[])
              .add(entity.path);
          issues.add(
            VaultRepairIssue(
              kind: VaultRepairIssueKind.assetIdentityMismatch,
              reference: reference,
            ),
          );
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
                plaintextHash: await _hashBytes(plaintext),
              ),
            );
      } on Object {
        invalidPathsById
            .putIfAbsent(assetId, () => <String>[])
            .add(entity.path);
        issues.add(
          VaultRepairIssue(
            kind: VaultRepairIssueKind.unreadableAsset,
            reference: reference,
          ),
        );
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
            issues.add(
              VaultRepairIssue(
                kind: VaultRepairIssueKind.unverifiedOrphanAsset,
                reference: await _vaultRelativeReference(file.path),
              ),
            );
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
        issues.add(
          VaultRepairIssue(
            kind: VaultRepairIssueKind.conflictingAsset,
            reference: assetId,
          ),
        );
        continue;
      }
      if (assetReferences.any(
        (_AssetReference reference) => !contentTypeMatchesExtension(
          group.value.first.mimeType,
          reference.extension,
        ),
      )) {
        issues.add(
          VaultRepairIssue(
            kind: VaultRepairIssueKind.assetIdentityMismatch,
            reference: assetId,
          ),
        );
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
      _ValidatedAssetFile? canonical;
      for (final _ValidatedAssetFile file in group.value) {
        if (p.normalize(file.path) == p.normalize(canonicalPath)) {
          canonical = file;
          break;
        }
      }
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
      canonical = group.value
          .where(
            (_ValidatedAssetFile file) =>
                p.normalize(file.path) == p.normalize(canonicalPath),
          )
          .firstOrNull;
      if (contents.length > 1) {
        issues.add(
          VaultRepairIssue(
            kind: VaultRepairIssueKind.conflictingAsset,
            reference: assetId,
          ),
        );
        if (canonical != null) {
          _attachResolvedAsset(entries, assetReferences.first, canonical);
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
            issues.add(
              VaultRepairIssue(
                kind: VaultRepairIssueKind.conflictingAsset,
                reference: assetId,
              ),
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
          issues.add(
            VaultRepairIssue(
              kind: VaultRepairIssueKind.cleanupFailure,
              reference: await _vaultRelativeReference(canonicalPath),
            ),
          );
          _attachResolvedAsset(entries, assetReferences.first, selected);
          continue;
        }
      }
      _attachResolvedAsset(entries, assetReferences.first, selected);
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

    for (final AssetId id in references.keys) {
      if (!filesById.containsKey(id)) {
        if (!invalidPathsById.containsKey(id)) {
          issues.add(
            VaultRepairIssue(
              kind: VaultRepairIssueKind.missingAsset,
              reference: id,
            ),
          );
        }
      }
    }
    return _AssetRepairStats(
      relocatedAssets: relocatedAssets,
      issues: issues,
      cleanupTargets: cleanupTargets,
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

  Future<bool> _copyAssetFileIfNeeded({
    required DateOnly date,
    required AssetAttachment attachment,
    required String currentPath,
  }) async {
    final String newPath = await _assetAbsolutePathFor(
      date: date,
      attachment: attachment,
    );
    if (p.normalize(currentPath) == p.normalize(newPath)) {
      return false;
    }
    final File oldFile = File(currentPath);
    if (!oldFile.existsSync()) {
      return false;
    }
    await File(newPath).parent.create(recursive: true);
    await oldFile.copy(newPath);
    return true;
  }

  DecryptionContext _decryptionContext(UnlockedVaultSession session) {
    return DecryptionContext(
      vaultId: session.vaultId,
      trustedDevice: session.trustedDevice,
      recoveryWrapKey: session.recoveryWrapKey,
      deviceSlotId: session.deviceSlotId,
    );
  }

  /// 讀取並解密 vault 資產（磁碟上的 `.enc`）供記憶體內預覽，例如列表縮圖。
  Future<Uint8List?> readDecryptedAssetBytes(
    UnlockedVaultSession session,
    String encryptedAbsolutePath, {
    int maxEncryptedFileBytes = 32 << 20,
  }) async {
    final String trimmed = encryptedAbsolutePath.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final File file = File(trimmed);
    if (!file.existsSync()) {
      return null;
    }
    final int encLength = await file.length();
    if (encLength > maxEncryptedFileBytes) {
      return null;
    }
    try {
      final ParsedEncryptedDocument parsed = _cryptoService.parseFileBytes(
        await file.readAsBytes(),
      );
      final List<int> plain = await _cryptoService.decryptBytes(
        headerBytes: parsed.headerBytes,
        ciphertextBytes: parsed.ciphertextBytes,
        context: _decryptionContext(session),
      );
      return Uint8List.fromList(plain);
    } on Object {
      return null;
    }
  }

  /// 僅在 catalog 為空時寫入預設標籤；已存在則 no-op。需 index 已開啟。
  /// [locale] 應與目前 App 介面語系一致（例如 [Localizations.localeOf]）。
  Future<bool> seedDefaultTagCatalogIfEmpty({required Locale locale}) async {
    final List<TagCatalogItem> existing = await listTagCatalog();
    if (existing.isNotEmpty) {
      return false;
    }
    final List<TagCatalogItem> defaultCatalog = defaultTagCatalogForLocale(
      locale,
    );
    await _persistTagCatalogToVault(defaultCatalog);
    final IndexDatabase indexDb = _requireOpenIndex();
    for (final TagCatalogItem item in defaultCatalog) {
      if (item.accentArgb == null) {
        continue;
      }
      await indexDb.upsertTagAccentArgb(item.label, item.accentArgb!);
    }
    return true;
  }

  Future<RecoveryMetadata> _requireMetadataForSession(
    UnlockedVaultSession session,
  ) async {
    final RecoveryMetadata metadata =
        await readRecoveryMetadata() ??
        (throw StateError('找不到 Recovery metadata。'));
    if (metadata.vaultId != session.vaultId) {
      throw StateError('目前 session 與 vault 資料不一致。');
    }
    return metadata;
  }

  List<int> _requireRecoveryWrapKey(UnlockedVaultSession session) {
    final List<int>? recoveryWrapKey = session.recoveryWrapKey;
    if (recoveryWrapKey == null) {
      throw StateError('目前 session 沒有可用的 Recovery wrapping key。');
    }
    return recoveryWrapKey;
  }

  Future<void> _verifyRecoveryDecryptFile(
    File file,
    DecryptionContext recoveryContext,
  ) async {
    final ParsedEncryptedDocument parsed = _cryptoService.parseFileBytes(
      await file.readAsBytes(),
    );
    try {
      await _cryptoService.decryptBytes(
        headerBytes: parsed.headerBytes,
        ciphertextBytes: parsed.ciphertextBytes,
        context: recoveryContext,
      );
    } on SecretBoxAuthenticationError {
      throw StateError('復原金鑰與日記庫資料不相符。若為更新金鑰前的舊備份，請輸入建立該備份時保存的復原金鑰。');
    }
  }

  /// 優先試 `entries/**/*.md.enc`，其餘 `entries|assets/**/*.enc`，不含 manifest。
  Future<List<File>> _encryptedFilesForRecoveryVerification() async {
    final Directory vaultRoot = await _pathStrategy.vaultRootDirectory();
    final String manifestPath = await _pathStrategy.manifestPath();
    final List<File> entryEncrypted = <File>[];
    final List<File> otherEncrypted = <File>[];

    if (!vaultRoot.existsSync()) {
      return const <File>[];
    }

    final File peopleCatalog = File(await _pathStrategy.peopleCatalogPath());
    final List<File> preferred = <File>[
      if (peopleCatalog.existsSync()) peopleCatalog,
    ];

    await for (final FileSystemEntity entity in vaultRoot.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) {
        continue;
      }
      if (!_isUnderVaultContentSubdir(entity.path, vaultRoot.path)) {
        continue;
      }
      if (entity.path == manifestPath ||
          !entity.path.toLowerCase().endsWith('.enc')) {
        continue;
      }
      final String lowered = entity.path.toLowerCase();
      if (lowered.endsWith('.md.enc')) {
        entryEncrypted.add(entity);
      } else {
        otherEncrypted.add(entity);
      }
    }

    int pathSort(File a, File b) => a.path.compareTo(b.path);
    entryEncrypted.sort(pathSort);
    otherEncrypted.sort(pathSort);

    return <File>[...preferred, ...entryEncrypted, ...otherEncrypted];
  }

  bool _isUnderVaultContentSubdir(String absolutePath, String vaultRootPath) {
    final String relative = p.relative(absolutePath, from: vaultRootPath);
    if (relative.startsWith('..')) {
      return false;
    }
    return relative.startsWith('entries${p.separator}') ||
        relative.startsWith('assets${p.separator}');
  }

  Future<void> _verifyRecoveryKey(
    RecoveryMetadata metadata,
    List<int> recoveryWrapKey,
  ) async {
    final File manifest = File(await _pathStrategy.manifestPath());
    final DecryptionContext recoveryContext = DecryptionContext.recovery(
      recoveryWrapKey: recoveryWrapKey,
      vaultId: metadata.vaultId,
    );

    if (manifest.existsSync()) {
      await _verifyRecoveryDecryptFile(manifest, recoveryContext);
      return;
    }

    final List<File> fallbackTargets =
        await _encryptedFilesForRecoveryVerification();
    if (fallbackTargets.isEmpty) {
      return;
    }

    Object? parseProblem;
    Object? verificationProblem;
    String? authFailurePath;
    bool sawParsableEncryptedFile = false;
    for (final File file in fallbackTargets) {
      late final ParsedEncryptedDocument parsed;
      try {
        parsed = _cryptoService.parseFileBytes(await file.readAsBytes());
      } on Object catch (parseErr, _) {
        parseProblem ??= parseErr;
        continue;
      }

      sawParsableEncryptedFile = true;
      try {
        await _cryptoService.decryptBytes(
          headerBytes: parsed.headerBytes,
          ciphertextBytes: parsed.ciphertextBytes,
          context: recoveryContext,
        );
        return;
      } on SecretBoxAuthenticationError {
        authFailurePath ??= file.path;
      } on Object catch (decryptErr, _) {
        verificationProblem ??= decryptErr;
      }
    }

    if (verificationProblem != null) {
      throw StateError(
        '無法用現有加密檔驗證復原金鑰（至少一個檔案疑似毀損或格式異常）。'
        ' 最近一次驗證問題：$verificationProblem',
      );
    }

    if (sawParsableEncryptedFile && authFailurePath != null) {
      throw StateError('復原金鑰與現有日記庫資料不相符。（路徑：$authFailurePath）');
    }

    throw StateError(
      '無法解析或驗證任何加密檔'
      '${parseProblem == null ? '' : '（最近一次格式錯誤：$parseProblem）'}',
    );
  }

  Future<void> _writeEncryptedManifest(
    UnlockedVaultSession session,
    RecoveryMetadata metadata,
  ) async {
    final List<EntryIndexRecord> entries = await listEntries();
    final int assetCount = await _requireOpenIndex().countAttachments();
    final Map<String, Object?> manifest = <String, Object?>{
      'vault_id': metadata.vaultId,
      'entry_count': entries.length,
      'asset_count': assetCount,
      'oldest_entry_date': entries.isEmpty ? null : entries.last.date.value,
      'newest_entry_date': entries.isEmpty ? null : entries.first.date.value,
      'app_version': '1.0.0',
    };

    final EncryptionResult encryption = await _cryptoService.encryptBytes(
      documentId: 'manifest',
      vaultId: metadata.vaultId,
      plaintextBytes: utf8.encode(jsonEncode(manifest)),
      contentType: 'application/json',
      recoveryWrapKey: _requireRecoveryWrapKey(session),
      recoverySlotKdf: metadata.kdf,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _atomicWriteBytes(
      File(await _pathStrategy.manifestPath()),
      encryption.toFileBytes(),
    );
  }

  Future<List<AssetAttachment>> _storePendingAttachments({
    required DiaryEntry entry,
    required List<PendingAttachment> pendingAttachments,
    required List<int> recoveryWrapKey,
    required KdfDescriptor recoverySlotKdf,
    required String vaultId,
  }) async {
    final List<AssetAttachment> results = <AssetAttachment>[];
    for (final PendingAttachment pending in pendingAttachments) {
      final AssetId assetId = pending.assetId;
      final String originalFilename = p.basename(
        pending.originalFilename.trim(),
      );
      final String extension = p
          .extension(originalFilename)
          .replaceFirst('.', '');
      final String safeFilename = originalFilename.isEmpty
          ? (extension.isEmpty ? assetId : '$assetId.$extension')
          : originalFilename;
      final List<int> sourceBytes = pending.bytes != null
          ? pending.bytes!
          : await File(pending.sourcePath!).readAsBytes();
      if (!contentTypeMatchesExtension(pending.mimeType, extension) ||
          !attachmentContentMatchesMimeType(sourceBytes, pending.mimeType)) {
        throw ArgumentError.value(
          originalFilename,
          'pendingAttachments',
          '附件內容、MIME 與副檔名不一致。',
        );
      }
      final DateTime createdAt = DateTime.now();
      final EncryptionResult encrypted = await _cryptoService.encryptBytes(
        documentId: assetId,
        vaultId: vaultId,
        plaintextBytes: sourceBytes,
        contentType: pending.mimeType,
        recoveryWrapKey: recoveryWrapKey,
        recoverySlotKdf: recoverySlotKdf,
        createdAt: createdAt,
        updatedAt: createdAt,
      );
      final String assetPath = await _pathStrategy.assetAbsolutePath(
        date: entry.date,
        assetId: assetId,
        extension: extension.isEmpty ? 'bin' : extension,
      );
      await _atomicWriteBytes(File(assetPath), encrypted.toFileBytes());
      results.add(
        AssetAttachment(
          id: assetId,
          entryId: entry.id,
          mimeType: pending.mimeType,
          originalFilename: originalFilename.isEmpty ? null : originalFilename,
          safeFilename: safeFilename,
          byteSize: sourceBytes.length,
          createdAt: createdAt,
          sha256: await _hashBytes(sourceBytes),
        ),
      );
    }
    return results;
  }

  Future<void> _rewrapVaultRecoveryKey({
    required VaultId vaultId,
    required List<int> oldRecoveryWrapKey,
    required List<int> newRecoveryWrapKey,
    required RecoveryMetadata newMetadata,
  }) async {
    final List<File> files = await _allEncryptedFiles();
    for (final File file in files) {
      final ParsedEncryptedDocument parsed = _cryptoService.parseFileBytes(
        await file.readAsBytes(),
      );
      final List<int> plaintextBytes = await _cryptoService.decryptBytes(
        headerBytes: parsed.headerBytes,
        ciphertextBytes: parsed.ciphertextBytes,
        context: DecryptionContext.recovery(
          recoveryWrapKey: oldRecoveryWrapKey,
          vaultId: vaultId,
        ),
      );
      final EncryptionResult encryption = await _cryptoService.encryptBytes(
        documentId: parsed.header.fileId,
        vaultId: parsed.header.vaultId,
        plaintextBytes: plaintextBytes,
        contentType: parsed.header.contentType,
        recoveryWrapKey: newRecoveryWrapKey,
        recoverySlotKdf: newMetadata.kdf,
        createdAt: parsed.header.createdAt,
        updatedAt: DateTime.now(),
      );
      await _atomicWriteBytes(file, encryption.toFileBytes());
    }
  }

  Future<void> _rewrapVaultForTrustedDevice(
    UnlockedVaultSession session,
    RecoveryMetadata metadata,
  ) async {
    final List<File> files = await _allEncryptedFiles();
    final List<int> recoveryWrapKey = _requireRecoveryWrapKey(session);
    for (final File file in files) {
      final ParsedEncryptedDocument parsed = _cryptoService.parseFileBytes(
        await file.readAsBytes(),
      );
      final List<int> plaintextBytes = await _cryptoService.decryptBytes(
        headerBytes: parsed.headerBytes,
        ciphertextBytes: parsed.ciphertextBytes,
        context: DecryptionContext.recovery(
          recoveryWrapKey: recoveryWrapKey,
          vaultId: session.vaultId,
        ),
      );
      final EncryptionResult encryption = await _cryptoService.encryptBytes(
        documentId: parsed.header.fileId,
        vaultId: parsed.header.vaultId,
        plaintextBytes: plaintextBytes,
        contentType: parsed.header.contentType,
        recoveryWrapKey: recoveryWrapKey,
        recoverySlotKdf: metadata.kdf,
        createdAt: parsed.header.createdAt,
        updatedAt: DateTime.now(),
      );
      await _atomicWriteBytes(file, encryption.toFileBytes());
    }
  }

  Future<List<File>> _allEncryptedFiles() async {
    final Directory vaultRoot = await _pathStrategy.vaultRootDirectory();
    final File manifest = File(await _pathStrategy.manifestPath());
    final List<File> files = <File>[if (manifest.existsSync()) manifest];

    await for (final FileSystemEntity entity in vaultRoot.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File || entity.path == manifest.path) {
        continue;
      }
      if (entity.path.endsWith('.enc')) {
        files.add(entity);
      }
    }
    return files;
  }

  Future<DeviceWrappedPayload> _storeWrappedRecoveryKey({
    required VaultId vaultId,
    required List<int> recoveryWrapKey,
    required KeystoreAuthKind authKind,
  }) async {
    final DeviceWrappedPayload payload = await _deviceKeyManager
        .wrapWithDeviceKey(
          vaultId: vaultId,
          plaintextBytes: recoveryWrapKey,
          authKind: authKind,
        );
    await _deviceKeyManager.storeWrappedRecoveryKey(
      vaultId: vaultId,
      record: WrappedRecoveryKeyRecord(
        slotId: payload.slotId,
        nonceBase64: payload.nonceBase64,
        ciphertextBase64: payload.ciphertextBase64,
        wrappedAt: DateTime.now(),
        formatVersion:
            WrappedRecoveryKeyRecord.kWrappedRecoveryKeyFormatVersion,
        platform: payload.platform,
      ),
    );
    await _deviceKeyManager.purgeInactiveDeviceKeys(
      vaultId,
      activeAuthKind: authKind,
    );
    return payload;
  }

  Future<KeystoreAuthKind> _requireCurrentKeystoreAuthKind() async {
    final AppUnlockMode mode = await _appLockService.getUnlockMode();
    return requireKeystoreAuthKindForMode(appLock: _appLockService, mode: mode);
  }

  Future<void> _resumeRewrapIfNeeded(
    UnlockedVaultSession session,
    RecoveryMetadata metadata,
  ) async {
    if (await _requireOpenIndex().getAppValue(kRewrapInProgressKey) != 'true') {
      return;
    }
    await _rewrapVaultForTrustedDevice(session, metadata);
    await _setRewrapState(inProgress: false);
    await rebuildIndex(session);
  }

  Future<void> _setRewrapState({required bool inProgress}) async {
    final IndexDatabase indexDb = _requireOpenIndex();
    await indexDb.setAppValue(
      kRewrapInProgressKey,
      inProgress ? 'true' : 'false',
    );
    if (inProgress) {
      await indexDb.setAppValue(
        kRewrapStartedAtKey,
        DateTime.now().toIso8601String(),
      );
      return;
    }
    await indexDb.deleteAppValue(kRewrapStartedAtKey);
  }

  Future<void> _deleteEntryFilesOnDisk({
    required EntryIndexRecord record,
    required List<AssetAttachment> attachments,
  }) async {
    await deleteFileIfExists(record.filePath);
    await _deleteAttachmentsOnDisk(date: record.date, attachments: attachments);
  }

  Future<String> _assetAbsolutePathFor({
    required DateOnly date,
    required AssetAttachment attachment,
  }) async {
    final String extension = p
        .extension(attachment.safeFilename)
        .replaceFirst('.', '');
    return _pathStrategy.assetAbsolutePath(
      date: date,
      assetId: attachment.id,
      extension: extension.isEmpty ? 'bin' : extension,
    );
  }

  Future<void> _deleteAttachmentsOnDisk({
    required DateOnly date,
    required Iterable<AssetAttachment> attachments,
  }) async {
    for (final AssetAttachment attachment in attachments) {
      final String assetPath = await _assetAbsolutePathFor(
        date: date,
        attachment: attachment,
      );
      await deleteFileIfExists(assetPath);
    }
  }

  Future<void> _deleteObsoleteFilesAfterSave(Iterable<String> paths) async {
    // 儲存結果已可讀取後，舊檔清理失敗只會留下可修復的孤兒檔，不應把成功儲存回報為失敗。
    for (final String path in paths) {
      try {
        await deleteFileIfExists(path);
      } on FileSystemException {
        continue;
      }
    }
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
      context: _decryptionContext(session),
    );
    if (validateAttachmentContent &&
        !attachmentContentMatchesMimeType(plaintext, expectedContentType)) {
      return false;
    }
    return await _hashBytes(plaintext) == expectedPlaintextHash;
  }

  Future<String> _vaultRelativeReference(String absolutePath) async {
    final Directory root = await _pathStrategy.vaultRootDirectory();
    return p
        .relative(p.normalize(absolutePath), from: p.normalize(root.path))
        .replaceAll('\\', '/');
  }

  Future<bool> _storeRepairSummary(VaultRepairReport report) async {
    final VaultRepairSummary summary = VaultRepairSummary.fromReport(report);
    try {
      await _requireOpenIndex().setAppValue(
        _kLastRepairSummaryKey,
        jsonEncode(summary.toJson()),
      );
      return true;
    } on Object {
      return false;
    }
  }

  Future<T> _serializeVaultMutation<T>(Future<T> Function() operation) {
    final Completer<T> completer = Completer<T>();
    final Future<void> previous = _mutationTail;
    _mutationTail = () async {
      try {
        await previous;
      } on Object {
        // 前一項錯誤已交還原呼叫端，不阻斷後續 vault 寫入。
      }
      try {
        completer.complete(await operation());
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    }();
    return completer.future;
  }

  Future<void> _atomicWriteBytes(File file, Uint8List bytes) async {
    await file.parent.create(recursive: true);
    final File tempFile = File('${file.path}.tmp');
    await tempFile.writeAsBytes(bytes, flush: true);
    if (file.existsSync()) {
      await file.delete();
    }
    await tempFile.rename(file.path);
  }

  Future<String> _hashString(String value) async {
    return _hashBytes(utf8.encode(value));
  }

  Future<String> _hashBytes(List<int> bytes) async {
    final Hash hash = await Sha256().hash(bytes);
    return hash.bytes
        .map((int byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  String _generateRecoveryKey() {
    final String first = generateBackupId().replaceFirst('bkp_', '');
    final String second = generateBackupId().replaceFirst('bkp_', '');
    final String raw = '$first$second';
    return raw
        .replaceAll('_', '')
        .replaceAll('-', '')
        .substring(0, 24)
        .toUpperCase()
        .replaceAllMapped(
          RegExp(r'.{4}'),
          (Match match) => '${match.group(0)}-',
        )
        .replaceAll(RegExp(r'-$'), '');
  }

  Future<void> closeUnlockedResources() async {
    _peopleCatalogCache = null;
    _peopleCatalogVaultId = null;
    _peopleAnalyticsJob?.cancel();
    _peopleAnalyticsJob = null;
    final Future<void>? inFlight = _peopleAnalyticsRebuildInFlight;
    if (inFlight != null) {
      try {
        await inFlight;
      } on Object {
        // 衍生分析失敗不妨礙鎖定與釋放 session 資源。
      }
    }
    _peopleAnalyticsProgressController.add(
      const PeopleAnalyticsProgress.idle(),
    );
    await _indexDatabaseManager.close();
  }

  Future<void> clearTrustedDeviceAccess() async {
    final RecoveryMetadata? metadata = await readRecoveryMetadata();
    if (metadata == null) {
      return;
    }
    await _deviceKeyManager.clearTrustedKey(metadata.vaultId);
  }

  Future<void> deleteDerivedLocalState() {
    return _indexDatabaseManager.deleteDatabaseFiles();
  }

  /// 目前 session 的 Keystore 保護是否與解鎖模式偏好一致。
  Future<bool> needsKeystoreMigration(UnlockedVaultSession session) async {
    final KeystoreAuthKind expected = await _requireCurrentKeystoreAuthKind();
    final WrappedRecoveryKeyRecord? wrappedRecord = await _deviceKeyManager
        .readWrappedRecoveryKey(session.vaultId);
    String? syncedSuffix;
    try {
      syncedSuffix = await _requireOpenIndex().getAppValue(
        kKeystoreWrapModeKey,
      );
    } on StateError {
      return !keystoreSlotsMatchExpected(
        session: session,
        expected: expected,
        wrappedRecord: wrappedRecord,
      );
    }
    return !trustedProtectionMatches(
      session: session,
      expected: expected,
      syncedSuffix: syncedSuffix,
      wrappedRecord: wrappedRecord,
    );
  }

  Future<UnlockedVaultSession> ensureKeystoreMatchesUnlockMode(
    UnlockedVaultSession session, {
    AppUnlockMode? targetMode,
  }) async {
    if (targetMode != null) {
      final UnlockModeCapabilityFailure? failure =
          await precheckUnlockModeChange(
            appLock: _appLockService,
            mode: targetMode,
          );
      if (failure != null) {
        throw StateError(failure.message);
      }
    }
    final KeystoreAuthKind expected = targetMode != null
        ? keystoreAuthFor(targetMode)
        : await _requireCurrentKeystoreAuthKind();
    final WrappedRecoveryKeyRecord? wrappedRecord = await _deviceKeyManager
        .readWrappedRecoveryKey(session.vaultId);
    String? syncedSuffix;
    try {
      syncedSuffix = await _requireOpenIndex().getAppValue(
        kKeystoreWrapModeKey,
      );
    } on StateError {
      await _openIndexForSession(session);
      syncedSuffix = await _requireOpenIndex().getAppValue(
        kKeystoreWrapModeKey,
      );
    }
    if (trustedProtectionMatches(
      session: session,
      expected: expected,
      syncedSuffix: syncedSuffix,
      wrappedRecord: wrappedRecord,
    )) {
      return session;
    }
    if (needsOnlyIndexSuffixSync(
      session: session,
      expected: expected,
      syncedSuffix: syncedSuffix,
      wrappedRecord: wrappedRecord,
    )) {
      await _requireOpenIndex().setAppValue(
        kKeystoreWrapModeKey,
        expected.storageSuffix,
      );
      return session;
    }
    final UnlockedVaultSession refreshed =
        await refreshTrustedSessionProtection(session, authKind: expected);
    await _requireOpenIndex().setAppValue(
      kKeystoreWrapModeKey,
      expected.storageSuffix,
    );
    return refreshed;
  }

  Future<UnlockedVaultSession> refreshTrustedSessionProtection(
    UnlockedVaultSession session, {
    required KeystoreAuthKind authKind,
  }) async {
    final RecoveryMetadata metadata = await _requireMetadataForSession(session);
    final TrustedDeviceInfo deviceInfo = await _deviceKeyManager
        .ensureDeviceKey(metadata.vaultId, authKind: authKind);
    await _storeWrappedRecoveryKey(
      vaultId: metadata.vaultId,
      recoveryWrapKey: _requireRecoveryWrapKey(session),
      authKind: authKind,
    );
    return session.copyWith(deviceSlotId: deviceInfo.slotId);
  }

  /// 解鎖後 attach 搜尋索引：開啟連線、必要時重置損壞 schema、同步標籤樣式。
  ///
  /// 不會全量 [rebuildIndex]；vault 變更後的重建由還原、金鑰替換或手動修復觸發。
  /// 人物：只確保 analytics 表存在，不解密名冊、不背景全量 rebuild。
  Future<void> ensureIndexReady(UnlockedVaultSession session) async {
    await _openIndexForSession(session);
    if (!await _requireOpenIndex().hasExpectedIndexSchema()) {
      await _indexDatabaseManager.deleteDatabaseFiles();
      await _openIndexForSession(session);
      await _requireOpenIndex().ensurePeopleAnalyticsTable();
      await syncTagStylesBetweenVaultAndIndex();
      return;
    }
    await _requireOpenIndex().ensurePeopleAnalyticsTable();
    await syncTagStylesBetweenVaultAndIndex();
  }

  Future<List<Person>> listPeople(UnlockedVaultSession session) async {
    final List<Person>? cached = _peopleCatalogCache;
    if (cached != null && _peopleCatalogVaultId == session.vaultId) {
      return List<Person>.unmodifiable(cached);
    }
    final List<Person> people = await PeopleStore(
      pathStrategy: _pathStrategy,
      cryptoService: _cryptoService,
    ).read(session);
    _peopleCatalogCache = people;
    _peopleCatalogVaultId = session.vaultId;
    return List<Person>.unmodifiable(people);
  }

  Future<Person> createPerson(
    UnlockedVaultSession session,
    PersonDraft draft, {
    bool confirmWarnings = false,
  }) =>
      _savePersonDraft(session, draft: draft, confirmWarnings: confirmWarnings);

  Future<Person> updatePerson(
    UnlockedVaultSession session,
    PersonId personId,
    PersonDraft draft, {
    bool confirmWarnings = false,
    bool addOldNameAsAlias = false,
  }) => _savePersonDraft(
    session,
    personId: personId,
    draft: draft,
    confirmWarnings: confirmWarnings,
    addOldNameAsAlias: addOldNameAsAlias,
  );

  Future<Person> _savePersonDraft(
    UnlockedVaultSession session, {
    required PersonDraft draft,
    PersonId? personId,
    required bool confirmWarnings,
    bool addOldNameAsAlias = false,
  }) async {
    final RecoveryMetadata metadata = await _requireMetadataForSession(session);
    final List<Person> existing = List<Person>.from(await listPeople(session));
    final int existingIndex = existing.indexWhere(
      (Person item) => item.id == personId,
    );
    if (personId != null && existingIndex < 0) {
      throw StateError('找不到要更新的人物');
    }
    final Person? previous = existingIndex >= 0
        ? existing[existingIndex]
        : null;

    final String name = draft.name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (name.isEmpty) {
      throw ArgumentError('人物姓名不可為空白');
    }
    final List<String> baseAliases = draft.aliases
        .map((String a) => a.trim().replaceAll(RegExp(r'\s+'), ' '))
        .where((String a) => a.isNotEmpty)
        .toList();
    final List<String> aliases;
    if (addOldNameAsAlias &&
        previous != null &&
        normalizePersonName(previous.name) != normalizePersonName(name)) {
      final String oldName = previous.name.trim();
      if (oldName.isNotEmpty &&
          !baseAliases.any(
            (String a) =>
                normalizePersonName(a) == normalizePersonName(oldName),
          ) &&
          normalizePersonName(oldName) != normalizePersonName(name)) {
        aliases = <String>[oldName, ...baseAliases];
      } else {
        aliases = baseAliases;
      }
    } else {
      aliases = baseAliases;
    }

    if (!isValidAcquaintanceYear(draft.acquaintanceYear)) {
      throw ArgumentError('認識年份無效');
    }

    final List<PersonNameIssue> issues = collectPersonNameIssues(
      name: name,
      aliases: aliases,
      existingPeople: existing,
      excludingPersonId: personId,
    );
    final PersonNameValidationException validation =
        PersonNameValidationException(issues);
    if (validation.hasConflict ||
        (validation.requiresConfirmation && !confirmWarnings)) {
      throw validation;
    }

    final DateTime now = DateTime.now();
    final Person normalized = Person(
      id: previous?.id ?? generatePersonId(),
      name: name,
      aliases: aliases,
      relationships: draft.relationships,
      relationshipDescription: draft.relationshipDescription.trim(),
      notes: draft.notes.trim(),
      friendliness: draft.friendliness,
      accentArgb: draft.accentArgb,
      birthday: draft.birthday,
      acquaintanceYear: draft.acquaintanceYear,
      createdAt: previous?.createdAt ?? now,
      updatedAt: now,
    );

    if (existingIndex >= 0) {
      existing[existingIndex] = normalized;
    } else {
      existing.add(normalized);
    }

    await PeopleStore(
      pathStrategy: _pathStrategy,
      cryptoService: _cryptoService,
    ).write(session, metadata: metadata, people: existing);
    _peopleCatalogCache = existing;
    _peopleCatalogVaultId = session.vaultId;
    return normalized;
  }

  Future<void> deletePerson(UnlockedVaultSession session, PersonId id) async {
    final RecoveryMetadata metadata = await _requireMetadataForSession(session);
    final List<Person> existing = List<Person>.from(await listPeople(session));
    existing.removeWhere((Person person) => person.id == id);
    await PeopleStore(
      pathStrategy: _pathStrategy,
      cryptoService: _cryptoService,
    ).write(session, metadata: metadata, people: existing);
    _peopleCatalogCache = existing;
    _peopleCatalogVaultId = session.vaultId;
  }

  /// 統計過期或尚未建立時自動全量重建；並行呼叫會共用同一個 in-flight Future。
  Future<void> ensurePeopleAnalyticsReady(UnlockedVaultSession session) async {
    while (true) {
      final Future<void>? inFlight = _peopleAnalyticsRebuildInFlight;
      if (inFlight != null) {
        final _PeopleAnalyticsJob? job = _peopleAnalyticsJob;
        if (job?.vaultId == session.vaultId) {
          await inFlight;
          return;
        }
        job?.cancel();
        try {
          await inFlight;
        } on Object {
          // 切換 vault 時舊工作取消屬預期行為。
        }
      }
      if (_peopleAnalyticsRebuildInFlight != null) {
        continue;
      }

      final _PeopleAnalyticsJob job = _PeopleAnalyticsJob(session.vaultId);
      _peopleAnalyticsJob = job;
      final Future<void> started = _runPeopleAnalyticsJob(session, job);
      _peopleAnalyticsRebuildInFlight = started;
      try {
        await started;
      } finally {
        if (identical(_peopleAnalyticsRebuildInFlight, started)) {
          _peopleAnalyticsRebuildInFlight = null;
          _peopleAnalyticsJob = null;
        }
      }
      return;
    }
  }

  Future<void> _cancelPeopleAnalyticsRebuild() async {
    final Future<void>? inFlight = _peopleAnalyticsRebuildInFlight;
    if (inFlight == null) {
      return;
    }
    _peopleAnalyticsJob?.cancel();
    try {
      await inFlight;
    } on _PeopleAnalyticsCancelled {
      // 修復會在索引重建後重新分析，取消舊工作屬預期行為。
    } finally {
      if (identical(_peopleAnalyticsRebuildInFlight, inFlight)) {
        _peopleAnalyticsRebuildInFlight = null;
        _peopleAnalyticsJob = null;
      }
    }
  }

  Future<void> _runPeopleAnalyticsJob(
    UnlockedVaultSession session,
    _PeopleAnalyticsJob job,
  ) async {
    await _openIndexForSession(session);
    await _requireOpenIndex().ensurePeopleAnalyticsTable();
    if (job.cancelled) {
      throw const _PeopleAnalyticsCancelled();
    }
    await _refreshPeopleAnalyticsBody(session, job);
  }

  Future<void> _refreshPeopleAnalyticsBody(
    UnlockedVaultSession session,
    _PeopleAnalyticsJob job,
  ) async {
    try {
      await _refreshPeopleAnalyticsBodyWithWorker(session, job);
    } finally {
      job.worker?.close();
      job.worker = null;
    }
  }

  Future<void> _refreshPeopleAnalyticsBodyWithWorker(
    UnlockedVaultSession session,
    _PeopleAnalyticsJob job,
  ) async {
    _peopleAnalysisScannedDocuments = 0;
    _peopleAnalysisBatchWrites = 0;
    _peopleAnalysisWorkerStarts = 0;
    final IndexDatabase indexDb = _requireOpenIndex();
    try {
      await _backfillPeopleVisibleText(session, job, indexDb);
    } on Object {
      job.worker?.close();
      job.worker = null;
      rethrow;
    }
    if (job.cancelled) {
      throw const _PeopleAnalyticsCancelled();
    }
    final List<Person> people = await listPeople(session);
    final List<String> fingerprintParts = <String>[
      for (final Person person in people)
        '${person.id}:${person.sortedNormalizedNames.join('|')}',
    ]..sort();
    final String catalogFingerprint = await _hashString(
      fingerprintParts.join('\n'),
    );
    final bool needsReset = await indexDb.needsPeopleAnalyticsReset(
      catalogFingerprint,
    );
    if (needsReset) {
      await indexDb.resetPeopleAnalytics();
      await indexDb.beginPeopleAnalyticsRebuild(catalogFingerprint);
    }
    final int initialPending = await indexDb
        .countChangedPeopleAnalysisDocuments();
    if (initialPending == 0) {
      if (needsReset || await indexDb.isPeopleAnalyticsStale()) {
        await indexDb.markPeopleAnalyticsReady(catalogFingerprint);
      }
      _peopleAnalyticsProgressController.add(
        const PeopleAnalyticsProgress(
          state: PeopleAnalyticsProgressState.ready,
        ),
      );
      return;
    }
    if (!needsReset) {
      await indexDb.setPeopleAnalyticsStale(true);
    }
    _peopleAnalyticsProgressController.add(
      PeopleAnalyticsProgress(
        state: PeopleAnalyticsProgressState.analyzing,
        totalDocuments: initialPending,
      ),
    );
    try {
      final PersonNameMatcher matcher = PersonNameMatcher(people);
      var processed = 0;
      EntryId? afterEntryId;
      while (true) {
        if (job.cancelled) {
          throw const _PeopleAnalyticsCancelled();
        }
        final List<PeopleAnalysisSourceDocument> changed = await indexDb
            .changedPeopleAnalysisDocuments(afterEntryId: afterEntryId);
        if (changed.isEmpty) {
          if (await indexDb.countChangedPeopleAnalysisDocuments() == 0) {
            break;
          }
          afterEntryId = null;
          continue;
        }
        afterEntryId = changed.last.entryId;
        final int payloadLength = changed.fold<int>(
          0,
          (int total, PeopleAnalysisSourceDocument document) =>
              total +
              document.titleText.length +
              document.bodyVisibleText.length,
        );
        final bool useWorker = changed.length > 8 || payloadLength > 32 * 1024;
        final Map<String, List<String>>? backgroundHits;
        if (useWorker) {
          if (job.worker == null) {
            job.worker = await _PeopleAnalysisWorker.start();
            _peopleAnalysisWorkerStarts += 1;
          }
          if (!job.matcherConfigured) {
            await job.worker!.configurePeople(people);
            job.matcherConfigured = true;
          }
          backgroundHits = await job.worker!.match(changed);
        } else {
          backgroundHits = null;
        }
        if (job.cancelled) {
          throw const _PeopleAnalyticsCancelled();
        }
        final List<PeopleAnalysisDocumentResult> results =
            <PeopleAnalysisDocumentResult>[
              for (final PeopleAnalysisSourceDocument document in changed)
                PeopleAnalysisDocumentResult(
                  document: document,
                  personIds: backgroundHits == null
                      ? matcher.matchTitleAndBody(
                          title: document.titleText,
                          body: document.bodyVisibleText,
                        )
                      : (backgroundHits[document.entryId] ?? const <String>[])
                            .toSet(),
                ),
            ];
        await indexDb.replacePeopleAnalyticsForDocuments(results);
        _peopleAnalysisScannedDocuments += changed.length;
        _peopleAnalysisBatchWrites += 1;
        processed += changed.length;
        _peopleAnalyticsProgressController.add(
          PeopleAnalyticsProgress(
            state: PeopleAnalyticsProgressState.analyzing,
            processedDocuments: processed,
            totalDocuments: initialPending,
          ),
        );
        await Future<void>.delayed(Duration.zero);
      }
      if (job.cancelled) {
        throw const _PeopleAnalyticsCancelled();
      }
      await indexDb.markPeopleAnalyticsReady(catalogFingerprint);
      _peopleAnalyticsProgressController.add(
        PeopleAnalyticsProgress(
          state: PeopleAnalyticsProgressState.ready,
          processedDocuments: processed,
          totalDocuments: initialPending,
        ),
      );
    } on _PeopleAnalyticsCancelled {
      await indexDb.setPeopleAnalyticsStale(true);
      rethrow;
    } on Object {
      await indexDb.setPeopleAnalyticsStale(true);
      rethrow;
    } finally {
      job.worker?.close();
      job.worker = null;
    }
  }

  Future<void> _backfillPeopleVisibleText(
    UnlockedVaultSession session,
    _PeopleAnalyticsJob job,
    IndexDatabase indexDb,
  ) async {
    final int initialMissing = await indexDb
        .countMissingPeopleVisibleTextDocuments();
    if (initialMissing == 0) {
      return;
    }
    job.worker ??= await _PeopleAnalysisWorker.start();
    _peopleAnalysisWorkerStarts += 1;
    var processed = 0;
    EntryId? afterEntryId;
    while (true) {
      if (job.cancelled) {
        throw const _PeopleAnalyticsCancelled();
      }
      final List<PeopleVisibleTextSourceDocument> documents = await indexDb
          .missingPeopleVisibleTextDocuments(afterEntryId: afterEntryId);
      if (documents.isEmpty) {
        if (await indexDb.countMissingPeopleVisibleTextDocuments() == 0) {
          break;
        }
        if (afterEntryId == null) {
          throw StateError('部分日記索引無法補建可見正文。');
        }
        afterEntryId = null;
        continue;
      }
      afterEntryId = documents.last.entryId;
      final Map<String, String> markdownByEntryId = <String, String>{};
      final Map<String, String> visibleTextByEntryId = <String, String>{};
      var payloadLength = 0;

      Future<void> flushWorkerPayload() async {
        if (markdownByEntryId.isEmpty) {
          return;
        }
        final _PeopleAnalysisWorker? worker = job.worker;
        if (job.cancelled || worker == null) {
          throw const _PeopleAnalyticsCancelled();
        }
        visibleTextByEntryId.addAll(
          await worker.extractVisibleText(markdownByEntryId),
        );
        markdownByEntryId.clear();
        payloadLength = 0;
      }

      for (final PeopleVisibleTextSourceDocument document in documents) {
        if (job.cancelled) {
          throw const _PeopleAnalyticsCancelled();
        }
        final File file = File(document.filePath);
        if (!file.existsSync()) {
          continue;
        }
        final ParsedEncryptedDocument parsed = _cryptoService.parseFileBytes(
          await file.readAsBytes(),
        );
        final String markdown = await _cryptoService.decryptMarkdown(
          headerBytes: parsed.headerBytes,
          ciphertextBytes: parsed.ciphertextBytes,
          context: _decryptionContext(session),
        );
        markdownByEntryId[document.entryId] = markdown;
        payloadLength += markdown.length;
        if (markdownByEntryId.length >= 8 || payloadLength >= 32 * 1024) {
          await flushWorkerPayload();
        }
      }
      await flushWorkerPayload();
      if (job.cancelled) {
        throw const _PeopleAnalyticsCancelled();
      }
      final Map<PeopleVisibleTextSourceDocument, String> updates =
          <PeopleVisibleTextSourceDocument, String>{
            for (final PeopleVisibleTextSourceDocument document in documents)
              if (visibleTextByEntryId[document.entryId] case final String text)
                document: text,
          };
      await indexDb.updatePeopleVisibleTextDocuments(updates);
      processed += documents.length;
      _peopleAnalyticsProgressController.add(
        PeopleAnalyticsProgress(
          state: PeopleAnalyticsProgressState.analyzing,
          phase: PeopleAnalyticsProgressPhase.preparingIndex,
          processedDocuments: processed.clamp(0, initialMissing),
          totalDocuments: initialMissing,
        ),
      );
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<Map<PersonId, PersonMentionStats>> allPersonMentionStats(
    UnlockedVaultSession session, {
    DateTime? now,
  }) async {
    await ensurePeopleAnalyticsReady(session);
    return _requireOpenIndex().allPersonMentionStats(now: now);
  }

  Future<List<EntryIndexRecord>> relatedEntriesForPerson(
    UnlockedVaultSession session,
    PersonId personId,
  ) async {
    await ensurePeopleAnalyticsReady(session);
    return _requireOpenIndex().relatedEntriesForPerson(personId);
  }

  Future<List<PersonScopedMentionRank>> topMentionedPeople(
    UnlockedVaultSession session, {
    required int limit,
    String? yearPrefix,
    String? monthPrefix,
  }) async {
    await ensurePeopleAnalyticsReady(session);
    return _requireOpenIndex().topMentionedPeople(
      limit: limit,
      yearPrefix: yearPrefix,
      monthPrefix: monthPrefix,
    );
  }

  /// 測試用：清除索引中的 Keystore 後綴同步欄位。
  @visibleForTesting
  Future<void> deleteKeystoreWrapModeSuffixForTest() async {
    await _requireOpenIndex().deleteAppValue(kKeystoreWrapModeKey);
  }

  @visibleForTesting
  Future<int> pendingPeopleAnalysisDocumentCountForTest(
    UnlockedVaultSession session,
  ) async {
    await _openIndexForSession(session);
    return _requireOpenIndex().countChangedPeopleAnalysisDocuments();
  }

  Future<void> _openIndexForSession(UnlockedVaultSession session) {
    return _indexDatabaseManager.openForSession(session);
  }

  IndexDatabase _requireOpenIndex() => _indexDatabaseManager.requireOpen();

  bool _sameStringLists(List<String> left, List<String> right) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) {
        return false;
      }
    }
    return true;
  }

  _EntrySearchFields _buildEntrySearchFields(DiaryEntry entry) {
    final EntryIndexText indexText = EntryIndexText.fromMarkdown(
      entry.markdownBody,
    );
    return _EntrySearchFields(
      previewText: indexText.previewText,
      previewMarkdown: previewMarkdownExcerpt(entry.markdownBody),
      titleSearchText: _titleSearchText(entry.title),
      bodySearchText: indexText.searchText,
      bodyVisibleText: indexText.visibleText,
    );
  }

  String _titleSearchText(String? title) {
    final String? trimmed = title?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return '';
    }
    return normalizeSearchText(trimmed);
  }
}
