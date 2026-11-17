import 'package:flutter/widgets.dart' show StringCharacters;

import 'package:quill_diary/domain/ai/private_text.dart';
import 'package:quill_diary/domain/shared/privacy_tokens.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/shared/data_versions.dart';

enum PersonaCardKind { memory, tone }

enum PersonaUpdateTarget {
  memory,
  tone,
  both;

  List<PersonaCardKind> get kinds => switch (this) {
    memory => [PersonaCardKind.memory],
    tone => [PersonaCardKind.tone],
    both => PersonaCardKind.values,
  };
}

enum PersonaStep { materials, confirmation, review }

abstract final class PersonaLimits {
  static const memoryCodeUnits = 8000;
  static const toneCodeUnits = 4000;
  static const requestCodeUnits = 16000;
  static const responseCodeUnits = 64000;
  static const importBytes = 16 * 1024 * 1024;

  /// 單段材料上限。正式請求還要加上提示詞，所以小於 [requestCodeUnits]。
  static const pieceCodeUnits = 9000;
  static int card(PersonaCardKind kind) =>
      kind == PersonaCardKind.memory ? memoryCodeUnits : toneCodeUnits;
}

bool personaTimesMatch(DateTime? left, DateTime? right) {
  if (left == null || right == null) return left == null && right == null;
  return left.toUtc().microsecondsSinceEpoch ==
      right.toUtc().microsecondsSinceEpoch;
}

final personaBareTokenPattern = RegExp(
  r'(?<!\{\{)(?<![A-Za-z0-9_])(?:PER|PRI)_[0-9A-F]{2,}(?![A-Za-z0-9_])',
);

class PersonaCandidate {
  PersonaCandidate({required this.text, Map<String, String?>? tokens})
    : tokens = Map.of(tokens ?? const {});
  final String text;
  final Map<String, String?> tokens;

  void validate(PersonaCardKind kind) {
    if (text.trim().isEmpty || text.length > PersonaLimits.card(kind)) {
      throw const FormatException('分身內容長度不正確');
    }
    validateBindings();
    for (final match in privacyTokenPattern.allMatches(text)) {
      if (!tokens.containsKey(match[0])) {
        throw const FormatException('內容含有未知代號');
      }
    }
  }

  void validateBindings() {
    for (final entry in tokens.entries) {
      if (!privacyTokenHasKind(entry.key, PrivacyTokenKind.person) ||
          entry.value != null && !isPrefixedId(entry.value!, 'per')) {
        throw const FormatException('分身人物對照不正確');
      }
    }
  }

  Map<String, Object?> toJson() => {'text': text, 'person_tokens': tokens};
  factory PersonaCandidate.fromJson(Map<String, dynamic> json) =>
      PersonaCandidate(
        text: json['text'] as String,
        tokens: (json['person_tokens'] as Map).cast<String, String?>(),
      )..validateBindings();
}

class PersonaCard extends PersonaCandidate {
  PersonaCard({
    required super.text,
    super.tokens,
    required this.updatedAt,
    required List<String> selectedDiaryIds,
  }) : selectedDiaryIds = List.of(selectedDiaryIds);
  final DateTime updatedAt;
  final List<String> selectedDiaryIds;
  @override
  void validate(PersonaCardKind kind) {
    super.validate(kind);
    if (selectedDiaryIds.any((id) => !isPrefixedId(id, 'jrn')) ||
        selectedDiaryIds.toSet().length != selectedDiaryIds.length) {
      throw const FormatException('日記識別不正確');
    }
  }

  @override
  Map<String, Object?> toJson() => {
    'updated_at': updatedAt.toUtc().toIso8601String(),
    ...super.toJson(),
    'selected_diary_ids': selectedDiaryIds,
  };
  factory PersonaCard.fromJson(Map<String, dynamic> json) => PersonaCard(
    text: json['text'] as String,
    tokens: (json['person_tokens'] as Map).cast<String, String?>(),
    updatedAt: DateTime.parse(json['updated_at'] as String).toUtc(),
    selectedDiaryIds: (json['selected_diary_ids'] as List).cast<String>(),
  );
}

