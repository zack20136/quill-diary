import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/ai/ai_connection_settings.dart';
import '../../domain/chat_diary/chat_diary_privacy_processor.dart';
import '../../domain/chat_diary/chat_diary_session.dart';
import '../../domain/security/unlocked_vault_session.dart';
import '../../domain/shared/value_objects.dart';
import '../../infrastructure/ai/ai_client.dart';
import '../../infrastructure/ai/ai_image_preparer.dart';
import '../../infrastructure/chat_diary/chat_diary_store.dart';
import '../../infrastructure/preferences/preferences_providers.dart';
import '../../infrastructure/storage/shared/media_type_utils.dart';
import '../../infrastructure/storage/storage_providers.dart';
import '../../l10n/app_localizations.dart';
import '../ai/ai_connection_providers.dart';
import 'chat_diary_prompt_resolver.dart';
import 'chat_diary_providers.dart';
import 'chat_diary_request_preview.dart';

enum ChatDiaryLoadResult { loaded, missing, cancelled, failed }

class ChatDiaryController extends ChangeNotifier {
  ChatDiaryController(this.ref) : _chatStore = ref.read(chatDiaryStoreProvider);
  final Ref ref;
  final ChatDiaryStore _chatStore;
  ChatDiarySession? chat;
  UnlockedVaultSession? _vaultSession;
  AiClient? _client;
  String? _clientApiKey;
  Timer? _saveTimer;
  int _operationVersion = 0;
  bool _disposed = false;
  bool _handedOff = false;
  bool busy = false;
  AiErrorCode? _error;
  String? _errorMessageId;
  bool _unexpectedError = false;
  AiErrorCode? get error => _error;
  String? get errorMessageId => _errorMessageId;
  bool get unexpectedError => _unexpectedError;

  void _setError(AiErrorCode? code, {String? messageId}) {
    _error = code;
    _errorMessageId = messageId;
    _unexpectedError = false;
  }

