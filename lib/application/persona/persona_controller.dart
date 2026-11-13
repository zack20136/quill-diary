import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_diary/application/ai/ai_connection_providers.dart';
import 'package:quill_diary/application/persona/persona_material.dart';
import 'package:quill_diary/application/persona/persona_providers.dart';
import 'package:quill_diary/application/persona/persona_request_payload.dart';
import 'package:quill_diary/application/session/session_providers.dart';
import 'package:quill_diary/application/vault/vault_providers.dart';
import 'package:quill_diary/domain/ai/ai_connection_settings.dart';
import 'package:quill_diary/domain/ai/private_text.dart';
import 'package:quill_diary/domain/diary/diary_entry.dart';
import 'package:quill_diary/domain/persona/persona.dart';
import 'package:quill_diary/domain/persona/persona_chat_import.dart';
import 'package:quill_diary/domain/persona/persona_privacy.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/ai/ai_client.dart';
import 'package:quill_diary/infrastructure/persona/persona_store.dart';
import 'package:quill_diary/infrastructure/storage/shared/vault_file_ops.dart';
import 'package:quill_diary/l10n/app_localizations.dart';

class PersonaGenerationContext {
  PersonaGenerationContext({
    required this.personaId,
    required this.updateTarget,
    required this.modelTarget,
    required Map<PersonaCardKind, PersonaCandidate> fallbackCards,
    required Map<PersonaCardKind, DateTime?> baseUpdatedAt,
    required this.session,
    required this.connection,
    required this.instructions,
    required this.extractionInstructions,
    required this.registry,
    required List<PersonaMaterial> blocks,
    required Map<String, String> baseline,
    required this.subject,
    required this.selectionSignature,
  }) : baseUpdatedAt = Map.unmodifiable(baseUpdatedAt),
       blocks = List.unmodifiable(blocks),
       baseline = Map.unmodifiable(baseline),
       fallbackCards = Map.unmodifiable(fallbackCards);
  final String personaId;
  final PersonaUpdateTarget updateTarget;
  final PersonaUpdateTarget? modelTarget;
  final Map<PersonaCardKind, PersonaCandidate> fallbackCards;
  final Map<PersonaCardKind, DateTime?> baseUpdatedAt;
  final UnlockedVaultSession session;
  final AiConnectionConfig? connection;
  final String instructions;
  final String extractionInstructions;
  final PersonaTokenRegistry registry;
  final List<PersonaMaterial> blocks;
  final Map<String, String> baseline;
  final String subject;
  final String selectionSignature;

  List<Map<String, Object?>> get requestMaterials => modelTarget == null
      ? const []
      : blocks.map((block) => block.toRequestJson()).toList();

  bool get requiresBatching =>
      modelTarget != null &&
      personaRequestLength(
            instructions,
            personaGenerationData(
              subject: subject,
              baseline: baseline,
              materials: requestMaterials,
            ),
          ) >
          PersonaLimits.requestCodeUnits;
}

bool personaSourceHasVisibleText(String text, List<PrivateTextRange> ranges) {
  final merged = mergePrivateRanges(ranges, text.length);
  final visible = StringBuffer();
  var cursor = 0;
  for (final range in merged) {
    visible.write(text.substring(cursor, range.start));
    cursor = range.end;
  }
  visible.write(text.substring(cursor));
  return personaHasVisibleText(visible.toString());
}

final personaControllerProvider = Provider.autoDispose
    .family<PersonaController, String>((ref, id) {
      final controller = PersonaController(ref, id);
      ref.listen(effectiveAppSessionProvider, (_, next) {
        if (!next.hasValue ||
            !next.value!.isUnlocked ||
            !identical(next.value!.session, controller.session)) {
          controller.lock();
        }
      });
      ref.onDispose(controller.dispose);
      ref.listen(aiEnabledProvider, (_, enabled) {
        if (!enabled && controller.busy) controller.stop();
      });
      ref.listen(personaDeletionsProvider.select((value) => value[id]), (_, _) {
        controller._cancelDraftSaves();
        controller.stop();
      });
      return controller;
    });

