import 'package:quill_diary/domain/ai/ai_connection_settings.dart';
import 'package:quill_diary/domain/ai/private_text.dart';
import 'package:quill_diary/shared/data_versions.dart';

/// 從已送出的外送文字還原當時命中的人物區間。對不上就回空清單。
List<PersonTextRange> chatDiaryPersonRangesFromOutbound({
  required String text,
  required String outbound,
  required Map<String, String> originalTextByToken,
  required Map<String, String> tokenBySourceKey,
}) {
  final matches = RegExp(r'⟦[PS][0-9A-F]{2,}⟧').allMatches(outbound).toList();
  if (matches.isEmpty) return const [];
  final personIds = {
    for (final entry in tokenBySourceKey.entries)
      if (entry.key.startsWith('person:'))
        entry.value: entry.key.substring('person:'.length),
  };
  final ranges = <PersonTextRange>[];
  var textIndex = 0;
  var outboundIndex = 0;
  for (var i = 0; i < matches.length;) {
    final literal = outbound.substring(outboundIndex, matches[i].start);
    if (!text.startsWith(literal, textIndex)) return const [];
    textIndex += literal.length;
    var groupEnd = i;
    while (groupEnd + 1 < matches.length &&
        matches[groupEnd].end == matches[groupEnd + 1].start) {
      groupEnd++;
    }
    final after = groupEnd + 1 < matches.length
        ? outbound.substring(matches[groupEnd].end, matches[groupEnd + 1].start)
        : outbound.substring(matches[groupEnd].end);
    var regionEnd = after.isEmpty ? text.length : -1;
    var from = textIndex;
    while (after.isNotEmpty) {
      final at = text.indexOf(after, from);
      if (at < 0) break;
      regionEnd = at;
      from = at + 1;
    }
    if (regionEnd < textIndex) return const [];
    final surfaces = _chatDiaryTokenSurfaces(
      text.substring(textIndex, regionEnd),
      [for (var index = i; index <= groupEnd; index++) matches[index][0]!],
      originalTextByToken,
    );
    if (surfaces == null) return const [];
    var local = 0;
    for (var index = 0; index < surfaces.length; index++) {
      final token = matches[i + index][0]!;
      final surface = surfaces[index];
      final personId = personIds[token];
      if (token.startsWith('⟦P') && personId != null && surface.isNotEmpty) {
        ranges.add(
          PersonTextRange(
            textIndex + local,
            textIndex + local + surface.length,
            personId,
          ),
        );
      }
      local += surface.length;
    }
    textIndex = regionEnd;
    outboundIndex = matches[groupEnd].end;
    i = groupEnd + 1;
  }
  final tail = outbound.substring(outboundIndex);
  if (!text.startsWith(tail, textIndex) ||
      textIndex + tail.length != text.length) {
    return const [];
  }
  return ranges;
}

/// 依代號的原文對齊這一段文字。人物可以用別名，私密片段必須對上原文。
List<String>? _chatDiaryTokenSurfaces(
  String chunk,
  List<String> tokens,
  Map<String, String> originalTextByToken,
) {
  List<String>? cover(String piece, int count) {
    if (count <= 0 || piece.length < count) return null;
    if (count == 1) return [piece];
    return [
      for (var index = 0; index < count - 1; index++) piece[index],
      piece.substring(count - 1),
    ];
  }

  List<String>? walk(int offset, int index) {
    if (index == tokens.length) {
      return offset == chunk.length ? <String>[] : null;
    }
    final token = tokens[index];
    final original = originalTextByToken[token];
    if (original != null &&
        original.isNotEmpty &&
        chunk.startsWith(original, offset)) {
      final rest = walk(offset + original.length, index + 1);
      if (rest != null) return [original, ...rest];
    }
    if (!token.startsWith('⟦P')) return null;
    for (var next = index + 1; next < tokens.length; next++) {
      final anchor = originalTextByToken[tokens[next]];
      if (anchor == null || anchor.isEmpty) continue;
      var from = offset + 1;
      while (from <= chunk.length) {
        final at = chunk.indexOf(anchor, from);
        if (at < 0) break;
        final covered = cover(chunk.substring(offset, at), next - index);
        if (covered != null) {
          final rest = walk(at, next);
          if (rest != null) return [...covered, ...rest];
        }
        from = at + 1;
      }
    }
    if (tokens.skip(index).every((item) => item.startsWith('⟦P'))) {
      return cover(chunk.substring(offset), tokens.length - index);
    }
    return null;
  }

  return walk(0, 0);
}

