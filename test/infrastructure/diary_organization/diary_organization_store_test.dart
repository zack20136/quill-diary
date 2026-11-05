import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/diary_organization/diary_organization.dart';
import 'package:quill_diary/infrastructure/crypto/crypto_service.dart';
import 'package:quill_diary/infrastructure/diary_organization/diary_organization_store.dart';

import '../../helpers/ai/ai_test_helpers.dart';
import '../../helpers/vault/vault_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('整理草稿加密保存、備份排除，套用只改內文並清除草稿', () async {
    final harness = await VaultTestHarness.create();
    addTearDown(harness.dispose);
    final setup = await harness.repository.setupRecoveryKey();
    final id = await harness.saveSimpleEntry(
      setup,
      markdownBody: '私密的原文',
      title: '原標題',
      tags: ['標籤'],
    );
    final source = (await harness.repository.loadEntry(setup.session, id))!;
    final store = DiaryOrganizationStore(
      paths: harness.pathStrategy,
      crypto: LocalCryptoService(),
      repository: harness.repository,
    );
    final draft = DiaryOrganization(
      source: source,
      connection: testChatDiarySession().connectionConfig,
    );
    draft.prepare();
    draft.replaceBody('整理後的內文');
    draft.stage = OrganizationStage.review;
    await store.save(draft, setup.session);
    final directory = await harness.pathStrategy.organizationDraftDirectory(id);
    final bytes = await File('${directory.path}/session.json.enc')
        .readAsBytes();
    expect(String.fromCharCodes(bytes), isNot(contains('私密的原文')));
    expect(
      (await store.load(id, setup.session))!.stage,
      OrganizationStage.review,
    );
    final backup = await harness.createTransferIo().backup.writeBackupZip(
      File('${harness.tempDir.path}/backup.zip'),
    );
    final archive = ZipDecoder().decodeBytes(await backup.readAsBytes());
    expect(
      archive.files.any(
        (file) => file.name.contains('diary_organization_drafts'),
      ),
      isFalse,
    );
    final saved = (await store.apply(draft, setup.session))!;
    expect(saved.markdownBody, '整理後的內文');
    expect(saved.title, source.title);
    expect(saved.date.value, source.date.value);
    expect(saved.createdAt, source.createdAt);
    expect(saved.tags, source.tags);
    expect(saved.attachmentIds, source.attachmentIds);
    expect(directory.existsSync(), isFalse);
    expect((await harness.repository.searchEntries('整理後')).single.id, id);
  });

  test('儲存日記後在清理前中斷，下次載入辨識已套用並清理', () async {
    final harness = await VaultTestHarness.create();
    addTearDown(harness.dispose);
    final setup = await harness.repository.setupRecoveryKey();
    final id = await harness.saveSimpleEntry(setup);
    final source = (await harness.repository.loadEntry(setup.session, id))!;
    final store = DiaryOrganizationStore(
      paths: harness.pathStrategy,
      crypto: LocalCryptoService(),
      repository: harness.repository,
    );
    final draft = DiaryOrganization(
      source: source,
      connection: testChatDiarySession().connectionConfig,
    );
    draft.prepare();
    draft.replaceBody('已套用的內文');
    draft.stage = OrganizationStage.applying;
    await store.save(draft, setup.session);
    await harness.repository.applyOrganizedBody(
      setup.session,
      source: source,
      body: draft.restoredBody,
    );
    expect(await store.load(id, setup.session), isNull);
    expect(
      (await harness.repository.loadEntry(setup.session, id))!.markdownBody,
      '已套用的內文',
    );
    expect(
      (await harness.pathStrategy.organizationDraftDirectory(id)).existsSync(),
      isFalse,
    );
  });

  test('刪除日記清除整理草稿，晚到的儲存也不能重新建立', () async {
    final harness = await VaultTestHarness.create();
    addTearDown(harness.dispose);
    final setup = await harness.repository.setupRecoveryKey();
    final id = await harness.saveSimpleEntry(setup);
    final source = (await harness.repository.loadEntry(setup.session, id))!;
    final store = DiaryOrganizationStore(
      paths: harness.pathStrategy,
      crypto: LocalCryptoService(),
      repository: harness.repository,
    );
    final draft = DiaryOrganization(
      source: source,
      connection: testChatDiarySession().connectionConfig,
    );
    await store.save(draft, setup.session);
    await harness.repository.deleteEntry(setup.session, id);
    expect(
      (await harness.pathStrategy.organizationDraftDirectory(id)).existsSync(),
      isFalse,
    );
    await expectLater(store.save(draft, setup.session), throwsFormatException);
    expect(
      (await harness.pathStrategy.organizationDraftDirectory(id)).existsSync(),
      isFalse,
    );
  });
}