class PersonaController extends ChangeNotifier {
  PersonaController(this.ref, this.personId);
  final Ref ref;
  final String personId;
  PersonaRecord? record;
  UnlockedVaultSession? session;
  final Map<String, DiaryEntry> entries = {};
  final Map<String, PersonaChatImport> imports = {};
  PersonaGenerationContext? preview;
  bool loading = false;
  bool busy = false;
  bool failed = false;
  bool cleanupPending = false;
  bool missingDiaries = false;
  int completedRequests = 0;
  int totalRequests = 0;
  final Map<String, String> _responses = {};
  AiClient? _client;
  Timer? _saveTimer;
  int _epoch = 0;
  int _draftEpoch = 0;
  int _revision = 0;
  int _savedRevision = 0;
  PersonaStore? _store;
  bool _disposed = false;
  void Function()? _releaseJob;
  PersonaDraft? get draft => record?.draft;
  bool get materialsNeedReview =>
      draft?.diaries.any(
        (d) => d.needsReview || !entries.containsKey(d.entryId),
      ) ==
      true;
  bool isCandidateValid(PersonaCardKind kind) {
    final card = draft?.candidate?[kind];
    if (card == null) return false;
    try {
      card.validate(kind);
      return true;
    } on FormatException {
      return false;
    }
  }

  bool get canSaveCandidate =>
      draft?.target.kinds.every(isCandidateValid) == true;
  bool get hasMaterials {
    final toneOnly = draft?.target == PersonaUpdateTarget.tone;
    return draft?.includeCurrent.entries.any(
              (entry) => entry.value && record?.cards?[entry.key] != null,
            ) ==
            true ||
        draft?.diaries.any((d) {
              final body = entries[d.entryId]?.markdownBody;
              return body != null &&
                  (toneOnly ||
                      personaSourceHasVisibleText(body, d.hiddenRanges));
            }) ==
            true ||
        draft?.chats.any((source) {
              final chat = imports[source.importId];
              if (chat == null) return false;
              if (chat.isRaw) {
                return toneOnly ||
                    personaSourceHasVisibleText(chat.rawText, chat.rawHidden);
              }
              return chat
                  .messagesInWindow(source)
                  .any(
                    (m) =>
                        !source.excluded.contains(m.id) &&
                        (toneOnly ||
                            personaSourceHasVisibleText(
                              m.text,
                              source.hidden[m.id] ?? const [],
                            )),
                  );
            }) ==
            true;
  }

  PersonaStore get store =>
      _store ??= ref.read<PersonaStore>(personaStoreProvider);

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  void _ensure(int epoch) {
    if (_disposed ||
        epoch != _epoch ||
        session == null ||
        !identical(
          ref.read(effectiveAppSessionProvider).value?.session,
          session,
        )) {
      throw const FormatException('分身工作已失效');
    }
  }