class ChatDiaryImage {
  const ChatDiaryImage({
    required this.id,
    required this.mimeType,
    required this.filename,
  });
  final String id;
  final String mimeType;
  final String filename;
  Map<String, Object?> toJson() => {
    'id': id,
    'mime_type': mimeType,
    'filename': filename,
  };
  factory ChatDiaryImage.fromJson(Map<String, dynamic> json) => ChatDiaryImage(
    id: json['id'] as String,
    mimeType: json['mime_type'] as String,
    filename: json['filename'] as String,
  );
}

enum ChatDiaryMessageStatus { complete, pending, interrupted, failed }

class ChatDiaryMessage {
  ChatDiaryMessage({
    required this.id,
    required this.isUser,
    required this.text,
    required this.outboundText,
    this.imageIds = const [],
    this.status = ChatDiaryMessageStatus.complete,
    this.parentId,
    this.privateRanges = const [],
    this.personRanges,
    Set<String>? privateTokenIds,
    this.errorCode,
    this.systemPromptSnapshot = '',
    this.connectionSnapshot,
  }) : privateTokenIds = privateTokenIds ?? {};
  final String id;
  final bool isUser;
  String text;
  String outboundText;
  final List<String> imageIds;
  ChatDiaryMessageStatus status;
  String? parentId;
  final List<PrivateTextRange> privateRanges;
  List<PersonTextRange>? personRanges;
  final Set<String> privateTokenIds;
  String? errorCode;
  String systemPromptSnapshot;
  AiConnectionConfig? connectionSnapshot;

  Map<String, Object?> toJson() => {
    'id': id,
    'is_user': isUser,
    'text': text,
    'outbound_text': outboundText,
    'image_ids': imageIds,
    'status': status.name,
    if (parentId != null) 'parent_id': parentId,
    'private_ranges': privateRanges.map((range) => range.toJson()).toList(),
    if (personRanges != null)
      'person_ranges': personRanges!.map((range) => range.toJson()).toList(),
    'private_token_ids': privateTokenIds.toList(),
    if (errorCode != null) 'error_code': errorCode,
    'system_prompt': systemPromptSnapshot,
    if (connectionSnapshot != null) 'connection': connectionSnapshot!.toJson(),
  };
  factory ChatDiaryMessage.fromJson(Map<String, dynamic> json) =>
      ChatDiaryMessage(
        id: json['id'] as String,
        isUser: json['is_user'] as bool,
        text: json['text'] as String,
        outboundText: json['outbound_text'] as String,
        imageIds: (json['image_ids'] as List? ?? []).cast<String>(),
        status: ChatDiaryMessageStatus.values.byName(
          json['status'] as String? ?? 'complete',
        ),
        parentId: json['parent_id'] as String?,
        privateRanges: (json['private_ranges'] as List? ?? [])
            .map(
              (range) => PrivateTextRange.fromJson(
                (range as Map).cast<String, dynamic>(),
              ),
            )
            .toList(),
        personRanges: json.containsKey('person_ranges')
            ? (json['person_ranges'] as List)
                  .map(
                    (range) => PersonTextRange.fromJson(
                      (range as Map).cast<String, dynamic>(),
                    ),
                  )
                  .toList()
            : null,
        privateTokenIds: (json['private_token_ids'] as List? ?? [])
            .cast<String>()
            .toSet(),
        errorCode: json['error_code'] as String?,
        systemPromptSnapshot: json['system_prompt'] as String? ?? '',
        connectionSnapshot: json['connection'] == null
            ? null
            : AiConnectionConfig.fromJson(
                (json['connection'] as Map).cast<String, dynamic>(),
              ),
      );
}

class ChatDiarySession {
  ChatDiarySession({
    required this.id,
    required this.vaultId,
    required this.connectionConfig,
    required this.hidePersonNames,
    required this.createdAt,
    required this.date,
    List<ChatDiaryMessage>? messages,
    List<ChatDiaryImage>? images,
    Map<String, String>? originalTextByToken,
    Map<String, String>? tokenBySourceKey,
    this.composerText = '',
    List<PrivateTextRange>? composerRanges,
    List<String>? pendingImageIds,
    this.generationPromptSnapshot = '',
    this.generationConnectionSnapshot,
    this.generatedEntryId,
    this.finished = false,
    Map<String, String>? selectedChildren,
    this.openingMessage = '',
    this.generatedFromMessageId,
    this.generatedDraftSignature,
    this.editingMessageId,
    this.editBackup,
  }) : messages = messages ?? [],
       images = images ?? [],
       originalTextByToken = originalTextByToken ?? {},
       tokenBySourceKey = tokenBySourceKey ?? {},
       composerRanges = composerRanges ?? [],
       pendingImageIds = pendingImageIds ?? [],
       selectedChildren = selectedChildren ?? {};

  static bool isValidId(String id) =>
      RegExp(r'^chat_[0-9A-HJKMNP-TV-Z]{26}$').hasMatch(id);
  static String draftKeyFor(String id) {
    if (!isValidId(id)) throw const FormatException('無效的聊天識別');
    return 'chat_diary_${id.substring(5)}';
  }

