import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quill_diary/domain/diary/diary_entry.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/storage/tag_styles_store.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';

import '../../helpers/vault/vault_test_harness.dart';

void main() {
  late VaultTestHarness harness;

  setUp(() async {
    harness = await VaultTestHarness.create();
  });

  tearDown(() async {
    await harness.dispose();
  });

  test('修復會將放錯路徑的日記搬回 canonical', () async {
    final RecoverySetupResult setup = await harness.repository
        .setupRecoveryKey();
    const String date = '2026-06-15';
    final String entryId = await harness.saveSimpleEntry(
      setup,
      date: date,
      title: 'Misplaced',
    );

    final String canonicalPath = await harness.pathStrategy.entryAbsolutePath(
      date: const DateOnly(date),
      entryId: entryId,
    );
    final Directory vaultRoot = await harness.pathStrategy.vaultRootDirectory();
    final String wrongPath = p.join(
      vaultRoot.path,
      'entries',
      '2099',
      '01',
      '$entryId.md.enc',
    );
    await File(wrongPath).parent.create(recursive: true);
    await File(canonicalPath).rename(wrongPath);
    expect(File(canonicalPath).existsSync(), isFalse);

    final VaultRepairReport report = await harness.repository
        .repairVaultWithReport(setup.session);

    expect(File(canonicalPath).existsSync(), isTrue);
    expect(File(wrongPath).existsSync(), isFalse);
    expect(report.relocatedEntries, 1);
  });

  test('修復會刪除重複 entry id 的較舊檔案', () async {
    final RecoverySetupResult setup = await harness.repository
        .setupRecoveryKey();
    final String entryId = generateEntryId();
    final DateTime older = DateTime.parse('2026-05-10T08:00:00Z');
    final DateTime newer = DateTime.parse('2026-06-12T08:00:00Z');

    await harness.repository.saveEntry(
      setup.session,
      DiaryEntry(
        id: entryId,
        vaultId: setup.session.vaultId,
        title: 'Older copy',
        date: const DateOnly('2026-05-10'),
        createdAt: older,
        updatedAt: older,
        markdownBody: 'older',
      ),
    );
    final String mayPath = await harness.pathStrategy.entryAbsolutePath(
      date: const DateOnly('2026-05-10'),
      entryId: entryId,
    );

    final Directory vaultRoot = await harness.pathStrategy.vaultRootDirectory();
    final String duplicatePath = p.join(
      vaultRoot.path,
      'entries',
      '2026',
      '05',
      'stale-$entryId.md.enc',
    );
    await File(duplicatePath).parent.create(recursive: true);
    await File(mayPath).copy(duplicatePath);

    await harness.repository.saveEntry(
      setup.session,
      DiaryEntry(
        id: entryId,
        vaultId: setup.session.vaultId,
        title: 'Newer copy',
        date: const DateOnly('2026-06-12'),
        createdAt: newer,
        updatedAt: newer,
        markdownBody: 'newer',
      ),
    );
    final String junePath = await harness.pathStrategy.entryAbsolutePath(
      date: const DateOnly('2026-06-12'),
      entryId: entryId,
    );

    final VaultRepairReport report = await harness.repository
        .repairVaultWithReport(setup.session);

    expect(report.removedDuplicateEntries, 1);
    expect(File(junePath).existsSync(), isTrue);
    expect(File(duplicatePath).existsSync(), isFalse);
    final DiaryEntry? loaded = await harness.repository.loadEntry(
      setup.session,
      entryId,
    );
    expect(loaded?.title, 'Newer copy');
  });

  test('修復會刪除無引用的孤立附件', () async {
    final RecoverySetupResult setup = await harness.repository
        .setupRecoveryKey();
    await harness.saveSimpleEntry(setup, title: 'No assets');

    final Directory vaultRoot = await harness.pathStrategy.vaultRootDirectory();
    final String orphanPath = p.join(
      vaultRoot.path,
      'assets',
      '2026',
      '06',
      'orphan-asset-id.png.enc',
    );
    await File(orphanPath).parent.create(recursive: true);
    await File(orphanPath).writeAsBytes(<int>[1, 2, 3]);

    final VaultRepairReport report = await harness.repository
        .repairVaultWithReport(setup.session);

    expect(report.removedOrphanAssets, 1);
    expect(File(orphanPath).existsSync(), isFalse);
  });

  test('修復會補齊無效 tag_styles.json 後的標籤目錄', () async {
    final RecoverySetupResult setup = await harness.repository
        .setupRecoveryKey();
    await harness.repository.saveEntry(
      setup.session,
      DiaryEntry(
        id: generateEntryId(),
        vaultId: setup.session.vaultId,
        date: const DateOnly('2026-06-20'),
        createdAt: DateTime.parse('2026-06-20T10:00:00Z'),
        updatedAt: DateTime.parse('2026-06-20T10:00:00Z'),
        markdownBody: 'body',
        tags: const <String>['修復標籤'],
      ),
    );

    final File tagStylesFile = File(
      p.join(
        (await harness.pathStrategy.vaultRootDirectory()).path,
        'tag_styles.json',
      ),
    );
    await tagStylesFile.writeAsString(
      jsonEncode(<String, Object?>{'tags': <Object?>[]}),
    );

    await harness.repository.repairVaultWithReport(setup.session);

    final List<TagCatalogItem> catalog = await harness.repository
        .listTagCatalog();
    expect(catalog.any((TagCatalogItem item) => item.label == '修復標籤'), isTrue);
  });

  test('修復後索引篇數與日記一致', () async {
    final RecoverySetupResult setup = await harness.repository
        .setupRecoveryKey();
    await harness.saveSimpleEntry(setup, title: 'One');
    await harness.saveSimpleEntry(setup, title: 'Two', date: '2026-06-21');

    final VaultRepairReport report = await harness.repository
        .repairVaultWithReport(setup.session);

    expect(report.entryCount, 2);
    expect((await harness.repository.listEntries()).length, 2);
  });
}
