import 'dart:convert';

import 'package:quill_diary/domain/ai/ai_connection_settings.dart';
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
  final pending = {
    for (final entry in surfaces.entries)
      entry.key: List<String>.of(entry.value),
  };
  final output = StringBuffer();
  final ranges = <PrivateTextRange>[];
  final tokens = <String>[];
  var cursor = 0;
  for (final match in privacyTokenPattern.allMatches(body)) {
    output.write(body.substring(cursor, match.start));
    final token = match[0]!;
    final queue = pending[token];
    final original = queue != null && queue.isNotEmpty
        ? queue.removeAt(0)
        : originals[token];
    if (original == null) {
      output.write(token);
    } else {
      ranges.add(
        PrivateTextRange(output.length, output.length + original.length),
      );
      tokens.add(token);
      output.write(original);
    }
    cursor = match.end;
  }
  output.write(body.substring(cursor));
  return (text: output.toString(), ranges: ranges, tokens: tokens);
}

Map<String, List<String>> _surfaceMap(Object? raw) {
  if (raw is! Map) return const {};
  return {
    for (final entry in raw.entries)
      if (entry.value is List)
        entry.key as String: [
          for (final item in entry.value as List) item as String,
        ],
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
  final Map<String, String> originals = {};
  final Map<String, String> personTokenById = {};
  final Map<String, List<String>> tokenSurfaces = {};
  String protectedSource = '';
  final List<OrganizationTurn> turns = [];
  int? rootTurn;
  final Map<int, int> selectedChildren = {};
  int? editingTurn;
  AiComposerSnapshot? composerBackup;
  String? organizedBody;
  bool generationInterrupted = false;
  String composer = '';
  List<PrivateTextRange> composerRanges = [];
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
    final path = <int>[];
    int? cursor = index;
    while (cursor != null &&
        cursor >= 0 &&
        cursor < turns.length &&
        !path.contains(cursor)) {
      path.add(cursor);
      cursor = turns[cursor].parentIndex;
    }
    if (path.isEmpty) return;
    final ordered = path.reversed.toList();
    rootTurn = ordered.first;
    for (var i = 1; i < ordered.length; i++) {
      selectedChildren[ordered[i - 1]] = ordered[i];
    }
  }

  void appendTurn(OrganizationTurn turn) {
    turns.add(turn);
    selectTurn(turns.length - 1);
  }

  String get currentBody => organizedBody ?? protectedSource;
  String get restoredBody => restore(currentBody);

  String restore(String text) =>
      organizationVisibleText(text, originals, surfaces: tokenSurfaces).text;

  void prepare({List<PersonTextRange> personRanges = const []}) {
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
    protectedSource = protectOrganizationText(
      source.markdownBody,
      ranges,
      originals,
      personRanges: personRanges,
      personTokenById: personTokenById,
      tokenSurfaces: tokenSurfaces,
    );
    stage = OrganizationStage.chat;
  }

  /// 舊草稿把同一人物拆成多個代號；讀回時合併，並保留每次出現的原文。
  void classifyPersonTokens(List<PersonTextRange> personRanges) {
    if (protectedSource.isEmpty || personRanges.isEmpty) return;
    final visible = organizationVisibleText(
      protectedSource,
      originals,
      surfaces: tokenSurfaces,
    );
    final renamed = <String, String>{};
    final collected = <String, List<String>>{};
    for (var i = 0; i < visible.tokens.length; i++) {
      final token = visible.tokens[i];
      final range = visible.ranges[i];
      PersonTextRange? person;
      for (final candidate in personRanges) {
        if (candidate.start == range.start && candidate.end == range.end) {
          person = candidate;
          break;
        }
      }
      if (person == null) continue;
      final surface = visible.text.substring(range.start, range.end);
      final known = personTokenById[person.personId];
      final String desired;
      if (known != null &&
          (originals.containsKey(known) || renamed.containsValue(known))) {
        desired = known;
      } else if (token.startsWith('⟦P') && !renamed.containsKey(token)) {
        desired = token;
      } else {
        if (known != null) personTokenById.remove(person.personId);
        desired = privacyTokenForPerson(
          personId: person.personId,
          surface: surface,
          tokenByPersonId: personTokenById,
          originals: originals,
          reservedText: source.markdownBody,
        );
      }
      personTokenById[person.personId] = desired;
      collected.putIfAbsent(desired, () => []).add(surface);
      if (token != desired) renamed[token] = desired;
    }
    if (renamed.isNotEmpty) {
      for (var i = 0; i < turns.length; i++) {
        final turn = turns[i];
        final pending = {
          for (final entry in turn.surfaces.entries)
            entry.key: List<String>.of(entry.value),
        };
        final lists = <String, List<String>>{};
        for (final match in privacyTokenPattern.allMatches(turn.user)) {
          final token = match[0]!;
          final desired = renamed[token] ?? token;
          if (!collected.containsKey(desired)) continue;
          final queue = pending[token];
          final surface = queue != null && queue.isNotEmpty
              ? queue.removeAt(0)
              : originals[token];
          if (surface == null) continue;
          lists.putIfAbsent(desired, () => []).add(surface);
        }
        final canonical = {
          for (final entry in collected.entries) entry.key: entry.value.first,
        };
        turns[i] = OrganizationTurn(
          user: turn.user,
          reply: turn.reply,
          interrupted: turn.interrupted,
          parentIndex: turn.parentIndex,
          surfaces: {
            for (final entry in lists.entries)
              if (entry.value.any((item) => item != canonical[entry.key]))
                entry.key: entry.value,
          },
        );
      }
    }
    _renameTokens(renamed);
    for (final entry in collected.entries) {
      originals[entry.key] = entry.value.first;
      if (entry.value.every((item) => item == entry.value.first)) {
        tokenSurfaces.remove(entry.key);
      } else {
        tokenSurfaces[entry.key] = List.of(entry.value);
      }
    }
    for (final token in renamed.keys) {
      originals.remove(token);
      tokenSurfaces.remove(token);
    }
  }

  void _renameTokens(Map<String, String> renamed) {
    if (renamed.isEmpty) return;
    final pattern = RegExp(renamed.keys.map(RegExp.escape).join('|'));
    String replace(String text) =>
        text.replaceAllMapped(pattern, (match) => renamed[match[0]]!);
    protectedSource = replace(protectedSource);
    if (organizedBody != null) organizedBody = replace(organizedBody!);
    for (var i = 0; i < turns.length; i++) {
      final turn = turns[i];
      turns[i] = OrganizationTurn(
        user: replace(turn.user),
        reply: replace(turn.reply),
        interrupted: turn.interrupted,
        parentIndex: turn.parentIndex,
        surfaces: {
          for (final entry in turn.surfaces.entries)
            renamed[entry.key] ?? entry.key: entry.value,
        },
      );
    }
    final updated = {
      for (final entry in originals.entries)
        renamed[entry.key] ?? entry.key: entry.value,
    };
    originals
      ..clear()
      ..addAll(updated);
    final updatedSurfaces = {
      for (final entry in tokenSurfaces.entries)
        renamed[entry.key] ?? entry.key: entry.value,
    };
    tokenSurfaces
      ..clear()
      ..addAll(updatedSurfaces);
    for (final entry in personTokenById.entries.toList()) {
      final next = renamed[entry.value];
      if (next != null) personTokenById[entry.key] = next;
    }
  }

  void validateBody(String body) {
    final expected = privacyTokenPattern
        .allMatches(protectedSource)
        .map((m) => m[0]!)
        .toList();
    final actual = privacyTokenPattern
        .allMatches(body)
        .map((m) => m[0]!)
        .toList();
    final extraSelections = <String>{};
    for (final token in actual) {
      final repeatedSelection =
          token.startsWith('⟦S') &&
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

  void replaceBody(String body) {
    validateBody(body);
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
    'connection': connection.toJson(),
    'stage': stage.name,
    'ranges': hiddenRanges.map((r) => r.toJson()).toList(),
    'originals': originals,
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
    'generation_interrupted': generationInterrupted,
    'composer': composer,
    'composer_ranges': composerRanges.map((r) => r.toJson()).toList(),
  };

  factory DiaryOrganization.fromJson(Map<String, dynamic> json) {
    if (json['version'] != DataVersions.diaryOrganization) {
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
      connection: AiConnectionConfig.fromJson(
        json['connection'] as Map<String, dynamic>,
      ),
    );
    result.stage = OrganizationStage.values.byName(json['stage'] as String);
    result.hiddenRanges = (json['ranges'] as List)
        .map(
          (r) => PrivateTextRange.fromJson(Map<String, dynamic>.from(r as Map)),
        )
        .toList();
    final originals = Map<String, String>.from(json['originals'] as Map);
    result.originals.addAll(originals);
    if (json['person_tokens'] is Map) {
      result.personTokenById.addAll(
        Map<String, String>.from(json['person_tokens'] as Map),
      );
    }
    result.tokenSurfaces.addAll(_surfaceMap(json['token_surfaces']));
    final used = originals.keys
        .where((token) => privacyTokenPattern.stringMatch(token) == token)
        .toSet();
    final renamed = <String, String>{};
    final longTokenPattern = RegExp(r'^⟦Q[0-9A-HJKMNP-TV-Z]+_[0-9]+⟧$');
    for (final entry in originals.entries) {
      var token = entry.key;
      if (!used.contains(token)) {
        if (!longTokenPattern.hasMatch(token)) {
          throw const FormatException('整理草稿的保護代號無效');
        }
        token = nextPrivacyToken(
          used,
          reservedText: result.source.markdownBody,
        );
        used.add(token);
        renamed[entry.key] = token;
      }
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
    if (json['composer_backup'] is Map) {
      result.composerBackup = AiComposerSnapshot.fromJson(
        Map<String, dynamic>.from(json['composer_backup'] as Map),
      );
    }
    result.organizedBody = json['organized_body'] as String?;
    result.generationInterrupted = json['generation_interrupted'] as bool;
    result.composer = json['composer'] as String;
    result.composerRanges = (json['composer_ranges'] as List)
        .map(
          (r) => PrivateTextRange.fromJson(Map<String, dynamic>.from(r as Map)),
        )
        .toList();
    result.persisted = true;
    result._renameTokens(renamed);
    if (result.organizedBody != null) {
      result.validateBody(result.organizedBody!);
    }
    return result;
  }
}

String protectOrganizationText(
  String text,
  List<PrivateTextRange> ranges,
  Map<String, String> originals, {
  List<PersonTextRange> personRanges = const [],
  Map<String, String>? personTokenById,
  Map<String, List<String>>? tokenSurfaces,
}) {
  final people = personTokenById ?? <String, String>{};
  final output = StringBuffer();
  var cursor = 0;
  for (final range in mergePrivateRanges([
    ...ranges,
    for (final match in privacyTokenPattern.allMatches(text))
      PrivateTextRange(match.start, match.end),
  ], text.length)) {
    output.write(text.substring(cursor, range.start));
    final surface = text.substring(range.start, range.end);
    PersonTextRange? person;
    for (final candidate in personRanges) {
      if (candidate.start == range.start && candidate.end == range.end) {
        person = candidate;
        break;
      }
    }
    final String token;
    if (person == null) {
      token = nextPrivacyToken(originals.keys, prefix: 'S', reservedText: text);
      originals[token] = surface;
    } else {
      token = privacyTokenForPerson(
        personId: person.personId,
        surface: surface,
        tokenByPersonId: people,
        originals: originals,
        reservedText: text,
      );
      // 不同寫法依出現順序留著，還原時才不會收成同一串文字。
      tokenSurfaces?.putIfAbsent(token, () => <String>[]).add(surface);
    }
    output.write(token);
    cursor = range.end;
  }
  output.write(text.substring(cursor));
  tokenSurfaces?.removeWhere((token, list) {
    final canonical = originals[token];
    return canonical != null && list.every((item) => item == canonical);
  });
  return output.toString();
}
