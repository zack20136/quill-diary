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
import 'package:quill_diary/domain/ai/ai_connection_settings.dart';
import 'package:quill_diary/domain/ai/ai_failure.dart';
import 'package:quill_diary/domain/ai/private_text.dart';
import 'package:quill_diary/domain/diary/diary_entry.dart';
import 'package:quill_diary/domain/diary_organization/diary_organization.dart';
import 'package:quill_diary/domain/people/person_name_matcher.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
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
      return ref.read(diaryOrganizationStoreProvider).load(id, session);
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
      ref.listen(diaryRevisionProvider, (_, _) {
        if (controller.draft != null &&
            controller.draft!.stage != OrganizationStage.applying &&
            controller.draft!.stage != OrganizationStage.applied) {
          unawaited(controller.refreshConflict());
        }
      });
      return controller;
    });

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
    return canInteract &&
        current!.stage == OrganizationStage.chat &&
        current.editingTurn == null &&
        current.composer.trim().isEmpty &&
        current.activeTurnIndices.any(
          (i) => current.turns[i].user.isNotEmpty,
        ) &&
        last != null &&
        !current.turns[last].interrupted &&
        current.turns[last].reply.isNotEmpty;
  }

  PersonNameMatcher? _personMatcher;
  AiClient? _client;
  Timer? _saveTimer;
  int _version = 0;
  bool _disposed = false;
  bool _dirty = false;

  /// 使用者改過，或已從草稿載入的隱藏區間，不再依設定重算。
  bool _privacyConfirmed = false;
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
      final saved = await _store.load(entryId, session);
      _ensure(version);
      final settings = await ref.read(aiSettingsStoreProvider).read(session);
      _ensure(version);
      await _syncPersonMatcher(
        session,
        version,
        hidePersonNames: settings.hidePersonNames,
      );
      if (saved != null) {
        saved.classifyPersonTokens(_personRanges(saved.source.markdownBody));
        if (saved.stage == OrganizationStage.chat) saved.organizedBody = null;
        _privacyConfirmed = true;
        draft = saved;
      } else {
        final entry = await ref
            .read(vaultRepositoryProvider)
            .loadEntry(session, entryId);
        _ensure(version);
        if (entry == null) throw const AiFailure(AiErrorCode.storage);
        _privacyConfirmed = false;
        draft = DiaryOrganization(
          source: entry,
          connection: settings.connection.activeConfig,
        )..hiddenRanges = _presetRanges(entry.markdownBody);
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

  List<PersonTextRange> _personRanges(String text) {
    final matcher = _personMatcher;
    if (matcher == null) return const [];
    return [
      for (final span in matcher.findSpans(text))
        PersonTextRange(span.start, span.end, span.personId),
    ];
  }

  List<PrivateTextRange> _presetRanges(String text) => [
    for (final range in _personRanges(text))
      PrivateTextRange(range.start, range.end),
  ];

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

  void _applyUnconfirmedPreset() {
    final current = draft;
    if (current == null ||
        _privacyConfirmed ||
        current.stage != OrganizationStage.privacy ||
        current.protectedSource.isNotEmpty) {
      return;
    }
    current.hiddenRanges = _presetRanges(current.source.markdownBody);
  }

  /// 尚未確認的預選跟著最新人物隱藏設定更新。
  Future<void> refreshPrivacyPreset() async {
    final session = vault;
    final current = draft;
    if (session == null || current == null || busy || _disposed) return;
    final version = _version;
    await _syncPersonMatcher(session, version);
    if (_disposed || version != _version || draft != current) return;
    _applyUnconfirmedPreset();
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

  void updatePrivacy(List<PrivateTextRange> ranges) {
    final current = draft;
    if (current == null || busy || current.stage != OrganizationStage.privacy) {
      return;
    }
    if (jsonEncode(current.hiddenRanges.map((r) => r.toJson()).toList()) ==
        jsonEncode(ranges.map((r) => r.toJson()).toList())) {
      return;
    }
    current.hiddenRanges = List.of(ranges);
    current.protectedSource = '';
    current.originals.clear();
    current.personTokenById.clear();
    current.tokenSurfaces.clear();
    _privacyConfirmed = true;
    _dirty = true;
    _scheduleSave();
    notifyListeners();
  }

  void updateComposer(String text, List<PrivateTextRange> ranges) {
    if (draft == null || busy) return;
    draft!.composer = text;
    draft!.composerRanges = List.of(ranges);
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
    draft!.connection = connection;
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
      _applyUnconfirmedPreset();
      draft!.prepare(personRanges: _personRanges(draft!.source.markdownBody));
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
    final prompt = await _prepareRequestContext(session, generate);
    if (_disposed ||
        version != _version ||
        draft != current ||
        vault != session) {
      return null;
    }
    return _buildRequest(prompt, generate: generate).preview;
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
    return resolveDiaryOrganizationPrompt(
      generate: generate,
      language: language,
      settings: stored.organizationPrompts,
    );
  }

  _OrganizationRequest _buildRequest(
    String prompt, {
    required bool generate,
    String? message,
    int? retryTurn,
  }) {
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
    final personRanges = retryTurn == null
        ? _personRanges(text)
        : <PersonTextRange>[];
    final ranges = <PrivateTextRange>[
      if (message == null && retryTurn == null) ...current.composerRanges,
      for (final range in personRanges)
        PrivateTextRange(range.start, range.end),
    ];
    final key = jsonEncode([
      generate,
      prompt,
      current.connection.toJson(),
      current.protectedSource,
      current.personTokenById,
      [for (final index in path) current.turns[index].toJson()],
      target,
      text,
      ranges.map((r) => r.toJson()).toList(),
      personRanges.map((r) => r.toJson()).toList(),
    ]);
    final cached = _requests[generate];
    if (cached?.key == key) return cached!.request;
    final originals = Map<String, String>.of(current.originals);
    final personTokens = Map<String, String>.of(current.personTokenById);
    final pendingSurfaces = <String, List<String>>{};
    final pending = generate
        ? null
        : retryTurn != null
        ? text
        : protectOrganizationText(
            text,
            ranges,
            originals,
            personRanges: personRanges,
            personTokenById: personTokens,
            tokenSurfaces: pendingSurfaces,
          );
    if (retryTurn != null) {
      pendingSurfaces.addAll(current.turns[retryTurn].surfaces);
    }
    final messages = <AiInputMessage>[
      for (final index in path) ...[
        if (current.turns[index].user.isNotEmpty)
          AiInputMessage(isUser: true, text: current.turns[index].user),
        if (!current.turns[index].interrupted &&
            current.turns[index].reply.isNotEmpty)
          AiInputMessage(isUser: false, text: current.turns[index].reply),
      ],
      if (pending != null && pending.isNotEmpty)
        AiInputMessage(isUser: true, text: pending),
    ];
    final request = _OrganizationRequest(
      instructions: prompt,
      diaryContext: AiDiaryContext(originalBody: current.protectedSource),
      messages: messages,
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
      await refreshConflict();
      _ensure(version);
      if (conflict || editorDraftExists) return;
      final connection = current.connection;
      if (!connection.isConfigured) {
        throw const AiFailure(AiErrorCode.configuration);
      }
      validateAiEndpoint(connection);
      final key = await ref
          .read(aiSettingsStoreProvider)
          .readApiKey(connection);
      _ensure(version);
      if (connection.provider.requiresApiKey && key.isEmpty) {
        throw const AiFailure(AiErrorCode.configuration);
      }
      final prompt = await _prepareRequestContext(session, generate);
      _ensure(version);
      final request = _buildRequest(
        prompt,
        generate: generate,
        message: message,
        retryTurn: retryTurn,
      );
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
          current.composer = current.composerBackup?.text ?? '';
          current.composerRanges = List.of(
            current.composerBackup?.ranges ?? [],
          );
          current.composerBackup = null;
          current.editingTurn = null;
        }
      }
      _dirty = true;
      notifyListeners();
      await persist(rethrowError: true);
      _ensure(version);
      _client = ref.read(aiClientFactoryProvider)(connection, key);
      if (generate) _setGenerationPhase(OrganizationGenerationPhase.receiving);
      final output = StringBuffer();
      await for (final delta in _client!.reply(
        request.systemPrompt,
        request.messages,
      )) {
        _ensure(version);
        output.write(delta);
        if (turn != null) {
          turn.reply = output.toString();
          _scheduleSave();
          notifyListeners();
        }
      }
      _ensure(version);
      var text = output.toString().trim();
      if (text.isEmpty) throw const AiFailure(AiErrorCode.response);
      if (generate) {
        _setGenerationPhase(OrganizationGenerationPhase.validating);
        if (text.startsWith('```')) {
          text = text
              .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
              .replaceFirst(RegExp(r'\s*```$'), '');
        }
        final response = jsonDecode(text) as Map<String, dynamic>;
        if (response['reply'] is! String) throw const FormatException('缺少整理說明');
        final next = DiaryOrganization.fromJson(current.toJson());
        final body = response['body'] as String;
        if (body.trim().isEmpty) throw const FormatException('整理稿不可空白');
        next.replaceBody(body);
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
        turn!.reply = text;
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
      imageIds: [],
    );
    final visible = organizationVisibleText(
      current.turns[index].user,
      current.originals,
      surfaces: current.turns[index].surfaces,
    );
    current.editingTurn = index;
    current.composer = visible.text;
    current.composerRanges = visible.ranges;
    await persist();
    notifyListeners();
  }

  Future<void> cancelEditing() async {
    final current = draft;
    if (current == null || busy) return;
    current.composer = current.composerBackup?.text ?? '';
    current.composerRanges = List.of(current.composerBackup?.ranges ?? []);
    current.composerBackup = null;
    current.editingTurn = null;
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
        draft!.organizedBody == null) {
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
      unawaited(_store.save(current, session).catchError((Object _) {}));
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
    required this.instructions,
    required this.diaryContext,
    required this.messages,
    required this.originals,
    required this.personTokens,
    required this.pendingSurfaces,
    required this.pending,
    required this.parent,
  });
  final String instructions;
  final AiDiaryContext diaryContext;
  final List<AiInputMessage> messages;
  String get systemPrompt => preview.systemPrompt;
  final Map<String, String> originals;
  final Map<String, String> personTokens;
  final Map<String, List<String>> pendingSurfaces;
  final String? pending;
  final int? parent;
  AiRequestPreview get preview => AiRequestPreview(
    instructions: instructions,
    diaryContext: diaryContext,
    turns: [
      for (var i = 0; i < messages.length; i++)
        AiPreviewTurn(
          isUser: messages[i].isUser,
          text: messages[i].text,
          imageIds: [],
          pending:
              pending != null &&
              pending!.isNotEmpty &&
              i == messages.length - 1,
        ),
    ],
  );
}
