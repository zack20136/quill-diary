import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:quill_diary/domain/diary/diary_entry_summary.dart';
import 'package:quill_diary/domain/people/person.dart';
import 'package:quill_diary/domain/people/person_name_matcher.dart';
import 'package:quill_diary/domain/people/relationship_type.dart';
import 'package:quill_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/crypto/crypto_service.dart';
import 'package:quill_diary/infrastructure/database/index_database.dart';
import 'package:quill_diary/infrastructure/database/index_database_manager.dart';
import 'package:quill_diary/infrastructure/markdown/front_matter_codec.dart';
import 'package:quill_diary/infrastructure/markdown/visible_text_from_markdown.dart';
import 'package:quill_diary/infrastructure/storage/people_store.dart';
import 'package:quill_diary/infrastructure/storage/shared/vault_file_ops.dart';
import 'package:quill_diary/infrastructure/storage/vault_path_strategy.dart';

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

class VaultPeopleService {
  VaultPeopleService({
    required this._pathStrategy,
    required this._cryptoService,
    required this._indexDatabaseManager,
    required this._requireMetadataForSession,
  });

  final VaultPathStrategy _pathStrategy;
  final CryptoService _cryptoService;
  final IndexDatabaseManager _indexDatabaseManager;
  final Future<RecoveryMetadata> Function(UnlockedVaultSession)
  _requireMetadataForSession;

  /// 解鎖後首次讀取名冊才填入；避免解鎖熱路徑解密。
  PeopleCatalog? _peopleCatalogCache;

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

  PeopleAnalyticsDebugMetrics get peopleAnalyticsDebugMetrics =>
      PeopleAnalyticsDebugMetrics(
        scannedDocuments: _peopleAnalysisScannedDocuments,
        batchWrites: _peopleAnalysisBatchWrites,
        workerStarts: _peopleAnalysisWorkerStarts,
      );

  Future<PeopleCatalog> readPeopleCatalog(UnlockedVaultSession session) async {
    final PeopleCatalog? cached = _peopleCatalogCache;
    if (cached != null && _peopleCatalogVaultId == session.vaultId) {
      return cached;
    }
    final PeopleCatalog catalog = await PeopleStore(
      pathStrategy: _pathStrategy,
      cryptoService: _cryptoService,
    ).read(session);
    _peopleCatalogCache = catalog;
    _peopleCatalogVaultId = session.vaultId;
    return catalog;
  }

  Future<List<Person>> listPeople(UnlockedVaultSession session) async {
    final PeopleCatalog catalog = await readPeopleCatalog(session);
    return List<Person>.unmodifiable(catalog.people);
  }

  Future<List<RelationshipType>> listRelationshipTypes(
    UnlockedVaultSession session,
  ) async {
    final PeopleCatalog catalog = await readPeopleCatalog(session);
    return List<RelationshipType>.unmodifiable(catalog.relationshipTypes);
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
    final PeopleCatalog catalog = await readPeopleCatalog(session);
    final List<Person> existing = List<Person>.from(catalog.people);
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

    final Set<String> typeIds = catalog.relationshipTypeIds;
    for (final String relationshipId in draft.relationships) {
      if (!typeIds.contains(relationshipId)) {
        throw ArgumentError('未知的關係類型');
      }
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

    final String? mentionName = normalizePersonMentionName(
      mentionName: draft.mentionName,
      name: name,
      aliases: aliases,
    );

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
      mentionName: mentionName,
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

    final PeopleCatalog next = catalog.copyWith(people: existing);
    await _persistPeopleCatalog(session, metadata: metadata, catalog: next);
    return normalized;
  }

  Future<void> deletePerson(UnlockedVaultSession session, PersonId id) async {
    final RecoveryMetadata metadata = await _requireMetadataForSession(session);
    final PeopleCatalog catalog = await readPeopleCatalog(session);
    final List<Person> existing = List<Person>.from(catalog.people)
      ..removeWhere((Person person) => person.id == id);
    await _persistPeopleCatalog(
      session,
      metadata: metadata,
      catalog: catalog.copyWith(people: existing),
    );
  }

  /// 新增自訂關係類型；[label] 寫入當前語系，另一語拷貝同一字串。
  Future<RelationshipType> addRelationshipType(
    UnlockedVaultSession session, {
    required String label,
    required bool preferZh,
  }) async {
    final String trimmed = label.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('關係名稱不可為空白');
    }
    final RecoveryMetadata metadata = await _requireMetadataForSession(session);
    final PeopleCatalog catalog = await readPeopleCatalog(session);
    final List<RelationshipType> types = List<RelationshipType>.from(
      catalog.relationshipTypes,
    );
    _ensureUniqueLabel(types: types, label: trimmed, preferZh: preferZh);
    final String id = generateRelationshipTypeId(
      existingIds: <String>{for (final RelationshipType t in types) t.id},
    );
    final RelationshipType created = RelationshipType(
      id: id,
      labelZh: trimmed,
      labelEn: trimmed,
    );
    types.add(created);
    await _persistPeopleCatalog(
      session,
      metadata: metadata,
      catalog: catalog.copyWith(relationshipTypes: types),
    );
    return created;
  }

