import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_diary/application/ai/ai_connection_providers.dart';
import 'package:quill_diary/application/ai/ai_prompts.dart';
import 'package:quill_diary/application/ai/ai_request_preview.dart';
import 'package:quill_diary/application/diary/diary_entry_providers.dart';
import 'package:quill_diary/application/editor/editor_draft_providers.dart';
import 'package:quill_diary/application/session/session_providers.dart';
import 'package:quill_diary/application/settings/personalization_providers.dart';
import 'package:quill_diary/application/vault/vault_providers.dart';
import 'package:quill_diary/domain/ai/ai_composer_snapshot.dart';
import 'package:quill_diary/domain/ai/ai_connection_settings.dart';
import 'package:quill_diary/domain/ai/ai_failure.dart';
import 'package:quill_diary/domain/ai/privacy_names.dart';
import 'package:quill_diary/domain/ai/private_text.dart';
import 'package:quill_diary/domain/diary/diary_entry.dart';
import 'package:quill_diary/domain/diary_organization/diary_organization.dart';
import 'package:quill_diary/domain/people/person_name_matcher.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/domain/shared/privacy_tokens.dart';
import 'package:quill_diary/infrastructure/ai/ai_client.dart';
import 'package:quill_diary/infrastructure/diary_organization/diary_organization_store.dart';

final diaryOrganizationStoreProvider = Provider<DiaryOrganizationStore>(
  (ref) => DiaryOrganizationStore(
    paths: ref.watch(vaultPathStrategyProvider),
    crypto: ref.watch(cryptoServiceProvider),
    repository: ref.watch(vaultRepositoryProvider),
  ),
);

final organizationDraftProvider = FutureProvider.autoDispose
    .family<DiaryOrganization?, String>((ref, id) async {
      final session = await ref.watch(activeVaultSessionProvider.future);
      if (session == null) return null;
      try {
        return await ref.read(diaryOrganizationStoreProvider).load(id, session);
      } on AiFailure catch (failure) {
        if (failure.code == AiErrorCode.unreadable) return null;
        rethrow;
      }
    });

final diaryOrganizationControllerProvider = Provider.autoDispose
    .family<DiaryOrganizationController, String>((ref, id) {
      final controller = DiaryOrganizationController(ref, id);
      ref.listen(appSessionProvider, (_, next) {
        if (controller.vault != null &&
            (!next.isUnlocked || next.session != controller.vault)) {
          controller.lock();
        }
      });
      ref.onDispose(controller.dispose);
      ref.listen(aiEnabledProvider, (_, enabled) {
        if (!enabled && controller.busy) controller.stop();
      });
      ref.listen(diaryRevisionProvider, (_, _) {
        if (controller.draft != null &&
            controller.draft!.stage != OrganizationStage.applying &&
            controller.draft!.stage != OrganizationStage.applied) {
          unawaited(controller.refreshConflict());
        }
      });
      return controller;
    });

/// 從模型回覆取出第一個可用的整理結果。前後說明與圍欄都略過。
Map<String, dynamic>? organizationGenerationPayload(String text) {
  var index = 0;
  while (index < text.length) {
    final start = text.indexOf('{', index);
    if (start < 0) return null;
    final end = _jsonObjectEnd(text, start);
    if (end == null) {
      index = start + 1;
      continue;
    }
    try {
      final decoded = jsonDecode(text.substring(start, end));
      if (decoded is Map) {
        final reply = decoded['reply'];
        final body = decoded['body'];
        if (reply is String && body is String && body.trim().isNotEmpty) {
          return Map<String, dynamic>.from(decoded);
        }
      }
    } on FormatException {
      // 這段括號不是可用的整理結果，往後再找。
    }
    index = start + 1;
  }
  return null;
}

int? _jsonObjectEnd(String text, int start) {
  var depth = 0;
  var inString = false;
  var escape = false;
  for (var i = start; i < text.length; i++) {
    final char = text[i];
    if (inString) {
      if (escape) {
        escape = false;
      } else if (char == '\\') {
        escape = true;
      } else if (char == '"') {
        inString = false;
      }
      continue;
    }
    if (char == '"') {
      inString = true;
    } else if (char == '{') {
      depth++;
    } else if (char == '}') {
      depth--;
      if (depth == 0) return i + 1;
    }
  }
  return null;
}