void _validateRangeCoordinates(Iterable<PrivateTextRange> ranges) {
  if (ranges.any((r) => r.start < 0 || r.end <= r.start)) {
    throw const FormatException('隱藏區間不正確');
  }
}

class PersonaDiarySource {
  PersonaDiarySource({
    required this.entryId,
    required this.bodyHash,
    List<PrivateTextRange>? hiddenRanges,
    List<PrivateTextRange>? revealedRanges,
    this.needsReview = false,
  }) : hiddenRanges = List.of(hiddenRanges ?? []),
       revealedRanges = List.of(revealedRanges ?? []);
  final String entryId;
  String bodyHash;
  List<PrivateTextRange> hiddenRanges;
  List<PrivateTextRange> revealedRanges;
  bool needsReview;
  Map<String, Object?> toJson() => {
    'entry_id': entryId,
    'body_hash': bodyHash,
    'hidden_ranges': privateRangesToJson(hiddenRanges),
    if (revealedRanges.isNotEmpty)
      'revealed_ranges': privateRangesToJson(revealedRanges),
    'needs_review': needsReview,
  };
  factory PersonaDiarySource.fromJson(Map<String, dynamic> json) =>
      PersonaDiarySource(
        entryId: json['entry_id'] as String,
        bodyHash: json['body_hash'] as String,
        hiddenRanges: privateRangesFromJson(json['hidden_ranges']),
        revealedRanges: privateRangesFromJson(json['revealed_ranges']),
        needsReview: json['needs_review'] as bool,
      );
}

class PersonaChatSource {
  PersonaChatSource({
    required this.importId,
    String? contentId,
    Set<String>? excluded,
    Map<String, List<PrivateTextRange>>? hidden,
    Map<String, List<PrivateTextRange>>? revealed,
    this.fromDate,
    this.toDate,
  }) : contentId = contentId ?? generatePersonaContentId(),
       excluded = Set.of(excluded ?? {}),
       hidden = Map.of(hidden ?? {}),
       revealed = Map.of(revealed ?? {});
  final String importId;
  String contentId;
  final Set<String> excluded;
  final Map<String, List<PrivateTextRange>> hidden;
  final Map<String, List<PrivateTextRange>> revealed;
  String? fromDate;
  String? toDate;
  Map<String, Object?> toJson() => {
    'import_id': importId,
    'content_id': contentId,
    'excluded': excluded.toList(),
    'hidden': hidden.map((k, v) => MapEntry(k, privateRangesToJson(v))),
    if (revealed.isNotEmpty)
      'revealed': revealed.map((k, v) => MapEntry(k, privateRangesToJson(v))),
    'from_date': fromDate,
    'to_date': toDate,
  };
  factory PersonaChatSource.fromJson(Map<String, dynamic> json) =>
      PersonaChatSource(
        importId: json['import_id'] as String,
        contentId: json['content_id'] as String,
        excluded: (json['excluded'] as List).cast<String>().toSet(),
        hidden: (json['hidden'] as Map).map(
          (k, v) => MapEntry(k as String, privateRangesFromJson(v)),
        ),
        revealed: (json['revealed'] as Map? ?? const {}).map(
          (k, v) => MapEntry(k as String, privateRangesFromJson(v)),
        ),
        fromDate: json['from_date'] as String?,
        toDate: json['to_date'] as String?,
      );
}