  final String id;
  final String vaultId;
  AiConnectionConfig connectionConfig;
  bool hidePersonNames;
  final DateTime createdAt;
  String date;
  final List<ChatDiaryMessage> messages;
  final List<ChatDiaryImage> images;
  final Map<String, String> originalTextByToken;
  final Map<String, String> tokenBySourceKey;
  String composerText;
  List<PrivateTextRange> composerRanges;
  final List<String> pendingImageIds;
  String generationPromptSnapshot;
  AiConnectionConfig? generationConnectionSnapshot;
  String? generatedEntryId;
  bool finished;
  final Map<String, String> selectedChildren;
  String openingMessage;
  String? generatedFromMessageId;
  String? generatedDraftSignature;
  String? editingMessageId;
  AiComposerSnapshot? editBackup;
  static const _root = '__root__';

  Set<String> get referencedImageIds => {
    for (final message in messages) ...message.imageIds,
    ...pendingImageIds,
    ...?editBackup?.imageIds,
  };

  bool get hasDraftContent =>
      composerText.trim().isNotEmpty ||
      pendingImageIds.isNotEmpty ||
      messages.any(
        (message) =>
            message.isUser &&
            (message.text.trim().isNotEmpty || message.imageIds.isNotEmpty),
      ) ||
      generatedEntryId != null ||
      (editBackup?.text.trim().isNotEmpty ?? false) ||
      (editBackup?.imageIds.isNotEmpty ?? false);

  AiComposerSnapshot get composer => AiComposerSnapshot(
    text: composerText,
    ranges: List.of(composerRanges),
    imageIds: List.of(pendingImageIds),
  );
  set composer(AiComposerSnapshot snapshot) {
    composerText = snapshot.text;
    composerRanges = List.of(snapshot.ranges);
    pendingImageIds
      ..clear()
      ..addAll(snapshot.imageIds);
  }

  List<ChatDiaryMessage> get activeMessages {
    final byId = {for (final message in messages) message.id: message};
    final result = <ChatDiaryMessage>[];
    final seen = <String>{};
    String? parent;
    var next = selectedChildren[_root];
    while (next != null) {
      final message = byId[next];
      if (message == null || message.parentId != parent || !seen.add(next)) {
        throw const FormatException('無效的聊天分支');
      }
      result.add(message);
      parent = next;
      next = selectedChildren[next];
    }
    if (messages.isNotEmpty && result.isEmpty) {
      throw const FormatException('缺少聊天分支');
    }
    return result;
  }

  List<ChatDiaryMessage> pathTo(String? id) {
    final byId = {for (final message in messages) message.id: message};
    final result = <ChatDiaryMessage>[];
    final seen = <String>{};
    while (id != null) {
      final message = byId[id];
      if (message == null || !seen.add(id)) {
        throw const FormatException('無效的聊天路徑');
      }
      result.add(message);
      id = message.parentId;
    }
    return result.reversed.toList();
  }

  void selectMessage(String id) {
    for (final message in pathTo(id)) {
      selectedChildren[message.parentId ?? _root] = message.id;
    }
  }

  void appendMessage(ChatDiaryMessage newMessage) {
    if (messages.any((message) => message.id == newMessage.id) ||
        newMessage.parentId != null &&
            !messages.any((message) => message.id == newMessage.parentId)) {
      throw const FormatException('無效的訊息關聯');
    }
    messages.add(newMessage);
    selectMessage(newMessage.id);
  }

  Map<(String?, bool), List<ChatDiaryMessage>> get messageVersions {
    final versions = <(String?, bool), List<ChatDiaryMessage>>{};
    for (final message in messages) {
      versions
          .putIfAbsent((message.parentId, message.isUser), () => [])
          .add(message);
    }
    return versions;
  }

  bool get isDraftOutdated =>
      generatedEntryId != null &&
      generatedFromMessageId != activeMessages.lastOrNull?.id;

  void validateGraph() {
    final byId = {for (final message in messages) message.id: message};
    if (byId.length != messages.length) {
      throw const FormatException('重複的訊息識別');
    }
    final complete = <String>{};
    for (final message in messages) {
      final seen = <String>{};
      String? id = message.id;
      while (id != null && !complete.contains(id)) {
        final node = byId[id];
        if (node == null || !seen.add(id)) {
          throw const FormatException('無效的訊息樹');
        }
        id = node.parentId;
      }
      complete.addAll(seen);
    }
    for (final entry in selectedChildren.entries) {
      if (byId[entry.value]?.parentId !=
              (entry.key == _root ? null : entry.key) ||
          !byId.containsKey(entry.value)) {
        throw const FormatException('無效的分支選取');
      }
    }
    if (editingMessageId != null &&
        (!byId.containsKey(editingMessageId) ||
            !byId[editingMessageId]!.isUser ||
            editBackup == null)) {
      throw const FormatException('無效的編輯狀態');
    }
    activeMessages;
  }

