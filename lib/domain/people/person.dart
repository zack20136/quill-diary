import '../shared/value_objects.dart';

/// 熟悉程度 1–5；JSON 欄位固定為 `friendliness`。
final class FriendlinessLevel {
  const FriendlinessLevel._(this.value);

  static const int min = 1;
  static const int max = 5;
  static const FriendlinessLevel normal = FriendlinessLevel._(3);

  final int value;

  static FriendlinessLevel? tryParse(Object? raw) {
    if (raw == null) {
      return null;
    }
    final int? parsed = raw is int ? raw : int.tryParse(raw.toString());
    if (parsed == null || parsed < min || parsed > max) {
      return null;
    }
    return FriendlinessLevel._(parsed);
  }

  factory FriendlinessLevel(int value) {
    final FriendlinessLevel? parsed = tryParse(value);
    if (parsed == null) {
      throw ArgumentError.value(value, 'value', '熟悉程度須為 $min–$max');
    }
    return parsed;
  }

  @override
  bool operator ==(Object other) =>
      other is FriendlinessLevel && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'FriendlinessLevel($value)';
}

/// 生日只保存月、日；以閏年規則允許 2 月 29 日。
final class PersonBirthday {
  PersonBirthday({required this.month, required this.day}) {
    if (month < 1 || month > 12) {
      throw ArgumentError.value(month, 'month', '月份須為 1–12');
    }
    if (day < 1 || day > 31) {
      throw ArgumentError.value(day, 'day', '日期無效');
    }
    final DateTime parsed = DateTime(2000, month, day);
    if (parsed.month != month || parsed.day != day) {
      throw ArgumentError('生日月日無效：$month-$day');
    }
  }

  final int month;
  final int day;

  static PersonBirthday? tryParse({
    required Object? month,
    required Object? day,
  }) {
    final int? m = month is int ? month : int.tryParse('$month');
    final int? d = day is int ? day : int.tryParse('$day');
    if (m == null || d == null) {
      return null;
    }
    try {
      return PersonBirthday(month: m, day: d);
    } on ArgumentError {
      return null;
    }
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'month': month,
    'day': day,
  };

  static PersonBirthday? fromJson(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final Map<Object?, Object?> map = raw;
    if (map.length != 2 ||
        !map.containsKey('month') ||
        !map.containsKey('day') ||
        map['month'] is! int ||
        map['day'] is! int) {
      return null;
    }
    return tryParse(month: map['month'], day: map['day']);
  }

  @override
  bool operator ==(Object other) =>
      other is PersonBirthday && other.month == month && other.day == day;

  @override
  int get hashCode => Object.hash(month, day);
}

/// 人物名冊實體；日記不永久關聯人物 ID。
final class Person {
  Person({
    required this.id,
    required this.name,
    List<String> aliases = const <String>[],
    Set<String> relationships = const <String>{},
    this.relationshipDescription = '',
    this.notes = '',
    this.friendliness = FriendlinessLevel.normal,
    this.accentArgb,
    this.mentionName,
    this.birthday,
    this.acquaintanceYear,
    required this.createdAt,
    required this.updatedAt,
  }) : aliases = List<String>.unmodifiable(aliases),
       relationships = Set<String>.unmodifiable(relationships) {
    normalizedName = normalizePersonName(name);
    aliasSearchValues = List<PersonAliasSearchValue>.unmodifiable(
      this.aliases
          .map(
            (String alias) => PersonAliasSearchValue(
              alias: alias,
              normalized: normalizePersonName(alias),
            ),
          )
          .where((PersonAliasSearchValue value) => value.normalized.isNotEmpty),
    );
    normalizedAliases = List<String>.unmodifiable(
      aliasSearchValues.map((PersonAliasSearchValue value) => value.normalized),
    );
    allNormalizedNames = Set<String>.unmodifiable(<String>{
      if (normalizedName.isNotEmpty) normalizedName,
      ...normalizedAliases,
    });
    sortedNormalizedNames = List<String>.unmodifiable(
      allNormalizedNames.toList(growable: false)..sort(),
    );
  }

  final PersonId id;
  final String name;
  final List<String> aliases;

  /// 關係類型 id（內建或自訂）；是否存在於類型表由 PeopleCatalog 校驗。
  final Set<String> relationships;
  final String relationshipDescription;
  final String notes;
  final FriendlinessLevel friendliness;
  final int? accentArgb;