enum OrganizationGenerationPhase {
  idle,
  preparing,
  receiving,
  validating,
  saving,
}

class DiaryOrganizationController extends ChangeNotifier {
  DiaryOrganizationController(this.ref, this.entryId);
  final Ref ref;
  final String entryId;
  DiaryOrganization? draft;
  UnlockedVaultSession? vault;
  bool loading = false;
  bool busy = false;
  bool conflict = false;
  bool editorDraftExists = false;
  AiErrorCode? error;
  OrganizationGenerationPhase generationPhase =
      OrganizationGenerationPhase.idle;
  final _requests = <bool, ({String key, _OrganizationRequest request})>{};
  bool get generating => generationPhase != OrganizationGenerationPhase.idle;
  bool get canInteract =>
      draft != null && !busy && !conflict && !editorDraftExists;
  bool get canGenerate {
    final current = draft;
    final last = current?.activeTurnIndices.lastOrNull;
    return ref.read(aiEnabledProvider) &&
        canInteract &&
        current!.stage == OrganizationStage.chat &&
        current.editingTurn == null &&
        current.composer.trim().isEmpty &&
        current.activeTurnIndices.any(
          (i) => current.turns[i].user.isNotEmpty,
        ) &&
        last != null &&
        !current.turns[last].interrupted &&
        current.turns[last].reply.isNotEmpty &&
        current.replyIsInScope(last);
  }

  PersonNameMatcher? _personMatcher;
  PersonNameMatcher? get personMatcher => _personMatcher;
  AiClient? _client;
  Timer? _saveTimer;
  int _version = 0;
  bool _disposed = false;
  bool _dirty = false;
  DiaryOrganizationStore get _store => ref.read(diaryOrganizationStoreProvider);

  Future<void> load(UnlockedVaultSession session) async {
    if ((vault == session && draft != null) || loading) return;
    vault = session;
    loading = true;
    error = null;
    final version = ++_version;
    _dirty = false;
    notifyListeners();
    try {
      DiaryOrganization? saved;
      try {
        saved = await _store.load(entryId, session);
      } on AiFailure catch (failure) {
        if (failure.code != AiErrorCode.unreadable) rethrow;
        await _store.delete(entryId);
        _ensure(version);
      }
      _ensure(version);
      final settings = await ref.read(aiSettingsStoreProvider).read(session);
      _ensure(version);
      await _syncPersonMatcher(
        session,
        version,
        hidePersonNames: settings.hidePersonNames,
      );
      if (saved != null) {
        if (saved.stage == OrganizationStage.chat) saved.organizedBody = null;
        draft = saved;
      } else {
        final entry = await ref
            .read(vaultRepositoryProvider)
            .loadEntry(session, entryId);
        _ensure(version);
        if (entry == null) throw const AiFailure(AiErrorCode.storage);
        draft = DiaryOrganization(
          source: entry,
          connection: settings.connection.activeConfig.captureRequestSnapshot(),
        );
      }
      await refreshConflict();
    } on Object catch (failure) {
      if (version == _version) {
        error = failure is AiFailure ? failure.code : AiErrorCode.storage;
      }
    } finally {
      if (!_disposed && version == _version) {
        loading = false;
        notifyListeners();
      }
    }
  }

  PersonNameHits _nameHits(String text) =>
      personNameRanges(text, _personMatcher);

  Future<void> _syncPersonMatcher(
    UnlockedVaultSession session,
    int version, {
    bool? hidePersonNames,
  }) async {
    final hide =
        hidePersonNames ??
        (await ref.read(aiSettingsStoreProvider).read(session)).hidePersonNames;
    _ensure(version);
    if (!hide) {
      _personMatcher = null;
      return;
    }
    final people = await ref.read(vaultRepositoryProvider).listPeople(session);
    _ensure(version);
    _personMatcher = PersonNameMatcher(people);
  }

  /// 人物隱藏開關只更新之後送出用的姓名掃描，不改已保存的手動區間。
  Future<void> refreshPrivacyPreset() async {
    final session = vault;
    final current = draft;
    if (session == null || current == null || busy || _disposed) return;
    final version = _version;
    await _syncPersonMatcher(session, version);
    if (_disposed || version != _version || draft != current) return;
    notifyListeners();
  }

