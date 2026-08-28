import 'dart:math';

import 'person.dart';

/// 內建關係類型 id（與舊 enum `.name` 相同，舊資料零轉換）。
abstract final class BuiltinRelationshipIds {
  static const String family = 'family';
  static const String partner = 'partner';
  static const String friend = 'friend';
  static const String classmate = 'classmate';
  static const String colleague = 'colleague';
  static const String collaborator = 'collaborator';
  static const String other = 'other';

  static const List<String> all = <String>[
    family,
    partner,
    friend,
    classmate,
    colleague,
    collaborator,
    other,
  ];

  static final Set<String> asSet = Set<String>.unmodifiable(all);

  static bool isBuiltin(String id) => asSet.contains(id);
}

final RegExp _customIdPattern = RegExp(r'^[a-z0-9]{8}$');

/// 人物關係類型（內建與自訂同一形狀）。
final class RelationshipType {
  const RelationshipType({
    required this.id,
    required this.labelZh,
    required this.labelEn,
  });

  final String id;
  final String labelZh;
  final String labelEn;

  /// 依語系 languageCode 選字；缺則 fallback 另一語，再不行用 [id]。
  String labelForLanguageCode(String languageCode) {
    final bool preferZh = languageCode.toLowerCase().startsWith('zh');
    final String primary = preferZh ? labelZh : labelEn;
    if (primary.trim().isNotEmpty) {
      return primary;
    }
    final String secondary = preferZh ? labelEn : labelZh;
    if (secondary.trim().isNotEmpty) {
      return secondary;
    }
    return id;
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'labelZh': labelZh,
    'labelEn': labelEn,
  };

  static RelationshipType? fromJson(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final Map<Object?, Object?> map = raw;
    if (map.length != 3 ||
        !map.containsKey('id') ||
        !map.containsKey('labelZh') ||
        !map.containsKey('labelEn')) {
      return null;
    }
    final Object? idRaw = map['id'];
    final Object? labelZhRaw = map['labelZh'];
    final Object? labelEnRaw = map['labelEn'];
    if (idRaw is! String ||
        labelZhRaw is! String ||
        labelEnRaw is! String ||
        idRaw.isEmpty ||
        labelZhRaw.trim().isEmpty ||
        labelEnRaw.trim().isEmpty) {
      return null;
    }
    if (!BuiltinRelationshipIds.isBuiltin(idRaw) &&
        !_customIdPattern.hasMatch(idRaw)) {
      return null;
    }
    return RelationshipType(
      id: idRaw,
      labelZh: labelZhRaw.trim(),
      labelEn: labelEnRaw.trim(),
    );
  }

  RelationshipType copyWith({String? labelZh, String? labelEn}) =>
      RelationshipType(
        id: id,
        labelZh: labelZh ?? this.labelZh,
        labelEn: labelEn ?? this.labelEn,
      );

  @override
  bool operator ==(Object other) =>
      other is RelationshipType &&
      other.id == id &&
      other.labelZh == labelZh &&
      other.labelEn == labelEn;

  @override
  int get hashCode => Object.hash(id, labelZh, labelEn);
}

/// 內建七種預設雙語標籤（對齊舊 ARB；執行期以檔案／種子為準）。
List<RelationshipType> defaultBuiltinRelationshipTypes() =>
    _kDefaultBuiltinRelationshipTypes;

const List<RelationshipType> _kDefaultBuiltinRelationshipTypes =
    <RelationshipType>[
      RelationshipType(
        id: BuiltinRelationshipIds.family,
        labelZh: '家人',
        labelEn: 'Family',
      ),
      RelationshipType(
        id: BuiltinRelationshipIds.partner,
        labelZh: '伴侶',
        labelEn: 'Partner',
      ),
      RelationshipType(
        id: BuiltinRelationshipIds.friend,
        labelZh: '朋友',
        labelEn: 'Friend',
      ),
      RelationshipType(
        id: BuiltinRelationshipIds.classmate,
        labelZh: '同學',
        labelEn: 'Classmate',
      ),
      RelationshipType(
        id: BuiltinRelationshipIds.colleague,
        labelZh: '同事',
        labelEn: 'Colleague',
      ),
      RelationshipType(
        id: BuiltinRelationshipIds.collaborator,
        labelZh: '合作夥伴',
        labelEn: 'Collaborator',
      ),
      RelationshipType(
        id: BuiltinRelationshipIds.other,
        labelZh: '其他',
        labelEn: 'Other',
      ),
    ];

/// 產生自訂關係 id：8 碼小寫 `[a-z0-9]`，避開內建與 [existingIds]。
String generateRelationshipTypeId({
  required Set<String> existingIds,
  Random? random,
}) {
  final Random rng = random ?? Random.secure();
  const String alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
  for (int attempt = 0; attempt < 64; attempt++) {
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < 8; i++) {
      buffer.write(alphabet[rng.nextInt(alphabet.length)]);
    }
    final String id = buffer.toString();
    if (BuiltinRelationshipIds.isBuiltin(id) || existingIds.contains(id)) {
      continue;
    }
    return id;
  }
  throw StateError('無法產生唯一的關係類型 id。');
}

/// 校驗類型表：id 唯一、同語系 label 唯一；失敗回傳錯誤訊息。
String? validateRelationshipTypes(List<RelationshipType> types) {
  final Set<String> ids = <String>{};
  final Set<String> labelsZh = <String>{};
  final Set<String> labelsEn = <String>{};
  for (final RelationshipType type in types) {
    if (type.id.isEmpty ||
        type.labelZh.trim().isEmpty ||
        type.labelEn.trim().isEmpty) {
      return '關係類型欄位不正確。';
    }
    if (!BuiltinRelationshipIds.isBuiltin(type.id) &&
        !_customIdPattern.hasMatch(type.id)) {
      return '關係類型 id 格式不正確。';
    }
    if (!ids.add(type.id)) {
      return '關係類型 id 重複。';
    }
    if (!labelsZh.add(type.labelZh.trim())) {
      return '關係類型中文名稱重複。';
    }
    if (!labelsEn.add(type.labelEn.trim())) {
      return '關係類型英文名稱重複。';
    }
  }
  return null;
}

/// 人物名冊（類型表 + 人物）。
final class PeopleCatalog {
  PeopleCatalog({
    required List<RelationshipType> relationshipTypes,
    required List<Person> people,
  }) : relationshipTypes = List<RelationshipType>.unmodifiable(
         relationshipTypes,
       ),
       people = List<Person>.unmodifiable(people);

  factory PeopleCatalog.empty() => PeopleCatalog(
    relationshipTypes: defaultBuiltinRelationshipTypes(),
    people: const <Person>[],
  );

  final List<RelationshipType> relationshipTypes;
  final List<Person> people;

  Set<String> get relationshipTypeIds => <String>{
    for (final RelationshipType type in relationshipTypes) type.id,
  };

  RelationshipType? typeById(String id) {
    for (final RelationshipType type in relationshipTypes) {
      if (type.id == id) {
        return type;
      }
    }
    return null;
  }

  /// 依類型表順序排出人物已選的關係 id。
  List<String> orderedRelationshipIds(Set<String> selected) {
    return <String>[
      for (final RelationshipType type in relationshipTypes)
        if (selected.contains(type.id)) type.id,
    ];
  }

  PeopleCatalog copyWith({
    List<RelationshipType>? relationshipTypes,
    List<Person>? people,
  }) => PeopleCatalog(
    relationshipTypes: relationshipTypes ?? this.relationshipTypes,
    people: people ?? this.people,
  );
}
