import 'dart:convert';

import 'package:quill_diary/domain/ai/ai_composer_snapshot.dart';
import 'package:quill_diary/domain/ai/ai_connection_settings.dart';
import 'package:quill_diary/domain/ai/privacy_names.dart';
import 'package:quill_diary/domain/ai/privacy_text_processor.dart';
import 'package:quill_diary/domain/ai/private_text.dart';
import 'package:quill_diary/domain/diary/diary_entry.dart';
import 'package:quill_diary/domain/shared/privacy_tokens.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/shared/data_versions.dart';

enum OrganizationStage { privacy, chat, review, applying, applied }

({String text, List<PrivateTextRange> ranges, List<String> tokens})
organizationVisibleText(
  String body,
  Map<String, String> originals, {
  Map<String, List<String>> surfaces = const {},
}) {
  return restorePrivacyText(body, originals, surfaces: surfaces);
}

Map<String, List<String>> _surfaceMap(Object? raw) {
  if (raw == null) return const {};
  return {
    for (final entry in (raw as Map).entries)
      entry.key as String: (entry.value as List).cast<String>(),
  };
}

String organizationEntrySignature(DiaryEntry entry) => jsonEncode([
  entry.id,
  entry.vaultId,
  entry.title,
  entry.date.value,
  entry.createdAt.toIso8601String(),
  entry.tags,
  entry.markdownBody,
  entry.attachmentIds,
]);

class OrganizationTurn {
  OrganizationTurn({
    required this.user,
    this.reply = '',
    this.interrupted = true,
    this.parentIndex,
    this.surfaces = const {},
  });
  final String user;
  String reply;
  bool interrupted;
  final int? parentIndex;

  /// 這則訊息裡，人物代號每次出現的原文。只有和對照表不同時才保存。
  final Map<String, List<String>> surfaces;
  Map<String, Object?> toJson() => {
    'user': user,
    'reply': reply,
    'interrupted': interrupted,
    'parent': parentIndex,
    if (surfaces.isNotEmpty) 'surfaces': surfaces,
  };
}

class DiaryOrganization {
  DiaryOrganization({required this.source, required this.connection});
  final DiaryEntry source;
  AiConnectionConfig connection;
  OrganizationStage stage = OrganizationStage.privacy;
  List<PrivateTextRange> hiddenRanges = [];
  List<PrivateTextRange> revealedRanges = [];
  final Set<String> revealedSecrets = {};
  final Map<String, String> originals = {};
  final Set<String> automaticTokenIds = {};
  final Map<String, String> personTokenById = {};
  final Map<String, List<String>> tokenSurfaces = {};
  String protectedSource = '';
  final List<OrganizationTurn> turns = [];
  int? rootTurn;
  final Map<int, int> selectedChildren = {};
  int? editingTurn;
  AiComposerSnapshot? composerBackup;
  String? organizedBody;
  String? generationReply;
  bool generationInterrupted = false;
  String composer = '';
  List<PrivateTextRange> composerRanges = [];
  List<PrivateTextRange> composerRevealed = [];
  bool persisted = false;
  List<int> get activeTurnIndices {
    final path = <int>[];
    var index = rootTurn;
    while (index != null &&
        index >= 0 &&
        index < turns.length &&
        !path.contains(index)) {
      path.add(index);
      index = selectedChildren[index];
    }
    return path;
  }

  List<int> versionsOf(int index) => [
    for (var i = 0; i < turns.length; i++)
      if (turns[i].parentIndex == turns[index].parentIndex) i,
  ];

  void selectTurn(int index) {
    final path = _pathToTurn(index);
    if (path.isEmpty) return;
    rootTurn = path.first;
    for (var i = 1; i < path.length; i++) {
      selectedChildren[path[i - 1]] = path[i];
    }
  }

  void appendTurn(OrganizationTurn turn) {
    turns.add(turn);
    selectTurn(turns.length - 1);
  }

  String get currentBody => organizedBody ?? protectedSource;
  String get restoredBody {
    if (organizedBody case final body?) validateBody(body);
    return restore(currentBody);
  }