class PersonaDraft {
  PersonaDraft({
    required this.target,
    required Map<PersonaCardKind, DateTime?> baseUpdatedAt,
    this.step = PersonaStep.materials,
    this.hidePersonNames = true,
    this.connectionId,
    this.model,
    List<PersonaDiarySource>? diaries,
    List<PersonaChatSource>? chats,
    Map<PersonaCardKind, List<PrivateTextRange>>? cardHiddenRanges,
    Map<PersonaCardKind, List<PrivateTextRange>>? cardRevealedRanges,
    Map<PersonaCardKind, bool>? includeCurrent,
    this.candidate,
    this.manualEdit = false,
  }) : baseUpdatedAt = Map.of(baseUpdatedAt),
       diaries = List.of(diaries ?? []),
       chats = List.of(chats ?? []),
       cardHiddenRanges = Map.of(cardHiddenRanges ?? {}),
       cardRevealedRanges = Map.of(cardRevealedRanges ?? {}),
       includeCurrent = Map.of(includeCurrent ?? {});
  final PersonaUpdateTarget target;
  final bool manualEdit;
  final Map<PersonaCardKind, DateTime?> baseUpdatedAt;
  PersonaStep step;
  bool hidePersonNames;
  String? connectionId;
  String? model;
  final List<PersonaDiarySource> diaries;
  final List<PersonaChatSource> chats;
  final Map<PersonaCardKind, List<PrivateTextRange>> cardHiddenRanges;
  final Map<PersonaCardKind, List<PrivateTextRange>> cardRevealedRanges;
  final Map<PersonaCardKind, bool> includeCurrent;
  Map<PersonaCardKind, PersonaCandidate>? candidate;

  void validate() {
    if (includeCurrent.keys.any((kind) => !target.kinds.contains(kind))) {
      throw const FormatException('帶入舊卡的選項不屬於本次更新');
    }
    if (manualEdit &&
        (step != PersonaStep.review ||
            diaries.isNotEmpty ||
            chats.isNotEmpty)) {
      throw const FormatException('本機編輯不可攜帶生成材料');
    }
    if (baseUpdatedAt.length != target.kinds.length ||
        !target.kinds.every(baseUpdatedAt.containsKey) ||
        diaries.map((d) => d.entryId).toSet().length != diaries.length ||
        chats.map((c) => c.importId).toSet().length != chats.length) {
      throw const FormatException('分身草稿基準或材料重複');
    }
    for (final d in diaries) {
      if (!isPrefixedId(d.entryId, 'jrn') ||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(d.bodyHash)) {
        throw const FormatException('日記參照不正確');
      }
      _validateRangeCoordinates(d.hiddenRanges);
      _validateRangeCoordinates(d.revealedRanges);
    }
    for (final c in chats) {
      if (!isPrefixedId(c.importId, 'pim') ||
          !isPrefixedId(c.contentId, 'pco') ||
          c.fromDate != null && DateOnly.tryParse(c.fromDate!) == null ||
          c.toDate != null && DateOnly.tryParse(c.toDate!) == null ||
          c.fromDate != null &&
              c.toDate != null &&
              c.fromDate!.compareTo(c.toDate!) > 0) {
        throw const FormatException('聊天參照或日期範圍不正確');
      }
      for (final r in c.hidden.values) {
        _validateRangeCoordinates(r);
      }
      for (final r in c.revealed.values) {
        _validateRangeCoordinates(r);
      }
    }
    for (final e in cardHiddenRanges.entries) {
      if (!target.kinds.contains(e.key)) {
        throw const FormatException('隱藏範圍不屬於這次更新');
      }
      _validateRangeCoordinates(e.value);
    }
    for (final e in cardRevealedRanges.entries) {
      if (!target.kinds.contains(e.key)) {
        throw const FormatException('隱藏範圍不屬於這次更新');
      }
      _validateRangeCoordinates(e.value);
    }
    if (candidate != null &&
        (candidate!.length != target.kinds.length ||
            !target.kinds.every(candidate!.containsKey))) {
      throw const FormatException('候選內容不完整');
    }
    // 編輯中的文字允許暫時不完整；正式提交仍逐項完整驗證。
    if (step == PersonaStep.review && candidate == null) {
      throw const FormatException('審閱缺少候選');
    }
  }

