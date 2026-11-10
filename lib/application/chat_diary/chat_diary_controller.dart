import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_diary/application/ai/ai_connection_providers.dart';
import 'package:quill_diary/application/ai/ai_prompts.dart';
import 'package:quill_diary/application/ai/ai_request_preview.dart';
import 'package:quill_diary/application/chat_diary/chat_diary_generations.dart';
import 'package:quill_diary/application/chat_diary/chat_diary_providers.dart';
import 'package:quill_diary/application/persona/persona_prompts.dart';
import 'package:quill_diary/application/persona/persona_providers.dart';
import 'package:quill_diary/application/session/session_providers.dart';
import 'package:quill_diary/application/settings/personalization_providers.dart';
import 'package:quill_diary/application/vault/vault_providers.dart';
import 'package:quill_diary/domain/ai/ai_composer_snapshot.dart';
import 'package:quill_diary/domain/ai/ai_connection_settings.dart';
import 'package:quill_diary/domain/ai/ai_failure.dart';
import 'package:quill_diary/domain/ai/private_text.dart';
import 'package:quill_diary/domain/chat_diary/chat_diary_generation.dart';
import 'package:quill_diary/domain/chat_diary/chat_diary_privacy_processor.dart';
import 'package:quill_diary/domain/chat_diary/chat_diary_session.dart';
import 'package:quill_diary/domain/people/person.dart';
import 'package:quill_diary/domain/persona/persona.dart';
import 'package:quill_diary/domain/persona/persona_reference.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/ai/ai_client.dart';
import 'package:quill_diary/infrastructure/ai/ai_image_preparer.dart';
import 'package:quill_diary/infrastructure/chat_diary/chat_diary_store.dart';
import 'package:quill_diary/infrastructure/storage/shared/media_type_utils.dart';
import 'package:quill_diary/l10n/l10n.dart';

enum ChatDiaryLoadResult { loaded, missing, cancelled, failed }

enum ChatDiaryGenerationResult { generated, empty, notGenerated }

class _LoadedPersona {
  const _LoadedPersona({this.record, this.failed = false});

  final PersonaRecord? record;
  final bool failed;
}

class ChatDiaryController extends ChangeNotifier {
  ChatDiaryController(this.ref) : _chatStore = ref.read(chatDiaryStoreProvider);
  final Ref ref;
  final ChatDiaryStore _chatStore;
  ChatDiarySession? chat;
  UnlockedVaultSession? _vaultSession;
  AiClient? _client;
  String? _clientApiKey;
  AiConnectionConfig? _clientConfig;
  Timer? _saveTimer;
  int _operationVersion = 0;
  bool _disposed = false;
  bool _handedOff = false;
  bool busy = false;
  bool personaUnavailable = false;
  ChatDiaryGeneration? _generation;
  AiErrorCode? _error;
  String? _errorMessageId;
  bool _unexpectedError = false;
  bool _errorFromGeneration = false;
  AiErrorCode? get error => _error;
  String? get errorMessageId => _errorMessageId;
  bool get unexpectedError => _unexpectedError;
  bool get errorFromGeneration => _errorFromGeneration;

  void _setError(
    AiErrorCode? code, {
    String? messageId,
    bool fromGeneration = false,
  }) {
    _error = code;
    _errorMessageId = messageId;
    _unexpectedError = false;
    _errorFromGeneration = fromGeneration;
  }