  /// 只改當前語系對應的 label；另一語不變。
  Future<RelationshipType> renameRelationshipType(
    UnlockedVaultSession session, {
    required String id,
    required String label,
    required bool preferZh,
  }) async {
    final String trimmed = label.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('關係名稱不可為空白');
    }
    final RecoveryMetadata metadata = await _requireMetadataForSession(session);
    final PeopleCatalog catalog = await readPeopleCatalog(session);
    final List<RelationshipType> types = List<RelationshipType>.from(
      catalog.relationshipTypes,
    );
    final int index = types.indexWhere((RelationshipType t) => t.id == id);
    if (index < 0) {
      throw StateError('找不到要重新命名的關係類型');
    }
    _ensureUniqueLabel(
      types: types,
      label: trimmed,
      preferZh: preferZh,
      excludingId: id,
    );
    final RelationshipType previous = types[index];
    final RelationshipType updated = preferZh
        ? previous.copyWith(labelZh: trimmed)
        : previous.copyWith(labelEn: trimmed);
    types[index] = updated;
    await _persistPeopleCatalog(
      session,
      metadata: metadata,
      catalog: catalog.copyWith(relationshipTypes: types),
    );
    return updated;
  }

  /// 刪除類型，並從所有人物 relationships 清掉該 id。回傳受影響人數。
  Future<int> deleteRelationshipType(
    UnlockedVaultSession session,
    String id,
  ) async {
    final RecoveryMetadata metadata = await _requireMetadataForSession(session);
    final PeopleCatalog catalog = await readPeopleCatalog(session);
    if (catalog.typeById(id) == null) {
      throw StateError('找不到要刪除的關係類型');
    }
    final List<RelationshipType> types = catalog.relationshipTypes
        .where((RelationshipType type) => type.id != id)
        .toList(growable: false);
    int affected = 0;
    final List<Person> people = <Person>[];
    for (final Person person in catalog.people) {
      if (!person.relationships.contains(id)) {
        people.add(person);
        continue;
      }
      affected++;
      people.add(
        person.withRelationships(person.relationships.difference(<String>{id})),
      );
    }
    await _persistPeopleCatalog(
      session,
      metadata: metadata,
      catalog: PeopleCatalog(relationshipTypes: types, people: people),
    );
    return affected;
  }

  /// 依 [orderedIds] 重排關係類型；必須剛好涵蓋現行全部 id。
  Future<void> reorderRelationshipTypes(
    UnlockedVaultSession session,
    List<String> orderedIds,
  ) async {
    final RecoveryMetadata metadata = await _requireMetadataForSession(session);
    final PeopleCatalog catalog = await readPeopleCatalog(session);
    final Map<String, RelationshipType> byId = <String, RelationshipType>{
      for (final RelationshipType type in catalog.relationshipTypes)
        type.id: type,
    };
    if (orderedIds.length != byId.length ||
        orderedIds.toSet().length != orderedIds.length ||
        !orderedIds.every(byId.containsKey)) {
      throw ArgumentError('關係類型排序無效');
    }
    final List<RelationshipType> types = <RelationshipType>[
      for (final String id in orderedIds) byId[id]!,
    ];
    await _persistPeopleCatalog(
      session,
      metadata: metadata,
      catalog: catalog.copyWith(relationshipTypes: types),
    );
  }

  Future<void> _persistPeopleCatalog(
    UnlockedVaultSession session, {
    required RecoveryMetadata metadata,
    required PeopleCatalog catalog,
  }) async {
    await PeopleStore(
      pathStrategy: _pathStrategy,
      cryptoService: _cryptoService,
    ).write(session, metadata: metadata, catalog: catalog);
    _peopleCatalogCache = catalog;
    _peopleCatalogVaultId = session.vaultId;
  }

  void _ensureUniqueLabel({
    required List<RelationshipType> types,
    required String label,
    required bool preferZh,
    String? excludingId,
  }) {
    for (final RelationshipType type in types) {
      if (excludingId != null && type.id == excludingId) {
        continue;
      }
      final String existing = preferZh ? type.labelZh : type.labelEn;
      if (existing.trim() == label) {
        throw ArgumentError('關係名稱已存在');
      }
    }
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

  Future<void> cancelRebuild() async {
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
    await _indexDatabaseManager.openForSession(session);
    await _indexDatabaseManager.requireOpen().ensurePeopleAnalyticsTable();
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
    final IndexDatabase indexDb = _indexDatabaseManager.requireOpen();
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
    final String catalogFingerprint = await hashVaultText(
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
          context: vaultDecryptionContext(session),
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
    return _indexDatabaseManager.requireOpen().allPersonMentionStats(now: now);
  }

  Future<List<DiaryEntrySummary>> relatedEntriesForPerson(
    UnlockedVaultSession session,
    PersonId personId,
  ) async {
    await ensurePeopleAnalyticsReady(session);
    return _indexDatabaseManager.requireOpen().relatedEntriesForPerson(
      personId,
    );
  }

  Future<List<PersonScopedMentionRank>> topMentionedPeople(
    UnlockedVaultSession session, {
    required int limit,
    String? yearPrefix,
    String? monthPrefix,
  }) async {
    await ensurePeopleAnalyticsReady(session);
    return _indexDatabaseManager.requireOpen().topMentionedPeople(
      limit: limit,
      yearPrefix: yearPrefix,
      monthPrefix: monthPrefix,
    );
  }

  /// 測試用：清除索引中的 Keystore 後綴同步欄位。

  Future<int> pendingPeopleAnalysisDocumentCountForTest(
    UnlockedVaultSession session,
  ) async {
    await _indexDatabaseManager.openForSession(session);
    return _indexDatabaseManager
        .requireOpen()
        .countChangedPeopleAnalysisDocuments();
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
  }
}