  Map<String, Object?> toJson() => {
    'target': target.name,
    'manual_edit': manualEdit,
    'step': step.name,
    'base_updated_at': baseUpdatedAt.map(
      (k, v) => MapEntry(k.name, v?.toUtc().toIso8601String()),
    ),
    'hide_people': hidePersonNames,
    'connection_id': connectionId,
    'model': model,
    'diaries': diaries.map((d) => d.toJson()).toList(),
    'chats': chats.map((c) => c.toJson()).toList(),
    'card_hidden_ranges': cardHiddenRanges.map(
      (k, v) => MapEntry(k.name, privateRangesToJson(v)),
    ),
    if (cardRevealedRanges.isNotEmpty)
      'card_revealed_ranges': cardRevealedRanges.map(
        (k, v) => MapEntry(k.name, privateRangesToJson(v)),
      ),
    'include_current': includeCurrent.map(
      (kind, include) => MapEntry(kind.name, include),
    ),
    'candidate': candidate?.map((k, v) => MapEntry(k.name, v.toJson())),
  };
  factory PersonaDraft.fromJson(Map<String, dynamic> json) => PersonaDraft(
    target: PersonaUpdateTarget.values.byName(json['target'] as String),
    manualEdit: json['manual_edit'] as bool? ?? false,
    step: PersonaStep.values.byName(json['step'] as String),
    baseUpdatedAt: (json['base_updated_at'] as Map).map(
      (k, v) => MapEntry(
        PersonaCardKind.values.byName(k as String),
        v == null ? null : DateTime.parse(v as String).toUtc(),
      ),
    ),
    hidePersonNames: json['hide_people'] as bool,
    connectionId: json['connection_id'] as String?,
    model: json['model'] as String?,
    includeCurrent: (json['include_current'] as Map? ?? const {}).map(
      (kind, include) => MapEntry(
        PersonaCardKind.values.byName(kind as String),
        include as bool,
      ),
    ),
    diaries: (json['diaries'] as List)
        .map(
          (v) =>
              PersonaDiarySource.fromJson(Map<String, dynamic>.from(v as Map)),
        )
        .toList(),
    chats: (json['chats'] as List)
        .map(
          (v) =>
              PersonaChatSource.fromJson(Map<String, dynamic>.from(v as Map)),
        )
        .toList(),
    cardHiddenRanges: (json['card_hidden_ranges'] as Map).map(
      (k, v) => MapEntry(
        PersonaCardKind.values.byName(k as String),
        privateRangesFromJson(v),
      ),
    ),
    cardRevealedRanges: (json['card_revealed_ranges'] as Map? ?? const {}).map(
      (k, v) => MapEntry(
        PersonaCardKind.values.byName(k as String),
        privateRangesFromJson(v),
      ),
    ),
    candidate: (json['candidate'] as Map?)?.map(
      (k, v) => MapEntry(
        PersonaCardKind.values.byName(k as String),
        PersonaCandidate.fromJson(Map<String, dynamic>.from(v as Map)),
      ),
    ),
  );
}