  void _ensure(int version) {
    if (_disposed || version != _version || vault == null) {
      throw const AiFailure(AiErrorCode.storage);
    }
  }

  Future<void> refreshConflict() async {
    final session = vault;
    final current = draft;
    if (session == null || current == null) return;
    final latest = await ref
        .read(vaultRepositoryProvider)
        .loadEntry(session, entryId);
    final editing = await ref
        .read(editorDraftStoreProvider)
        .read(entryId, session);
    if (draft != current || vault != session || _disposed) return;
    if (latest == null) {
      ++_version;
      _client?.close();
      _client = null;
      _saveTimer?.cancel();
      draft = null;
      _personMatcher = null;
      _requests.clear();
      generationPhase = OrganizationGenerationPhase.idle;
      busy = false;
      loading = false;
      error = AiErrorCode.storage;
      notifyListeners();
      return;
    }
    conflict =
        organizationEntrySignature(latest) !=
        organizationEntrySignature(current.source);
    editorDraftExists = editing != null;
    notifyListeners();
  }

  bool get canStart {
    final current = draft;
    if (current == null || busy || conflict || editorDraftExists) return false;
    final text = current.source.markdownBody;
    var visible = text;
    for (final range in mergePrivateRanges(
      current.hiddenRanges,
      text.length,
    ).reversed) {
      visible = visible.replaceRange(range.start, range.end, '');
    }
    visible = visible.replaceAll(RegExp(r'!\[[^\]]*\]\([^\n]*?\)'), '');
    return visible.trim().isNotEmpty;
  }

  void updatePrivacy(
    List<PrivateTextRange> ranges, [
    List<PrivateTextRange> revealed = const [],
  ]) {
    final current = draft;
    if (current == null || busy || current.stage != OrganizationStage.privacy) {
      return;
    }
    if (samePrivateRanges(current.hiddenRanges, ranges) &&
        samePrivateRanges(current.revealedRanges, revealed)) {
      return;
    }
    current.hiddenRanges = List.of(ranges);
    current.revealedRanges = List.of(revealed);
    current.protectedSource = '';
    current.originals.clear();
    current.automaticTokenIds.clear();
    // 區間變了就要重算；留下的明文清單會讓重新隱藏的個資繼續外送。
    current.revealedSecrets.clear();
    current.personTokenById.clear();
    current.tokenSurfaces.clear();
    _dirty = true;
    _scheduleSave();
    notifyListeners();
  }

  void updateComposer(
    String text,
    List<PrivateTextRange> ranges, [
    List<PrivateTextRange> revealed = const [],
  ]) {
    if (draft == null || busy) return;
    draft!.composer = text;
    draft!.composerRanges = List.of(ranges);
    draft!.composerRevealed = List.of(revealed);
    _dirty = true;
    _scheduleSave();
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(
      const Duration(milliseconds: 250),
      () => unawaited(persist()),
    );
  }

  Future<void> persist({bool rethrowError = false}) async {
    _saveTimer?.cancel();
    final current = draft;
    final session = vault;
    final version = _version;
    if (current == null || session == null || !current.persisted && !_dirty) {
      return;
    }
    try {
      await _store.save(current, session, isCurrent: () => version == _version);
      if (ref.mounted) ref.invalidate(organizationDraftProvider(entryId));
    } on Object {
      if (version == _version) {
        error = AiErrorCode.storage;
        if (!_disposed) notifyListeners();
      }
      if (rethrowError) throw const AiFailure(AiErrorCode.storage);
    }
  }

  Future<void> changeConnection(AiConnectionConfig connection) async {
    if (busy || draft == null) return;
    draft!.connection = connection.captureRequestSnapshot();
    error = null;
    if (draft!.persisted) await persist();
    notifyListeners();
  }

  Future<void> startChat() async {
    if (!canStart || draft!.stage != OrganizationStage.privacy) return;
    final version = _version;
    final keepAlive = ref.keepAlive();
    busy = true;
    notifyListeners();
    try {
      await refreshConflict();
      _ensure(version);
      if (conflict || editorDraftExists) return;
      final session = vault;
      if (session == null) return;
      await _syncPersonMatcher(session, version);
      final hits = _nameHits(draft!.source.markdownBody);
      draft!.prepare(personRanges: hits.people, ambiguousNames: hits.ambiguous);
      _dirty = true;
      await persist(rethrowError: true);
    } finally {
      if (!_disposed && version == _version) {
        busy = false;
        notifyListeners();
      }
      keepAlive.close();
    }
  }