  Map<String, Object?> toJson() {
    return {
      'schema_version': DataVersions.chatDiary,
      'id': id,
      'vault_id': vaultId,
      'config': connectionConfig.toJson(),
      'hide_people': hidePersonNames,
      'created_at': createdAt.toIso8601String(),
      'date': date,
      'messages': messages.map((message) => message.toJson()).toList(),
      'images': images.map((image) => image.toJson()).toList(),
      'replacements': originalTextByToken,
      'token_keys': tokenBySourceKey,
      'composer_text': composerText,
      'composer_ranges': composerRanges.map((range) => range.toJson()).toList(),
      'pending_image_ids': pendingImageIds,
      'diary_prompt': generationPromptSnapshot,
      if (generationConnectionSnapshot != null)
        'generation_connection': generationConnectionSnapshot!.toJson(),
      if (generatedEntryId != null) 'generated_entry_id': generatedEntryId,
      'finished': finished,
      'selected_children': selectedChildren,
      'opening_message': openingMessage,
      if (generatedFromMessageId != null)
        'generated_from_message_id': generatedFromMessageId,
      if (generatedDraftSignature != null)
        'generated_draft_signature': generatedDraftSignature,
      if (editingMessageId != null) 'editing_message_id': editingMessageId,
      if (editBackup != null) 'edit_backup': editBackup!.toJson(),
    };
  }

  factory ChatDiarySession.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final version = json['schema_version'];
    if (!isValidId(id) || version != DataVersions.chatDiary) {
      throw const FormatException('無效的聊天格式');
    }
    final chat = ChatDiarySession(
      id: id,
      vaultId: json['vault_id'] as String,
      connectionConfig: AiConnectionConfig.fromJson(
        (json['config'] as Map).cast<String, dynamic>(),
      ),
      hidePersonNames: json['hide_people'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      date: json['date'] as String,
      messages: (json['messages'] as List)
          .map(
            (message) => ChatDiaryMessage.fromJson(
              (message as Map).cast<String, dynamic>(),
            ),
          )
          .toList(),
      images: (json['images'] as List)
          .map(
            (image) =>
                ChatDiaryImage.fromJson((image as Map).cast<String, dynamic>()),
          )
          .toList(),
      originalTextByToken: (json['replacements'] as Map).cast<String, String>(),
      tokenBySourceKey: (json['token_keys'] as Map).cast<String, String>(),
      composerText: json['composer_text'] as String? ?? '',
      composerRanges: (json['composer_ranges'] as List? ?? [])
          .map(
            (range) => PrivateTextRange.fromJson(
              (range as Map).cast<String, dynamic>(),
            ),
          )
          .toList(),
      pendingImageIds: (json['pending_image_ids'] as List? ?? [])
          .cast<String>(),
      generationPromptSnapshot: json['diary_prompt'] as String? ?? '',
      generationConnectionSnapshot: json['generation_connection'] == null
          ? null
          : AiConnectionConfig.fromJson(
              (json['generation_connection'] as Map).cast<String, dynamic>(),
            ),
      generatedEntryId: json['generated_entry_id'] as String?,
      finished: json['finished'] as bool? ?? false,
      selectedChildren: (json['selected_children'] as Map)
          .cast<String, String>(),
      openingMessage: json['opening_message'] as String? ?? '',
      generatedFromMessageId: json['generated_from_message_id'] as String?,
      generatedDraftSignature: json['generated_draft_signature'] as String?,
      editingMessageId: json['editing_message_id'] as String?,
      editBackup: json['edit_backup'] == null
          ? null
          : AiComposerSnapshot.fromJson(
              (json['edit_backup'] as Map).cast<String, dynamic>(),
            ),
    );
    chat.validateGraph();
    for (final message in chat.messages) {
      if (!message.isUser || message.personRanges != null) continue;
      message.personRanges = chatDiaryPersonRangesFromOutbound(
        text: message.text,
        outbound: message.outboundText,
        originalTextByToken: chat.originalTextByToken,
        tokenBySourceKey: chat.tokenBySourceKey,
      );
    }
    return chat;
  }
}

class ChatDiaryDraft {
  const ChatDiaryDraft({this.title, required this.markdownBody});
  final String? title;
  final String markdownBody;

  factory ChatDiaryDraft.fromMarkdown(String text) {
    final match = RegExp(r'^# ([^\r\n]+)(?:\r?\n|$)').firstMatch(text);
    return ChatDiaryDraft(
      title: match?.group(1)?.trim(),
      markdownBody: match == null ? text : text.substring(match.end).trim(),
    );
  }
}