class PersonaRecord {
  PersonaRecord({
    required this.vaultId,
    required this.personId,
    required this.personaId,
    this.deleting = false,
    this.cards,
    this.draft,
  });
  final String vaultId;
  final String personId;
  final String personaId;
  final bool deleting;
  final Map<PersonaCardKind, PersonaCard>? cards;
  final PersonaDraft? draft;
  bool get available =>
      !deleting &&
      cards != null &&
      PersonaCardKind.values.every((kind) => cards!.containsKey(kind));
  PersonaRecord withDraft(PersonaDraft? value) => PersonaRecord(
    vaultId: vaultId,
    personId: personId,
    personaId: personaId,
    deleting: deleting,
    cards: cards,
    draft: value,
  );
  void validate() {
    if (!isPrefixedId(vaultId, 'vlt') ||
        !isPrefixedId(personId, 'per') ||
        !isPrefixedId(personaId, 'prs') ||
        deleting && (cards != null || draft != null)) {
      throw const FormatException('分身識別或刪除狀態不正確');
    }
    if (cards != null) {
      if (cards!.length != 2 ||
          !PersonaCardKind.values.every(cards!.containsKey)) {
        throw const FormatException('正式分身需要人物記憶與聊天風格');
      }
      for (final e in cards!.entries) {
        e.value.validate(e.key);
      }
    }
    draft?.validate();
    for (final entry
        in draft?.cardHiddenRanges.entries ??
            <MapEntry<PersonaCardKind, List<PrivateTextRange>>>[]) {
      final card = cards?[entry.key];
      if (card == null && entry.value.isNotEmpty) {
        throw const FormatException('隱藏區間沒有對應的正式卡片');
      }
      if (card != null) validatePersonaRanges(card.text, entry.value);
    }
    if (draft?.manualEdit == true && cards == null) {
      throw const FormatException('沒有可編輯的分身內容');
    }
    if (cards == null &&
        draft != null &&
        draft!.target != PersonaUpdateTarget.both) {
      throw const FormatException('首次建立需要同時整理人物記憶與聊天風格');
    }
  }

  Map<String, Object?> toJson() => {
    'schema_version': DataVersions.persona,
    'vault_id': vaultId,
    'person_id': personId,
    'persona_id': personaId,
    'status': deleting ? 'deleting' : 'normal',
    'cards': cards?.map((k, v) => MapEntry(k.name, v.toJson())),
    'draft': draft?.toJson(),
  };
  factory PersonaRecord.fromJson(Map<String, dynamic> json) {
    if (json['schema_version'] is! int ||
        json['schema_version'] != DataVersions.persona ||
        !['normal', 'deleting'].contains(json['status'])) {
      throw const FormatException('不支援的分身格式或狀態');
    }
    final value = PersonaRecord(
      vaultId: json['vault_id'] as String,
      personId: json['person_id'] as String,
      personaId: json['persona_id'] as String,
      deleting: json['status'] == 'deleting',
      cards: (json['cards'] as Map?)?.map(
        (k, v) => MapEntry(
          PersonaCardKind.values.byName(k as String),
          PersonaCard.fromJson(Map<String, dynamic>.from(v as Map)),
        ),
      ),
      draft: json['draft'] == null
          ? null
          : PersonaDraft.fromJson(
              Map<String, dynamic>.from(json['draft'] as Map),
            ),
    );
    value.validate();
    return value;
  }
}

void validatePersonaRanges(String text, Iterable<PrivateTextRange> ranges) {
  final boundaries = <int>{0};
  var offset = 0;
  for (final character in text.characters) {
    offset += character.length;
    boundaries.add(offset);
  }
  for (final r in ranges) {
    if (r.start < 0 ||
        r.end <= r.start ||
        r.end > text.length ||
        !boundaries.contains(r.start) ||
        !boundaries.contains(r.end)) {
      throw const FormatException('隱藏區間切開字元或超出正文');
    }
  }
}

PrivateTextRange personaSelectionRange(String text, int start, int end) {
  var offset = 0;
  var safeStart = start;
  var safeEnd = end;
  for (final character in text.characters) {
    final next = offset + character.length;
    if (start > offset && start < next) safeStart = offset;
    if (end > offset && end < next) safeEnd = next;
    offset = next;
  }
  return PrivateTextRange(safeStart, safeEnd);
}

String personaStateIdentity(String personId) => 'persona:$personId:state';
String personaImportIdentity(
  String personId,
  String importId,
  String contentId,
) => 'persona:$personId:$importId:$contentId';

class PersonaRecoveryRequiredException extends FormatException {
  const PersonaRecoveryRequiredException() : super('分身檔案需要處理，請先檢查或重建分身再更換金鑰');
}
