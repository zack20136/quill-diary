import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart' show Sha256;
import 'package:path/path.dart' as p;
import 'package:quill_diary/domain/ai/ai_connection_settings.dart';
import 'package:quill_diary/domain/ai/ai_failure.dart';
import 'package:quill_diary/domain/chat_diary/chat_diary_session.dart';
import 'package:quill_diary/domain/diary/editor_draft.dart';
import 'package:quill_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/ai/ai_client.dart';
import 'package:quill_diary/infrastructure/crypto/crypto_service.dart';
import 'package:quill_diary/infrastructure/storage/editor_draft_store.dart';
import 'package:quill_diary/infrastructure/storage/shared/vault_file_ops.dart';
import 'package:quill_diary/infrastructure/storage/vault_path_strategy.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';

class ChatDiaryStore {
  ChatDiaryStore({
    required this.paths,
    required this.crypto,
    required this.repository,
    required this.editorDraftStore,
    this.clientFactory = AiClient.new,
  });
  final VaultPathStrategy paths;
  final CryptoService crypto;
  final VaultRepository repository;
  final EditorDraftStore editorDraftStore;
  Future<void> _pendingOperations = Future.value();
  final AiClient Function(AiConnectionConfig, String) clientFactory;
  Future<void> flush() => _pendingOperations;

