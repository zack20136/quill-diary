import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart' show getCrc32;
import 'package:quill_diary/application/editor/editor_draft_models.dart';
import 'package:quill_diary/domain/ai/ai_connection_settings.dart';
import 'package:quill_diary/domain/chat_diary/chat_diary_session.dart';
import 'package:quill_diary/domain/chat_diary/chat_diary_settings.dart';
import 'package:quill_diary/domain/diary/diary_entry.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/ai/ai_client.dart';
import 'package:quill_diary/infrastructure/ai/ai_connection_settings_store.dart';
import 'package:quill_diary/infrastructure/chat_diary/chat_diary_settings_store.dart';
import 'package:quill_diary/infrastructure/chat_diary/chat_diary_store.dart';
import 'package:quill_diary/infrastructure/storage/editor_draft_store.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';

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
  ),
  hidePersonNames: hidePersonNames,
  createdAt: DateTime(2026, 10, 27),
  date: '2026-10-27',
);

final testAiPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=',
);

class MemoryAiConnectionSettingsStore extends AiConnectionSettingsStore {
  AiConnectionSettings settings = const AiConnectionSettings();
  final keys = <String, String>{};
  bool failReads = false;
  Future<void>? readGate;
  Future<void>? keyReadGate;
  int keyReads = 0;
  @override
  Future<AiConnectionSettings> read() async {
    await readGate;
    if (failReads) throw StateError('讀取設定失敗');
    return settings;
  }

  @override
  Future<void> save(AiConnectionSettings value) async {
    settings = value;
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
    keys[connectionConfig.credentialId] = apiKey;
  }
}

class MemoryChatDiarySettingsStore extends ChatDiarySettingsStore {
  ChatDiarySettings settings = const ChatDiarySettings();
  int reads = 0;
  Future<void>? readGate;
  Completer<void>? readStarted;
  @override
  Future<ChatDiarySettings> read() async {
    reads++;
    readStarted?.complete();
    await readGate;
    return settings;
  }

  @override
  Future<void> save(ChatDiarySettings value) async {
    settings = value;
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
    final text = await reply('Reply with OK.', [
      const AiInputMessage(isUser: true, text: 'Reply with OK.'),
    ]).join();
    if (text.trim().isEmpty) throw const AiFailure(AiErrorCode.response);
  }

  @override
  Future<List<String>> listModels() async {
    await modelsGate;
    if (modelFailure != null) throw modelFailure!;
    return const ['test-model'];
  }

  @override
  Stream<String> reply(
    String systemPrompt,
    List<AiInputMessage> messages,
  ) async* {
    calls.add((prompt: systemPrompt, messages: messages));
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

class MemoryChatDiaryStore implements ChatDiaryStore {
  MemoryChatDiaryStore([ChatDiarySession? initialChat]) {
    if (initialChat != null) {
      storedChats[initialChat.id] = jsonEncode(initialChat.toJson());
    }
  }
  final storedChats = <String, String>{};
  final images = <String, Uint8List>{};
  final failedImages = <String>{};
  String? failingDeleteId;
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
  Future<List<ChatDiarySession>> list(UnlockedVaultSession session) async {
    final result = <ChatDiarySession>[];
    for (final id in storedChats.keys.toList()) {
      final chatSession = await load(id, session);
      if (chatSession != null &&
          !chatSession.finished &&
          chatSession.hasDraftContent) {
        result.add(chatSession);
      }
    }
    return result
      ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MemoryChatDiaryEntryRepository implements VaultRepository {
  MemoryChatDiaryEntryRepository(this.entry);
  DiaryEntry? entry;
  @override
  Future<DiaryEntry?> loadEntry(
    UnlockedVaultSession session,
    String entryId,
  ) async => entry?.id == entryId ? entry : null;
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