  Future<AiRequestPreview?> previewRequest({bool generate = false}) async {
    final current = draft;
    final session = vault;
    if (current == null || session == null || _disposed) return null;
    final version = _version;
    try {
      final requestContext = await _prepareRequestContext(session, generate);
      if (_disposed ||
          version != _version ||
          draft != current ||
          vault != session) {
        return null;
      }
      return (await _buildRequest(requestContext, generate: generate)).preview;
    } on Object {
      if (_disposed ||
          version != _version ||
          draft != current ||
          vault != session) {
        return null;
      }
      rethrow;
    }
  }

  Future<String> _prepareRequestContext(
    UnlockedVaultSession session,
    bool generate,
  ) async {
    final version = _version;
    final stored = await ref.read(aiSettingsStoreProvider).read(session);
    final language = await ref.read(userPreferencesProvider).appLocale;
    await _syncPersonMatcher(
      session,
      version,
      hidePersonNames: stored.hidePersonNames,
    );
    return resolveDiaryOrganizationInstructions(
      generate: generate,
      language: language,
      settings: stored.organizationPrompts,
    );
  }

  Future<_OrganizationRequest> _buildRequest(
    String prompt, {
    required bool generate,
    String? message,
    int? retryTurn,
  }) async {
    final current = draft!;
    final target = generate ? null : retryTurn ?? current.editingTurn;
    final path = current.activeTurnIndices
        .takeWhile((index) => index != target)
        .toList();
    final text = generate
        ? ''
        : retryTurn != null
        ? current.turns[retryTurn].user
        : message ?? current.composer;
    final matched = retryTurn == null ? _nameHits(text) : PersonNameHits.empty;
    final personRanges = matched.people;
    final ranges = <PrivateTextRange>[
      if (message == null && retryTurn == null) ...current.composerRanges,
    ];
    final key = jsonEncode([
      generate,
      prompt,
      current.connection.toSnapshotJson(),
      current.protectedSource,
      current.personTokenById,
      [for (final index in path) current.turns[index].toJson()],
      target,
      text,
      ranges.map((r) => r.toJson()).toList(),
      personRanges.map((r) => r.toJson()).toList(),
      matched.ambiguous.map((r) => r.toJson()).toList(),
      current.composerRevealed.map((r) => r.toJson()).toList(),
      (current.revealedSecrets.toList()..sort()),
    ]);
    final cached = _requests[generate];
    if (cached?.key == key) return cached!.request;
    final originals = Map<String, String>.of(current.originals);
    final personTokens = Map<String, String>.of(current.personTokenById);
    final pendingSurfaces = <String, List<String>>{};
    final automaticTokens = Set<String>.of(current.automaticTokenIds);
    final pending = generate
        ? null
        : retryTurn != null
        ? text
        : protectOrganizationText(
            text,
            ranges,
            originals,
            personRanges: personRanges,
            ambiguousNames: matched.ambiguous,
            revealedRanges: message == null && retryTurn == null
                ? current.composerRevealed
                : const [],
            personTokenById: personTokens,
            tokenSurfaces: pendingSurfaces,
            automaticTokenIds: automaticTokens,
            revealedSecrets: current.revealedSecrets,
          );
    if (retryTurn != null) {
      pendingSurfaces.addAll(current.turns[retryTurn].surfaces);
    }
    final messages = <AiInputMessage>[
      for (final index in path) ...[
        if (current.turns[index].user.isNotEmpty)
          AiInputMessage(isUser: true, text: current.turns[index].user),
        if (!current.turns[index].interrupted &&
            current.replyIsInScope(index) &&
            current.turns[index].reply.isNotEmpty)
          AiInputMessage(isUser: false, text: current.turns[index].reply),
      ],
      if (pending != null && pending.isNotEmpty)
        AiInputMessage(isUser: true, text: pending),
    ];
    final prepared = await prepareAiRequest(
      connection: current.connection,
      instructions: prompt,
      diaryBody: current.protectedSource,
      messages: messages,
      originals: originals,
      optionalPrivateTokens: automaticTokens,
      revealedSecrets: current.revealedSecrets,
    );
    final request = _OrganizationRequest(
      prepared: prepared,
      originals: originals,
      personTokens: personTokens,
      pendingSurfaces: pendingSurfaces,
      pending: pending,
      parent: target == null
          ? path.lastOrNull
          : current.turns[target].parentIndex,
    );
    _requests[generate] = (key: key, request: request);
    return request;
  }