  List<int> _pathToTurn(int index) {
    final path = <int>[];
    int? cursor = index;
    while (cursor != null &&
        cursor >= 0 &&
        cursor < turns.length &&
        !path.contains(cursor)) {
      path.add(cursor);
      cursor = turns[cursor].parentIndex;
    }
    return path.reversed.toList();
  }

  Map<String, String> originalsForTurns(Iterable<int> path) {
    final sourceTokens = privacyTokenPattern
        .allMatches(protectedSource)
        .map((m) => m[0]!)
        .toSet();
    final scoped = {for (final token in sourceTokens) token: originals[token]!};
    for (final index in path) {
      final turn = turns[index];
      for (final match in privacyTokenPattern.allMatches(turn.user)) {
        final token = match[0]!;
        final original = originals[token];
        if (original != null) {
          scoped.putIfAbsent(
            token,
            () => turn.surfaces[token]?.firstOrNull ?? original,
          );
        }
      }
    }
    return scoped;
  }

  bool replyIsInScope(int index, {String? text}) {
    final allowed = originalsForTurns(_pathToTurn(index));
    return privacyTokenPattern
        .allMatches(text ?? turns[index].reply)
        .every((m) => allowed.containsKey(m[0]));
  }

  ({String text, List<PrivateTextRange> ranges, List<String> tokens})
  visibleText(
    String text, {
    int? turn,
    Map<String, List<String>> surfaces = const {},
  }) => organizationVisibleText(
    text,
    originalsForTurns(turn == null ? activeTurnIndices : _pathToTurn(turn)),
    surfaces: surfaces,
  );

  bool get hasUnsafeCandidate {
    final body = organizedBody;
    if (body == null) return false;
    final allowed = originalsForTurns(activeTurnIndices);
    return privacyTokenPattern
        .allMatches(body)
        .any((m) => !allowed.containsKey(m[0]));
  }

  String restore(String text) =>
      visibleText(text, surfaces: tokenSurfaces).text;

  String? get visibleGenerationReply {
    final reply = generationReply;
    return reply == null ? null : restore(reply);
  }

  void prepare({
    List<PersonTextRange> personRanges = const [],
    List<PrivateTextRange> ambiguousNames = const [],
  }) {
    if (protectedSource.isNotEmpty) {
      stage = OrganizationStage.chat;
      return;
    }
    personTokenById.clear();
    tokenSurfaces.clear();
    // 圖片引用只傳代號，網址與本機附件路徑也留在裝置。
    final ranges = mergePrivateRanges([
      ...hiddenRanges,
      for (final match in RegExp(
        r'!\[[^\]]*\]\([^\n]*?\)',
      ).allMatches(source.markdownBody))
        PrivateTextRange(match.start, match.end),
    ], source.markdownBody.length);
    revealedSecrets.clear();
    protectedSource = protectOrganizationText(
      source.markdownBody,
      ranges,
      originals,
      personRanges: personRanges,
      ambiguousNames: ambiguousNames,
      revealedRanges: revealedRanges,
      personTokenById: personTokenById,
      tokenSurfaces: tokenSurfaces,
      automaticTokenIds: automaticTokenIds,
      revealedSecrets: revealedSecrets,
    );
    stage = OrganizationStage.chat;
  }

  void validateBody(String body, {Set<String>? allowedTokens}) {
    _validateBodyStructure(body);
    final allowed =
        allowedTokens ?? originalsForTurns(activeTurnIndices).keys.toSet();
    if (privacyTokenPattern
        .allMatches(body)
        .any((m) => !allowed.contains(m[0]))) {
      throw const FormatException('整理稿包含本次未提供的保護代號');
    }
  }