  void _setUnexpectedError({String? messageId, bool fromGeneration = false}) {
    _error = null;
    _errorMessageId = messageId;
    _unexpectedError = true;
    _errorFromGeneration = fromGeneration;
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  Future<ChatDiaryLoadResult> start(
    String id,
    UnlockedVaultSession vaultSession, {
    required String openingMessage,
  }) => _loadSession(
    () => _chatStore.load(id, vaultSession),
    vaultSession,
    chatId: id,
    newChatId: id,
    openingMessage: openingMessage,
  );

  Future<ChatDiaryLoadResult> load(
    String id,
    UnlockedVaultSession vaultSession, {
    String? openingMessage,
  }) => _loadSession(
    () => _chatStore.load(id, vaultSession),
    vaultSession,
    chatId: id,
    openingMessage: openingMessage,
  );

  Future<ChatDiaryLoadResult> loadForEntry(
    String entryId,
    UnlockedVaultSession vaultSession,
  ) => _loadSession(
    () => _chatStore.loadForEntry(entryId, vaultSession),
    vaultSession,
  );

  Future<ChatDiaryLoadResult> _loadSession(
    Future<ChatDiarySession?> Function() read,
    UnlockedVaultSession vaultSession, {
    String? chatId,
    String? newChatId,
    String? openingMessage,
  }) async {
    if (busy &&
        chatId != null &&
        chat?.id == chatId &&
        _vaultSession == vaultSession) {
      return ChatDiaryLoadResult.loaded;
    }
    _cancelOperation();
    final operationVersion = _operationVersion;
    _vaultSession = vaultSession;
    chat = null;
    _setError(null);
    _handedOff = false;
    final settingsStore = ref.read(aiSettingsStoreProvider);
    bool cancelled() => _disposed || operationVersion != _operationVersion;
    try {
      var chatSession = await read();
      if (cancelled()) return ChatDiaryLoadResult.cancelled;
      if (chatSession == null && newChatId != null) {
        final stored = await settingsStore.read(vaultSession);
        if (cancelled()) return ChatDiaryLoadResult.cancelled;
        final connectionConfig = stored.connection.activeConfig
            .captureRequestSnapshot();
        final now = DateTime.now();
        chatSession = ChatDiarySession(
          id: newChatId,
          vaultId: vaultSession.vaultId,
          connectionConfig: connectionConfig,
          hidePersonNames: stored.hidePersonNames,
          createdAt: now,
          date: DateOnly.fromDateTime(now).value,
          openingMessage: openingMessage ?? '',
        );
      }
      if (chatSession == null) {
        notifyListeners();
        return ChatDiaryLoadResult.missing;
      }
      chat = chatSession;
      if (chatSession.selectedPersona != null) {
        await _loadReplyPersona(chatSession.selectedPersona, operationVersion);
        if (cancelled()) return ChatDiaryLoadResult.cancelled;
      }
      var needsSave = false;
      for (final message in chatSession.messages) {
        if (message.status == ChatDiaryMessageStatus.pending) {
          message.status = ChatDiaryMessageStatus.interrupted;
          needsSave = true;
        }
      }
      if (chatSession.openingMessage.isEmpty &&
          chatSession.messages.isEmpty &&
          openingMessage != null) {
        chatSession.openingMessage = openingMessage;
        needsSave = true;
      }
      if (needsSave) await persist(throwOnError: true);
      if (cancelled()) return ChatDiaryLoadResult.cancelled;
      unawaited(
        _chatStore
            .cleanupRemoteFiles(vaultSession, settingsStore.readApiKey)
            .onError((_, _) => false),
      );
      notifyListeners();
      return ChatDiaryLoadResult.loaded;
    } on FormatException {
      if (cancelled()) return ChatDiaryLoadResult.cancelled;
      _setError(AiErrorCode.unreadable);
      notifyListeners();
      return ChatDiaryLoadResult.failed;
    } on Object catch (error) {
      if (cancelled()) return ChatDiaryLoadResult.cancelled;
      _setError(error is AiFailure ? error.code : AiErrorCode.storage);
      notifyListeners();
      return ChatDiaryLoadResult.failed;
    }
  }

  Future<ChatDiaryLoadResult> resumeAfterEditor(
    String chatId,
    UnlockedVaultSession vaultSession,
  ) async {
    final loading = load(chatId, vaultSession);
    final operationVersion = _operationVersion;
    final result = await loading;
    if (result != ChatDiaryLoadResult.loaded) return result;
    final chatSession = chat;
    bool isCurrent() =>
        !_disposed &&
        operationVersion == _operationVersion &&
        chat == chatSession &&
        _vaultSession == vaultSession;
    if (chatSession == null || !isCurrent()) {
      return ChatDiaryLoadResult.cancelled;
    }
    final draftStore = ref.read(editorDraftStoreProvider);
    final diaryDraft = await draftStore.read(
      ChatDiarySession.draftKeyFor(chatId),
      vaultSession,
    );
    if (!isCurrent()) return ChatDiaryLoadResult.cancelled;
    if (diaryDraft == null && chatSession.generatedEntryId != null) {
      chatSession.generatedEntryId = null;
      chatSession.generatedDraftSignature = null;
      chatSession.generatedFromMessageId = null;
      chatSession.generationPromptSnapshot = '';
      chatSession.generationConnectionSnapshot = null;
      await persist(throwOnError: true);
      if (!isCurrent()) return ChatDiaryLoadResult.cancelled;
    }
    return ChatDiaryLoadResult.loaded;
  }

  void updateComposer(String text, List<PrivateTextRange> ranges) {
    final chatSession = chat;
    if (chatSession == null || busy || chatSession.finished || _handedOff) {
      return;
    }
    chatSession.composerText = text;
    chatSession.composerRanges = List.of(ranges);
    _scheduleSave();
    notifyListeners();
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(
      const Duration(milliseconds: 250),
      () => unawaited(persist()),
    );
  }

  Future<void> persist({
    bool throwOnError = false,
    bool pruneImages = false,
  }) async {
    _saveTimer?.cancel();
    final chatSession = chat;
    final vaultSession = _vaultSession;
    final operationVersion = _operationVersion;
    if (chatSession == null ||
        vaultSession == null ||
        chatSession.finished ||
        _handedOff) {
      return;
    }
    try {
      await _chatStore.save(
        chatSession,
        vaultSession,
        pruneImages: pruneImages,
      );
    } on Object {
      if (_disposed ||
          operationVersion != _operationVersion ||
          chat != chatSession ||
          _vaultSession != vaultSession) {
        if (throwOnError) throw const AiFailure(AiErrorCode.storage);
        return;
      }
      _setError(
        AiErrorCode.storage,
        messageId: error == AiErrorCode.storage ? _errorMessageId : null,
      );
      notifyListeners();
      if (throwOnError) throw const AiFailure(AiErrorCode.storage);
    }
  }

  Future<void> addImage(Uint8List bytes) async {
    final chatSession = chat;
    final vaultSession = _vaultSession;
    if (chatSession == null ||
        vaultSession == null ||
        busy ||
        chatSession.finished ||
        _handedOff) {
      return;
    }
    final keepAlive = ref.keepAlive();
    final operationVersion = ++_operationVersion;
    _saveTimer?.cancel();
    busy = true;
    _setError(null);
    notifyListeners();
    final id = generateAssetId();
    var attached = false;
    try {
      final prepared = await prepareAiImage(id, bytes);
      _ensureOperationIsCurrent(operationVersion);
      final originalMime = sniffKnownMediaMimeType(bytes);
      final keepOriginal = originalMime?.startsWith('image/') == true;
      final mime = keepOriginal ? originalMime! : prepared.mimeType;
      final image = ChatDiaryImage(
        id: id,
        mimeType: mime,
        filename: 'image.${extensionFromMimeType(mime)}',
      );
      await _chatStore.saveImage(
        chatSession.id,
        image,
        keepOriginal ? bytes : prepared.bytes,
        vaultSession,
      );
      _ensureOperationIsCurrent(operationVersion);
      chatSession.images.add(image);
      chatSession.pendingImageIds.add(id);
      attached = true;
      await persist(throwOnError: true);
    } on AiFailure catch (failure) {
      if (operationVersion == _operationVersion) _setError(failure.code);
    } on Object {
      if (operationVersion == _operationVersion) _setError(AiErrorCode.image);
    } finally {
      if (!attached) {
        try {
          await _chatStore.deleteDraftImage(chatSession.id, id);
        } on Object {
          if (operationVersion == _operationVersion) {
            _setError(AiErrorCode.storage);
          }
        }
      }
      if (operationVersion == _operationVersion) {
        busy = false;
        notifyListeners();
      }
      keepAlive.close();
    }
  }

  void removePendingImage(String id) {
    final chatSession = chat;
    if (chatSession == null || busy || chatSession.finished || _handedOff) {
      return;
    }
    chatSession.pendingImageIds.remove(id);
    _pruneUnreferencedImages();
    unawaited(persist(pruneImages: true));
    notifyListeners();
  }

  void _pruneUnreferencedImages() {
    final chatSession = chat!;
    final referenced = chatSession.referencedImageIds;
    chatSession.images.removeWhere((image) => !referenced.contains(image.id));
  }

  Future<bool> handOffToEditor({required bool Function() canOpen}) async {
    final operationVersion = _operationVersion;
    await persist(throwOnError: true);
    _ensureOperationIsCurrent(operationVersion);
    if (!canOpen()) return false;
    _handedOff = true;
    return true;
  }

  List<ChatDiaryMessage> get conversationHistory {
    final chatSession = chat;
    if (chatSession == null) return const [];
    final editing = chatSession.editingMessageId;
    return editing == null
        ? chatSession.activeMessages
        : chatSession.pathTo(
            chatSession.messages
                .firstWhere((message) => message.id == editing)
                .parentId,
          );
  }

  Future<AiRequestPreview?> previewRequest({bool generate = false}) async {
    final chatSession = chat;
    if (chatSession == null || _vaultSession == null) {
      return null;
    }
    final operationVersion = _operationVersion;
    try {
      final history = generate
          ? chatSession.activeMessages
          : conversationHistory;
      final pending = chatSession.composer;
      final privacy = await _createPrivacyProcessor(history);
      _ensureOperationIsCurrent(operationVersion);
      final composer = generate
          ? ''
          : privacy.protect(pending.text, pending.ranges, false);
      final loadedPersona = generate
          ? null
          : await _loadReplyPersona(
              chatSession.selectedPersona,
              operationVersion,
            );
      _ensureOperationIsCurrent(operationVersion);
      final replyPersona = loadedPersona?.record;
      final missingPersonaName = lookupAppLocalizations(
        (await ref.read(userPreferencesProvider).appLocale).materialLocale,
      ).personaRoleFriend;
      _ensureOperationIsCurrent(operationVersion);
      final prompt = await _resolveRequestPrompt(
        generate
            ? ChatDiaryPromptPurpose.generation
            : ChatDiaryPromptPurpose.conversation,
        privacy,
        operationVersion,
        replyPersona: replyPersona,
      );
      final turns = <AiPreviewTurn>[
        for (final message in history)
          if (message.isUser ||
              message.status == ChatDiaryMessageStatus.complete)
            AiPreviewTurn(
              isUser: message.isUser,
              text: generate
                  ? _protectedMessageText(privacy, message)
                  : _conversationMessageText(
                      privacy,
                      message,
                      history,
                      forceAttribution: replyPersona != null,
                      missingPersonaName: missingPersonaName,
                    ),
              imageIds: List.of(message.imageIds),
            ),
        if (!generate && (composer.isNotEmpty || pending.imageIds.isNotEmpty))
          AiPreviewTurn(
            isUser: true,
            text: composer,
            imageIds: List.of(pending.imageIds),
            pending: true,
          ),
      ];
      await persist(throwOnError: true);
      _ensureOperationIsCurrent(operationVersion);
      return AiRequestPreview(
        instructions: prompt,
        conversationTurns: generate ? turns : null,
        turns: generate
            ? [
                AiPreviewTurn(
                  isUser: true,
                  text: _generationData(
                    privacy,
                    history,
                    missingPersonaName: missingPersonaName,
                  ),
                  imageIds: [for (final turn in turns) ...turn.imageIds],
                ),
              ]
            : turns,
      );
    } on Object {
      if (_disposed ||
          operationVersion != _operationVersion ||
          chat != chatSession) {
        return null;
      }
      rethrow;
    }
  }

  Future<void> applySettings(
    AiConnectionConfig connectionConfig,
    bool hidePersonNames,
  ) async {
    final chatSession = chat;
    if (chatSession == null ||
        chatSession.finished ||
        _vaultSession == null ||
        _handedOff) {
      return;
    }
    _cancelOperation(
      closeClient: busy || !sameAiClient(_clientConfig, connectionConfig),
    );
    chatSession.connectionConfig = connectionConfig.captureRequestSnapshot();
    chatSession.hidePersonNames = hidePersonNames;
    _setError(null);
    await persist(throwOnError: true);
    notifyListeners();
  }

  /// 改這一則聊天的供應商與模型，並記成下一則新聊天要用的。
  Future<void> selectModel(ChatModelOption option) async {
    final chatSession = chat;
    final session = _vaultSession;
    if (chatSession == null ||
        chatSession.finished ||
        busy ||
        _handedOff ||
        session == null ||
        option.isCurrentSnapshot) {
      return;
    }
    final operationVersion = _operationVersion;
    final store = ref.read(aiSettingsStoreProvider);
    final stored = await store.read(session);
    if (_disposed ||
        operationVersion != _operationVersion ||
        chat != chatSession ||
        _vaultSession != session ||
        _handedOff ||
        busy) {
      return;
    }
    final next = connectionForSelectedModel(stored.connection, option);
    if (next == null) return;
    final applying = applySettings(next, chatSession.hidePersonNames);
    final appliedVersion = _operationVersion;
    await applying;
    if (_disposed ||
        appliedVersion != _operationVersion ||
        chat != chatSession ||
        _vaultSession != session ||
        _handedOff) {
      return;
    }
    await store.updateActiveConnection(session, next);
  }

  Future<ChatDiaryPrivacyProcessor> _createPrivacyProcessor([
    Iterable<ChatDiaryMessage>? messages,
  ]) async {
    final chatSession = chat;
    final vaultSession = _vaultSession;
    final version = _operationVersion;
    if (chatSession == null || vaultSession == null) {
      throw const AiFailure(AiErrorCode.network);
    }
    final people = chatSession.hidePersonNames
        ? await ref.read(vaultRepositoryProvider).listPeople(vaultSession)
        : const <Person>[];
    _ensureOperationIsCurrent(version);
    return ChatDiaryPrivacyProcessor(chatSession, people, messages: messages);
  }

  void _ensureOperationIsCurrent(int operationVersion) {
    if (_disposed ||
        operationVersion != _operationVersion ||
        _vaultSession == null ||
        chat == null) {
      throw const AiFailure(AiErrorCode.network);
    }
  }

  Future<AiClient> _clientForOperation(int operationVersion) async {
    _ensureOperationIsCurrent(operationVersion);
    final connectionConfig = chat!.connectionConfig;
    final key = await requireAiRequestKey(
      enabled: ref.read(aiEnabledProvider),
      connection: connectionConfig,
      readApiKey: () =>
          ref.read(aiSettingsStoreProvider).readApiKey(connectionConfig),
    );
    _ensureOperationIsCurrent(operationVersion);
    if (_client == null ||
        key != _clientApiKey ||
        !sameAiClient(_clientConfig, connectionConfig)) {
      _client?.close();
      _client = ref.read(aiClientFactoryProvider)(connectionConfig, key);
      _clientApiKey = key;
      _clientConfig = connectionConfig;
      final chatValue = chat!;
      final vaultSession = _vaultSession!;
      _client!.onFileUploaded = (file) => _chatStore.trackRemoteFile(
        chatValue,
        file,
        vaultSession,
        connectionConfig: connectionConfig,
      );
    }
    return _client!;
  }

  String _protectedMessageText(
    ChatDiaryPrivacyProcessor privacy,
    ChatDiaryMessage message,
  ) {
    final text = message.isUser
        ? privacy.protect(
            message.text,
            message.privateRanges,
            true,
            message.personRanges,
          )
        : privacy.protect(message.outboundText);
    if (message.isUser && message.outboundText != text) {
      message.outboundText = text;
    }
    return text;
  }

  Future<List<AiInputMessage>> _buildRequestMessages(
    ChatDiaryPrivacyProcessor privacy,
    int operationVersion, {
    bool diary = false,
    List<ChatDiaryMessage>? history,
    bool personaReply = false,
  }) async {
    final chatSession = chat!;
    final vaultSession = _vaultSession!;
    final result = <AiInputMessage>[];
    final selectedHistory = history ?? chatSession.activeMessages;
    final missingPersonaName = lookupAppLocalizations(
      (await ref.read(userPreferencesProvider).appLocale).materialLocale,
    ).personaRoleFriend;
    _ensureOperationIsCurrent(operationVersion);
    for (final message in selectedHistory) {
      if (!message.isUser &&
          message.status != ChatDiaryMessageStatus.complete) {
        continue;
      }
      final images = <AiInputImage>[];
      for (final id in message.imageIds) {
        _ensureOperationIsCurrent(operationVersion);
        final bytes = await _chatStore.readImage(chatSession, id, vaultSession);
        _ensureOperationIsCurrent(operationVersion);
        if (bytes == null) throw const AiFailure(AiErrorCode.image);
        final prepared = await prepareAiImage(id, bytes);
        _ensureOperationIsCurrent(operationVersion);
        images.add(prepared);
      }
      result.add(
        AiInputMessage(
          isUser: message.isUser,
          text: diary
              ? _protectedMessageText(privacy, message)
              : _conversationMessageText(
                  privacy,
                  message,
                  selectedHistory,
                  forceAttribution: personaReply,
                  missingPersonaName: missingPersonaName,
                ),
          images: images,
        ),
      );
    }
    if (!diary) return result;
    return [
      AiInputMessage(
        isUser: true,
        text: _generationData(
          privacy,
          selectedHistory,
          missingPersonaName: missingPersonaName,
        ),
        images: [for (final message in result) ...message.images],
      ),
    ];
  }

  Future<String> _resolveRequestPrompt(
    ChatDiaryPromptPurpose purpose,
    ChatDiaryPrivacyProcessor privacy,
    int operationVersion, {
    PersonaRecord? replyPersona,
  }) async {
    final settingsStore = ref.read(aiSettingsStoreProvider);
    final preferences = ref.read(userPreferencesProvider);
    final prompts = (await settingsStore.read(_vaultSession!)).chatDiaryPrompts;
    _ensureOperationIsCurrent(operationVersion);
    final language = await preferences.appLocale;
    _ensureOperationIsCurrent(operationVersion);
    final l10n = lookupAppLocalizations(language.materialLocale);
    if (purpose == ChatDiaryPromptPurpose.conversation &&
        replyPersona != null) {
      final people = await ref
          .read(vaultRepositoryProvider)
          .listPeople(_vaultSession!);
      _ensureOperationIsCurrent(operationVersion);
      return buildPersonaConversationPrompt(
        personId: replyPersona.personId,
        personaId: replyPersona.personaId,
        cards: replyPersona.cards!,
        people: people,
        privacy: privacy,
        l10n: l10n,
        guidance: prompts.guidanceOverride,
      );
    }
    var prompt = resolveChatDiaryPrompt(purpose, language, prompts);
    if (purpose == ChatDiaryPromptPurpose.generation &&
        chat!.activeMessages.any((m) => m.persona != null)) {
      prompt = '${l10n.personaDiarySourcePrompt}\n\n$prompt';
    }
    return privacy.protectPrompt(prompt);
  }

  Map<String, String> _speaker(
    ChatDiaryPrivacyProcessor privacy,
    ChatDiaryMessage message, {
    required String missingPersonaName,
  }) {
    if (message.isUser) return const {'kind': 'user'};
    final persona = message.persona;
    if (persona == null) return const {'kind': 'ai_default'};
    return {
      'kind': 'ai_persona',
      'person': privacy.personaPersonToken(
        persona.personId,
        chat!.personaParticipants[persona.personaId]?.name ??
            missingPersonaName,
      ),
    };
  }

  String _conversationMessageText(
    ChatDiaryPrivacyProcessor privacy,
    ChatDiaryMessage message,
    List<ChatDiaryMessage> history, {
    bool forceAttribution = false,
    required String missingPersonaName,
  }) {
    final text = _protectedMessageText(privacy, message);
    if (message.isUser ||
        !forceAttribution && !history.any((m) => m.persona != null)) {
      return text;
    }
    return jsonEncode({
      'speaker': _speaker(
        privacy,
        message,
        missingPersonaName: missingPersonaName,
      ),
      'text': text,
    });
  }

  String _generationData(
    ChatDiaryPrivacyProcessor privacy,
    List<ChatDiaryMessage> history, {
    required String missingPersonaName,
  }) {
    final attributed = history.any((m) => m.persona != null);
    return jsonEncode([
      for (final message in history)
        if (message.isUser || message.status == ChatDiaryMessageStatus.complete)
          {
            'role': message.isUser ? 'user' : 'assistant',
            if (attributed)
              'speaker': _speaker(
                privacy,
                message,
                missingPersonaName: missingPersonaName,
              ),
            'text': _protectedMessageText(privacy, message),
          },
    ]);
  }

  Future<_LoadedPersona> _loadReplyPersona(
    PersonaReference? identity,
    int version,
  ) async {
    if (identity == null || _vaultSession == null) {
      return const _LoadedPersona();
    }
    PersonaRecord? record;
    try {
      record = await ref
          .read(personaStoreProvider)
          .load(identity.personId, _vaultSession!);
    } on Object {
      _ensureOperationIsCurrent(version);
      return const _LoadedPersona(failed: true);
    }
    _ensureOperationIsCurrent(version);
    if (!identity.matches(record)) {
      _forgetCurrentPersona(identity);
      return const _LoadedPersona();
    }
    final people = await ref
        .read(vaultRepositoryProvider)
        .listPeople(_vaultSession!);
    _ensureOperationIsCurrent(version);
    final person = people.where((p) => p.id == identity.personId).firstOrNull;
    if (person == null) {
      _forgetCurrentPersona(identity);
      return const _LoadedPersona();
    }
    chat!.personaParticipants.putIfAbsent(
      identity.personaId,
      () =>
          PersonaParticipant(name: person.name, accentArgb: person.accentArgb),
    );
    return _LoadedPersona(record: record);
  }

  void _forgetCurrentPersona(PersonaReference identity) {
    final selected = chat?.selectedPersona;
    if (selected?.personId != identity.personId ||
        selected?.personaId != identity.personaId) {
      return;
    }
    chat!.selectedPersona = null;
    personaUnavailable = true;
    notifyListeners();
  }

  Future<void> selectPersona(PersonaRecord? record) async {
    if (chat == null ||
        busy ||
        chat!.finished ||
        _handedOff ||
        _vaultSession == null) {
      return;
    }
    final previous = chat!.selectedPersona;
    final unavailable = personaUnavailable;
    final version = _operationVersion;
    if (record == null) {
      chat!.selectedPersona = null;
      personaUnavailable = false;
    } else {
      final identity = PersonaReference(
        personId: record.personId,
        personaId: record.personaId,
      );
      final resolved = await _loadReplyPersona(identity, version);
      _ensureOperationIsCurrent(version);
      if (resolved.failed || resolved.record == null) {
        if (chat!.selectedPersona != previous ||
            personaUnavailable != unavailable) {
          try {
            await persist(throwOnError: true);
          } on Object {
            chat!.selectedPersona = previous;
            personaUnavailable = unavailable;
            rethrow;
          }
        }
        notifyListeners();
        return;
      }
      chat!.selectedPersona = identity;
      personaUnavailable = false;
    }
    try {
      await persist(throwOnError: true);
    } on Object {
      chat!.selectedPersona = previous;
      personaUnavailable = unavailable;
      rethrow;
    }
    notifyListeners();
  }

  bool get canSend =>
      ref.read(aiEnabledProvider) &&
      !busy &&
      chat != null &&
      !chat!.finished &&
      !_handedOff &&
      (chat!.composerText.trim().isNotEmpty ||
          chat!.pendingImageIds.isNotEmpty);
  bool get canGenerate =>
      ref.read(aiEnabledProvider) &&
      !busy &&
      !_handedOff &&
      chat != null &&
      !chat!.finished &&
      chat!.editingMessageId == null &&
      chat!.activeMessages.any(
        (message) =>
            message.isUser &&
            (message.text.trim().isNotEmpty || message.imageIds.isNotEmpty),
      );

  void beginEditing(String messageId) {
    final chatSession = chat;
    if (chatSession == null ||
        busy ||
        chatSession.finished ||
        _handedOff ||
        chatSession.editingMessageId != null) {
      return;
    }
    final message = chatSession.activeMessages
        .where((message) => message.id == messageId && message.isUser)
        .firstOrNull;
    if (message == null) {
      return;
    }
    chatSession.editBackup = chatSession.composer;
    chatSession.editingMessageId = message.id;
    chatSession.composer = AiComposerSnapshot(
      text: message.text,
      ranges: List.of(message.privateRanges),
      imageIds: List.of(message.imageIds),
    );
    _setError(null);
    _scheduleSave();
    notifyListeners();
  }

  void cancelEditing() {
    final chatSession = chat;
    if (chatSession == null || busy || chatSession.editingMessageId == null) {
      return;
    }
    chatSession.composer = chatSession.editBackup!;
    chatSession.editingMessageId = null;
    chatSession.editBackup = null;
    _pruneUnreferencedImages();
    _setError(null);
    unawaited(persist(pruneImages: true));
    notifyListeners();
  }

  void selectVersion(String messageId) {
    final chatSession = chat;
    if (chatSession == null ||
        busy ||
        _handedOff ||
        chatSession.editingMessageId != null) {
      return;
    }
    chatSession.selectMessage(messageId);
    _setError(null);
    if (!chatSession.finished) {
      _scheduleSave();
    } else if (_vaultSession != null) {
      unawaited(
        _chatStore.save(chatSession, _vaultSession!).onError((_, _) {
          _setError(AiErrorCode.storage);
          notifyListeners();
        }),
      );
    }
    notifyListeners();
  }

  Future<void> send() async {
    if (!canSend || _vaultSession == null) {
      return;
    }
    final chatSession = chat!;
    final parentId = conversationHistory.lastOrNull?.id;
    await _requestReply(
      parentId: parentId,
      newComposer: chatSession.composer,
      replyAs: chatSession.selectedPersona,
    );
  }

  Future<void> regenerateReply(String messageId) async {
    if (!ref.read(aiEnabledProvider)) return;
    final chatSession = chat;
    if (chatSession == null ||
        busy ||
        chatSession.finished ||
        _vaultSession == null ||
        _handedOff ||
        chatSession.editingMessageId != null) {
      return;
    }
    final message = chatSession.activeMessages
        .where((message) => message.id == messageId && !message.isUser)
        .firstOrNull;
    if (message == null || message.parentId == null) {
      return;
    }
    await _requestReply(parentId: message.parentId, replyAs: message.persona);
  }

  Future<void> _requestReply({
    required String? parentId,
    AiComposerSnapshot? newComposer,
    PersonaReference? replyAs,
  }) async {
    final chatSession = chat!;
    final keepAlive = ref.keepAlive();
    busy = true;
    _setError(null);
    final operationVersion = ++_operationVersion;
    ChatDiaryMessage? assistantMessage;
    notifyListeners();
    try {
      final history = chatSession.pathTo(parentId);
      final privacy = await _createPrivacyProcessor(history);
      _ensureOperationIsCurrent(operationVersion);
      final loadedPersona = await _loadReplyPersona(replyAs, operationVersion);
      _ensureOperationIsCurrent(operationVersion);
      if (replyAs != null && loadedPersona.failed) {
        throw const AiFailure(AiErrorCode.unavailable);
      }
      final replyPersona = loadedPersona.record;
      var replyParent = parentId;
      if (newComposer != null) {
        final protected = privacy.protect(newComposer.text, newComposer.ranges);
        final message = ChatDiaryMessage(
          id: generateChatDiaryMessageId(),
          isUser: true,
          text: newComposer.text,
          outboundText: protected,
          parentId: parentId,
          imageIds: List.of(newComposer.imageIds),
          privateRanges: List.of(newComposer.ranges),
          personRanges: List.of(privacy.requestPersonRanges),
          privateTokenIds: privacy.requestPrivateTokens,
        );
        chatSession.appendMessage(message);
        replyParent = message.id;
        chatSession.composer =
            chatSession.editBackup ??
            AiComposerSnapshot(text: '', ranges: [], imageIds: []);
        chatSession.editingMessageId = null;
        chatSession.editBackup = null;
      }
      assistantMessage = ChatDiaryMessage(
        id: generateChatDiaryMessageId(),
        isUser: false,
        text: '',
        outboundText: '',
        parentId: replyParent,
        status: ChatDiaryMessageStatus.pending,
        connectionSnapshot: AiConnectionConfig.fromSnapshotJson(
          chatSession.connectionConfig.toSnapshotJson(),
        ),
        persona: replyPersona == null
            ? null
            : PersonaReference(
                personId: replyPersona.personId,
                personaId: replyPersona.personaId,
              ),
      );
      chatSession.appendMessage(assistantMessage);
      final prompt = await _resolveRequestPrompt(
        ChatDiaryPromptPurpose.conversation,
        privacy,
        operationVersion,
        replyPersona: replyPersona,
      );
      if (assistantMessage.persona == null) {
        assistantMessage.systemPromptSnapshot = prompt;
      }
      await persist(throwOnError: true);
      _ensureOperationIsCurrent(operationVersion);
      ref.invalidate(chatDiaryDraftsProvider);
      final messages = await _buildRequestMessages(
        privacy,
        operationVersion,
        history: chatSession.pathTo(replyParent),
        personaReply: replyPersona != null,
      );
      final client = await _clientForOperation(operationVersion);
      _ensureOperationIsCurrent(operationVersion);
      await for (final delta in client.reply(prompt, messages)) {
        _ensureOperationIsCurrent(operationVersion);
        assistantMessage.outboundText += delta;
        assistantMessage.text = privacy.restore(assistantMessage.outboundText);
        _scheduleSave();
        notifyListeners();
      }
      _ensureOperationIsCurrent(operationVersion);
      if (assistantMessage.outboundText.trim().isEmpty) {
        throw const AiFailure(AiErrorCode.response);
      }
      assistantMessage.status = ChatDiaryMessageStatus.complete;
    } on AiFailure catch (failure) {
      if (operationVersion == _operationVersion) {
        _setError(failure.code, messageId: assistantMessage?.id);
        assistantMessage?.status = ChatDiaryMessageStatus.failed;
        assistantMessage?.errorCode = failure.code.name;
      }
    } on Object {
      if (operationVersion == _operationVersion) {
        final message = assistantMessage;
        _setUnexpectedError(messageId: message?.id);
        if (message != null) {
          message.status = ChatDiaryMessageStatus.failed;
          message.errorCode = null;
        }
      }
    } finally {
      if (operationVersion == _operationVersion) {
        await persist();
        if (operationVersion == _operationVersion) {
          busy = false;
          ref.invalidate(chatDiaryDraftsProvider);
          notifyListeners();
        }
      }
      keepAlive.close();
    }
  }

  Future<bool> hasEditedDiaryDraft() async {
    final chatSession = chat;
    final vaultSession = _vaultSession;
    if (chatSession == null || vaultSession == null) {
      return false;
    }
    final record = await ref
        .read(editorDraftStoreProvider)
        .read(ChatDiarySession.draftKeyFor(chatSession.id), vaultSession);
    return record != null &&
        (chatSession.generatedDraftSignature == null ||
            await ChatDiaryStore.draftSignature(record) !=
                chatSession.generatedDraftSignature);
  }

  Future<ChatDiaryGenerationResult> generate(AppLocalizations l10n) async {
    if (!canGenerate) return ChatDiaryGenerationResult.notGenerated;
    return ref
        .read(appSessionProvider.notifier)
        .runSensitiveTask((_) => _generate(l10n));
  }

  Future<ChatDiaryGenerationResult> _generate(AppLocalizations l10n) async {
    final chatSession = chat;
    final vaultSession = _vaultSession;
    if (!canGenerate || chatSession == null || vaultSession == null) {
      return ChatDiaryGenerationResult.notGenerated;
    }
    final keepAlive = ref.keepAlive();
    busy = true;
    _setError(null);
    final operationVersion = ++_operationVersion;
    final generations = ref.read(chatDiaryGenerationsProvider.notifier);
    final generation = generations.begin(
      vaultId: vaultSession.vaultId,
      chatId: chatSession.id,
    );
    _generation = generation;
    var phase = ChatDiaryGenerationPhase.failed;
    notifyListeners();
    try {
      final privacy = await _createPrivacyProcessor();
      _ensureOperationIsCurrent(operationVersion);
      final prompt = await _resolveRequestPrompt(
        ChatDiaryPromptPurpose.generation,
        privacy,
        operationVersion,
      );
      final connectionConfig = chatSession.connectionConfig;
      final messages = await _buildRequestMessages(
        privacy,
        operationVersion,
        diary: true,
      );
      await persist(throwOnError: true);
      _ensureOperationIsCurrent(operationVersion);
      ref.invalidate(chatDiaryDraftsProvider);
      final client = await _clientForOperation(operationVersion);
      generations.update(generation, ChatDiaryGenerationPhase.waiting);
      final output = StringBuffer();
      var writing = false;
      await for (final delta in client.reply(prompt, messages)) {
        _ensureOperationIsCurrent(operationVersion);
        if (!writing && delta.isNotEmpty) {
          writing = true;
          generations.update(generation, ChatDiaryGenerationPhase.writing);
        }
        output.write(delta);
      }
      _ensureOperationIsCurrent(operationVersion);
      if (output.toString().trim().isEmpty) {
        phase = ChatDiaryGenerationPhase.empty;
        return ChatDiaryGenerationResult.empty;
      }
      generations.update(generation, ChatDiaryGenerationPhase.saving);
      final draft = privacy.restoreDiary(
        output.toString(),
        l10n.chatDiaryPrivateNotes,
      );
      await _chatStore.commitGeneratedDraft(
        chatSession,
        draft,
        vaultSession,
        prompt: prompt,
        connection: connectionConfig,
        ensureCurrent: () => _ensureOperationIsCurrent(operationVersion),
      );
      _ensureOperationIsCurrent(operationVersion);
      phase = ChatDiaryGenerationPhase.completed;
      return ChatDiaryGenerationResult.generated;
    } on AiFailure catch (failure) {
      if (operationVersion == _operationVersion) {
        _setError(failure.code, fromGeneration: true);
      }
    } on Object {
      if (operationVersion == _operationVersion) {
        _setUnexpectedError(fromGeneration: true);
      }
    } finally {
      if (operationVersion == _operationVersion) {
        _finishGeneration(phase, error: _error);
        busy = false;
        ref.invalidate(chatDiaryDraftsProvider);
        notifyListeners();
      }
      keepAlive.close();
    }
    return ChatDiaryGenerationResult.notGenerated;
  }

  void _cancelOperation({bool closeClient = true}) {
    _operationVersion++;
    _finishGeneration(ChatDiaryGenerationPhase.cancelled);
    _saveTimer?.cancel();
    if (closeClient) {
      _client?.close();
      _client = null;
      _clientApiKey = null;
      _clientConfig = null;
    }
    busy = false;
    for (final message in chat?.activeMessages ?? <ChatDiaryMessage>[]) {
      if (message.status == ChatDiaryMessageStatus.pending) {
        message.status = ChatDiaryMessageStatus.interrupted;
      }
    }
  }

  void _finishGeneration(ChatDiaryGenerationPhase phase, {AiErrorCode? error}) {
    final generation = _generation;
    if (generation == null) return;
    _generation = null;
    ref
        .read(chatDiaryGenerationsProvider.notifier)
        .update(generation, phase, error: error);
  }

  void stop() {
    _cancelOperation();
    unawaited(persist());
    notifyListeners();
  }

  void personaDeleted(String personId) {
    final value = chat;
    if (value == null) return;
    if (value.activeMessages.any(
      (m) =>
          m.status == ChatDiaryMessageStatus.pending &&
          m.persona?.personId == personId,
    )) {
      _cancelOperation();
    }
    if (value.selectedPersona?.personId == personId) {
      value.selectedPersona = null;
      personaUnavailable = true;
    }
    unawaited(persist());
    notifyListeners();
  }

  void lock() {
    _cancelOperation();
    unawaited(persist());
    _saveTimer?.cancel();
    chat = null;
    _vaultSession = null;
    notifyListeners();
  }

  void syncVaultSession(UnlockedVaultSession? session) {
    if (_vaultSession != null && _vaultSession != session) lock();
  }

  Future<void> delete(
    String id,
    UnlockedVaultSession vaultSession, {
    String? entryId,
  }) async {
    final chatSession = chat;
    if (_disposed ||
        (chatSession != null &&
            (chatSession.id != id || _vaultSession != vaultSession))) {
      throw const AiFailure(AiErrorCode.storage);
    }
    final keepAlive = ref.keepAlive();
    _vaultSession = vaultSession;
    _cancelOperation();
    final operationVersion = _operationVersion;
    final saving = persist(throwOnError: true);
    _handedOff = true;
    busy = true;
    notifyListeners();
    try {
      await saving;
      await _chatStore.flush();
      if (_disposed || operationVersion != _operationVersion) {
        throw const AiFailure(AiErrorCode.storage);
      }
      await _chatStore.delete(
        id,
        session: vaultSession,
        entryId: entryId ?? chatSession?.generatedEntryId,
      );
      ref
          .read(chatDiaryGenerationsProvider.notifier)
          .forget(vaultSession.vaultId, id);
      if (operationVersion == _operationVersion) {
        chat = null;
        _vaultSession = null;
      }
    } on Object {
      if (operationVersion == _operationVersion) _handedOff = false;
      rethrow;
    } finally {
      if (operationVersion == _operationVersion) {
        busy = false;
        notifyListeners();
      }
      keepAlive.close();
    }
  }

  @override
  void dispose() {
    _cancelOperation();
    unawaited(persist());
    _saveTimer?.cancel();
    _disposed = true;
    _vaultSession = null;
    chat = null;
    super.dispose();
  }
}