  Future<void> sendMessage({String? message, int? retryTurn}) async {
    if (!ref.read(aiEnabledProvider)) return;
    if (!canInteract || draft!.stage != OrganizationStage.chat) return;
    if (message != null && draft!.editingTurn != null) return;
    if (retryTurn == null && (message ?? draft!.composer).trim().isEmpty) {
      return;
    }
    await _request(generate: false, message: message, retryTurn: retryTurn);
  }

  Future<void> generateDraft() async {
    if (!canGenerate) return;
    await _request(generate: true);
  }

  void _setGenerationPhase(OrganizationGenerationPhase phase) {
    generationPhase = phase;
    notifyListeners();
  }

  Future<void> _request({
    required bool generate,
    String? message,
    int? retryTurn,
  }) async {
    final current = draft!;
    final session = vault!;
    final keepAlive = ref.keepAlive();
    final version = ++_version;
    var savedResult = false;
    busy = true;
    error = null;
    generationPhase = generate
        ? OrganizationGenerationPhase.preparing
        : OrganizationGenerationPhase.idle;
    notifyListeners();
    try {
      _ensure(version);
      await refreshConflict();
      _ensure(version);
      if (conflict || editorDraftExists) return;
      final connection = current.connection;
      final key = await requireAiRequestKey(
        enabled: ref.read(aiEnabledProvider),
        connection: connection,
        readApiKey: () =>
            ref.read(aiSettingsStoreProvider).readApiKey(connection),
      );
      _ensure(version);
      final requestContext = await _prepareRequestContext(session, generate);
      _ensure(version);
      final request = await _buildRequest(
        requestContext,
        generate: generate,
        message: message,
        retryTurn: retryTurn,
      );
      final prepared = request.prepared;
      current.automaticTokenIds.addAll(prepared.automaticTokenIds);
      current.originals.addAll(request.originals);
      current.protectedSource = prepared.internalDiary!;
      OrganizationTurn? turn;
      if (generate) {
        current.generationInterrupted = true;
      } else {
        current.originals.addAll(request.originals);
        current.personTokenById.addAll(request.personTokens);
        turn = OrganizationTurn(
          user: request.pending!,
          parentIndex: request.parent,
          surfaces: {
            for (final entry in request.pendingSurfaces.entries)
              entry.key: List<String>.of(entry.value),
          },
        );
        current.appendTurn(turn);
        if (message == null && retryTurn == null) {
          _restoreComposer(current);
        }
      }
      _dirty = true;
      notifyListeners();
      await persist(rethrowError: true);
      _ensure(version);
      _client = ref.read(aiClientFactoryProvider)(connection, key);
      if (generate) _setGenerationPhase(OrganizationGenerationPhase.receiving);
      final output = StringBuffer();
      await for (final delta in _client!.reply(prepared)) {
        _ensure(version);
        output.write(delta);
        if (turn != null) {
          turn.reply = output.toString();
          _scheduleSave();
          notifyListeners();
        }
      }
      _ensure(version);
      final text = output.toString().trim();
      if (text.isEmpty) throw const AiFailure(AiErrorCode.response);
      if (generate) {
        _setGenerationPhase(OrganizationGenerationPhase.validating);
        final response = organizationGenerationPayload(text);
        if (response == null) throw const AiFailure(AiErrorCode.response);
        final next = DiaryOrganization.fromJson(current.toJson());
        final body = response['body'] as String;
        final allowed = privacyTokenPattern
            .allMatches(request.diaryContext.diaryBody)
            .map((m) => m[0]!)
            .toSet();
        for (final message in request.messages.where((m) => m.isUser)) {
          allowed.addAll(
            privacyTokenPattern.allMatches(message.text).map((m) => m[0]!),
          );
        }
        allowed.addAll(prepared.knownTokens);
        next.replaceBody(body, allowedTokens: allowed);
        final reply = (response['reply'] as String).trim();
        _ensure(version);
        next.generationReply = reply.isEmpty ? null : reply;
        next.generationInterrupted = false;
        next.stage = OrganizationStage.review;
        _setGenerationPhase(OrganizationGenerationPhase.saving);
        try {
          await _store.save(
            next,
            session,
            isCurrent: () => version == _version,
          );
        } on Object {
          throw const AiFailure(AiErrorCode.storage);
        }
        _ensure(version);
        draft = next;
        savedResult = true;
        ref.invalidate(organizationDraftProvider(entryId));
      } else {
        if (!current.replyIsInScope(current.turns.indexOf(turn!), text: text)) {
          throw const AiFailure(AiErrorCode.response);
        }
        turn.reply = text;
        turn.interrupted = false;
      }
    } on Object catch (failure) {
      if (version == _version) {
        error = failure is AiFailure ? failure.code : AiErrorCode.response;
      }
    } finally {
      if (version == _version && !_disposed) {
        _client?.close();
        _client = null;
        busy = false;
        generationPhase = OrganizationGenerationPhase.idle;
        if (!savedResult) await persist();
        if (!_disposed) notifyListeners();
      }
      keepAlive.close();
    }
  }

