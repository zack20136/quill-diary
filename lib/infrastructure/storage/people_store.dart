import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../domain/people/person.dart';
import '../../domain/people/relationship_type.dart';
import '../../domain/recovery/recovery_metadata.dart';
import '../../domain/security/unlocked_vault_session.dart';
import '../../domain/shared/value_objects.dart';
import '../crypto/crypto_service.dart';
import 'shared/vault_file_ops.dart';
import 'vault_path_strategy.dart';

/// 加密人物名冊（`vault/people.json.enc`，LDJ2）。
class PeopleStore {
  PeopleStore({
    required VaultPathStrategy pathStrategy,
    required CryptoService cryptoService,
  }) : _pathStrategy = pathStrategy,
       _cryptoService = cryptoService;

  static const int catalogVersion = 1;
  static const String documentId = 'people_catalog';

  final VaultPathStrategy _pathStrategy;
  final CryptoService _cryptoService;

  Future<PeopleCatalog> read(UnlockedVaultSession session) async {
    final File file = File(await _pathStrategy.peopleCatalogPath());
    await recoverFileReplacement(file);
    if (!file.existsSync()) {
      return PeopleCatalog.empty();
    }

    final ParsedEncryptedDocument parsed = _cryptoService.parseFileBytes(
      await file.readAsBytes(),
    );
    final List<int> plain = await _cryptoService.decryptBytes(
      headerBytes: parsed.headerBytes,
      ciphertextBytes: parsed.ciphertextBytes,
      context: DecryptionContext(
        vaultId: session.vaultId,
        trustedDevice: session.trustedDevice,
        recoveryWrapKey: session.recoveryWrapKey,
        deviceSlotId: session.deviceSlotId,
      ),
    );
    final Object? decoded = jsonDecode(utf8.decode(plain));
    if (decoded is! Map) {
      throw const FormatException('人物名冊格式不正確。');
    }
    const Set<String> requiredKeys = <String>{'version', 'updatedAt', 'people'};
    const Set<String> optionalKeys = <String>{'relationshipTypes'};
    if (!requiredKeys.every(decoded.containsKey) ||
        decoded.keys.any(
          (Object? key) =>
              key is! String ||
              (!requiredKeys.contains(key) && !optionalKeys.contains(key)),
        )) {
      throw const FormatException('人物名冊欄位不正確。');
    }
    final Object? version = decoded['version'];
    if (version is! int || version != catalogVersion) {
      throw const FormatException('人物名冊版本不支援。');
    }
    final Object? updatedAtRaw = decoded['updatedAt'];
    if (updatedAtRaw is! String || DateTime.tryParse(updatedAtRaw) == null) {
      throw const FormatException('人物名冊缺少有效的更新時間。');
    }
    final Object? peopleRaw = decoded['people'];
    if (peopleRaw is! List) {
      throw const FormatException('人物名冊缺少 people 陣列。');
    }

    final List<RelationshipType> relationshipTypes;
    final Object? typesRaw = decoded['relationshipTypes'];
    if (typesRaw == null) {
      relationshipTypes = defaultBuiltinRelationshipTypes();
    } else if (typesRaw is! List) {
      throw const FormatException('人物名冊關係類型格式不正確。');
    } else {
      relationshipTypes = <RelationshipType>[];
      for (final Object? item in typesRaw) {
        final RelationshipType? type = RelationshipType.fromJson(item);
        if (type == null) {
          throw const FormatException('人物名冊含有損壞的關係類型。');
        }
        relationshipTypes.add(type);
      }
    }

    final List<Person> people = <Person>[];
    for (final Object? item in peopleRaw) {
      if (item is Map &&
          (item['friendliness'] is! int ||
              FriendlinessLevel.tryParse(item['friendliness']) == null)) {
        throw const FormatException('人物名冊含有無效的熟悉程度。');
      }
      final Person? person = Person.fromJson(item);
      if (person == null) {
        throw const FormatException('人物名冊含有損壞的人物資料。');
      }
      people.add(person);
    }
    final PeopleCatalog catalog = PeopleCatalog(
      relationshipTypes: relationshipTypes,
      people: people,
    );
    _validateCatalog(catalog);
    return catalog;
  }

  Future<void> write(
    UnlockedVaultSession session, {
    required RecoveryMetadata metadata,
    required PeopleCatalog catalog,
  }) async {
    _validateCatalog(catalog);
    final List<int> recoveryWrapKey =
        session.recoveryWrapKey ??
        (throw StateError('目前 session 缺少 recovery wrap key。'));
    final DateTime now = DateTime.now();
    final Map<String, Object?> payload = <String, Object?>{
      'version': catalogVersion,
      'updatedAt': now.toIso8601String(),
      'relationshipTypes': catalog.relationshipTypes
          .map((RelationshipType type) => type.toJson())
          .toList(growable: false),
      'people': catalog.people
          .map(
            (Person person) => _personToJsonOrdered(
              person,
              catalog.orderedRelationshipIds(person.relationships),
            ),
          )
          .toList(growable: false),
    };
    final Uint8List plainBytes = Uint8List.fromList(
      utf8.encode(jsonEncode(payload)),
    );
    final EncryptionResult encrypted = await _cryptoService.encryptBytes(
      documentId: documentId,
      vaultId: metadata.vaultId,
      plaintextBytes: plainBytes,
      contentType: 'application/json',
      recoveryWrapKey: recoveryWrapKey,
      recoverySlotKdf: metadata.kdf,
      createdAt: now,
      updatedAt: now,
    );

    final File file = File(await _pathStrategy.peopleCatalogPath());
    await replaceFileBytesRecoverably(file, encrypted.toFileBytes());
  }
}

void _validateCatalog(PeopleCatalog catalog) {
  final String? typesError = validateRelationshipTypes(
    catalog.relationshipTypes,
  );
  if (typesError != null) {
    throw FormatException(typesError);
  }
  final Set<String> typeIds = catalog.relationshipTypeIds;
  for (final Person person in catalog.people) {
    for (final String relationshipId in person.relationships) {
      if (!typeIds.contains(relationshipId)) {
        throw const FormatException('人物名冊含有未知的關係類型。');
      }
    }
  }
  _validateCatalogPeople(catalog.people);
}

Map<String, Object?> _personToJsonOrdered(
  Person person,
  List<String> orderedRelationships,
) {
  final Map<String, Object?> json = person.toJson();
  json['relationships'] = orderedRelationships;
  return json;
}

void _validateCatalogPeople(List<Person> people) {
  final Set<PersonId> personIds = <PersonId>{};
  final Set<String> catalogNames = <String>{};
  for (final Person person in people) {
    if (Person.fromJson(person.toJson()) == null) {
      throw const FormatException('人物名冊含有無效的人物資料。');
    }
    if (!personIds.add(person.id)) {
      throw const FormatException('人物名冊含有重複的人物 ID。');
    }
    final List<String> names = <String>[
      person.normalizedName,
      ...person.normalizedAliases,
    ];
    if (names.any((String name) => name.isEmpty) ||
        names.toSet().length != names.length) {
      throw const FormatException('同一人物含有重複的姓名或別名。');
    }
    for (final String name in names) {
      if (!catalogNames.add(name)) {
        throw const FormatException('人物名冊含有重複的姓名或別名。');
      }
    }
  }
}
