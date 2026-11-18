import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart' show getCrc32;
import 'package:quill_diary/domain/ai/ai_catalog.dart';
import 'package:quill_diary/domain/ai/ai_connection_settings.dart';
import 'package:quill_diary/domain/ai/ai_failure.dart';
import 'package:quill_diary/domain/ai/ai_stored_settings.dart';
import 'package:quill_diary/domain/chat_diary/chat_diary_session.dart';
import 'package:quill_diary/domain/diary/editor_draft.dart';
import 'package:quill_diary/domain/persona/persona_reference.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/ai/ai_client.dart';
import 'package:quill_diary/infrastructure/ai/ai_settings_store.dart';
import 'package:quill_diary/infrastructure/ai/ai_transport.dart';
import 'package:quill_diary/infrastructure/chat_diary/chat_diary_store.dart';
import 'package:quill_diary/infrastructure/storage/editor_draft_store.dart';

ChatDiarySession testChatDiarySession({
  String vaultId = 'vault',
  bool hidePersonNames = true,
}) => ChatDiarySession(
  id: generateChatDiaryId(),
  vaultId: vaultId,
  connectionConfig: const AiConnectionConfig(
    provider: AiProvider.custom,
    customProtocol: AiApiProtocol.ollamaChat,
    model: 'test-model',
    baseUrl: 'http://127.0.0.1:11434',
  ).captureRequestSnapshot(),
  hidePersonNames: hidePersonNames,
  createdAt: DateTime(2026, 10, 27),
  date: '2026-10-27',
);

final testAiPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=',
);

class OverviewAiSettingsStore extends AiSettingsStore {
  OverviewAiSettingsStore() : super.detached();
  AiConnectionSettings settings = const AiConnectionSettings();
  bool aiEnabled = true;
  bool hidePersonNames = true;
  ChatDiaryPromptSettings chatDiaryPrompts = const ChatDiaryPromptSettings();
  DiaryOrganizationPromptSettings organizationPrompts =
      const DiaryOrganizationPromptSettings();
  final keys = <String, String>{};
  bool failReads = false;
  bool failEnabledWrites = false;
  Future<void>? enabledWriteGate;
  Future<void>? readGate;
  Future<void>? keyReadGate;
  int keyReads = 0;
  int reads = 0;
  Completer<void>? readStarted;

  @override
  Future<AiStoredSettings> read(UnlockedVaultSession session) async {
    reads++;
    readStarted?.complete();
    await readGate;
    if (failReads) throw const AiFailure(AiErrorCode.settings);
    return AiStoredSettings(
      connection: settings,
      aiEnabled: aiEnabled,
      hidePersonNames: hidePersonNames,
      chatDiaryPrompts: chatDiaryPrompts,
      organizationPrompts: organizationPrompts,
    );
  }

  @override
  Future<void> save(
    UnlockedVaultSession session,
    AiStoredSettings stored,
  ) async {
    settings = stored.connection;
    aiEnabled = stored.aiEnabled;
    hidePersonNames = stored.hidePersonNames;
    chatDiaryPrompts = stored.chatDiaryPrompts;
    organizationPrompts = stored.organizationPrompts;
  }

  @override
  Future<AiSettingsInspection> inspect(UnlockedVaultSession session) async =>
      AiSettingsInspection(
        vaultId: session.vaultId,
        revision: 'test',
        status: failReads
            ? AiSettingsStatus.unreadable
            : AiSettingsStatus.ready,
      );

  @override
  Future<void> replaceUnreadableWithDefaults(
    UnlockedVaultSession session, {
    required AiSettingsInspection expected,
  }) async {
    failReads = false;
    settings = const AiConnectionSettings();
    chatDiaryPrompts = const ChatDiaryPromptSettings();
    organizationPrompts = const DiaryOrganizationPromptSettings();
    hidePersonNames = true;
    aiEnabled = true;
  }

  @override
  Future<void> updateAiEnabled(
    UnlockedVaultSession session,
    bool enabled,
  ) async {
    final fail = failEnabledWrites;
    await enabledWriteGate;
    if (fail) throw StateError('AI 開關寫入失敗');
    aiEnabled = enabled;
  }