  Future<void> beginEditing(int index) async {
    final current = draft;
    if (current == null || busy) return;
    current.composerBackup ??= AiComposerSnapshot(
      text: current.composer,
      ranges: List.of(current.composerRanges),
      revealed: List.of(current.composerRevealed),
      imageIds: [],
    );
    final visible = current.visibleText(
      current.turns[index].user,
      turn: index,
      surfaces: current.turns[index].surfaces,
    );
    current.editingTurn = index;
    current.composer = visible.text;
    current.composerRanges = visible.ranges;
    current.composerRevealed = [];
    await persist();
    notifyListeners();
  }

  void _restoreComposer(DiaryOrganization current) {
    final backup = current.composerBackup;
    current.composer = backup?.text ?? '';
    current.composerRanges = List.of(backup?.ranges ?? const []);
    current.composerRevealed = List.of(backup?.revealed ?? const []);
    current.composerBackup = null;
    current.editingTurn = null;
  }

  Future<void> cancelEditing() async {
    final current = draft;
    if (current == null || busy) return;
    _restoreComposer(current);
    await persist();
    notifyListeners();
  }

  Future<void> selectTurn(int index) async {
    if (draft == null || busy || draft!.editingTurn != null) return;
    draft!.selectTurn(index);
    await persist();
    notifyListeners();
  }

  Future<void> selectModel(ChatModelOption option) async {
    final current = draft;
    final session = vault;
    if (current == null ||
        session == null ||
        busy ||
        option.isCurrentSnapshot) {
      return;
    }
    final version = _version;
    final store = ref.read(aiSettingsStoreProvider);
    final stored = await store.read(session);
    _ensure(version);
    if (draft != current || busy) return;
    final next = connectionForSelectedModel(stored.connection, option);
    if (next == null) return;
    await changeConnection(next);
    _ensure(version);
    await store.updateActiveConnection(session, next);
  }

  Future<void> editBody(String body) async {
    if (!canInteract || draft!.organizedBody == null) return;
    final version = _version;
    final keepAlive = ref.keepAlive();
    busy = true;
    notifyListeners();
    try {
      final next = DiaryOrganization.fromJson(draft!.toJson());
      next.replaceBody(body);
      next.generationReply = null;
      await _store.save(next, vault!, isCurrent: () => version == _version);
      _ensure(version);
      draft = next;
      ref.invalidate(organizationDraftProvider(entryId));
    } finally {
      if (!_disposed && version == _version) {
        busy = false;
        notifyListeners();
      }
      keepAlive.close();
    }
  }

  Future<void> returnToChat() async {
    if (busy || draft == null || vault == null) return;
    final version = _version;
    final keepAlive = ref.keepAlive();
    busy = true;
    error = null;
    notifyListeners();
    try {
      final next = DiaryOrganization.fromJson(draft!.toJson())
        ..organizedBody = null
        ..generationReply = null
        ..generationInterrupted = false
        ..stage = OrganizationStage.chat;
      await _store.save(next, vault!, isCurrent: () => version == _version);
      _ensure(version);
      draft = next;
      _requests.clear();
      ref.invalidate(organizationDraftProvider(entryId));
    } finally {
      if (!_disposed && version == _version) {
        busy = false;
        notifyListeners();
      }
      keepAlive.close();
    }
  }