  Future<void> load() async {
    if (_disposed || loading) return;
    final waitingEpoch = _epoch;
    final state = await ref.read(effectiveAppSessionProvider.future);
    if (_disposed || waitingEpoch != _epoch || loading) return;
    if (!state.isUnlocked || state.session == null) return;
    if (identical(session, state.session) && record != null) return;
    session = state.session;
    final epoch = ++_epoch;
    loading = true;
    failed = false;
    notifyListeners();
    try {
      final value = await store.load(personId, session!);
      _ensure(epoch);
      record = value;
      _savedRevision = _revision;
      _invalidate();
      cleanupPending = store.pendingCleanup.contains(personId);
      if (draft != null) await _loadMaterials(epoch);
    } on Object {
      if (epoch == _epoch) failed = true;
    } finally {
      if (epoch == _epoch) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<({DiaryEntry entry, String hash})?> _readDiary(
    String id,
    int epoch,
  ) async {
    final entry = await ref
        .read(vaultRepositoryProvider)
        .loadEntry(session!, id);
    _ensure(epoch);
    if (entry == null || entry.vaultId != session!.vaultId) return null;
    final hash = await hashVaultText(entry.markdownBody);
    _ensure(epoch);
    return (entry: entry, hash: hash);
  }

  Future<void> _loadMaterials(int epoch) async {
    entries.clear();
    imports.clear();
    for (final source in draft!.diaries) {
      final loaded = await _readDiary(source.entryId, epoch);
      if (loaded == null) {
        source.needsReview = true;
        continue;
      }
      if (source.bodyHash != loaded.hash) {
        source.bodyHash = loaded.hash;
        source.hiddenRanges = [];
        source.needsReview = true;
      }
      validatePersonaRanges(loaded.entry.markdownBody, source.hiddenRanges);
      entries[loaded.entry.id] = loaded.entry;
    }
    for (final source in draft!.chats) {
      final value = await store.readImport(
        personId,
        record!.personaId,
        source,
        session!,
      );
      _ensure(epoch);
      imports[value.importId] = value;
    }
  }

  Future<void> begin(PersonaUpdateTarget target, {bool edit = false}) async {
    if (busy || session == null) return;
    final epoch = ++_epoch;
    final current = record;
    if (edit && current?.cards == null) {
      throw const FormatException('沒有可編輯的分身內容');
    }
    _cancelDraftSaves();
    final actualTarget = current?.cards == null
        ? PersonaUpdateTarget.both
        : target;
    final d = PersonaDraft(
      target: actualTarget,
      manualEdit: edit,
      baseUpdatedAt: {
        for (final kind in actualTarget.kinds)
          kind: current?.cards?[kind]?.updatedAt,
      },
    );
    final settings = await ref.read(aiSettingsStoreProvider).read(session!);
    _ensure(epoch);
    d.hidePersonNames = settings.hidePersonNames;
    d.connectionId = settings.connection.activeConfig.connectionId;
    d.model = settings.connection.activeConfig.model;
    var nextMissingDiaries = false;
    final nextEntries = <String, DiaryEntry>{};
    for (final id in {
      if (!edit)
        for (final k in actualTarget.kinds)
          ...?current?.cards?[k]?.selectedDiaryIds,
    }) {
      final loaded = await _readDiary(id, epoch);
      if (loaded == null) {
        nextMissingDiaries = true;
        continue;
      }
      nextEntries[id] = loaded.entry;
      d.diaries.add(PersonaDiarySource(entryId: id, bodyHash: loaded.hash));
    }
    if (edit) {
      d.step = PersonaStep.review;
      d.candidate = {
        for (final k in actualTarget.kinds)
          k: PersonaCandidate(
            text: current!.cards![k]!.text,
            tokens: current.cards![k]!.tokens,
          ),
      };
    }
    final nextRecord = PersonaRecord(
      vaultId: session!.vaultId,
      personId: personId,
      personaId: current?.personaId ?? generatePersonaId(),
      cards: current?.cards,
      draft: d,
    );
    await store.saveDraft(
      nextRecord,
      session!,
      create: current == null,
      ensureCurrent: () => _ensure(epoch),
    );
    _ensure(epoch);
    record = nextRecord;
    entries
      ..clear()
      ..addAll(nextEntries);
    imports.clear();
    missingDiaries = nextMissingDiaries;
    _invalidate();
    notifyListeners();
  }

  void _invalidate() {
    preview = null;
    // 確認頁依賴記憶體快照；快照清除後須重新檢視材料。
    if (draft?.step == PersonaStep.confirmation) {
      draft!.step = PersonaStep.materials;
    }
    _responses.clear();
    failed = false;
  }

  void resetToMaterials() {
    if (busy || draft == null) return;
    draft!.candidate = null;
    draft!.step = PersonaStep.materials;
    _invalidate();
    schedulePersist();
  }

  void setIncludeCurrent(PersonaCardKind kind, bool include) {
    if (busy ||
        draft == null ||
        !draft!.target.kinds.contains(kind) ||
        record?.cards?[kind] == null ||
        (draft!.includeCurrent[kind] ?? false) == include) {
      return;
    }
    draft!.includeCurrent[kind] = include;
    resetToMaterials();
  }

  void schedulePersist() {
    _revision++;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), _persistInBackground);
    notifyListeners();
  }

  void _cancelDraftSaves() {
    _draftEpoch++;
    _saveTimer?.cancel();
    _savedRevision = _revision;
  }

  void _persistInBackground() {
    final epoch = _epoch;
    unawaited(
      persist().catchError((Object _) {
        if (!_disposed && epoch == _epoch && session != null) {
          failed = true;
          notifyListeners();
        }
      }),
    );
  }

  Future<void> persist({void Function()? ensureCurrent}) async {
    _saveTimer?.cancel();
    if (session == null || record == null) return;
    final current = record!;
    final vault = session!;
    final storage = store;
    final draftEpoch = _draftEpoch;
    final revision = _revision;
    // 儲存層同步擷取快照；鎖定後不再依賴控制器的 session 或 Riverpod ref。
    await storage.saveDraft(
      current,
      vault,
      ensureCurrent: () {
        if (draftEpoch != _draftEpoch) throw const FormatException('草稿已捨棄或更換');
        ensureCurrent?.call();
      },
    );
    if (draftEpoch == _draftEpoch && revision == _revision) {
      _savedRevision = revision;
    }
  }

