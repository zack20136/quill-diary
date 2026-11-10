import 'package:quill_diary/domain/ai/ai_composer_snapshot.dart';
import 'package:quill_diary/domain/ai/ai_connection_settings.dart';
import 'package:quill_diary/domain/ai/ai_failure.dart';
import 'package:quill_diary/domain/ai/private_text.dart';
import 'package:quill_diary/domain/persona/persona_reference.dart';
import 'package:quill_diary/shared/data_versions.dart';

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
    this.personRanges = const [],
    Set<String>? privateTokenIds,
    this.errorCode,
    this.systemPromptSnapshot = '',
    this.connectionSnapshot,
    this.persona,
  }) : privateTokenIds = privateTokenIds ?? {};
  final String id;
  final bool isUser;
  String text;
  String outboundText;
  final List<String> imageIds;
  ChatDiaryMessageStatus status;
  String? parentId;
  final List<PrivateTextRange> privateRanges;
  List<PersonTextRange> personRanges;
  final Set<String> privateTokenIds;
  String? errorCode;
  String systemPromptSnapshot;
  AiConnectionConfig? connectionSnapshot;
  PersonaReference? persona;

  Map<String, Object?> toJson() => {
    'id': id,
    'is_user': isUser,
    'text': text,
    'outbound_text': outboundText,
    'image_ids': imageIds,
    'status': status.name,
    if (parentId != null) 'parent_id': parentId,
    'private_ranges': privateRanges.map((range) => range.toJson()).toList(),
    if (personRanges.isNotEmpty)
      'person_ranges': personRanges.map((range) => range.toJson()).toList(),
    'private_token_ids': privateTokenIds.toList(),
    if (errorCode != null) 'error_code': errorCode,
    if (persona == null) 'system_prompt': systemPromptSnapshot,
    if (persona != null) 'persona': persona!.toJson(),
    if (connectionSnapshot != null)
      'connection': connectionSnapshot!.toSnapshotJson(),
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
            : const [],
        privateTokenIds: (json['private_token_ids'] as List? ?? [])
            .cast<String>()
            .toSet(),
        errorCode: json['error_code'] as String?,
        systemPromptSnapshot: json['system_prompt'] as String? ?? '',
        persona: json['persona'] == null
            ? null
            : PersonaReference.fromJson(
                Map<String, dynamic>.from(json['persona'] as Map),
              ),
        connectionSnapshot: json['connection'] == null
            ? null
            : AiConnectionConfig.fromSnapshotJson(
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
    this.selectedPersona,
    Map<String, PersonaParticipant>? personaParticipants,
  }) : messages = messages ?? [],
       images = images ?? [],
       originalTextByToken = originalTextByToken ?? {},
       tokenBySourceKey = tokenBySourceKey ?? {},
       composerRanges = composerRanges ?? [],
       pendingImageIds = pendingImageIds ?? [],
       selectedChildren = selectedChildren ?? {},
       personaParticipants = personaParticipants ?? {};

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
  PersonaReference? selectedPersona;
  final Map<String, PersonaParticipant> personaParticipants;
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
    validatePrivateRanges(composerText, composerRanges);
    if (editBackup case final backup?) {
      validatePrivateRanges(backup.text, backup.ranges);
    }
    if (tokenBySourceKey.values.any(
      (token) => !originalTextByToken.containsKey(token),
    )) {
      throw const FormatException('聊天隱私對照不完整');
    }
    for (final message in messages) {
      validatePrivateRanges(message.text, message.privateRanges);
      validatePrivateRanges(
        message.text,
        message.personRanges.map(
          (range) => PrivateTextRange(range.start, range.end),
        ),
      );
      if (message.privateTokenIds.any(
        (token) => !originalTextByToken.containsKey(token),
      )) {
        throw const FormatException('訊息隱私對照不完整');
      }
    }

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
      if (selectedPersona != null)
        'selected_persona': selectedPersona!.toJson(),
      if (personaParticipants.isNotEmpty)
        'persona_participants': {
          for (final e in personaParticipants.entries) e.key: e.value.toJson(),
        },
      'id': id,
      'vault_id': vaultId,
      'config': connectionConfig.toSnapshotJson(),
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
        'generation_connection': generationConnectionSnapshot!.toSnapshotJson(),
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
    if (!isValidId(id) ||
        version is! int ||
        version != DataVersions.chatDiary) {
      throw const FormatException('無效的聊天格式');
    }
    final chat = ChatDiarySession(
      id: id,
      selectedPersona: json['selected_persona'] == null
          ? null
          : PersonaReference.fromJson(
              Map<String, dynamic>.from(json['selected_persona'] as Map),
            ),
      personaParticipants: {
        for (final e in (json['persona_participants'] as Map? ?? {}).entries)
          e.key as String: PersonaParticipant.fromJson(
            Map<String, dynamic>.from(e.value as Map),
          ),
      },
      vaultId: json['vault_id'] as String,
      connectionConfig: AiConnectionConfig.fromSnapshotJson(
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
          : AiConnectionConfig.fromSnapshotJson(
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

/// 清單保留不可讀的工作識別，不用空白聊天冒充可用草稿。
class ChatDiaryDraftItem {
  ChatDiaryDraftItem.readable(ChatDiarySession value)
    : id = value.id,
      vaultId = value.vaultId,
      modifiedAt = value.createdAt,
      chat = value,
      error = null;
  const ChatDiaryDraftItem.unreadable({
    required this.id,
    required this.vaultId,
    required this.error,
    this.modifiedAt,
  }) : chat = null;
  final String id;
  final String vaultId;
  final DateTime? modifiedAt;
  final ChatDiarySession? chat;
  final AiErrorCode? error;
}