  Future<DiaryEntry?> apply() async {
    if (busy ||
        draft == null ||
        vault == null ||
        draft!.organizedBody == null ||
        draft!.hasUnsafeCandidate) {
      return null;
    }
    busy = true;
    error = null;
    final version = _version;
    final keepAlive = ref.keepAlive();
    notifyListeners();
    try {
      await refreshConflict();
      _ensure(version);
      if (conflict || editorDraftExists) return null;
      draft!.stage = OrganizationStage.applying;
      notifyListeners();
      final saved = await _store.apply(
        draft!,
        vault!,
        ensureCurrent: () => _ensure(version),
      );
      _ensure(version);
      if (saved == null) {
        conflict = true;
        return null;
      }
      ref.read(diaryRevisionProvider.notifier).bump();
      ref.invalidate(entryProvider(entryId));
      ref.invalidate(editorDraftKeysProvider);
      ref.invalidate(organizationDraftProvider(entryId));
      return saved;
    } on Object {
      error = AiErrorCode.storage;
      return null;
    } finally {
      if (version == _version) {
        busy = false;
        if (!_disposed) notifyListeners();
      }
      keepAlive.close();
    }
  }

  void stop() {
    if (busy && draft?.stage == OrganizationStage.applying) return;
    ++_version;
    _client?.close();
    _client = null;
    busy = false;
    generationPhase = OrganizationGenerationPhase.idle;
    unawaited(persist());
    notifyListeners();
  }

  Future<void> discard({bool restart = false}) async {
    if (busy && draft?.stage == OrganizationStage.applying) return;
    final version = ++_version;
    _saveTimer?.cancel();
    _client?.close();
    _client = null;
    busy = false;
    final session = vault;
    final previous = draft;
    draft = null;
    _personMatcher = null;
    _requests.clear();
    generationPhase = OrganizationGenerationPhase.idle;
    notifyListeners();
    try {
      await _store.delete(entryId);
    } on Object {
      if (!_disposed && version == _version) {
        draft = previous;
        notifyListeners();
      }
      rethrow;
    }
    if (_disposed || version != _version) return;
    _dirty = false;
    ref.invalidate(organizationDraftProvider(entryId));
    if (restart && session != null) await load(session);
    notifyListeners();
  }

  void lock() {
    ++_version;
    _saveTimer?.cancel();
    _client?.close();
    _client = null;
    final current = draft;
    final session = vault;
    if (current != null && session != null && (current.persisted || _dirty)) {
      unawaited(
        Future<void>.sync(() => _store.save(current, session))
            .catchError((Object _) {}),
      );
    }
    draft = null;
    _personMatcher = null;
    _requests.clear();
    generationPhase = OrganizationGenerationPhase.idle;
    vault = null;
    busy = false;
    loading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _personMatcher = null;
    _requests.clear();
    _saveTimer?.cancel();
    _client?.close();
    super.dispose();
  }
}

class _OrganizationRequest {
  const _OrganizationRequest({
    required this.prepared,
    required this.originals,
    required this.personTokens,
    required this.pendingSurfaces,
    required this.pending,
    required this.parent,
  });
  final PreparedAiRequest prepared;
  final Map<String, String> originals;
  final Map<String, String> personTokens;
  final Map<String, List<String>> pendingSurfaces;
  final String? pending;
  final int? parent;
  List<AiInputMessage> get messages => prepared.internalMessages;
  AiDiaryContext get diaryContext =>
      AiDiaryContext(diaryBody: prepared.internalDiary!);
  AiRequestPreview get preview => AiRequestPreview(
    request: prepared,
    instructions: prepared.internalInstructions,
    diaryContext: diaryContext,
    turns: [
      for (var i = 0; i < messages.length; i++)
        AiPreviewTurn(
          isUser: messages[i].isUser,
          text: messages[i].text,
          imageIds: const [],
          pending: pending?.isNotEmpty == true && i == messages.length - 1,
        ),
    ],
  );
}