  /// 日記 `@` 插入用的別名；`null` 表示使用 [name]。
  ///
  /// 有值時必須對應 [aliases] 其中一項（正規化比對）。
  final String? mentionName;
  final PersonBirthday? birthday;
  final int? acquaintanceYear;
  final DateTime createdAt;
  final DateTime updatedAt;

  late final String normalizedName;
  late final List<PersonAliasSearchValue> aliasSearchValues;
  late final List<String> normalizedAliases;

  /// 姓名與別名的不可變正規化集合（用於分析與搜尋）。
  late final Set<String> allNormalizedNames;
  late final List<String> sortedNormalizedNames;

  /// 編輯器 `@` 實際插入的文字；別名失效時回退為 [name]。
  String get diaryMentionLabel {
    final String? selected = resolvePersonMentionAlias(
      mentionName: mentionName,
      aliases: aliases,
    );
    return selected ?? name;
  }

  /// 僅替換 [relationships]；其餘欄位不變。
  Person withRelationships(Set<String> relationships) => Person(
    id: id,
    name: name,
    aliases: aliases,
    relationships: relationships,
    relationshipDescription: relationshipDescription,
    notes: notes,
    friendliness: friendliness,
    accentArgb: accentArgb,
    mentionName: mentionName,
    birthday: birthday,
    acquaintanceYear: acquaintanceYear,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'aliases': aliases,
    'relationships': (relationships.toList(growable: false)..sort()),
    'relationshipDescription': relationshipDescription,
    'notes': notes,
    'friendliness': friendliness.value,
    if (accentArgb != null) 'accentArgb': accentArgb,
    if (mentionName != null) 'mentionName': mentionName,
    'birthday': birthday?.toJson(),
    'acquaintanceYear': acquaintanceYear,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  static Person? fromJson(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final Map<Object?, Object?> map = raw;
    const Set<String> requiredKeys = <String>{
      'id',
      'name',
      'aliases',
      'relationships',
      'relationshipDescription',
      'notes',
      'friendliness',
      'birthday',
      'acquaintanceYear',
      'createdAt',
      'updatedAt',
    };
    const Set<String> optionalKeys = <String>{'accentArgb', 'mentionName'};
    if (!requiredKeys.every(map.containsKey) ||
        map.keys.any(
          (Object? key) => key is! String ||
              (!requiredKeys.contains(key) && !optionalKeys.contains(key)),
        )) {
      return null;
    }
    final Object? idRaw = map['id'];
    final Object? nameRaw = map['name'];
    final Object? createdAtRaw = map['createdAt'];
    final Object? updatedAtRaw = map['updatedAt'];
    final Object? relationshipDescriptionRaw = map['relationshipDescription'];
    final Object? notesRaw = map['notes'];
    if (idRaw is! String ||
        nameRaw is! String ||
        createdAtRaw is! String ||
        updatedAtRaw is! String ||
        relationshipDescriptionRaw is! String ||
        notesRaw is! String ||
        idRaw.isEmpty ||
        nameRaw.trim().isEmpty ||
        map['aliases'] is! List ||
        map['relationships'] is! List) {
      return null;
    }
    final DateTime? createdAt = DateTime.tryParse(createdAtRaw);
    final DateTime? updatedAt = DateTime.tryParse(updatedAtRaw);
    if (createdAt == null || updatedAt == null) {
      return null;
    }

    final List<String> aliases = <String>[];
    for (final Object? item in map['aliases']! as List) {
      if (item is! String || item.trim().isEmpty) {
        return null;
      }
      aliases.add(item);
    }

    final Set<String> relationships = <String>{};
    for (final Object? item in map['relationships']! as List) {
      if (item is! String || item.isEmpty) {
        return null;
      }
      if (!relationships.add(item)) {
        return null;
      }
    }

    final Object? yearRaw = map['acquaintanceYear'];
    if (yearRaw != null && (yearRaw is! int || yearRaw < 1)) {
      return null;
    }
    final int? acquaintanceYear = yearRaw as int?;
    final Object? friendlinessRaw = map['friendliness'];
    final FriendlinessLevel? friendliness = friendlinessRaw is int
        ? FriendlinessLevel.tryParse(friendlinessRaw)
        : null;
    if (friendliness == null) {
      return null;
    }
    final Object? accentArgbRaw = map['accentArgb'];
    if (accentArgbRaw != null &&
        (accentArgbRaw is! int ||
            accentArgbRaw < 0 ||
            accentArgbRaw > 0xFFFFFFFF ||
            ((accentArgbRaw >> 24) & 0xFF) != 0xFF)) {
      return null;
    }
    final Object? birthdayRaw = map['birthday'];
    final PersonBirthday? birthday = birthdayRaw == null
        ? null
        : PersonBirthday.fromJson(birthdayRaw);
    if (birthdayRaw != null && birthday == null) {
      return null;
    }
    final Object? mentionNameRaw = map['mentionName'];
    final String? mentionName;
    if (mentionNameRaw == null) {
      mentionName = null;
    } else if (mentionNameRaw is! String) {
      return null;
    } else {
      mentionName = resolvePersonMentionAlias(
        mentionName: mentionNameRaw,
        aliases: aliases,
      );
      if (mentionName == null) {
        return null;
      }
    }

    return Person(
      id: idRaw,
      name: nameRaw,
      aliases: aliases,
      relationshipDescription: relationshipDescriptionRaw,
      notes: notesRaw,
      relationships: relationships,
      friendliness: friendliness,
      accentArgb: accentArgbRaw as int?,
      mentionName: mentionName,
      birthday: birthday,
      acquaintanceYear: acquaintanceYear,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

/// 若 [mentionName] 對應某個別名，回傳該別名原文；否則回傳 `null`。
String? resolvePersonMentionAlias({
  required String? mentionName,
  required Iterable<String> aliases,
}) {
  if (mentionName == null) {
    return null;
  }
  final String normalized = normalizePersonName(mentionName);
  if (normalized.isEmpty) {
    return null;
  }
  for (final String alias in aliases) {
    if (normalizePersonName(alias) == normalized) {
      return alias;
    }
  }
  return null;
}

/// 寫入前正規化：選名稱則為 `null`；選別名則對齊別名原文；別名已刪則回退 `null`。
String? normalizePersonMentionName({
  required String? mentionName,
  required String name,
  required Iterable<String> aliases,
}) {
  if (mentionName == null) {
    return null;
  }
  final String normalized = normalizePersonName(mentionName);
  if (normalized.isEmpty || normalized == normalizePersonName(name)) {
    return null;
  }
  return resolvePersonMentionAlias(mentionName: mentionName, aliases: aliases);
}

final class PersonAliasSearchValue {
  const PersonAliasSearchValue({required this.alias, required this.normalized});

  final String alias;
  final String normalized;
}

/// 人物編輯草稿；ID 與時間欄位由儲存層管理。
final class PersonDraft {
  PersonDraft({
    required this.name,
    List<String> aliases = const <String>[],
    Set<String> relationships = const <String>{},
    this.relationshipDescription = '',
    this.notes = '',
    this.friendliness = FriendlinessLevel.normal,
    this.accentArgb,
    this.mentionName,
    this.birthday,
    this.acquaintanceYear,
  }) : aliases = List<String>.unmodifiable(aliases),
       relationships = Set<String>.unmodifiable(relationships);

  factory PersonDraft.fromPerson(Person person) => PersonDraft(
    name: person.name,
    aliases: person.aliases,
    relationships: person.relationships,
    relationshipDescription: person.relationshipDescription,
    notes: person.notes,
    friendliness: person.friendliness,
    accentArgb: person.accentArgb,
    mentionName: person.mentionName,
    birthday: person.birthday,
    acquaintanceYear: person.acquaintanceYear,
  );

  final String name;
  final List<String> aliases;
  final Set<String> relationships;
  final String relationshipDescription;
  final String notes;
  final FriendlinessLevel friendliness;
  final int? accentArgb;
  final String? mentionName;
  final PersonBirthday? birthday;
  final int? acquaintanceYear;
}

/// 名稱驗證結果：衝突禁止儲存；短名稱／前綴僅警告。
enum PersonNameIssueKind { duplicate, shortName, prefixOverlap }

final class PersonNameIssue {
  const PersonNameIssue({
    required this.kind,
    required this.name,
    this.conflictPersonId,
    this.conflictPersonName,
  });

  final PersonNameIssueKind kind;
  final String name;
  final PersonId? conflictPersonId;
  final String? conflictPersonName;
}

/// 人物姓名驗證失敗；UI 可依 [hasConflict] 與 [requiresConfirmation] 決定流程。
final class PersonNameValidationException implements Exception {
  PersonNameValidationException(Iterable<PersonNameIssue> issues)
    : issues = List<PersonNameIssue>.unmodifiable(issues);

  final List<PersonNameIssue> issues;

  bool get hasConflict => issues.any(
    (PersonNameIssue issue) => issue.kind == PersonNameIssueKind.duplicate,
  );

  bool get requiresConfirmation =>
      !hasConflict &&
      issues.any(
        (PersonNameIssue issue) =>
            issue.kind == PersonNameIssueKind.shortName ||
            issue.kind == PersonNameIssueKind.prefixOverlap,
      );

  @override
  String toString() => 'PersonNameValidationException(${issues.length})';
}

/// 判斷名稱是否過短（易誤判）。
bool _isShortPersonName(String normalized) {
  if (normalized.isEmpty) {
    return true;
  }
  final List<int> runes = normalized.runes.toList(growable: false);
  if (runes.length == 1) {
    final int code = runes.first;
    return _isCjkRune(code) || _isLatinOrDigitRune(code);
  }
  if (runes.length <= 2 && runes.every(_isLatinOrDigitRune)) {
    return true;
  }
  return false;
}

bool _isCjkRune(int code) {
  return (code >= 0x4E00 && code <= 0x9FFF) ||
      (code >= 0x3400 && code <= 0x4DBF) ||
      (code >= 0xF900 && code <= 0xFAFF);
}

bool _isLatinOrDigitRune(int code) {
  return (code >= 0x30 && code <= 0x39) ||
      (code >= 0x41 && code <= 0x5A) ||
      (code >= 0x61 && code <= 0x7A);
}

/// 收集姓名／別名的重複與警告（不含空字串）。
List<PersonNameIssue> collectPersonNameIssues({
  required String name,
  required Iterable<String> aliases,
  required Iterable<Person> existingPeople,
  PersonId? excludingPersonId,
}) {
  final List<PersonNameIssue> issues = <PersonNameIssue>[];
  final List<String> candidates = <String>[
    name,
    ...aliases,
  ].map(normalizePersonName).where((String n) => n.isNotEmpty).toList();

  final Set<String> seenInForm = <String>{};
  for (final String normalized in candidates) {
    if (!seenInForm.add(normalized)) {
      issues.add(
        PersonNameIssue(kind: PersonNameIssueKind.duplicate, name: normalized),
      );
    }
  }

  final Map<String, Person> ownedBy = <String, Person>{};
  for (final Person person in existingPeople) {
    if (excludingPersonId != null && person.id == excludingPersonId) {
      continue;
    }
    for (final String n in person.allNormalizedNames) {
      ownedBy[n] = person;
    }
  }

  for (final String normalized in seenInForm) {
    final Person? conflict = ownedBy[normalized];
    if (conflict != null) {
      issues.add(
        PersonNameIssue(
          kind: PersonNameIssueKind.duplicate,
          name: normalized,
          conflictPersonId: conflict.id,
          conflictPersonName: conflict.name,
        ),
      );
    }
    if (_isShortPersonName(normalized)) {
      issues.add(
        PersonNameIssue(kind: PersonNameIssueKind.shortName, name: normalized),
      );
    }
    for (final MapEntry<String, Person> entry in ownedBy.entries) {
      final String other = entry.key;
      if (other == normalized) {
        continue;
      }
      if (other.startsWith(normalized) || normalized.startsWith(other)) {
        issues.add(
          PersonNameIssue(
            kind: PersonNameIssueKind.prefixOverlap,
            name: normalized,
            conflictPersonId: entry.value.id,
            conflictPersonName: entry.value.name,
          ),
        );
      }
    }
  }

  return issues;
}

/// 認識年份：可空；若填寫須為正整數且不晚於目前年份。
bool isValidAcquaintanceYear(int? year, {DateTime? now}) {
  if (year == null) {
    return true;
  }
  final int currentYear = (now ?? DateTime.now()).year;
  return year >= 1 && year <= currentYear;
}