  @override
  Future<void> updateActiveConnection(
    UnlockedVaultSession session,
    AiConnectionConfig next,
  ) async {
    settings = AiConnectionSettings(
      activeConnectionId: next.connectionId,
      connections: {...settings.connections, next.connectionId: next},
    );
  }

  @override
  Future<void> updateSelectedPersona(
    UnlockedVaultSession session,
    PersonaReference? persona,
  ) async {
    chatDiaryPrompts = chatDiaryPrompts.withSelectedPersona(persona);
  }

  @override
  Future<String> readApiKey(AiConnectionConfig connectionConfig) async {
    keyReads++;
    await keyReadGate;
    return keys[connectionConfig.credentialId] ?? '';
  }

  @override
  Future<void> saveApiKey(
    AiConnectionConfig connectionConfig,
    String apiKey,
  ) async {
    if (connectionConfig.provider.hasCustomUrl &&
        connectionConfig.effectiveBaseUrl.isEmpty &&
        apiKey.trim().isNotEmpty) {
      throw const FormatException('金鑰缺少服務網址');
    }
    final trimmed = apiKey.trim();
    if (trimmed.isEmpty) {
      keys.remove(connectionConfig.credentialId);
    } else {
      keys[connectionConfig.credentialId] = trimmed;
    }
  }
}

class RecordingAiTransport implements AiTransport {
  final requests =
      <
        ({String method, Uri uri, Map<String, String> headers, List<int>? body})
      >[];
  final streams =
      <({Uri uri, Map<String, String> headers, Map<String, Object?> body})>[];
  final responses = <AiHttpResponse>[];
  List<String> lines = [];
  bool hang = false;
  bool closed = false;
  @override
  Future<AiHttpResponse> request(
    String method,
    Uri uri,
    Map<String, String> headers, [
    List<int>? body,
  ]) async {
    requests.add((
      method: method,
      uri: uri,
      headers: Map.of(headers),
      body: body,
    ));
    if (responses.isEmpty) throw StateError('測試未提供回應');
    return responses.removeAt(0);
  }

  @override
  Stream<String> stream(
    Uri uri,
    Map<String, String> headers,
    Map<String, Object?> body,
  ) async* {
    streams.add((uri: uri, headers: Map.of(headers), body: body));
    yield* Stream.fromIterable(lines);
    if (hang) await Completer<void>().future;
  }

  @override
  void close() {
    closed = true;
  }

  void respond(Object value, {int status = 200}) =>
      responses.add(AiHttpResponse(status, utf8.encode(jsonEncode(value))));
}

class FakeAiClient extends AiClient {
  FakeAiClient(AiConnectionConfig connectionConfig)
    : super.base(
        connectionConfig,
        'test-key',
        transport: RecordingAiTransport(),
      );
  final calls = <({String prompt, List<AiInputMessage> messages})>[];
  String output = '回覆';
  Future<void> Function(AiRemoteFile)? onDeleteFile;
  @override
  Future<void> deleteFile(AiRemoteFile file) async {
    await onDeleteFile?.call(file);
  }

  AiFailure? failure;
  AiFailure? modelFailure;
  Stream<String> Function()? response;
  bool closed = false;
  int connectionTests = 0;
  Future<void>? connectionGate;
  Future<void>? modelsGate;
  @override
  Future<void> testConnection() async {
    connectionTests++;
    await connectionGate;
    final text = await reply(
      await prepareAiTestRequest(this, 'Reply with OK.', [
        const AiInputMessage(isUser: true, text: 'Reply with OK.'),
      ]),
    ).join();
    if (text.trim().isEmpty) throw const AiFailure(AiErrorCode.response);
  }

  List<String> models = const ['test-model'];

  @override
  Future<List<String>> listModels() async {
    await modelsGate;
    if (modelFailure != null) throw modelFailure!;
    return models;
  }

  @override
  Stream<String> sendPrepared(PreparedAiRequest request) async* {
    calls.add((
      prompt: request.internalSystemPrompt,
      messages: request.internalMessages,
    ));
    if (failure != null) throw failure!;
    if (response != null) {
      yield* response!();
    } else {
      yield output;
    }
  }

  @override
  void close() {
    closed = true;
  }
}

