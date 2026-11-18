import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quill_diary/domain/ai/ai_stored_settings.dart';
import 'package:quill_diary/domain/ai/private_text.dart';
import 'package:quill_diary/domain/people/person.dart';
import 'package:quill_diary/domain/persona/persona.dart';
import 'package:quill_diary/domain/persona/persona_chat_import.dart';
import 'package:quill_diary/infrastructure/ai/ai_settings_store.dart';
import 'package:quill_diary/infrastructure/crypto/crypto_service.dart';
import 'package:quill_diary/infrastructure/persona/persona_store.dart';
import 'package:quill_diary/infrastructure/storage/portable/backup_archive_inspection.dart';
import 'package:quill_diary/infrastructure/storage/shared/vault_file_ops.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';
import 'package:quill_diary/infrastructure/storage/vault_state_keys.dart';

import '../../helpers/persona/persona_fixtures.dart';
import '../../helpers/vault/manifest_write_test_crypto_service.dart';
import '../../helpers/vault/vault_test_harness.dart';

void main() {
  late VaultTestHarness harness;
  late RecoverySetupResult setup;
  late PersonaStore store;
  late PersonaRecord record;
  setUp(() async {
    harness = await VaultTestHarness.create();
    setup = await harness.repository.setupRecoveryKey();
    final person = await harness.repository.createPerson(
      setup.session,
      PersonDraft(name: '測試朋友'),
    );
    store = PersonaStore(
      paths: harness.pathStrategy,
      crypto: LocalCryptoService(),
      repository: harness.repository,
    );
    record = personaDraftRecord(setup.session.vaultId, person.id);
    await store.saveDraft(record, setup.session, create: true);
  });
  tearDown(() => harness.dispose());

  Future<PersonaRecord> publish() async {
    record.draft!.candidate = personaCandidates();
    record.draft!.step = PersonaStep.review;
    await store.saveDraft(record, setup.session);
    return store.publish(record.personId, record.personaId, setup.session);
  }

  for (final suffix in ['.previous', '.tmp']) {
    test('分身僅剩 $suffix 時拒絕新輪替，不寫旗標；正確復原金鑰仍可存取並處理分身', () async {
      await publish();
      final entryId = await harness.saveSimpleEntry(
        setup,
        markdownBody: '保留的日記',
      );
      final state = File(
        '${(await store.directory(record.personId)).path}/state.json.enc',
      );
      final bytes = await state.readAsBytes();
      final candidate = await state.rename('${state.path}$suffix');
      final metadata = (await harness.repository.readRecoveryMetadata())!
          .toJson();
      await expectLater(
        harness.rotateRecoveryKey(setup.session),
        throwsFormatException,
      );
      expect(state.existsSync(), isFalse);
      expect(await candidate.readAsBytes(), bytes);
      expect(
        (await harness.repository.readRecoveryMetadata())!.toJson(),
        metadata,
      );
      expect(
        File(await harness.pathStrategy.recoveryRotationPendingPath())
            .existsSync(),
        isFalse,
      );
      expect(
        await harness.indexDatabaseManager.requireOpen().getAppValue(
          kRewrapInProgressKey,
        ),
        isNot('true'),
      );
      final recovered = await harness.repository.unlockWithRecoveryKey(
        setup.recoveryKey,
      );
      expect(recovered.trustedDevice, isFalse);
      expect(
        await harness.repository.ensureKeystoreMatchesUnlockMode(recovered),
        same(recovered),
      );
      expect(state.existsSync(), isFalse);
      expect(
        (await harness.repository.loadEntry(recovered, entryId))!.markdownBody,
        '保留的日記',
      );
      await store.delete(record.personId, recovered);
      final trusted = await harness.repository.ensureKeystoreMatchesUnlockMode(
        recovered,
      );
      expect(trusted.trustedDevice, isTrue);
    });
  }

  test('已發布分身與僅剩 tmp 的 AI 設定均納入輪替，新金鑰可讀且不遺留舊暫存', () async {
    final published = await publish();
    final settings = AiSettingsStore(
      pathStrategy: harness.pathStrategy,
      cryptoService: LocalCryptoService(),
      repository: harness.repository,
    );
    await settings.save(
      setup.session,
      const AiStoredSettings(hidePersonNames: false),
    );
    final file = File(await harness.pathStrategy.aiSettingsPath());
    await file.rename('${file.path}.tmp');
    final rotated = await harness.rotateRecoveryKey(setup.session);
    expect((await settings.read(rotated.session)).hidePersonNames, isFalse);
    expect(
      (await store.load(record.personId, rotated.session))!.toJson(),
      published.toJson(),
    );
    expect(File('${file.path}.tmp').existsSync(), isFalse);
  });

  test('真正的輪替中斷可恢復分身替換檔並回到使用者原金鑰', () async {
    await harness.dispose();
    final crypto = ManifestWriteTestCryptoService();
    harness = await VaultTestHarness.create(cryptoService: crypto);
    setup = await harness.repository.setupRecoveryKey();
    final person = await harness.repository.createPerson(
      setup.session,
      PersonDraft(name: '測試人物'),
    );
    store = PersonaStore(
      paths: harness.pathStrategy,
      crypto: crypto,
      repository: harness.repository,
    );
    record = personaDraftRecord(setup.session.vaultId, person.id);
    await store.saveDraft(record, setup.session, create: true);
    final published = await publish();
    crypto.failRotationAfterEncryptedFiles = 1;
    await expectLater(
      harness.rotateRecoveryKey(setup.session),
      throwsStateError,
    );
    crypto.failRotationAfterEncryptedFiles = null;
    final file = File(
      '${(await store.directory(record.personId)).path}/state.json.enc',
    );
    await file.rename('${file.path}.previous');
    await harness.repository.closeUnlockedResources();
    final recovered = await harness.repository.openTrustedSession();
    expect(
      (await store.load(record.personId, recovered))!.toJson(),
      published.toJson(),
    );
    expect(
      (await harness.repository.readRecoveryMetadata())!.recoveryKeyHint,
      setup.recoveryKey.substring(setup.recoveryKey.length - 4),
    );
    expect(
      File(await harness.pathStrategy.recoveryRotationPendingPath())
          .existsSync(),
      isFalse,
    );
  });

  test('既有裝置重新包裝旗標可續跑分身替換，不套用新操作的拒絕規則', () async {
    final published = await publish();
    await harness.indexDatabaseManager.requireOpen().setAppValue(
      kRewrapInProgressKey,
      'true',
    );
    final file = File(
      '${(await store.directory(record.personId)).path}/state.json.enc',
    );
    await file.rename('${file.path}.tmp');
    await harness.repository.closeUnlockedResources();
    final recovered = await harness.repository.openTrustedSession();
    expect(
      (await store.load(record.personId, recovered))!.toJson(),
      published.toJson(),
    );
    expect(
      await harness.indexDatabaseManager.requireOpen().getAppValue(
        kRewrapInProgressKey,
      ),
      'false',
    );
  });

  test('讀取匯入時拒絕超界隱藏座標與不存在的訊息參照，不裁切', () async {
    final imported = parsePersonaChat(
      '2026/11/06\n12:00\t朋友\t文字',
      vaultId: record.vaultId,
      personId: record.personId,
      personaId: record.personaId,
    );
    record.draft!.chats.add(PersonaChatSource(importId: imported.importId));
    record = await store.saveImport(
      imported,
      setup.session,
      draft: record.draft!,
    );
    final source = record.draft!.chats.single;
    source.hidden['m1'] = [const PrivateTextRange(0, 99)];
    await expectLater(
      store.readImport(
        record.personId,
        record.personaId,
        source,
        setup.session,
      ),
      throwsFormatException,
    );
    source.hidden.clear();
    source.excluded.add('missing');
    await expectLater(
      store.readImport(
        record.personId,
        record.personaId,
        source,
        setup.session,
      ),
      throwsFormatException,
    );
  });

  test('匯入內容成功但狀態提交失敗時保留舊指標、文字與隱藏範圍，下次清除孤立檔', () async {
    final imported = parsePersonaChat(
      '2026/11/06\n12:00\t朋友\t原始聊天文字',
      vaultId: record.vaultId,
      personId: record.personId,
      personaId: record.personaId,
    );
    final source = PersonaChatSource(
      importId: imported.importId,
      hidden: {
        'm1': [const PrivateTextRange(0, 2)],
      },
    );
    record.draft!.chats.add(source);
    record = await store.saveImport(
      imported,
      setup.session,
      draft: record.draft!,
    );
    final original = record.draft!.chats.single;
    final nextDraft = PersonaDraft.fromJson(
      jsonDecode(jsonEncode(record.draft!.toJson())) as Map<String, dynamic>,
    );
    nextDraft.chats.single.hidden['m1'] = [const PrivateTextRange(0, 1)];
    final edited = PersonaChatImport(
      vaultId: imported.vaultId,
      personId: imported.personId,
      personaId: imported.personaId,
      importId: imported.importId,
      importedAt: imported.importedAt,
      speakers: imported.speakers,
      messages: [
        PersonaImportMessage(
          id: 'm1',
          speakerId: 's1',
          text: '修改後文字',
          sentAtLocal: imported.messages.single.sentAtLocal,
        ),
      ],
    );
    var checkpoints = 0;
    await expectLater(
      store.saveImport(
        edited,
        setup.session,
        draft: nextDraft,
        ensureCurrent: () {
          if (++checkpoints == 3) throw const FormatException('狀態提交前停止');
        },
      ),
      throwsFormatException,
    );
    final pending = Directory(
      p.join((await store.directory(record.personId)).path, 'pending_imports'),
    );
    expect(pending.listSync().whereType<File>(), hasLength(2));
    final reopened = (await store.load(record.personId, setup.session))!;
    expect(reopened.draft!.chats.single.contentId, original.contentId);
    expect(reopened.draft!.chats.single.hidden['m1']!.single.end, 2);
    expect(
      (await store.readImport(
        record.personId,
        record.personaId,
        reopened.draft!.chats.single,
        setup.session,
      )).messages.single.text,
      '原始聊天文字',
    );
    expect(pending.listSync().whereType<File>(), hasLength(1));
    final committed = await store.saveImport(
      edited,
      setup.session,
      draft: nextDraft,
    );
    expect(committed.draft!.chats.single.importId, original.importId);
    expect(committed.draft!.chats.single.contentId, isNot(original.contentId));
    expect(
      (await store.readImport(
        record.personId,
        record.personaId,
        committed.draft!.chats.single,
        setup.session,
      )).messages.single.text,
      '修改後文字',
    );
    expect(pending.listSync().whereType<File>(), hasLength(1));
  });

  test('讀取匯入時固定內容指標，不使用等待期間的來源修改', () async {
    final imported = parsePersonaChat(
      '2026/11/06\n12:00\t朋友\t原始聊天文字',
      vaultId: record.vaultId,
      personId: record.personId,
      personaId: record.personaId,
    );
    record.draft!.chats.add(PersonaChatSource(importId: imported.importId));
    record = await store.saveImport(
      imported,
      setup.session,
      draft: record.draft!,
    );
    final source = record.draft!.chats.single;
    final reading = store.readImport(
      record.personId,
      record.personaId,
      source,
      setup.session,
    );
    source.contentId = PersonaChatSource(importId: imported.importId).contentId;

    expect((await reading).toJson(), imported.toJson());
  });

  test('相同匯入的不同內容檔交換密文時也會拒讀，不回復成過期文字', () async {
    final imported = parsePersonaChat(
      '2026/11/06\n12:00\t朋友\t聊天文字',
      vaultId: record.vaultId,
      personId: record.personId,
      personaId: record.personaId,
    );
    record.draft!.chats.add(PersonaChatSource(importId: imported.importId));
    record = await store.saveImport(
      imported,
      setup.session,
      draft: record.draft!,
    );
    final first = record.draft!.chats.single;
    final pending = Directory(
      p.join((await store.directory(record.personId)).path, 'pending_imports'),
    );
    final bytes = await pending
        .listSync()
        .whereType<File>()
        .single
        .readAsBytes();
    record = await store.saveImport(
      imported,
      setup.session,
      draft: record.draft!,
    );
    final second = record.draft!.chats.single;
    expect(second.contentId, isNot(first.contentId));
    final file = pending.listSync().whereType<File>().single;
    await file.writeAsBytes(bytes);
    await expectLater(
      store.readImport(
        record.personId,
        record.personaId,
        second,
        setup.session,
      ),
      throwsFormatException,
    );
    expect(await file.readAsBytes(), bytes);
  });

  test('分身儲存排隊前凍結快照，不讀取等待期間新增的候選或隱藏設定', () async {
    final gate = Completer<void>();
    final blocker = harness.repository.runVaultMutation(() => gate.future);
    final saving = store.saveDraft(record, setup.session);
    record.draft!.hidePersonNames = false;
    record.draft!.candidate = personaCandidates();
    record.draft!.step = PersonaStep.review;
    gate.complete();
    await blocker;
    await saving;
    final saved = (await store.load(record.personId, setup.session))!;
    expect(saved.draft!.hidePersonNames, isTrue);
    expect(saved.draft!.candidate, isNull);
    expect(saved.draft!.step, PersonaStep.materials);
  });

  test('候選先存草稿，正式提交後清除聊天及全部替換檔，不保存來源原文', () async {
    final imported = parsePersonaChat(
      '2026/11/06（五）\n12:00\t朋友\t這是敏感原文',
      vaultId: record.vaultId,
      personId: record.personId,
      personaId: record.personaId,
    );
    record.draft!.chats.add(PersonaChatSource(importId: imported.importId));
    record = await store.saveImport(
      imported,
      setup.session,
      draft: record.draft!,
    );
    final dir = await store.directory(record.personId);
    final pending = Directory(p.join(dir.path, 'pending_imports'));
    expect(pending.listSync().whereType<File>(), hasLength(1));
    expect((await store.load(record.personId, setup.session))!.cards, isNull);
    record = await publish();
    expect(record.draft, isNull);
    expect(pending.listSync(), isEmpty);
    final files = dir.listSync(recursive: true).whereType<File>().toList();
    expect(files.map((f) => p.basename(f.path)), ['state.json.enc']);
    final crypto = LocalCryptoService();
    final parsed = crypto.parseFileBytes(await files.single.readAsBytes());
    final plain = utf8.decode(
      await crypto.decryptBytes(
        headerBytes: parsed.headerBytes,
        ciphertextBytes: parsed.ciphertextBytes,
        context: vaultDecryptionContext(setup.session),
      ),
    );
    expect(plain, isNot(contains('敏感原文')));
    expect(plain, isNot(contains('import_id')));
    expect(plain, isNot(contains('body_hash')));
  });

  test('只更新一項時不變更另一項，缺一項的候選不會部分提交', () async {
    record = await publish();
    final tone = record.cards![PersonaCardKind.tone]!.toJson();
    final d = PersonaDraft(
      target: PersonaUpdateTarget.memory,
      baseUpdatedAt: {
        PersonaCardKind.memory:
            record.cards![PersonaCardKind.memory]!.updatedAt,
      },
      step: PersonaStep.review,
      candidate: {PersonaCardKind.memory: PersonaCandidate(text: '新記憶')},
    );
    await store.saveDraft(record.withDraft(d), setup.session);
    record = await store.publish(
      record.personId,
      record.personaId,
      setup.session,
    );
    expect(record.cards![PersonaCardKind.memory]!.text, '新記憶');
    expect(record.cards![PersonaCardKind.tone]!.toJson(), tone);
    final broken = PersonaDraft(
      target: PersonaUpdateTarget.both,
      baseUpdatedAt: {
        for (final e in record.cards!.entries) e.key: e.value.updatedAt,
      },
      candidate: {PersonaCardKind.memory: PersonaCandidate(text: '不能部分提交')},
    );
    await expectLater(
      store.saveDraft(record.withDraft(broken), setup.session),
      throwsFormatException,
    );
    expect(
      (await store.load(
        record.personId,
        setup.session,
      ))!.cards![PersonaCardKind.memory]!.text,
      '新記憶',
    );
  });

  test('損毀主檔或只剩舊副本時保留現場，不恢復舊草稿', () async {
    final file = File(
      p.join((await store.directory(record.personId)).path, 'state.json.enc'),
    );
    await file.copy('${file.path}.previous');
    await file.writeAsBytes([1, 2, 3]);
    await expectLater(
      store.load(record.personId, setup.session),
      throwsA(anything),
    );
    expect(File('${file.path}.previous').existsSync(), isTrue);
    await file.delete();
    await expectLater(
      store.load(record.personId, setup.session),
      throwsFormatException,
    );
    expect(file.existsSync(), isFalse);
  });

  test('取消提交保留原狀態，刪除後排隊中的一般暫存不能重建分身', () async {
    record.draft!.candidate = personaCandidates();
    await expectLater(
      store.saveDraft(
        record,
        setup.session,
        ensureCurrent: () => throw StateError('工作已取消'),
      ),
      throwsStateError,
    );
    expect(
      (await store.load(record.personId, setup.session))!.draft!.candidate,
      isNull,
    );
    await store.delete(record.personId, setup.session);
    await expectLater(
      store.saveDraft(record, setup.session),
      throwsFormatException,
    );
    expect(await store.load(record.personId, setup.session), isNull);
  });

  test('正式提交後的舊草稿保存不能恢復更新或覆蓋卡片', () async {
    record.draft!.candidate = personaCandidates(memory: '正式提交內容');
    record.draft!.step = PersonaStep.review;
    await store.saveDraft(record, setup.session);
    final published = await store.publish(
      record.personId,
      record.personaId,
      setup.session,
    );
    await expectLater(
      store.saveDraft(record, setup.session),
      throwsFormatException,
    );
    final saved = (await store.load(record.personId, setup.session))!;
    expect(saved.toJson(), published.toJson());
  });

  test('刪除重建分身後，舊生命週期的快照不能改寫新草稿', () async {
    final previous = record;
    await store.delete(record.personId, setup.session);
    record = personaDraftRecord(setup.session.vaultId, record.personId);
    await store.saveDraft(record, setup.session, create: true);
    await expectLater(
      store.saveDraft(previous, setup.session),
      throwsFormatException,
    );
    expect(
      (await store.load(record.personId, setup.session))!.personaId,
      record.personaId,
    );
  });

  test('備份也排除大小寫不同的原始分身目錄', () async {
    final rawDirectory = Directory(
      p.join(
        (await harness.pathStrategy.vaultRootDirectory()).path,
        'Personas',
      ),
    );
    await rawDirectory.create(recursive: true);
    await File(p.join(rawDirectory.path, 'pending.txt'))
        .writeAsString('不應備份的材料');
    final backup = File(p.join(harness.tempDir.path, 'backup.zip'));
    await harness
        .createTransferIo(session: setup.session)
        .backup
        .writeBackupZip(backup);

    final archive = ZipDecoder().decodeBytes(await backup.readAsBytes());
    expect(
      archive.files.where(
        (file) => file.name.split('/').first.toLowerCase() == 'personas',
      ),
      isEmpty,
    );
  });

  test('正式分身加密備份並還原備份當下內容，排除更新草稿與匯入原文', () async {
    await harness.saveSimpleEntry(setup);
    record = await publish();
    final published = record.withDraft(null).toJson();
    final draft = PersonaDraft(
      target: PersonaUpdateTarget.memory,
      baseUpdatedAt: {
        PersonaCardKind.memory:
            record.cards![PersonaCardKind.memory]!.updatedAt,
      },
    );
    record = record.withDraft(draft);
    await store.saveDraft(record, setup.session);
    final imported = parsePersonaChat(
      '2026/11/06\n12:00\t朋友\t不可備份的聊天原文',
      vaultId: record.vaultId,
      personId: record.personId,
      personaId: record.personaId,
    );
    draft.chats.add(
      PersonaChatSource(
        importId: imported.importId,
        hidden: {
          'm1': [const PrivateTextRange(0, 2)],
        },
      ),
    );
    record = await store.saveImport(imported, setup.session, draft: draft);
    record.draft!.candidate = {
      PersonaCardKind.memory: PersonaCandidate(text: '尚未套用的候選內容'),
    };
    record.draft!.step = PersonaStep.review;
    await store.saveDraft(record, setup.session);
    final unfinishedPerson = await harness.repository.createPerson(
      setup.session,
      PersonDraft(name: '只有草稿'),
    );
    final unfinished = personaDraftRecord(
      setup.session.vaultId,
      unfinishedPerson.id,
    );
    await store.saveDraft(unfinished, setup.session, create: true);
    final state = File(
      p.join((await store.directory(record.personId)).path, 'state.json.enc'),
    );
    final liveBytes = await state.readAsBytes();
    final io = harness.createTransferIo(session: setup.session).backup;
    final backup = await io.writeBackupZip(
      File(p.join(harness.tempDir.path, 'backup.zip')),
    );
    expect((await io.inspectBackup(backup)).ok, isTrue);
    expect(
      (await io.prepareRestorePreview(backup)).metadata.vaultId,
      setup.session.vaultId,
    );
    final zip = ZipDecoder().decodeBytes(await backup.readAsBytes());
    final files = zip.files
        .where((f) => f.name.startsWith('personas/'))
        .toList();
    expect(files.map((f) => f.name), [
      'personas/${record.personId}/state.json.enc',
    ]);
    final encrypted = files.single.content as List<int>;
    expect(
      utf8.decode(encrypted, allowMalformed: true),
      isNot(contains('既有記憶')),
    );
    final parsed = LocalCryptoService().parseFileBytes(encrypted);
    expect(parsed.header.fileId, 'persona:${record.personId}:state');
    final plain = await LocalCryptoService().decryptBytes(
      headerBytes: parsed.headerBytes,
      ciphertextBytes: parsed.ciphertextBytes,
      context: vaultDecryptionContext(setup.session),
    );
    expect(jsonDecode(utf8.decode(plain)), published);
    expect(await state.readAsBytes(), liveBytes);
    final live = (await store.load(record.personId, setup.session))!;
    expect(live.draft!.candidate![PersonaCardKind.memory]!.text, '尚未套用的候選內容');
    expect(live.draft!.chats, hasLength(1));
    live.draft!.candidate = {
      PersonaCardKind.memory: PersonaCandidate(text: '備份後更新的記憶'),
    };
    await store.saveDraft(live, setup.session);
    await store.publish(record.personId, record.personaId, setup.session);
    final rotated = await harness.rotateRecoveryKey(setup.session);
    expect(
      (await store.load(
        record.personId,
        rotated.session,
      ))!.cards![PersonaCardKind.memory]!.text,
      '備份後更新的記憶',
    );
    await io.restoreBackupZip(backup);
    final session = await harness.repository.unlockWithRecoveryKey(
      setup.recoveryKey,
    );
    final restored = (await store.load(record.personId, session))!;
    expect(restored.toJson(), published);
    expect(restored.available, isTrue);
    expect(restored.draft, isNull);
    expect((await store.list(session)).map((r) => r.personaId), [
      record.personaId,
    ]);
    expect(await store.load(unfinished.personId, session), isNull);
    expect(
      Directory(
        p.join(
          (await store.directory(record.personId)).path,
          'pending_imports',
        ),
      ).existsSync(),
      isFalse,
    );
  });

  test('交換人物密文不會讀成另一位的分身，保留檔案供明確復原', () async {
    final other = await harness.repository.createPerson(
      setup.session,
      PersonDraft(name: '另一位'),
    );
    final original = File(
      p.join((await store.directory(record.personId)).path, 'state.json.enc'),
    );
    final swapped = File(
      p.join((await store.directory(other.id)).path, 'state.json.enc'),
    );
    await swapped.parent.create(recursive: true);
    await original.copy(swapped.path);
    await expectLater(
      store.load(other.id, setup.session),
      throwsFormatException,
    );
    expect(swapped.existsSync(), isTrue);
    expect(
      (await store.load(record.personId, setup.session))!.personaId,
      record.personaId,
    );
  });

  for (final invalidPath in [
    'Personas/{person}/state.json.enc',
    'personas/{person}/pending_imports/private.json.enc',
    'personas/{person}/draft.json.enc',
    'personas/{person}/state.json.enc.previous',
  ]) {
    test('備份檢查與還原拒絕非正式分身路徑 $invalidPath，保留既有資料', () async {
      await harness.saveSimpleEntry(setup);
      final io = harness.createTransferIo(session: setup.session).backup;
      final file = await io.writeBackupZip(
        File(p.join(harness.tempDir.path, 'restore.zip')),
      );
      final archive = ZipDecoder().decodeBytes(await file.readAsBytes());
      archive.addFile(
        ArchiveFile(invalidPath.replaceAll('{person}', record.personId), 3, [
          1,
          2,
          3,
        ]),
      );
      await file.writeAsBytes(ZipEncoder().encode(archive));
      expect((await io.inspectBackup(file)).ok, isFalse);
      await expectLater(
        io.prepareRestorePreview(file),
        throwsA(isA<VaultBackupException>()),
      );
      await expectLater(
        io.restoreBackupZip(file),
        throwsA(
          isA<VaultBackupException>().having(
            (e) => e.issue,
            'issue',
            VaultBackupIssue.invalidArchive,
          ),
        ),
      );
      expect(
        (await store.load(record.personId, setup.session))!.personaId,
        record.personaId,
      );
    });
  }
}