  void _validateBodyStructure(String body) {
    final expected = privacyTokenPattern
        .allMatches(protectedSource)
        .map((m) => m[0]!)
        .where((token) => !automaticTokenIds.contains(token))
        .toList();
    final actual = privacyTokenPattern
        .allMatches(body)
        .map((m) => m[0]!)
        .toList();
    final extraSelections = <String>{};
    for (final token in actual) {
      final repeatedSelection =
          privacyTokenHasKind(token, PrivacyTokenKind.private) &&
          !expected.contains(token) &&
          !extraSelections.add(token);
      if (!originals.containsKey(token) || repeatedSelection) {
        throw const FormatException('整理稿的保護區段不完整');
      }
    }
    if (jsonEncode(actual.where(expected.contains).toList()) !=
        jsonEncode(expected)) {
      throw const FormatException('整理稿的保護區段不完整');
    }
  }

  void replaceBody(String body, {Set<String>? allowedTokens}) {
    validateBody(body, allowedTokens: allowedTokens);
    organizedBody = body;
  }

  Map<String, Object?> toJson() => {
    'version': DataVersions.diaryOrganization,
    'source': {
      'id': source.id,
      'vault': source.vaultId,
      'title': source.title,
      'date': source.date.value,
      'created': source.createdAt.toIso8601String(),
      'updated': source.updatedAt.toIso8601String(),
      'tags': source.tags,
      'body': source.markdownBody,
      'attachments': source.attachmentIds,
    },
    'connection': connection.toSnapshotJson(),
    'stage': stage.name,
    'ranges': privateRangesToJson(hiddenRanges),
    if (revealedRanges.isNotEmpty)
      'revealed_ranges': privateRangesToJson(revealedRanges),
    if (revealedSecrets.isNotEmpty)
      'revealed_secrets': revealedSecrets.toList(),
    'originals': originals,
    if (automaticTokenIds.isNotEmpty)
      'automatic_token_ids': automaticTokenIds.toList(),
    if (personTokenById.isNotEmpty) 'person_tokens': personTokenById,
    if (tokenSurfaces.isNotEmpty) 'token_surfaces': tokenSurfaces,
    'protected_source': protectedSource,
    'turns': turns.map((t) => t.toJson()).toList(),
    'root_turn': rootTurn,
    'selected_children': {
      for (final entry in selectedChildren.entries)
        entry.key.toString(): entry.value,
    },
    'editing_turn': editingTurn,
    'composer_backup': composerBackup?.toJson(),
    'organized_body': organizedBody,
    if (generationReply != null) 'generation_reply': generationReply,
    'generation_interrupted': generationInterrupted,
    'composer': composer,
    'composer_ranges': privateRangesToJson(composerRanges),
    if (composerRevealed.isNotEmpty)
      'composer_revealed': privateRangesToJson(composerRevealed),
  };