  Future<T> _runStorageOperation<T>(Future<T> Function() operation) {
    final result = repository.runVaultMutation(operation);
    _pendingOperations = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace stack) {},
    );
    return result;
  }

  Future<Directory> draftDirectory(String id) async {
    if (!ChatDiarySession.isValidId(id)) throw const FormatException('無效的聊天識別');
    return Directory(
      p.join((await paths.vaultRootDirectory()).path, 'chat_diary_drafts', id),
    );
  }

  Future<void> _writeEncryptedFile(
    File file,
    List<int> bytes,
    UnlockedVaultSession session,
    String contentType,
  ) async {
    await repository.validateRecoverySession(session);
    if (contentType == 'application/json' &&
        (hasFileReplacementCandidates(file))) {
      await _readEncryptedFile(file, session);
    }
    final RecoveryMetadata? metadata = await repository.readRecoveryMetadata();
    if (metadata == null ||
        metadata.vaultId != session.vaultId ||
        session.recoveryWrapKey == null) {
      throw const AiFailure(AiErrorCode.storage);
    }
    final now = DateTime.now();
    await writeEncryptedVaultJson(
      file: file,
      crypto: crypto,
      session: session,
      metadata: metadata,
      documentId: p.basename(file.path),
      plaintextBytes: bytes,
      contentType: contentType,
      createdAt: now,
      updatedAt: now,
      validateTemporary: (temporary) async {
        await _decodeEncryptedFile(temporary, session, p.basename(file.path));
      },
    );
  }

  Future<Uint8List> _readEncryptedFile(
    File file,
    UnlockedVaultSession session,
  ) async {
    final identity = p.basename(file.path);
    try {
      await recoverFileReplacement(
        file,
        validate: (candidate) async {
          await _decodeEncryptedFile(candidate, session, identity);
        },
      );
      return await _decodeEncryptedFile(file, session, identity);
    } on Object catch (error) {
      if (isUnreadableContentError(error)) {
        throw const AiFailure(AiErrorCode.unreadable);
      }
      rethrow;
    }
  }

  Future<Uint8List> _decodeEncryptedFile(
    File file,
    UnlockedVaultSession session,
    String identity,
  ) async {
    final parsed = crypto.parseFileBytes(await file.readAsBytes());
    if (parsed.header.vaultId != session.vaultId ||
        (parsed.header.contentType == 'application/json' &&
            parsed.header.fileId != identity)) {
      throw const AiFailure(AiErrorCode.unreadable);
    }
    final bytes = Uint8List.fromList(
      await crypto.decryptBytes(
        headerBytes: parsed.headerBytes,
        ciphertextBytes: parsed.ciphertextBytes,
        context: vaultDecryptionContext(session),
      ),
    );
    if (identity.endsWith('.json.enc')) {
      if (parsed.header.contentType != 'application/json') {
        throw const AiFailure(AiErrorCode.unreadable);
      }
      final json = Map<String, dynamic>.from(
        jsonDecode(utf8.decode(bytes)) as Map,
      );
      if (p.basename(file.parent.path) == 'chat_diary_remote_cleanup') {
        AiConnectionConfig.fromSnapshotJson(
          Map<String, dynamic>.from(json['config'] as Map),
        );
        for (final item in json['files'] as List) {
          AiRemoteFile.fromJson(Map<String, dynamic>.from(item as Map));
        }
      } else {
        final chat = ChatDiarySession.fromJson(json);
        final directoryId = p.basename(file.parent.path);
        final entryId = identity.replaceFirst('.chat.json.enc', '');
        if (chat.vaultId != session.vaultId ||
            identity == 'session.json.enc' && chat.id != directoryId ||
            identity.endsWith('.chat.json.enc') &&
                chat.generatedEntryId != entryId) {
          throw const AiFailure(AiErrorCode.unreadable);
        }
      }
    }
    return bytes;
  }

  Future<void> save(
    ChatDiarySession chat,
    UnlockedVaultSession session, {
    bool pruneImages = false,
  }) {
    final bytes = utf8.encode(jsonEncode(chat.toJson()));
    final discardEmptyDraft = !chat.finished && !chat.hasDraftContent;
    final imageIds = pruneImages ? chat.referencedImageIds : null;
    return _runStorageOperation(() async {
      final chat = ChatDiarySession.fromJson(
        jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
      );
      if (discardEmptyDraft) {
        await _deleteDraftFiles(chat.id);
        return;
      }
      final attached = await _findSavedConversationFile(chat, session);
      if (chat.finished && attached == null) {
        throw const AiFailure(AiErrorCode.storage);
      }
      await _writeEncryptedFile(
        attached ??
            File(
              p.join((await draftDirectory(chat.id)).path, 'session.json.enc'),
            ),
        bytes,
        session,
        'application/json',
      );
      if (!chat.finished && imageIds != null) {
        await _pruneDraftImages(chat.id, imageIds);
      }
    });
  }

  Future<void> _pruneDraftImages(String chatId, Set<String> keepIds) async {
    final directory = Directory(
      p.join((await draftDirectory(chatId)).path, 'images'),
    );
    if (!directory.existsSync()) return;
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is File &&
          !keepIds.contains(p.basename(entity.path).split('.').first)) {
        await entity.delete();
      }
    }
    if (directory.listSync().isEmpty) await directory.delete();
  }

  static Future<String> draftSignature(EditorDraftRecord record) async =>
      base64UrlEncode(
        (await Sha256().hash(
          utf8.encode(
            jsonEncode([
              record.title,
              record.dateValue,
              record.entryHour,
              record.entryMinute,
              record.tags,
              record.markdownBody,
              record.attachmentIds,
            ]),
          ),
        )).bytes,
      );

  Future<void> commitGeneratedDraft(
    ChatDiarySession chat,
    ChatDiaryDraft draft,
    UnlockedVaultSession session, {
    required String prompt,
    required AiConnectionConfig connection,
    required void Function() ensureCurrent,
  }) => _runStorageOperation(() async {
    ensureCurrent();
    await repository.validateRecoverySession(session);
    ensureCurrent();
    final draftKey = ChatDiarySession.draftKeyFor(chat.id);
    final entryId = chat.generatedEntryId ?? generateEntryId();
    final activeMessages = chat.activeMessages;
    final imageIds = <String>{
      for (final message in activeMessages.where((message) => message.isUser))
        ...message.imageIds,
    };
    final attachments = <EditorDraftPendingAttachment>[];
    var committed = false;
    try {
      for (final id in imageIds) {
        final image = chat.images.firstWhere((image) => image.id == id);
        final bytes = await _readImage(chat, id, session);
        ensureCurrent();
        if (bytes == null) throw const AiFailure(AiErrorCode.image);
        final relative = await editorDraftStore.stagePendingBytes(
          draftKey,
          bytes,
          image.filename,
          session,
        );
        attachments.add(
          EditorDraftPendingAttachment(
            assetId: id,
            relativePath: relative,
            mimeType: image.mimeType,
            originalFilename: image.filename,
          ),
        );
        ensureCurrent();
      }
      final now = DateTime.now();
      final record = EditorDraftRecord(
        title: draft.title,
        dateValue: chat.date,
        entryHour: now.hour,
        entryMinute: now.minute,
        tags: const [],
        markdownBody: draft.markdownBody,
        attachmentIds: imageIds.toList(),
        pendingAttachments: attachments,
        provisionalEntryId: entryId,
        createdAt: now,
        updatedAt: now,
      );
      final signature = await draftSignature(record);
      ensureCurrent();
      await editorDraftStore.write(
        draftKey,
        record,
        session,
        beforeCommit: ensureCurrent,
        onCommitted: () {
          committed = true;
          chat.generatedEntryId = entryId;
          chat.generatedDraftSignature = signature;
          chat.generatedFromMessageId = activeMessages.lastOrNull?.id;
          chat.generationPromptSnapshot = prompt;
          chat.generationConnectionSnapshot = connection;
        },
      );
    } finally {
      if (committed) {
        // 提交之後即使離頁，仍保存來源與指紋；後續操作只接手完整草稿。
        await _writeEncryptedFile(
          File(
            p.join((await draftDirectory(chat.id)).path, 'session.json.enc'),
          ),
          utf8.encode(jsonEncode(chat.toJson())),
          session,
          'application/json',
        );
      } else {
        for (final attachment in attachments) {
          final file = File(
            await editorDraftStore.pendingAbsolutePath(
              draftKey,
              attachment.relativePath,
            ),
          );
          if (file.existsSync()) await file.delete();
        }
        final pending = await paths.editorDraftPendingDirectory(draftKey);
        if (pending.existsSync() && pending.listSync().isEmpty) {
          await pending.delete();
        }
        final editor = pending.parent;
        if (editor.existsSync() && editor.listSync().isEmpty) {
          await editor.delete();
        }
      }
    }
  });

  Future<ChatDiarySession?> loadForEntry(
    String entryId,
    UnlockedVaultSession session,
  ) => _runStorageOperation(() async {
    await repository.validateRecoverySession(session);
    return _loadForEntry(entryId, session);
  });

  Future<ChatDiarySession?> _loadForEntry(
    String entryId,
    UnlockedVaultSession session,
  ) async {
    final entry = await repository.loadEntry(session, entryId);
    if (entry != null) {
      final file = File(
        await paths.entryChatAbsolutePath(date: entry.date, entryId: entryId),
      );
      if (hasFileReplacementCandidates(file)) {
        final chat = ChatDiarySession.fromJson(
          (jsonDecode(
            utf8.decode(await _readEncryptedFile(file, session)),
          ) as Map).cast<String, dynamic>(),
        );
        if (chat.generatedEntryId != entryId ||
            chat.vaultId != session.vaultId) {
          throw const AiFailure(AiErrorCode.storage);
        }
        return chat;
      }
    }
    return null;
  }

  Future<File?> _findSavedConversationFile(
    ChatDiarySession chat,
    UnlockedVaultSession session,
  ) async {
    final entryId = chat.generatedEntryId;
    if (!chat.finished || entryId == null) return null;
    final entry = await repository.loadEntry(session, entryId);
    if (entry == null) return null;
    final file = File(
      await paths.entryChatAbsolutePath(date: entry.date, entryId: entryId),
    );
    if (!hasFileReplacementCandidates(file)) {
      return null;
    }
    return file;
  }

  Future<ChatDiarySession?> load(String id, UnlockedVaultSession session) =>
      _runStorageOperation(() async {
        await repository.validateRecoverySession(session);
        return _loadDraftIfExists(id, session);
      });

  Future<ChatDiarySession?> _loadDraftIfExists(
    String id,
    UnlockedVaultSession session,
  ) async {
    final file = File(
      p.join((await draftDirectory(id)).path, 'session.json.enc'),
    );
    if (!hasFileReplacementCandidates(file)) {
      return null;
    }
    return _loadDraft(id, session);
  }

  Future<ChatDiarySession> _loadDraft(
    String id,
    UnlockedVaultSession session,
  ) async {
    final file = File(
      p.join((await draftDirectory(id)).path, 'session.json.enc'),
    );
    final chat = ChatDiarySession.fromJson(
      (jsonDecode(utf8.decode(await _readEncryptedFile(file, session))) as Map)
          .cast<String, dynamic>(),
    );
    if (chat.id != id || chat.vaultId != session.vaultId) {
      throw const AiFailure(AiErrorCode.storage);
    }
    return chat;
  }

  Future<List<ChatDiaryDraftItem>> listDrafts(UnlockedVaultSession session) =>
      _runStorageOperation(() async {
        final root = Directory(
          p.join((await paths.vaultRootDirectory()).path, 'chat_diary_drafts'),
        );
        await repository.validateRecoverySession(session);
        final result = <ChatDiaryDraftItem>[];
        if (!root.existsSync()) return result;
        await for (final entity in root.list(followLinks: false)) {
          if (entity is! Directory ||
              !ChatDiarySession.isValidId(p.basename(entity.path))) {
            continue;
          }
          try {
            final chat = await _loadDraft(p.basename(entity.path), session);
            final entryId = chat.generatedEntryId;
            // 正式日記已提交、聊天收尾被中斷時，下一次開啟清單補完本機交接。
            if (entryId != null &&
                await repository.loadEntry(session, entryId) != null) {
              await _complete(chat.id, entryId, session);
            } else if (chat.hasDraftContent) {
              result.add(ChatDiaryDraftItem.readable(chat));
            }
          } on Object catch (error) {
            final AiErrorCode issue;
            if (error is FileSystemException) {
              issue = AiErrorCode.storage;
            } else if (isUnreadableContentError(error) || error is AiFailure) {
              issue = AiErrorCode.unreadable;
            } else {
              rethrow;
            }
            DateTime? modifiedAt;
            try {
              modifiedAt = (await entity.stat()).modified;
            } on FileSystemException {
              /* 無法取得日期仍保留工作。 */
            }
            result.add(
              ChatDiaryDraftItem.unreadable(
                id: p.basename(entity.path),
                vaultId: session.vaultId,
                error: issue,
                modifiedAt: modifiedAt,
              ),
            );
          }
        }
        return result..sort(
          (a, b) => (b.modifiedAt ?? DateTime(0)).compareTo(
            a.modifiedAt ?? DateTime(0),
          ),
        );
      });

  Future<void> saveImage(
    String chatId,
    ChatDiaryImage image,
    Uint8List bytes,
    UnlockedVaultSession session,
  ) {
    final snapshot = Uint8List.fromList(bytes);
    return _runStorageOperation(() async {
      if (!RegExp(r'^att_[0-9A-HJKMNP-TV-Z]{26}$').hasMatch(image.id)) {
        throw const FormatException('無效的圖片識別');
      }
      await _writeEncryptedFile(
        File(
          p.join(
            (await draftDirectory(chatId)).path,
            'images',
            '${image.id}.enc',
          ),
        ),
        snapshot,
        session,
        image.mimeType,
      );
    });
  }

  Future<void> deleteDraftImage(String chatId, String imageId) =>
      _runStorageOperation(() async {
        if (!RegExp(r'^att_[0-9A-HJKMNP-TV-Z]{26}$').hasMatch(imageId)) {
          throw const FormatException('無效的圖片識別');
        }
        final directory = Directory(
          p.join((await draftDirectory(chatId)).path, 'images'),
        );
        for (final suffix in ['', '.previous', '.tmp']) {
          final file = File(p.join(directory.path, '$imageId.enc$suffix'));
          if (file.existsSync()) await file.delete();
        }
        if (directory.existsSync() && directory.listSync().isEmpty) {
          await directory.delete();
        }
        final draft = directory.parent;
        if (draft.existsSync() && draft.listSync().isEmpty) {
          await draft.delete();
        }
      });

  Future<Uint8List?> readImage(
    ChatDiarySession chat,
    String imageId,
    UnlockedVaultSession session,
  ) => _runStorageOperation(() => _readImage(chat, imageId, session));

  Future<Uint8List?> _readImage(
    ChatDiarySession chat,
    String imageId,
    UnlockedVaultSession session,
  ) async {
    if (!RegExp(r'^att_[0-9A-HJKMNP-TV-Z]{26}$').hasMatch(imageId) ||
        !chat.images.any((image) => image.id == imageId)) {
      throw const AiFailure(AiErrorCode.image);
    }
    if (chat.finished) return _readEntryImage(chat, imageId, session);
    final file = File(
      p.join((await draftDirectory(chat.id)).path, 'images', '$imageId.enc'),
    );
    if (!hasFileReplacementCandidates(file)) {
      return null;
    }
    return _readEncryptedFile(file, session);
  }

  Future<Uint8List?> _readEntryImage(
    ChatDiarySession chat,
    String imageId,
    UnlockedVaultSession session,
  ) async {
    final entryId = chat.generatedEntryId;
    if (entryId == null) return null;
    final entry = await repository.loadEntry(session, entryId);
    if (entry == null) return null;
    final attachment = (await repository.loadAttachments(entryId))
        .where((item) => item.id == imageId)
        .firstOrNull;
    if (attachment == null) return null;
    final extension = p
        .extension(attachment.safeFilename)
        .replaceFirst('.', '');
    final path = await paths.assetAbsolutePath(
      date: entry.date,
      assetId: imageId,
      extension: extension.isEmpty ? 'bin' : extension,
    );
    final file = File(path);
    if (!file.existsSync()) return null;
    return _readEncryptedFile(file, session);
  }

  Future<void> complete(
    String id,
    String entryId,
    UnlockedVaultSession session,
  ) => _runStorageOperation(() => _complete(id, entryId, session));

  Future<void> _complete(
    String id,
    String entryId,
    UnlockedVaultSession session,
  ) async {
    // 此處在正式日記提交之後執行，失敗也不能回滾已成功的日記。
    final chat = await _loadDraftIfExists(id, session);
    if (chat == null) {
      final completedChat = await _loadForEntry(entryId, session);
      if (completedChat?.id == id) {
        await _deleteDraftFiles(id);
        return;
      }
      throw const AiFailure(AiErrorCode.storage);
    }
    final entry = await repository.loadEntry(session, entryId);
    if (entry == null) throw const AiFailure(AiErrorCode.storage);
    chat.validateGraph();
    final usedImageIds = {
      for (final message in chat.messages) ...message.imageIds,
    };
    final usedPrivateTokens = {
      for (final message in chat.messages.where((message) => message.isUser))
        ...message.privateTokenIds,
    };
    chat.images.removeWhere((image) => !usedImageIds.contains(image.id));
    final referencedText = [
      ...chat.messages.map((message) => message.outboundText),
      ...chat.messages.map((message) => message.systemPromptSnapshot),
      chat.generationPromptSnapshot,
    ].join('\n');
    chat.originalTextByToken.removeWhere(
      (token, _) =>
          !referencedText.contains(token) && !usedPrivateTokens.contains(token),
    );
    chat.tokenBySourceKey.removeWhere(
      (_, token) => !chat.originalTextByToken.containsKey(token),
    );
    chat.finished = true;
    chat.generatedEntryId = entryId;
    chat.composerText = '';
    chat.composerRanges = [];
    chat.composerRevealed = [];
    chat.pendingImageIds.clear();
    chat.editingMessageId = null;
    chat.editBackup = null;
    await _writeEncryptedFile(
      File(
        await paths.entryChatAbsolutePath(date: entry.date, entryId: entryId),
      ),
      utf8.encode(jsonEncode(chat.toJson())),
      session,
      'application/json',
    );
    await _deleteDraftFiles(id);
  }

  Future<void> _deleteDraftFiles(String id) async {
    await editorDraftStore.clearMaterializedPendingFiles(
      ChatDiarySession.draftKeyFor(id),
    );
    final directory = await draftDirectory(id);
    if (directory.existsSync()) await directory.delete(recursive: true);
  }

  Future<void> delete(
    String id, {
    UnlockedVaultSession? session,
    String? entryId,
  }) => _runStorageOperation(() async {
    if (session != null && entryId != null) {
      final entry = await repository.loadEntry(session, entryId);
      if (entry != null) {
        await repository.deleteChatFilesBesideEntry(
          await paths.entryAbsolutePath(date: entry.date, entryId: entryId),
        );
      }
    }
    await _deleteDraftFiles(id);
  });

  Future<void> trackRemoteFile(
    ChatDiarySession chat,
    AiRemoteFile file,
    UnlockedVaultSession session, {
    AiConnectionConfig? connectionConfig,
  }) {
    final snapshot = jsonEncode(
      (connectionConfig ?? chat.connectionConfig).toSnapshotJson(),
    );
    return _runStorageOperation(() async {
      final connection = AiConnectionConfig.fromSnapshotJson(
        jsonDecode(snapshot) as Map<String, dynamic>,
      );
      final scope = (await Sha256().hash(
        utf8.encode(jsonEncode(connection.toSnapshotJson())),
      )).bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
      final record = File(
        p.join(
          (await paths.vaultRootDirectory()).path,
          'chat_diary_remote_cleanup',
          '${chat.id}.$scope.json.enc',
        ),
      );
      var files = <Object?>[];
      if (hasFileReplacementCandidates(record)) {
        files =
            ((jsonDecode(utf8.decode(await _readEncryptedFile(record, session)))
                        as Map)['files']
                    as List)
                .toList();
      }
      if (!files.any(
        (remoteRecord) => (remoteRecord as Map)['id'] == file.id,
      )) {
        files.add(file.toJson());
      }
      await _writeEncryptedFile(
        record,
        utf8.encode(
          jsonEncode({'config': connection.toSnapshotJson(), 'files': files}),
        ),
        session,
        'application/json',
      );
    });
  }

  Future<bool> cleanupRemoteFiles(
    UnlockedVaultSession session,
    Future<String> Function(AiConnectionConfig connectionConfig) keyFor, {
    String? chatId,
  }) async {
    final records = await _runStorageOperation(() async {
      final root = Directory(
        p.join(
          (await paths.vaultRootDirectory()).path,
          'chat_diary_remote_cleanup',
        ),
      );
      if (!root.existsSync()) return <File>[];
      return root
          .listSync(followLinks: false)
          .whereType<File>()
          .where(
            (file) =>
                file.path.endsWith('.json.enc') ||
                file.path.endsWith('.json.enc.previous') ||
                file.path.endsWith('.json.enc.tmp'),
          )
          .map(
            (file) =>
                file.path.replaceFirst(RegExp(r'\.(?:previous|tmp)$'), ''),
          )
          .where(
            (path) => chatId == null || p.basename(path).startsWith('$chatId.'),
          )
          .toSet()
          .map(File.new)
          .toList();
    });
    var success = true;
    for (final file in records) {
      AiClient? client;
      try {
        final cleanupRecord = await _runStorageOperation(() async {
          if (!hasFileReplacementCandidates(file)) {
            return null;
          }
          if (chatId == null) {
            final id = p.basename(file.path).split('.').first;
            final draft = File(
              p.join((await draftDirectory(id)).path, 'session.json.enc'),
            );
            if (hasFileReplacementCandidates(draft)) {
              final chat = await _loadDraft(id, session);
              if (chat.generatedEntryId == null ||
                  await repository.loadEntry(session, chat.generatedEntryId!) ==
                      null) {
                return null;
              }
            }
          }
          return (jsonDecode(
            utf8.decode(await _readEncryptedFile(file, session)),
          ) as Map).cast<String, dynamic>();
        });
        if (cleanupRecord == null) continue;
        final connectionConfig = AiConnectionConfig.fromSnapshotJson(
          (cleanupRecord['config'] as Map).cast<String, dynamic>(),
        );
        final key = await keyFor(connectionConfig);
        if (key.isEmpty && connectionConfig.provider.requiresApiKey) {
          success = false;
          continue;
        }
        client = clientFactory(connectionConfig, key);
        final deleted = <String>{};
        for (final item in cleanupRecord['files'] as List) {
          final remote = AiRemoteFile.fromJson(
            (item as Map).cast<String, dynamic>(),
          );
          try {
            await client.deleteFile(remote);
            deleted.add(remote.id);
          } on Object {
            success = false;
          }
        }
        await _runStorageOperation(() async {
          if (!hasFileReplacementCandidates(file)) {
            return;
          }
          final current = (jsonDecode(
            utf8.decode(await _readEncryptedFile(file, session)),
          ) as Map).cast<String, dynamic>();
          final remaining = (current['files'] as List)
              .where((item) => !deleted.contains((item as Map)['id']))
              .toList();
          if (remaining.isEmpty) {
            for (final suffix in ['', '.previous', '.tmp']) {
              final candidate = File('${file.path}$suffix');
              if (candidate.existsSync()) await candidate.delete();
            }
          } else {
            current['files'] = remaining;
            await _writeEncryptedFile(
              file,
              utf8.encode(jsonEncode(current)),
              session,
              'application/json',
            );
          }
        });
      } on Object {
        success = false;
      } finally {
        client?.close();
      }
    }
    return success;
  }
}
