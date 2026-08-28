import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/people/person.dart';
import 'package:quill_diary/domain/people/relationship_type.dart';
import 'package:quill_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_diary/infrastructure/crypto/crypto_service.dart';
import 'package:quill_diary/infrastructure/storage/people_store.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';

import '../../helpers/vault/vault_test_harness.dart';

void main() {
  test('v1 人物名冊可完整往返目前正式欄位', () async {
    final VaultTestHarness harness = await VaultTestHarness.create();
    addTearDown(harness.dispose);
    final RecoverySetupResult setup = await harness.repository
        .setupRecoveryKey();
    final RecoveryMetadata metadata = (await harness.repository
        .readRecoveryMetadata())!;
    final LocalCryptoService crypto = LocalCryptoService();
    final PeopleStore store = PeopleStore(
      pathStrategy: harness.pathStrategy,
      cryptoService: crypto,
    );
    final DateTime now = DateTime.utc(2026, 8, 10);
    final Person source = Person(
      id: 'per_complete',
      name: '王小明',
      aliases: const <String>['小明', '明哥'],
      relationships: BuiltinRelationshipIds.asSet,
      relationshipDescription: '大學同學與專案合作夥伴',
      notes: '測試備註',
      friendliness: FriendlinessLevel(4),
      accentArgb: 0xFF5480B0,
      mentionName: '明哥',
      birthday: PersonBirthday(month: 8, day: 10),
      acquaintanceYear: 2024,
      createdAt: now,
      updatedAt: now,
    );

    await store.write(
      setup.session,
      metadata: metadata,
      catalog: PeopleCatalog(
        relationshipTypes: defaultBuiltinRelationshipTypes(),
        people: <Person>[source],
      ),
    );

    final Map<String, Object?> payload = await _readCatalogPayload(
      harness: harness,
      setup: setup,
      crypto: crypto,
    );
    final Map<String, Object?> personJson =
        (payload['people']! as List<Object?>).single! as Map<String, Object?>;
    expect(payload['version'], 1);
    expect(payload['relationshipTypes'], isA<List<Object?>>());
    expect(personJson['relationships'], contains('collaborator'));
    expect(personJson['relationships'], isNot(contains('acquaintance')));
    expect(personJson['birthday'], <String, Object?>{'month': 8, 'day': 10});

    final File catalogFile = File(
      await harness.pathStrategy.peopleCatalogPath(),
    );
    final Uint8List bytesBeforeRead = await catalogFile.readAsBytes();
    final PeopleCatalog restoredCatalog = await store.read(setup.session);
    final Person restored = restoredCatalog.people.single;
    expect(await catalogFile.readAsBytes(), bytesBeforeRead);
    expect(restoredCatalog.relationshipTypes, hasLength(7));
    expect(restored.id, source.id);
    expect(restored.name, source.name);
    expect(restored.aliases, source.aliases);
    expect(restored.relationships, source.relationships);
    expect(restored.relationshipDescription, source.relationshipDescription);
    expect(restored.notes, source.notes);
    expect(restored.friendliness, source.friendliness);
    expect(restored.accentArgb, source.accentArgb);
    expect(restored.mentionName, source.mentionName);
    expect(restored.diaryMentionLabel, '明哥');
    expect(restored.birthday, source.birthday);
    expect(restored.acquaintanceYear, source.acquaintanceYear);
    expect(restored.createdAt, source.createdAt);
    expect(restored.updatedAt, source.updatedAt);
  });

  test('舊三鍵名冊缺少 relationshipTypes 時種子內建類型', () async {
    final VaultTestHarness harness = await VaultTestHarness.create();
    addTearDown(harness.dispose);
    final RecoverySetupResult setup = await harness.repository
        .setupRecoveryKey();
    final RecoveryMetadata metadata = (await harness.repository
        .readRecoveryMetadata())!;
    final LocalCryptoService crypto = LocalCryptoService();
    final DateTime now = DateTime.utc(2026, 8, 10);
    await _writeCatalogPayload(
      harness: harness,
      setup: setup,
      metadata: metadata,
      crypto: crypto,
      payload: <String, Object?>{
        'version': 1,
        'updatedAt': now.toIso8601String(),
        'people': <Object?>[_validPersonJson(now)],
      },
    );

    final PeopleCatalog catalog = await PeopleStore(
      pathStrategy: harness.pathStrategy,
      cryptoService: crypto,
    ).read(setup.session);
    expect(catalog.relationshipTypes, hasLength(7));
    expect(catalog.people.single.relationships, <String>{'friend'});
  });

  test('寫入後 relationshipTypes 順序可重排並保留', () async {
    final VaultTestHarness harness = await VaultTestHarness.create();
    addTearDown(harness.dispose);
    final RecoverySetupResult setup = await harness.repository
        .setupRecoveryKey();
    final RecoveryMetadata metadata = (await harness.repository
        .readRecoveryMetadata())!;
    final LocalCryptoService crypto = LocalCryptoService();
    final PeopleStore store = PeopleStore(
      pathStrategy: harness.pathStrategy,
      cryptoService: crypto,
    );
    final List<RelationshipType> builtins = defaultBuiltinRelationshipTypes();
    final List<RelationshipType> reversed = builtins.reversed.toList(
      growable: false,
    );
    await store.write(
      setup.session,
      metadata: metadata,
      catalog: PeopleCatalog(
        relationshipTypes: reversed,
        people: const <Person>[],
      ),
    );

    final PeopleCatalog catalog = await store.read(setup.session);
    expect(
      catalog.relationshipTypes.map((RelationshipType t) => t.id).toList(),
      reversed.map((RelationshipType t) => t.id).toList(),
    );
  });

  test('人物引用不存在的關係類型時整份拒絕', () async {
    final VaultTestHarness harness = await VaultTestHarness.create();
    addTearDown(harness.dispose);
    final RecoverySetupResult setup = await harness.repository
        .setupRecoveryKey();
    final RecoveryMetadata metadata = (await harness.repository
        .readRecoveryMetadata())!;
    final LocalCryptoService crypto = LocalCryptoService();
    final DateTime now = DateTime.utc(2026, 8, 10);
    final Map<String, Object?> person = _validPersonJson(now)
      ..['relationships'] = <String>['zzzzzzzz'];
    await _writeCatalogPayload(
      harness: harness,
      setup: setup,
      metadata: metadata,
      crypto: crypto,
      payload: <String, Object?>{
        'version': 1,
        'updatedAt': now.toIso8601String(),
        'relationshipTypes': defaultBuiltinRelationshipTypes()
            .map((RelationshipType t) => t.toJson())
            .toList(growable: false),
        'people': <Object?>[person],
      },
    );

    await expectLater(
      PeopleStore(
        pathStrategy: harness.pathStrategy,
        cryptoService: crypto,
      ).read(setup.session),
      throwsFormatException,
    );
  });

  const Object missingVersion = Object();
  for (final MapEntry<String, Object?> scenario in <MapEntry<String, Object?>>[
    const MapEntry<String, Object?>('版本 2', 2),
    const MapEntry<String, Object?>('版本 4', 4),
    const MapEntry<String, Object?>('版本 5', 5),
    const MapEntry<String, Object?>('未知版本', 99),
    const MapEntry<String, Object?>('缺少版本', missingVersion),
    const MapEntry<String, Object?>('非整數版本', '1'),
    const MapEntry<String, Object?>('浮點數版本', 1.0),
  ]) {
    test('${scenario.key}的人物名冊會被拒絕', () async {
      final VaultTestHarness harness = await VaultTestHarness.create();
      addTearDown(harness.dispose);
      final RecoverySetupResult setup = await harness.repository
          .setupRecoveryKey();
      final RecoveryMetadata metadata = (await harness.repository
          .readRecoveryMetadata())!;
      final LocalCryptoService crypto = LocalCryptoService();
      final DateTime now = DateTime.utc(2026, 8, 10);
      final Map<String, Object?> payload = <String, Object?>{
        'updatedAt': now.toIso8601String(),
        'people': <Object?>[],
      };
      if (!identical(scenario.value, missingVersion)) {
        payload['version'] = scenario.value;
      }
      await _writeCatalogPayload(
        harness: harness,
        setup: setup,
        metadata: metadata,
        crypto: crypto,
        payload: payload,
      );

      await expectLater(
        PeopleStore(
          pathStrategy: harness.pathStrategy,
          cryptoService: crypto,
        ).read(setup.session),
        throwsFormatException,
      );
    });
  }

  for (final MapEntry<String, void Function(Map<String, Object?>)> scenario
      in <MapEntry<String, void Function(Map<String, Object?>)>>[
        MapEntry<String, void Function(Map<String, Object?>)>(
          '缺少熟悉程度',
          (Map<String, Object?> person) => person.remove('friendliness'),
        ),
        MapEntry<String, void Function(Map<String, Object?>)>(
          '熟悉程度超出範圍',
          (Map<String, Object?> person) => person['friendliness'] = 6,
        ),
        MapEntry<String, void Function(Map<String, Object?>)>(
          '人物顏色不是不透明 ARGB',
          (Map<String, Object?> person) => person['accentArgb'] = 0x005480B0,
        ),
        MapEntry<String, void Function(Map<String, Object?>)>(
          '包含舊關係值',
          (Map<String, Object?> person) =>
              person['relationships'] = <String>['acquaintance'],
        ),
        MapEntry<String, void Function(Map<String, Object?>)>(
          '生日包含年份',
          (Map<String, Object?> person) => person['birthday'] =
              <String, Object?>{'year': 2024, 'month': 8, 'day': 10},
        ),
        MapEntry<String, void Function(Map<String, Object?>)>(
          '包含未知欄位',
          (Map<String, Object?> person) => person['legacy'] = true,
        ),
      ]) {
    test('v1 ${scenario.key}時不會默默補值或忽略', () async {
      final VaultTestHarness harness = await VaultTestHarness.create();
      addTearDown(harness.dispose);
      final RecoverySetupResult setup = await harness.repository
          .setupRecoveryKey();
      final RecoveryMetadata metadata = (await harness.repository
          .readRecoveryMetadata())!;
      final LocalCryptoService crypto = LocalCryptoService();
      final DateTime now = DateTime.utc(2026, 8, 10);
      final Map<String, Object?> person = _validPersonJson(now);
      scenario.value(person);
      await _writeCatalogPayload(
        harness: harness,
        setup: setup,
        metadata: metadata,
        crypto: crypto,
        payload: <String, Object?>{
          'version': 1,
          'updatedAt': now.toIso8601String(),
          'people': <Object?>[person],
        },
      );

      await expectLater(
        PeopleStore(
          pathStrategy: harness.pathStrategy,
          cryptoService: crypto,
        ).read(setup.session),
        throwsFormatException,
      );
    });
  }

  test('讀取認識年份不依賴目前裝置年份', () async {
    final VaultTestHarness harness = await VaultTestHarness.create();
    addTearDown(harness.dispose);
    final RecoverySetupResult setup = await harness.repository
        .setupRecoveryKey();
    final RecoveryMetadata metadata = (await harness.repository
        .readRecoveryMetadata())!;
    final LocalCryptoService crypto = LocalCryptoService();
    final Map<String, Object?> person = _validPersonJson(
      DateTime.utc(2026, 8, 10),
    )..['acquaintanceYear'] = 9999;
    await _writeCatalogPayload(
      harness: harness,
      setup: setup,
      metadata: metadata,
      crypto: crypto,
      payload: <String, Object?>{
        'version': 1,
        'updatedAt': DateTime.utc(2026, 8, 10).toIso8601String(),
        'people': <Object?>[person],
      },
    );

    expect(
      (await PeopleStore(
        pathStrategy: harness.pathStrategy,
        cryptoService: crypto,
      ).read(setup.session)).people.single.acquaintanceYear,
      9999,
    );
  });

  test('重複人物 ID 與跨人物姓名別名會被拒絕', () async {
    final VaultTestHarness harness = await VaultTestHarness.create();
    addTearDown(harness.dispose);
    final RecoverySetupResult setup = await harness.repository
        .setupRecoveryKey();
    final RecoveryMetadata metadata = (await harness.repository
        .readRecoveryMetadata())!;
    final LocalCryptoService crypto = LocalCryptoService();
    final DateTime now = DateTime.utc(2026, 8, 10);
    final Map<String, Object?> first = _validPersonJson(now);
    final Map<String, Object?> second = _validPersonJson(now)
      ..['name'] = '小華'
      ..['aliases'] = <String>['小明'];
    await _writeCatalogPayload(
      harness: harness,
      setup: setup,
      metadata: metadata,
      crypto: crypto,
      payload: <String, Object?>{
        'version': 1,
        'updatedAt': now.toIso8601String(),
        'people': <Object?>[first, second],
      },
    );

    await expectLater(
      PeopleStore(
        pathStrategy: harness.pathStrategy,
        cryptoService: crypto,
      ).read(setup.session),
      throwsFormatException,
    );
  });
}