  void _setUnexpectedError({String? messageId}) {
    _error = null;
    _errorMessageId = messageId;
    _unexpectedError = true;
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
    String? newChatId,
    String? openingMessage,
  }) async {
    _cancelOperation();
    final operationVersion = _operationVersion;
    _vaultSession = vaultSession;
    chat = null;
    _setError(null);
    _handedOff = false;
    final connectionSettingsStore = ref.read(aiConnectionSettingsStoreProvider);
    final diarySettingsStore = ref.read(chatDiarySettingsStoreProvider);
    bool cancelled() => _disposed || operationVersion != _operationVersion;
    try {
      var chatSession = await read();
      if (cancelled()) return ChatDiaryLoadResult.cancelled;
      if (chatSession == null && newChatId != null) {
        final connectionSettings = await connectionSettingsStore.read();
        if (cancelled()) return ChatDiaryLoadResult.cancelled;
        final diarySettings = await diarySettingsStore.read();
        if (cancelled()) return ChatDiaryLoadResult.cancelled;
        final connectionConfig = connectionSettings.activeConfig;
        validateAiEndpoint(connectionConfig);
        if (!connectionConfig.isConfigured) {
          throw const AiFailure(AiErrorCode.configuration);
        }
        if (connectionConfig.provider.requiresApiKey) {
          final apiKey = await connectionSettingsStore.readApiKey(
            connectionConfig,
          );
          if (cancelled()) return ChatDiaryLoadResult.cancelled;
          if (apiKey.isEmpty) throw const AiFailure(AiErrorCode.configuration);
        }
        final now = DateTime.now();
        chatSession = ChatDiarySession(
          id: newChatId,
          vaultId: vaultSession.vaultId,
          connectionConfig: connectionConfig,
          hidePersonNames: diarySettings.hidePersonNames,
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
            .cleanupRemoteFiles(
              vaultSession,
              connectionSettingsStore.readApiKey,
            )
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

  void updateComposer(String text, List<ChatDiaryPrivateRange> ranges) {
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

  Future<void> suspendForEditor() async {
    final operationVersion = _operationVersion;
    await persist(throwOnError: true);
    _ensureOperationIsCurrent(operationVersion);
    _handedOff = true;
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

  Future<ChatDiaryRequestPreview?> previewConversation() async {
    final chatSession = chat;
    if (chatSession == null || _vaultSession == null) {
      return null;
    }
    final operationVersion = _operationVersion;
    final settingsStore = ref.read(chatDiarySettingsStoreProvider);
    final preferences = ref.read(userPreferencesProvider);
    try {
      final history = conversationHistory;
      final pending = chatSession.composer;
      final privacy = await _createPrivacyProcessor(history);
      _ensureOperationIsCurrent(operationVersion);
      final settings = await settingsStore.read();
      _ensureOperationIsCurrent(operationVersion);
      final language = await preferences.appLocale;
      _ensureOperationIsCurrent(operationVersion);
      final composer = privacy.protect(pending.text, pending.ranges, false);
      final prompt = privacy.protectPrompt(
        resolveChatDiaryPrompt(
          ChatDiaryPromptPurpose.conversation,
          language,
          settings.prompts,
        ),
      );
      final turns = <ChatDiaryPreviewTurn>[
        for (final message in history)
          if (message.isUser ||
              message.status == ChatDiaryMessageStatus.complete)
            ChatDiaryPreviewTurn(
              isUser: message.isUser,
              text: _protectedMessageText(privacy, message),
              imageIds: List.of(message.imageIds),
            ),
        if (composer.isNotEmpty || pending.imageIds.isNotEmpty)
          ChatDiaryPreviewTurn(
            isUser: true,
            text: composer,
            imageIds: List.of(pending.imageIds),
            pending: true,
          ),
      ];
      await persist(throwOnError: true);
      _ensureOperationIsCurrent(operationVersion);
      return ChatDiaryRequestPreview(systemPrompt: prompt, turns: turns);
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
    stop();
    chatSession.connectionConfig = connectionConfig;
    chatSession.hidePersonNames = hidePersonNames;
    _setError(null);
    await persist(throwOnError: true);
    notifyListeners();
  }

  Future<ChatDiaryPrivacyProcessor> _createPrivacyProcessor([
    Iterable<ChatDiaryMessage>? messages,
  ]) async {
    final chatSession = chat!;
    final vaultSession = _vaultSession!;
    final people = chatSession.hidePersonNames
        ? await ref.read(vaultPeopleServiceProvider).listPeople(vaultSession)
        : const <Never>[];
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
    final key = await ref
        .read(aiConnectionSettingsStoreProvider)
        .readApiKey(connectionConfig);
    _ensureOperationIsCurrent(operationVersion);
    if (!connectionConfig.isConfigured ||
        (key.isEmpty && connectionConfig.provider.requiresApiKey)) {
      throw const AiFailure(AiErrorCode.configuration);
    }
    if (_client == null || key != _clientApiKey) {
      _client?.close();
      _client = ref.read(aiClientFactoryProvider)(connectionConfig, key);
      _clientApiKey = key;
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
    final text = privacy.protect(
      message.isUser ? message.text : message.outboundText,
      message.isUser ? message.privateRanges : const [],
    );
    if (message.isUser && message.outboundText != text) {
      message.outboundText = text;
    }
    return text;
  }

  Future<List<AiInputMessage>> _buildRequestMessages(
    ChatDiaryPrivacyProcessor privacy,
    int operationVersion, {
    bool diary = false,
  }) async {
    final chatSession = chat!;
    final vaultSession = _vaultSession!;
    final result = <AiInputMessage>[];
    for (final message in chatSession.activeMessages) {
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
          text: _protectedMessageText(privacy, message),
          images: images,
        ),
      );
    }
    if (!diary) return result;
    return [
      AiInputMessage(
        isUser: true,
        text: jsonEncode([
          for (final message in result)
            {
              'role': message.isUser ? 'user' : 'assistant',
              'text': message.text,
            },
        ]),
        images: [for (final message in result) ...message.images],
      ),
    ];
  }

  Future<String> _resolveRequestPrompt(
    ChatDiaryPromptPurpose purpose,
    ChatDiaryPrivacyProcessor privacy,
    int operationVersion,
  ) async {
    final settingsStore = ref.read(chatDiarySettingsStoreProvider);
    final preferences = ref.read(userPreferencesProvider);
    final settings = await settingsStore.read();
    _ensureOperationIsCurrent(operationVersion);
    final language = await preferences.appLocale;
    _ensureOperationIsCurrent(operationVersion);
    return privacy.protectPrompt(
      resolveChatDiaryPrompt(purpose, language, settings.prompts),
    );
  }

  bool get canSend =>
      !busy &&
      chat != null &&
      !chat!.finished &&
      !_handedOff &&
      (chat!.composerText.trim().isNotEmpty ||
          chat!.pendingImageIds.isNotEmpty);
  bool get canGenerate =>
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
    chatSession.composer = ChatDiaryComposerSnapshot(
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
    await _requestReply(parentId: parentId, newComposer: chatSession.composer);
  }

  Future<void> regenerateReply(String messageId) async {
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
    await _requestReply(parentId: message.parentId);
  }

  Future<void> _requestReply({
    required String? parentId,
    ChatDiaryComposerSnapshot? newComposer,
  }) async {
    final chatSession = chat!;
    busy = true;
    _setError(null);
    final operationVersion = ++_operationVersion;
    ChatDiaryMessage? assistantMessage;
    notifyListeners();
    try {
      final history = chatSession.pathTo(parentId);
      final privacy = await _createPrivacyProcessor(history);
      _ensureOperationIsCurrent(operationVersion);
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
          privateTokenIds: privacy.requestPrivateTokens,
        );
        chatSession.appendMessage(message);
        replyParent = message.id;
        chatSession.composer =
            chatSession.editBackup ??
            ChatDiaryComposerSnapshot(text: '', ranges: [], imageIds: []);
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
        connectionSnapshot: chatSession.connectionConfig,
      );
      chatSession.appendMessage(assistantMessage);
      final prompt = await _resolveRequestPrompt(
        ChatDiaryPromptPurpose.conversation,
        privacy,
        operationVersion,
      );
      assistantMessage.systemPromptSnapshot = prompt;
      await persist(throwOnError: true);
      _ensureOperationIsCurrent(operationVersion);
      final messages = await _buildRequestMessages(privacy, operationVersion);
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
        busy = false;
        await persist();
        notifyListeners();
      }
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

  Future<bool> generate(AppLocalizations l10n) async {
    final chatSession = chat;
    final vaultSession = _vaultSession;
    if (!canGenerate || chatSession == null || vaultSession == null) {
      return false;
    }
    busy = true;
    _setError(null);
    final operationVersion = ++_operationVersion;
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
      final client = await _clientForOperation(operationVersion);
      final output = StringBuffer();
      await for (final delta in client.reply(prompt, messages)) {
        _ensureOperationIsCurrent(operationVersion);
        output.write(delta);
      }
      _ensureOperationIsCurrent(operationVersion);
      if (output.toString().trim().isEmpty) {
        throw const AiFailure(AiErrorCode.response);
      }
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
      _handedOff = true;
      return true;
    } on AiFailure catch (failure) {
      if (operationVersion == _operationVersion) _setError(failure.code);
    } on Object {
      if (operationVersion == _operationVersion) _setUnexpectedError();
    } finally {
      if (operationVersion == _operationVersion) {
        busy = false;
        notifyListeners();
      }
    }
    return false;
  }

  void _cancelOperation() {
    _operationVersion++;
    _saveTimer?.cancel();
    _client?.close();
    _client = null;
    _clientApiKey = null;
    busy = false;
    for (final message in chat?.activeMessages ?? <ChatDiaryMessage>[]) {
      if (message.status == ChatDiaryMessageStatus.pending) {
        message.status = ChatDiaryMessageStatus.interrupted;
      }
    }
  }

  void stop() {
    _cancelOperation();
    unawaited(persist());
    notifyListeners();
  }

  void lock() {
    stop();
    _saveTimer?.cancel();
    chat = null;
    _vaultSession = null;
    notifyListeners();
  }

  Future<void> delete() async {
    final chatSession = chat;
    final vaultSession = _vaultSession;
    if (chatSession == null || vaultSession == null || _handedOff) return;
    stop();
    final operationVersion = _operationVersion;
    _handedOff = true;
    busy = true;
    notifyListeners();
    try {
      await _chatStore.flush();
      _ensureOperationIsCurrent(operationVersion);
      await _chatStore.delete(
        chatSession.id,
        session: vaultSession,
        entryId: chatSession.generatedEntryId,
      );
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
    }
  }

  @override
  void dispose() {
    stop();
    _saveTimer?.cancel();
    _disposed = true;
    _vaultSession = null;
    chat = null;
    super.dispose();
  }
}