  Future<void> selectDiary(String id, bool selected) async {
    if (busy || draft == null || session == null) return;
    if (selected && draft!.diaries.any((d) => d.entryId == id)) return;
    if (!selected) {
      draft!.diaries.removeWhere((d) => d.entryId == id);
      entries.remove(id);
    } else if (!draft!.diaries.any((d) => d.entryId == id)) {
      final epoch = _epoch;
      final loaded = await _readDiary(id, epoch);
      if (loaded == null) throw const FormatException('日記不可用');
      entries[id] = loaded.entry;
      draft!.diaries.add(
        PersonaDiarySource(entryId: id, bodyHash: loaded.hash),
      );
    }
    resetToMaterials();
    await persist();
  }

  Future<void> attachImport(PersonaChatImport value) => _commitImport(value);

  Future<void> selectModel(ChatModelOption option) async {
    if (busy || draft == null) return;
    draft!.connectionId = option.connectionConfig.connectionId;
    draft!.model = option.modelId;
    _invalidate();
    schedulePersist();
    await persist();
  }

  Future<void> updateImport(
    PersonaChatImport value, {
    Map<String, List<PrivateTextRange>>? hidden,
    Set<String>? excluded,
  }) => _commitImport(value, hidden: hidden, excluded: excluded);

  Future<void> _commitImport(
    PersonaChatImport value, {
    Map<String, List<PrivateTextRange>>? hidden,
    Set<String>? excluded,
  }) async {
    if (busy || draft == null || session == null) return;
    final epoch = _epoch;
    final currentDraft = draft!;
    final imported = PersonaChatImport.fromJson(
      jsonDecode(jsonEncode(value.toJson())) as Map<String, dynamic>,
    );
    final nextDraft = PersonaDraft.fromJson(
      jsonDecode(jsonEncode(currentDraft.toJson())) as Map<String, dynamic>,
    );
    var source = nextDraft.chats
        .where((c) => c.importId == imported.importId)
        .firstOrNull;
    if (source == null) {
      source = PersonaChatSource(importId: imported.importId);
      nextDraft.chats.add(source);
    }
    if (hidden != null) {
      source.hidden
        ..clear()
        ..addAll(hidden);
    }
    if (excluded != null) {
      source.excluded
        ..clear()
        ..addAll(excluded);
    }
    _saveTimer?.cancel();
    busy = true;
    notifyListeners();
    try {
      await persist();
      _ensure(epoch);
      final saved = await store.saveImport(
        imported,
        session!,
        draft: nextDraft,
        ensureCurrent: () => _ensure(epoch),
      );
      _ensure(epoch);
      final committed = saved.draft!.chats.singleWhere(
        (c) => c.importId == imported.importId,
      );
      final original = currentDraft.chats
          .where((c) => c.importId == imported.importId)
          .firstOrNull;
      // 材料頁仍持有來源物件；提交成功後同步同一物件，讓後續圈選使用新指標。
      if (original == null) {
        currentDraft.chats.add(committed);
      } else {
        original.contentId = committed.contentId;
        original.hidden
          ..clear()
          ..addAll(committed.hidden);
        original.excluded
          ..clear()
          ..addAll(committed.excluded);
      }
      currentDraft.candidate = null;
      currentDraft.step = PersonaStep.materials;
      record = saved.withDraft(currentDraft);
      imports[imported.importId] = imported;
      cleanupPending = store.pendingCleanup.contains(personId);
      _invalidate();
    } finally {
      if (epoch == _epoch) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<void> removeImport(String id) async {
    if (busy || draft == null || session == null) return;
    final epoch = _epoch;
    final next = PersonaRecord.fromJson(
      jsonDecode(jsonEncode(record!.toJson())) as Map<String, dynamic>,
    );
    next.draft!.chats.removeWhere((c) => c.importId == id);
    next.draft!.candidate = null;
    next.draft!.step = PersonaStep.materials;
    _saveTimer?.cancel();
    busy = true;
    notifyListeners();
    try {
      await persist();
      _ensure(epoch);
      await store.saveDraft(
        next,
        session!,
        ensureCurrent: () => _ensure(epoch),
      );
      _ensure(epoch);
      record = next;
      imports.remove(id);
      _invalidate();
      await store.load(personId, session!);
      _ensure(epoch);
      cleanupPending = store.pendingCleanup.contains(personId);
    } finally {
      if (epoch == _epoch) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<AiConnectionConfig> selectedConnection() async {
    final settings = await ref.read(aiSettingsStoreProvider).read(session!);
    final id = draft?.connectionId;
    final AiConnectionConfig config;
    try {
      config = id == null
          ? settings.connection.activeConfig
          : settings.connection.connectionFor(id);
    } on StateError {
      throw const FormatException('原模型連線已移除');
    }
    final next = config.copyWith(model: draft?.model ?? config.model);
    return next.captureRequestSnapshot();
  }

  Future<void> prepare(AppLocalizations l10n) async {
    if (busy || draft == null || session == null) return;
    _invalidate();
    final epoch = ++_epoch;
    await _loadMaterials(epoch);
    if (draft!.diaries.any((d) => d.needsReview) ||
        draft!.diaries.length != entries.length) {
      schedulePersist();
      throw const FormatException('日記需要重新檢查');
    }
    final people = await ref.read(vaultRepositoryProvider).listPeople(session!);
    _ensure(epoch);
    final selectionSignature = _selectionSignature(draft!);
    final registry = PersonaTokenRegistry(
      people,
      hideNames: draft!.hidePersonNames,
      reservedText: [
        for (final e in entries.values) e.markdownBody,
        for (final c in record!.cards?.values ?? <PersonaCard>[]) c.text,
        for (final i in imports.values) ...[
          for (final m in i.messages) m.text,
          if (i.isRaw) i.rawText,
        ],
      ].join('\n'),
    );
    registry.replaceImportNames([
      for (final chat in imports.values)
        for (final speaker in chat.speakers)
          if (speaker.id.startsWith('named-') &&
              !(chat.isRaw &&
                  speaker.role == PersonaSpeakerRole.personaSubject))
            speaker.label,
    ]);
    registry.bindSubjectImportNames(personId, [
      for (final chat in imports.values)
        if (chat.isRaw)
          for (final speaker in chat.speakers)
            if (speaker.role == PersonaSpeakerRole.personaSubject)
              speaker.label,
    ]);
    final includedCards = {
      for (final kind in draft!.target.kinds)
        if (draft!.includeCurrent[kind] == true && record!.cards?[kind] != null)
          kind: record!.cards![kind]!,
    };
    draft!.validate();
    final blocks = <PersonaMaterial>[];
    for (final source in draft!.diaries) {
      final entry = entries[source.entryId]!;
      final body = registry.protect(
        entry.markdownBody,
        scope: 'diary:${entry.id}',
        ranges: source.hiddenRanges,
      );
      if (!personaHasVisibleText(body)) continue;
      blocks.add(
        PersonaMaterial.diary(
          label: '${l10n.personaDiaries} ${blocks.length + 1}',
          date: entry.date.value,
          text: body,
        ),
      );
    }
    for (final source in draft!.chats) {
      final chat = imports[source.importId]!;
      if (chat.isRaw) {
        final body = registry.protect(
          chat.rawText,
          scope: '${chat.importId}:raw',
          ranges: chat.rawHidden,
          maskImportNames: true,
        );
        if (!personaHasVisibleText(body)) continue;
        blocks.add(
          PersonaMaterial.raw(
            label: '${l10n.personaChats} ${draft!.chats.indexOf(source) + 1}',
            text: body,
          ),
        );
        continue;
      }
      final speakers = {for (final s in chat.speakers) s.id: s};
      for (final message in chat.messagesInWindow(source)) {
        final speaker = speakers[message.speakerId]!;
        if (source.excluded.contains(message.id)) continue;
        final ranges = source.hidden[message.id] ?? const [];
        final body = registry.protect(
          message.text,
          scope: '${chat.importId}:${message.id}',
          ranges: ranges,
          maskImportNames: true,
        );
        if (!personaHasVisibleText(body)) continue;
        blocks.add(
          PersonaMaterial.chat(
            label: '${l10n.personaChats} ${draft!.chats.indexOf(source) + 1}',
            date: message.sentAtLocal,
            text: body,
            speakerRole: speaker.role,
            speaker: speaker.role == PersonaSpeakerRole.user
                ? 'user'
                : speaker.role == PersonaSpeakerRole.personaSubject
                ? registry.person(personId)
                : speaker.id.startsWith('named-')
                ? registry.anonymous('import:${speaker.label}')
                : registry.anonymous('${chat.importId}:${speaker.id}'),
            styleText: speaker.role != PersonaSpeakerRole.personaSubject
                ? ''
                : registry.protect(
                    message.text,
                    scope: '${chat.importId}:${message.id}',
                    ranges: mergePrivateRanges([
                      ...ranges,
                      ...message.quoteRanges,
                    ], message.text.length),
                    maskImportNames: true,
                  ),
          ),
        );
      }
    }
    if (blocks.isEmpty &&
        includedCards.isEmpty &&
        !(draft!.target == PersonaUpdateTarget.tone && hasMaterials)) {
      throw const FormatException('沒有可用材料');
    }
    final needsMemory =
        blocks.isNotEmpty &&
        draft!.target.kinds.contains(PersonaCardKind.memory);
    final needsTone =
        draft!.target.kinds.contains(PersonaCardKind.tone) &&
        blocks.any((block) => block.hasToneEvidence);
    final modelTarget = switch ((needsMemory, needsTone)) {
      (true, true) => PersonaUpdateTarget.both,
      (true, false) => PersonaUpdateTarget.memory,
      (false, true) => PersonaUpdateTarget.tone,
      (false, false) => null,
    };
    final connection = modelTarget == null ? null : await selectedConnection();
    _ensure(epoch);
    if (_selectionSignature(draft!) != selectionSignature) {
      throw const FormatException('分身材料或設定已變更，請重新確認');
    }
    final fallbackCards = {
      for (final kind in draft!.target.kinds)
        kind: PersonaCandidate(
          text:
              includedCards[kind]?.text ??
              (kind == PersonaCardKind.memory
                  ? l10n.personaNeutralMemory
                  : l10n.personaNeutralTone),
          tokens: includedCards[kind]?.tokens,
        ),
    };
    final baseline = {
      for (final kind in modelTarget?.kinds ?? <PersonaCardKind>[])
        if (includedCards[kind] case final card?)
          kind.name: registry.protect(
            card.text,
            scope: 'card:${kind.name}',
            tokens: card.tokens,
            ranges: draft!.cardHiddenRanges[kind] ?? [],
          ),
    };
    final instructions = [
      if (modelTarget != null) ...[
        if (needsMemory) l10n.personaMemoryUpdatePrompt,
        if (needsTone) l10n.personaToneUpdatePrompt,
        'target: ${modelTarget.name}',
        l10n.personaOutputPrompt(
          PersonaLimits.memoryCodeUnits,
          PersonaLimits.toneCodeUnits,
          personaHiddenText,
        ),
      ],
    ].join('\n\n');
    final subject = registry.protect(
      people.firstWhere((p) => p.id == personId).name,
      scope: 'subject',
    );
    preview = PersonaGenerationContext(
      personaId: record!.personaId,
      updateTarget: draft!.target,
      modelTarget: modelTarget,
      fallbackCards: fallbackCards,
      baseUpdatedAt: draft!.baseUpdatedAt,
      session: session!,
      connection: connection,
      instructions: instructions,
      extractionInstructions: modelTarget == null
          ? ''
          : '${l10n.personaExtractionPrompt(personaHiddenText)}\ntarget: ${modelTarget.name}',
      registry: registry,
      blocks: blocks,
      baseline: baseline,
      subject: subject,
      selectionSignature: selectionSignature,
    );
    completedRequests = 0;
    totalRequests = 0;
    draft!.step = PersonaStep.confirmation;
    await persist();
    _ensure(epoch);
    notifyListeners();
  }

  void _ensureJob(PersonaGenerationContext context, int epoch) {
    _ensure(epoch);
    if (!identical(session, context.session) ||
        record?.personaId != context.personaId ||
        !identical(preview, context) ||
        draft?.target != context.updateTarget) {
      throw const FormatException('分身工作已失效');
    }
  }

  bool _diskMatches(PersonaRecord? current, PersonaGenerationContext context) =>
      current?.personaId == context.personaId &&
      current?.deleting != true &&
      current?.draft != null &&
      _selectionSignature(current!.draft!) == context.selectionSignature &&
      context.baseUpdatedAt.entries.every(
        (entry) => personaTimesMatch(
          current.cards?[entry.key]?.updatedAt,
          entry.value,
        ),
      );

  Future<String> _request(
    PersonaGenerationContext context,
    int epoch,
    String instructions,
    String data, {
    bool cacheResult = true,
  }) async {
    _ensureJob(context, epoch);
    if (personaRequestLength(instructions, data) >
        PersonaLimits.requestCodeUnits) {
      throw const FormatException('分身請求超過長度上限');
    }
    final current = await store.load(personId, session!);
    _ensureJob(context, epoch);
    if (!_diskMatches(current, context)) {
      throw const FormatException('分身或基準已變更');
    }
    final key = await hashVaultText('$instructions\n$data');
    _ensureJob(context, epoch);
    if (_responses.containsKey(key)) return _responses[key]!;
    totalRequests++;
    notifyListeners();
    final output = StringBuffer();
    await for (final delta in _client!.reply(instructions, [
      AiInputMessage(isUser: true, text: data),
    ])) {
      _ensureJob(context, epoch);
      output.write(delta);
      if (output.length > PersonaLimits.responseCodeUnits) {
        _client?.close();
        throw const FormatException('模型回覆過長');
      }
    }
    _ensureJob(context, epoch);
    var text = output.toString();
    if (text.trim().isEmpty) throw const FormatException('模型未回傳內容');
    if (cacheResult) {
      text = context.registry.protectEvidence(text);
      context.registry.validateOutputTokens(text, data);
      _responses[key] = text;
    }
    completedRequests++;
    notifyListeners();
    return text;
  }

  String _selectionSignature(PersonaDraft draft) {
    final json = draft.toJson()
      ..remove('step')
      ..remove('candidate');
    return jsonEncode(json);
  }

  Future<void> generate() async {
    final context = preview;
    if (busy || context == null || !ref.read(aiEnabledProvider)) return;
    final epoch = ++_epoch;
    final keepAlive = ref.keepAlive();
    _releaseJob = keepAlive.close;
    AiClient? client;
    busy = true;
    failed = false;
    notifyListeners();
    try {
      _ensureJob(context, epoch);
      final current = await store.load(personId, context.session);
      _ensureJob(context, epoch);
      if (!_diskMatches(current, context)) {
        throw const FormatException('分身或基準已變更');
      }
      final candidate = {
        for (final entry in context.fallbackCards.entries)
          entry.key: PersonaCandidate(
            text: entry.value.text,
            tokens: entry.value.tokens,
          ),
      };
      final modelTarget = context.modelTarget;
      if (modelTarget != null) {
        final connection = context.connection!;
        if (personaRequestLength(
              context.instructions,
              personaGenerationData(
                subject: context.subject,
                baseline: context.baseline,
                materials: const [],
              ),
            ) >=
            PersonaLimits.requestCodeUnits) {
          throw const FormatException('分身固定內容已無法容納材料');
        }
        final key = await requireAiRequestKey(
          enabled: ref.read(aiEnabledProvider),
          connection: connection,
          readApiKey: () =>
              ref.read(aiSettingsStoreProvider).readApiKey(connection),
        );
        client = ref.read(aiClientFactoryProvider)(connection, key);
        _ensureJob(context, epoch);
        _client = client;
        var materials = context.requestMaterials.cast<Object?>().toList();
        for (
          var level = 0;
          personaRequestLength(
                context.instructions,
                personaGenerationData(
                  subject: context.subject,
                  baseline: context.baseline,
                  materials: materials,
                ),
              ) >
              PersonaLimits.requestCodeUnits;
          level++
        ) {
          if (level >= 4) throw const FormatException('材料仍過長，請減少材料');
          final batches = personaExtractionBatches(
            materials,
            subject: context.subject,
            instructions: context.extractionInstructions,
          );
          final summaries = <String>[];
          for (final batch in batches) {
            summaries.add(
              await _request(
                context,
                epoch,
                context.extractionInstructions,
                personaExtractionData(
                  subject: context.subject,
                  fragment: batch,
                ),
              ),
            );
          }
          if (jsonEncode(summaries).length >= jsonEncode(materials).length) {
            throw const FormatException('中間證據未縮短，請減少材料或調整模型');
          }
          materials = summaries;
        }
        final data = personaGenerationData(
          subject: context.subject,
          baseline: context.baseline,
          materials: materials,
        );
        final output = await _request(
          context,
          epoch,
          context.instructions,
          data,
          cacheResult: false,
        );
        final decoded = jsonDecode(output);
        final expected = modelTarget.kinds.map((k) => k.name).toSet();
        if (decoded is! Map ||
            decoded.length != expected.length ||
            !decoded.keys.every(expected.contains) ||
            decoded.values.any((v) => v is! String)) {
          throw const FormatException('模型輸出欄位不正確');
        }
        for (final kind in modelTarget.kinds) {
          final text = decoded[kind.name] as String;
          if (text.trim().isNotEmpty) {
            candidate[kind] = context.registry.candidate(
              text,
              kind,
              record!.cards?[kind],
              requestData: data,
            );
          }
        }
      }
      _ensureJob(context, epoch);
      draft!.candidate = candidate;
      draft!.step = PersonaStep.review;
      await persist(ensureCurrent: () => _ensureJob(context, epoch));
      _ensureJob(context, epoch);
    } on Object {
      if (epoch == _epoch) failed = true;
    } finally {
      client?.close();
      if (identical(_client, client)) _client = null;
      if (epoch == _epoch) {
        busy = false;
        notifyListeners();
      }
      keepAlive.close();
      if (epoch == _epoch) _releaseJob = null;
    }
  }

  void editCandidate(PersonaCardKind kind, String text) {
    if (busy || draft?.candidate == null) return;
    final previous = draft!.candidate![kind]!;
    draft!.candidate![kind] = PersonaCandidate(
      text: text,
      tokens: {
        for (final match in personaTokenPattern.allMatches(text))
          if (previous.tokens.containsKey(match[0]))
            match[0]!: previous.tokens[match[0]],
      },
    );
    schedulePersist();
  }

  Future<void> save() async {
    if (busy || draft?.candidate == null || session == null) return;
    final epoch = _epoch;
    busy = true;
    notifyListeners();
    try {
      await persist();
      _ensure(epoch);
      final saved = await store.publish(
        personId,
        record!.personaId,
        session!,
        ensureCurrent: () => _ensure(epoch),
      );
      _ensure(epoch);
      record = saved;
      _cancelDraftSaves();
      cleanupPending = store.pendingCleanup.contains(personId);
      entries.clear();
      imports.clear();
      _invalidate();
      ref.invalidate(savedPersonasProvider);
      ref.invalidate(personaRecordProvider(personId));
    } finally {
      if (epoch == _epoch) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<void> discardResult() async {
    if (busy || draft == null) return;
    if (draft!.manualEdit) {
      await discardUpdate();
      return;
    }
    draft!.candidate = null;
    draft!.step = PersonaStep.materials;
    _invalidate();
    await persist();
    notifyListeners();
  }

  Future<void> discardUpdate() async {
    if (session == null || record == null) return;
    stop();
    _cancelDraftSaves();
    final epoch = _epoch;
    final current = record!;
    busy = true;
    notifyListeners();
    try {
      PersonaRecord? saved;
      if (current.cards == null) {
        await store.delete(personId, session!);
      } else {
        saved = current.withDraft(null);
        await store.saveDraft(
          saved,
          session!,
          ensureCurrent: () => _ensure(epoch),
        );
        _ensure(epoch);
        await store.load(personId, session!);
      }
      _ensure(epoch);
      record = saved;
      cleanupPending = store.pendingCleanup.contains(personId);
      entries.clear();
      imports.clear();
      ref.invalidate(personaRecordProvider(personId));
    } on Object {
      if (epoch == _epoch) schedulePersist();
      rethrow;
    } finally {
      if (epoch == _epoch) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<void> delete() async {
    if (session == null) return;
    ref.read(personaDeletionsProvider.notifier).mark(personId);
    stop();
    await store.delete(personId, session!);
    record = null;
    cleanupPending = store.pendingCleanup.contains(personId);
    entries.clear();
    imports.clear();
    ref.invalidate(savedPersonasProvider);
    notifyListeners();
    ref.invalidate(personaRecordProvider(personId));
  }

  void stop() {
    _epoch++;
    _client?.close();
    _client = null;
    loading = false;
    busy = false;
    _invalidate();
    _releaseJob?.call();
    _releaseJob = null;
    notifyListeners();
  }

  void lock() {
    stop();
    _saveTimer?.cancel();
    if (_revision != _savedRevision) _persistInBackground();
    session = null;
    record = null;
    preview = null;
    entries.clear();
    imports.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    lock();
    super.dispose();
  }
}