class EmptyEditorDraftStore implements EditorDraftStore {
  @override
  Future<EditorDraftRecord?> read(
    String draftKey,
    UnlockedVaultSession session,
  ) async => null;

  @override
  Future<void> clearAllMaterializedPendingFiles() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class OverviewChatDiaryStore implements ChatDiaryStore {
  OverviewChatDiaryStore([ChatDiarySession? initialChat]) {
    if (initialChat != null) {
      storedChats[initialChat.id] = jsonEncode(initialChat.toJson());
    }
  }
  final storedChats = <String, String>{};
  final images = <String, Uint8List>{};
  final failedImages = <String>{};
  String? failingDeleteId;
  bool failSaves = false;
  int imageReads = 0;
  @override
  Future<Uint8List?> readImage(
    ChatDiarySession chatSession,
    String imageId,
    UnlockedVaultSession session,
  ) async {
    imageReads++;
    if (failedImages.contains(imageId)) {
      throw const AiFailure(AiErrorCode.image);
    }
    return images[imageId];
  }

  @override
  Future<ChatDiarySession?> loadForEntry(
    String entryId,
    UnlockedVaultSession session,
  ) async {
    for (final id in storedChats.keys.toList()) {
      final chatSession = await load(id, session);
      if (chatSession != null &&
          chatSession.finished &&
          chatSession.generatedEntryId == entryId) {
        return chatSession;
      }
    }
    return null;
  }

  @override
  Future<ChatDiarySession?> load(
    String id,
    UnlockedVaultSession session,
  ) async {
    final encodedChat = storedChats[id];
    if (encodedChat == null) return null;
    final chatSession = ChatDiarySession.fromJson(
      (jsonDecode(encodedChat) as Map).cast<String, dynamic>(),
    );
    if (chatSession.vaultId != session.vaultId) {
      throw const AiFailure(AiErrorCode.storage);
    }
    return chatSession;
  }

  @override
  Future<void> save(
    ChatDiarySession chatSession,
    UnlockedVaultSession session, {
    bool pruneImages = false,
  }) async {
    if (failSaves) throw StateError('合成保存失敗');
    if (!chatSession.finished && !chatSession.hasDraftContent) {
      storedChats.remove(chatSession.id);
    } else {
      storedChats[chatSession.id] = jsonEncode(chatSession.toJson());
    }
  }

  @override
  Future<bool> cleanupRemoteFiles(
    UnlockedVaultSession session,
    Future<String> Function(AiConnectionConfig) keyFor, {
    String? chatId,
  }) async => true;
  @override
  Future<void> delete(
    String id, {
    UnlockedVaultSession? session,
    String? entryId,
  }) async {
    if (id == failingDeleteId) throw StateError('刪除失敗');
    final encodedChat = storedChats.remove(id);
    if (encodedChat != null) {
      final chatSession = ChatDiarySession.fromJson(
        (jsonDecode(encodedChat) as Map).cast<String, dynamic>(),
      );
      if (!chatSession.finished) {
        for (final image in chatSession.images) {
          images.remove(image.id);
        }
      }
    }
  }

  @override
  Future<void> deleteDraftImage(String _, String imageId) async {
    images.remove(imageId);
  }

  @override
  Future<void> flush() async {}
  @override
  Future<List<ChatDiaryDraftItem>> listDrafts(
    UnlockedVaultSession session,
  ) async {
    final result = <ChatDiarySession>[];
    for (final id in storedChats.keys.toList()) {
      final chatSession = await load(id, session);
      if (chatSession != null &&
          !chatSession.finished &&
          chatSession.hasDraftContent) {
        result.add(chatSession);
      }
    }
    result.sort((left, right) => right.createdAt.compareTo(left.createdAt));
    return result.map(ChatDiaryDraftItem.readable).toList();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FailingChatDiaryStore extends ChatDiaryStore {
  FailingChatDiaryStore({
    required super.paths,
    required super.crypto,
    required super.repository,
    required super.editorDraftStore,
  });
  bool failSaves = false;
  bool failDeletes = false;
  Completer<void>? saveStarted;
  Future<void>? saveGate;
  Completer<void>? imageStarted;
  Future<void>? imageGate;
  @override
  Future<void> saveImage(
    String chatId,
    ChatDiaryImage image,
    Uint8List bytes,
    UnlockedVaultSession session,
  ) async {
    imageStarted?.complete();
    await imageGate;
    await super.saveImage(chatId, image, bytes, session);
  }

  @override
  Future<void> delete(
    String id, {
    UnlockedVaultSession? session,
    String? entryId,
  }) {
    if (failDeletes) throw StateError('刪除失敗');
    return super.delete(id, session: session, entryId: entryId);
  }

  @override
  Future<void> save(
    ChatDiarySession chat,
    UnlockedVaultSession session, {
    bool pruneImages = false,
  }) {
    if (failSaves) throw const AiFailure(AiErrorCode.storage);
    final gate = saveGate;
    if (gate != null) {
      saveStarted?.complete();
      return gate.then(
        (_) => super.save(chat, session, pruneImages: pruneImages),
      );
    }
    return super.save(chat, session, pruneImages: pruneImages);
  }
}

class GatedEditorDraftStore extends EditorDraftStore {
  GatedEditorDraftStore({
    required super.pathStrategy,
    required super.cryptoService,
  });
  Completer<void>? readStarted;
  Future<void>? readGate;
  Completer<void>? stageStarted;
  Future<void>? stageGate;
  Completer<void>? writeStarted;
  Future<void>? writeGate;
  @override
  Future<EditorDraftRecord?> read(
    String key,
    UnlockedVaultSession session,
  ) async {
    readStarted?.complete();
    await readGate;
    return super.read(key, session);
  }

  @override
  Future<String> stagePendingBytes(
    String key,
    List<int> bytes,
    String filename,
    UnlockedVaultSession session,
  ) async {
    stageStarted?.complete();
    await stageGate;
    return super.stagePendingBytes(key, bytes, filename, session);
  }

  @override
  Future<void> write(
    String key,
    EditorDraftRecord record,
    UnlockedVaultSession session, {
    void Function()? beforeCommit,
    void Function()? onCommitted,
  }) async {
    writeStarted?.complete();
    await writeGate;
    await super.write(
      key,
      record,
      session,
      beforeCommit: beforeCommit,
      onCommitted: onCommitted,
    );
  }
}

Uint8List pngWithPrivateMetadata() {
  final text = utf8.encode('Location\x00私人地址');
  final chunk = ByteData(12 + text.length)..setUint32(0, text.length);
  chunk.buffer.asUint8List().setRange(4, 8, ascii.encode('tEXt'));
  chunk.buffer.asUint8List().setRange(8, 8 + text.length, text);
  chunk.setUint32(
    8 + text.length,
    getCrc32(chunk.buffer.asUint8List().sublist(4, 8 + text.length)),
  );
  return Uint8List.fromList([
    ...testAiPng.sublist(0, testAiPng.length - 12),
    ...chunk.buffer.asUint8List(),
    ...testAiPng.sublist(testAiPng.length - 12),
  ]);
}

/// 五種協定共用的假串流，內容固定為 [text]。
List<String> syntheticProtocolReplyLines(
  AiApiProtocol protocol, {
  String text = 'OK',
}) => switch (protocol) {
  AiApiProtocol.chatCompletions => [
    'data: {"choices":[{"delta":{"content":"$text"},"finish_reason":"stop"}]}',
    '',
  ],
  AiApiProtocol.responses => [
    'data: {"type":"response.output_text.delta","delta":"$text"}',
    '',
    'data: {"type":"response.completed"}',
    '',
  ],
  AiApiProtocol.claudeMessages => [
    'data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"$text"}}',
    '',
    'data: {"type":"message_stop"}',
    '',
  ],
  AiApiProtocol.geminiContent => [
    'data: {"candidates":[{"content":{"parts":[{"text":"$text"}]},"finishReason":"STOP"}]}',
    '',
  ],
  AiApiProtocol.ollamaChat => ['{"message":{"content":"$text"},"done":true}'],
};

Future<PreparedAiRequest> prepareAiTestRequest(
  AiClient client,
  String prompt,
  List<AiInputMessage> messages,
) => prepareAiRequest(
  connection: client.connectionConfig,
  instructions: prompt,
  messages: messages,
  originals: {},
);