Map<String, Object?> _validPersonJson(DateTime now) => <String, Object?>{
  'id': 'per_valid',
  'name': '小明',
  'aliases': <String>[],
  'relationships': <String>['friend'],
  'relationshipDescription': '',
  'notes': '',
  'friendliness': 3,
  'birthday': null,
  'acquaintanceYear': null,
  'createdAt': now.toIso8601String(),
  'updatedAt': now.toIso8601String(),
};

Future<void> _writeCatalogPayload({
  required VaultTestHarness harness,
  required RecoverySetupResult setup,
  required RecoveryMetadata metadata,
  required LocalCryptoService crypto,
  required Map<String, Object?> payload,
}) async {
  final DateTime now = DateTime.utc(2026, 8, 10);
  final EncryptionResult encrypted = await crypto.encryptBytes(
    documentId: PeopleStore.documentId,
    vaultId: setup.session.vaultId,
    plaintextBytes: Uint8List.fromList(utf8.encode(jsonEncode(payload))),
    contentType: 'application/json',
    recoveryWrapKey: setup.session.recoveryWrapKey!,
    recoverySlotKdf: metadata.kdf,
    createdAt: now,
    updatedAt: now,
  );
  final File catalogFile = File(await harness.pathStrategy.peopleCatalogPath());
  await catalogFile.parent.create(recursive: true);
  await catalogFile.writeAsBytes(encrypted.toFileBytes(), flush: true);
}

Future<Map<String, Object?>> _readCatalogPayload({
  required VaultTestHarness harness,
  required RecoverySetupResult setup,
  required LocalCryptoService crypto,
}) async {
  final File catalogFile = File(await harness.pathStrategy.peopleCatalogPath());
  final ParsedEncryptedDocument parsed = crypto.parseFileBytes(
    await catalogFile.readAsBytes(),
  );
  final List<int> plain = await crypto.decryptBytes(
    headerBytes: parsed.headerBytes,
    ciphertextBytes: parsed.ciphertextBytes,
    context: DecryptionContext(
      vaultId: setup.session.vaultId,
      trustedDevice: setup.session.trustedDevice,
      recoveryWrapKey: setup.session.recoveryWrapKey,
      deviceSlotId: setup.session.deviceSlotId,
    ),
  );
  return jsonDecode(utf8.decode(plain))! as Map<String, Object?>;
}