  factory DiaryOrganization.fromJson(Map<String, dynamic> json) {
    if (json['version'] is! int ||
        json['version'] != DataVersions.diaryOrganization) {
      throw const FormatException('無法讀取整理草稿版本');
    }
    final source = json['source'] as Map<String, dynamic>;
    final result = DiaryOrganization(
      source: DiaryEntry(
        id: source['id'] as String,
        vaultId: source['vault'] as String,
        title: source['title'] as String?,
        date: DateOnly(source['date'] as String),
        createdAt: DateTime.parse(source['created'] as String),
        updatedAt: DateTime.parse(source['updated'] as String),
        tags: (source['tags'] as List).cast<String>(),
        markdownBody: source['body'] as String,
        attachmentIds: (source['attachments'] as List).cast<String>(),
      ),
      connection: AiConnectionConfig.fromSnapshotJson(
        json['connection'] as Map<String, dynamic>,
      ),
    );
    result.stage = OrganizationStage.values.byName(json['stage'] as String);
    result.hiddenRanges = privateRangesFromJson(json['ranges'] as List);
    result.revealedRanges = privateRangesFromJson(json['revealed_ranges']);
    result.revealedSecrets.addAll(
      (json['revealed_secrets'] as List? ?? []).cast<String>(),
    );
    final originals = Map<String, String>.from(json['originals'] as Map);
    result.originals.addAll(originals);
    result.automaticTokenIds.addAll(
      (json['automatic_token_ids'] as List? ?? []).cast<String>(),
    );
    if (result.automaticTokenIds.any(
      (token) =>
          !originals.containsKey(token) ||
          !privacyTokenHasKind(token, PrivacyTokenKind.private),
    )) {
      throw const FormatException('自動隱藏對照不完整');
    }
    result.personTokenById.addAll(
      Map<String, String>.from(json['person_tokens'] as Map? ?? const {}),
    );
    result.tokenSurfaces.addAll(_surfaceMap(json['token_surfaces']));
    if (originals.keys.any(
      (token) => privacyTokenPattern.stringMatch(token) != token,
    )) {
      throw const FormatException('整理草稿的保護代號無效');
    }
    result.protectedSource = json['protected_source'] as String;
    for (final raw in json['turns'] as List) {
      final turn = raw as Map;
      result.turns.add(
        OrganizationTurn(
          user: turn['user'] as String,
          reply: turn['reply'] as String,
          interrupted: turn['interrupted'] as bool,
          parentIndex: turn['parent'] as int?,
          surfaces: _surfaceMap(turn['surfaces']),
        ),
      );
    }
    result.rootTurn = json['root_turn'] as int?;
    for (final entry in (json['selected_children'] as Map).entries) {
      result.selectedChildren[int.parse(entry.key as String)] =
          entry.value as int;
    }
    result.editingTurn = json['editing_turn'] as int?;
    if (json['composer_backup'] != null) {
      result.composerBackup = AiComposerSnapshot.fromJson(
        Map<String, dynamic>.from(json['composer_backup'] as Map),
      );
    }
    result.organizedBody = json['organized_body'] as String?;
    result.generationReply = json['generation_reply'] as String?;
    result.generationInterrupted = json['generation_interrupted'] as bool;
    result.composer = json['composer'] as String;
    result.composerRanges = privateRangesFromJson(
      json['composer_ranges'] as List,
    );
    result.composerRevealed = privateRangesFromJson(json['composer_revealed']);
    validatePrivateRanges(result.source.markdownBody, result.hiddenRanges);
    validatePrivateRanges(result.source.markdownBody, result.revealedRanges);
    validatePrivateRanges(result.composer, result.composerRanges);
    validatePrivateRanges(result.composer, result.composerRevealed);
    if (result.composerBackup case final backup?) {
      validatePrivateRanges(backup.text, backup.ranges);
      validatePrivateRanges(backup.text, backup.revealed);
    }
    result.persisted = true;
    result.validateBody(result.protectedSource);
    if (result.personTokenById.values.any(
          (token) =>
              !privacyTokenHasKind(token, PrivacyTokenKind.person) ||
              !result.originals.containsKey(token),
        ) ||
        result.tokenSurfaces.keys.any(
          (token) => !result.originals.containsKey(token),
        )) {
      throw const FormatException('整理草稿的隱私對照不完整');
    }
    if (result.organizedBody != null) {
      // 舊候選可保留供返回對話；採用時另驗證目前分支，不能因此丟掉整份進度。
      result._validateBodyStructure(result.organizedBody!);
    }
    return result;
  }
}

String protectOrganizationText(
  String text,
  List<PrivateTextRange> ranges,
  Map<String, String> originals, {
  List<PersonTextRange> personRanges = const [],
  List<PrivateTextRange> ambiguousNames = const [],
  List<PrivateTextRange> revealedRanges = const [],
  Map<String, String>? personTokenById,
  Map<String, List<String>>? tokenSurfaces,
  Set<String>? automaticTokenIds,
  Set<String>? revealedSecrets,
}) {
  final ledger = PrivacyLedger(
    originals: originals,
    personTokens: personTokenById,
    surfaces: tokenSurfaces,
    automaticTokens: automaticTokenIds,
  );
  final result = protectNamedText(
    ledger.processor(),
    text,
    manualRanges: ranges,
    people: personRanges,
    ambiguous: ambiguousNames,
    revealedRanges: revealedRanges,
    distinctSelections: true,
    protectLiteralTokens: true,
  );
  ledger.record(result);
  revealedSecrets?.addAll(result.revealedSecrets);
  return result.text;
}
