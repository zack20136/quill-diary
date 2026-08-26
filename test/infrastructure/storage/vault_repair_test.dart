import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quill_diary/domain/diary/diary_entry.dart';
import 'package:quill_diary/domain/people/person.dart';
import 'package:quill_diary/domain/recovery/kdf_descriptor.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/storage/tag_styles_store.dart';
import 'package:quill_diary/infrastructure/crypto/crypto_service.dart';
import 'package:quill_diary/infrastructure/storage/pinned_entries_store.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';
import 'package:quill_diary/infrastructure/storage/vault_repair_file_operations.dart';

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
    expect(report.entryActionLogs.single.relocatedEntries, 1);
  });

  test('同 ID 日記內容不同時會保留最新版並隔離其他版本', () async {
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

    expect(File(junePath).existsSync(), isTrue);
    expect(File(duplicatePath).existsSync(), isFalse);
    expect(report.quarantinedCount, greaterThanOrEqualTo(1));
    final DiaryEntry? loaded = await harness.repository.loadEntry(
      setup.session,
      entryId,
    );
    expect(loaded?.title, 'Newer copy');
    final bool hasQuarantine = Directory(
      p.join(vaultRoot.path, 'quarantine'),
    ).existsSync();
    expect(hasQuarantine, isTrue);
  });

  test('衝突日記沒有 canonical 時會隔離較舊版本並保留最新版', () async {
    final RecoverySetupResult setup = await harness.repository
        .setupRecoveryKey();
    const String entryId = 'entry-no-canonical-conflict';
    final Directory vaultRoot = await harness.pathStrategy.vaultRootDirectory();
    final String olderPath = p.join(
      vaultRoot.path,
      'entries',
      'copies',
      'older.md.enc',
    );
    final String newerPath = p.join(
      vaultRoot.path,
      'entries',
      'copies',
      'newer.md.enc',
    );
    await _writeEncryptedEntry(
      harness: harness,
      setup: setup,
      path: olderPath,
      entryId: entryId,
      markdown: _entryMarkdown(
        id: entryId,
        title: 'Older',
        date: '2026-05-10',
        updatedAt: '2026-05-10T10:00:00.000Z',
      ),
    );
    await _writeEncryptedEntry(
      harness: harness,
      setup: setup,
      path: newerPath,
      entryId: entryId,
      markdown: _entryMarkdown(
        id: entryId,
        title: 'Newer',
        date: '2026-06-10',
        updatedAt: '2026-06-10T10:00:00.000Z',
      ),
    );
    final String canonicalPath = await harness.pathStrategy.entryAbsolutePath(
      date: const DateOnly('2026-06-10'),
      entryId: entryId,
    );

    final VaultRepairReport report = await harness.repository
        .repairVaultWithReport(setup.session);

    expect(File(olderPath).existsSync(), isFalse);
    expect(File(newerPath).existsSync(), isTrue);
    expect(File(canonicalPath).existsSync(), isFalse);
    expect(report.relocatedEntries, 0);
    expect(report.quarantinedCount, greaterThanOrEqualTo(1));
    expect(
      (await harness.repository.loadEntry(setup.session, entryId))?.title,
      'Newer',
    );
  });

  test('同 ID 且內容相同的日記副本會在提交後清理', () async {
    final RecoverySetupResult setup = await harness.repository
        .setupRecoveryKey();
    final String entryId = await harness.saveSimpleEntry(setup);
    final String canonicalPath = await harness.pathStrategy.entryAbsolutePath(
      date: const DateOnly('2026-05-24'),
      entryId: entryId,
    );
    final Directory vaultRoot = await harness.pathStrategy.vaultRootDirectory();
    final String duplicatePath = p.join(
      vaultRoot.path,
      'entries',
      '2026',
      '06',
      'copy-$entryId.md.enc',
    );
    await File(duplicatePath).parent.create(recursive: true);
    await File(canonicalPath).copy(duplicatePath);

    final VaultRepairReport report = await harness.repository
        .repairVaultWithReport(setup.session);

    expect(File(canonicalPath).existsSync(), isTrue);
    expect(File(duplicatePath).existsSync(), isFalse);
    expect(report.removedDuplicateEntries, 1);
    expect(report.hasUnresolvedIssues, isFalse);
  });

  test('路徑跳脫日記 ID 會被隔離且不會寫到 vault 外', () async {
    final RecoverySetupResult setup = await harness.repository
        .setupRecoveryKey();
    final Directory vaultRoot = await harness.pathStrategy.vaultRootDirectory();
    final String unsafePath = p.join(
      vaultRoot.path,
      'entries',
      '2026',
      '06',
      'unsafe.md.enc',
    );
    await _writeEncryptedEntry(
      harness: harness,
      setup: setup,
      path: unsafePath,
      entryId: '../escaped',
      markdown: '''---
id: "../escaped"
title: "unsafe"
date: "2026-06-20"
created_at: "2026-06-20T10:00:00.000Z"
updated_at: "2026-06-20T10:00:00.000Z"
tags: []
attachment_ids: []
attachments: []
---

body
''',
    );
    final String escapedPath = p.join(vaultRoot.parent.path, 'escaped.md.enc');

    final VaultRepairReport report = await harness.repository
        .repairVaultWithReport(setup.session);

    expect(File(unsafePath).existsSync(), isFalse);
    expect(File(escapedPath).existsSync(), isFalse);
    expect(report.quarantinedCount, greaterThanOrEqualTo(1));
    expect(
      report.findings.any(
        (VaultFinding finding) =>
            finding.kind == VaultRepairIssueKind.invalidEntryMetadata,
      ),
      isTrue,
    );
  });

  test('日記時間會拒絕溢位日期與時間並接受有效 ISO 時間', () async {
    final RecoverySetupResult setup = await harness.repository
        .setupRecoveryKey();
    final Directory root = await harness.pathStrategy.vaultRootDirectory();
    final List<({String id, String timestamp})> cases =
        <({String id, String timestamp})>[
          (id: 'invalid-overflow-date', timestamp: '2026-02-30T10:00:00.000Z'),
          (id: 'invalid-overflow-time', timestamp: '2026-02-20T25:00:00.000Z'),
          (id: 'valid-iso-time', timestamp: '2026-02-20T10:00:00.000+08:00'),
        ];
    for (final item in cases) {
      await _writeEncryptedEntry(
        harness: harness,
        setup: setup,
        path: p.join(root.path, 'entries', 'manual', '${item.id}.md.enc'),
        entryId: item.id,
        markdown: _entryMarkdown(
          id: item.id,
          title: item.id,
          date: '2026-02-20',
          updatedAt: item.timestamp,
        ),
      );
    }

    final VaultRepairReport report = await harness.repository
        .repairVaultWithReport(setup.session);

    expect(report.entryCount, 1);
    expect(report.quarantinedCount, greaterThanOrEqualTo(2));
    expect(
      report.findings
          .where(
            (VaultFinding finding) =>
                finding.kind == VaultRepairIssueKind.invalidEntryMetadata,
          )
          .length,
      2,
    );
    expect(
      await harness.repository.loadEntry(setup.session, 'valid-iso-time'),
      isNotNull,
    );
  });

  test('無法解析的孤立附件會隔離並回報不可讀', () async {
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

    expect(report.removedOrphanAssets, 0);
    expect(File(orphanPath).existsSync(), isFalse);
    expect(report.quarantinedCount, 0);
    expect(
      report.findings.any(
        (VaultFinding finding) =>
            finding.kind == VaultRepairIssueKind.unreadableAsset,
      ),
      isTrue,
    );
  });

  test('有效且無引用的孤立附件會在修復完成後刪除', () async {
    final RecoverySetupResult setup = await harness.repository
        .setupRecoveryKey();
    await harness.saveSimpleEntry(setup, title: 'No assets');
    const String assetId = 'orphan-asset-id';
    final String orphanPath = await harness.pathStrategy.assetAbsolutePath(
      date: const DateOnly('2026-06-20'),
      assetId: assetId,
      extension: 'png',
    );
    await _writeEncryptedAsset(
      harness: harness,
      setup: setup,
      path: orphanPath,
      assetId: assetId,
      bytes: _pngBytes(1),
    );

    final VaultRepairReport report = await harness.repository
        .repairVaultWithReport(setup.session);

    expect(report.removedOrphanAssets, 1);
    expect(File(orphanPath).existsSync(), isFalse);
  });

  test('有損壞日記時會隔離無法確認歸屬的有效附件', () async {
    final RecoverySetupResult setup = await harness.repository
        .setupRecoveryKey();
    final Directory vaultRoot = await harness.pathStrategy.vaultRootDirectory();
    final File corruptEntry = File(
      p.join(vaultRoot.path, 'entries', '2026', '06', 'broken.md.enc'),
    );
    await corruptEntry.parent.create(recursive: true);
    await corruptEntry.writeAsBytes(<int>[1, 2, 3]);
    const String assetId = 'possibly-referenced';
    final String assetPath = await harness.pathStrategy.assetAbsolutePath(
      date: const DateOnly('2026-06-20'),
      assetId: assetId,
      extension: 'png',
    );
    await _writeEncryptedAsset(
      harness: harness,
      setup: setup,
      path: assetPath,
      assetId: assetId,
      bytes: _pngBytes(4),
    );

    final VaultRepairReport report = await harness.repository
        .repairVaultWithReport(setup.session);

    expect(File(corruptEntry.path).existsSync(), isFalse);
    expect(File(assetPath).existsSync(), isFalse);
    expect(report.quarantinedCount, greaterThanOrEqualTo(2));
    expect(
      report.findings.any(
        (VaultFinding finding) =>
            finding.kind == VaultRepairIssueKind.unreadableEntry,
      ),
      isTrue,
    );
    expect(
      report.findings.any(
        (VaultFinding finding) =>
            finding.kind == VaultRepairIssueKind.unverifiedOrphanAsset,
      ),
      isTrue,
    );
  });

  test('有損壞日記時不會修剪無法驗證的釘選 ID', () async {
    final RecoverySetupResult setup = await harness.repository
        .setupRecoveryKey();
    final Directory vaultRoot = await harness.pathStrategy.vaultRootDirectory();
    final File corruptEntry = File(
      p.join(vaultRoot.path, 'entries', '2026', '06', 'broken.md.enc'),
    );
    await corruptEntry.parent.create(recursive: true);
    await corruptEntry.writeAsBytes(<int>[1, 2, 3]);
    final PinnedEntriesStore store = PinnedEntriesStore(harness.pathStrategy);
    await store.setPinned('broken', pinned: true);

    await harness.repository.repairVaultWithReport(setup.session);

    expect(await store.readIds(), contains('broken'));
  });

  test('健康日記庫重複修復不會改寫日記或附件', () async {
    final RecoverySetupResult setup = await harness.repository
        .setupRecoveryKey();
    const String entryId = 'entry-stable';
    const String assetId = 'asset-stable';
    final DateTime timestamp = DateTime.parse('2026-06-20T10:00:00Z');
    await harness.repository.saveEntry(
      setup.session,
      DiaryEntry(
        id: entryId,
        vaultId: setup.session.vaultId,
        date: const DateOnly('2026-06-20'),
        createdAt: timestamp,
        updatedAt: timestamp,
        markdownBody: 'stable',
        attachmentIds: const <AssetId>[assetId],
      ),
      pendingAttachments: <PendingAttachment>[
        PendingAttachment(
          assetId: assetId,
          bytes: Uint8List.fromList(_pngBytes(1)),
          mimeType: 'image/png',
          originalFilename: 'stable.png',
        ),
      ],
    );
    final File entryFile = File(
      await harness.pathStrategy.entryAbsolutePath(
        date: const DateOnly('2026-06-20'),
        entryId: entryId,
      ),
    );
    final File assetFile = File(
      await harness.pathStrategy.assetAbsolutePath(
        date: const DateOnly('2026-06-20'),
        assetId: assetId,
        extension: 'png',
      ),
    );
    final DateTime fixedMtime = DateTime.parse('2020-01-02T03:04:05Z');
    await entryFile.setLastModified(fixedMtime);
    await assetFile.setLastModified(fixedMtime);
    final List<int> entryBytes = await entryFile.readAsBytes();
    final List<int> assetBytes = await assetFile.readAsBytes();

    await harness.repository.repairVaultWithReport(setup.session);
    await harness.repository.repairVaultWithReport(setup.session);

    expect(await entryFile.readAsBytes(), entryBytes);
    expect(await assetFile.readAsBytes(), assetBytes);
    expect(
      (await entryFile.lastModified()).millisecondsSinceEpoch,
      fixedMtime.millisecondsSinceEpoch,
    );
    expect(
      (await assetFile.lastModified()).millisecondsSinceEpoch,
      fixedMtime.millisecondsSinceEpoch,
    );
  });

  test('修復後附件 metadata 與 manifest 附件數使用實際明文資料', () async {
    final RecoverySetupResult setup = await harness.repository
        .setupRecoveryKey();
    const String entryId = 'entry-metadata';
    const String assetId = 'asset-metadata';
    final DateTime timestamp = DateTime.parse('2026-06-20T10:00:00Z');
    await harness.repository.saveEntry(
      setup.session,
      DiaryEntry(
        id: entryId,
        vaultId: setup.session.vaultId,
        date: const DateOnly('2026-06-20'),
        createdAt: timestamp,
        updatedAt: timestamp,
        markdownBody: 'metadata',
        attachmentIds: const <AssetId>[assetId],
      ),
      pendingAttachments: <PendingAttachment>[
        PendingAttachment(
          assetId: assetId,
          bytes: Uint8List.fromList(_pngBytes(1)),
          mimeType: 'image/png',
          originalFilename: 'metadata.png',
        ),
      ],
    );
    final originalAttachment = (await harness.repository.loadAttachments(
      entryId,
    )).single;
    final File assetFile = File(
      await harness.pathStrategy.assetAbsolutePath(
        date: const DateOnly('2026-06-20'),
        assetId: assetId,
        extension: 'png',
      ),
    );
    await assetFile.setLastModified(DateTime.parse('2020-01-01T00:00:00Z'));

    await harness.repository.repairVaultWithReport(setup.session);

    final repairedAttachment = (await harness.repository.loadAttachments(
      entryId,
    )).single;
    expect(repairedAttachment.mimeType, 'image/png');
    expect(repairedAttachment.byteSize, originalAttachment.byteSize);
    expect(repairedAttachment.sha256, originalAttachment.sha256);
    expect(repairedAttachment.createdAt, originalAttachment.createdAt);

    final File manifestFile = File(await harness.pathStrategy.manifestPath());
    final LocalCryptoService crypto = LocalCryptoService();
    final ParsedEncryptedDocument manifest = crypto.parseFileBytes(
      await manifestFile.readAsBytes(),
    );
    final List<int> manifestBytes = await crypto.decryptBytes(
      headerBytes: manifest.headerBytes,
      ciphertextBytes: manifest.ciphertextBytes,
      context: DecryptionContext.recovery(
        recoveryWrapKey: setup.session.recoveryWrapKey!,
        vaultId: setup.session.vaultId,
      ),
    );
    final Map<String, Object?> manifestJson =
        jsonDecode(utf8.decode(manifestBytes)) as Map<String, Object?>;
    expect(manifestJson['entry_count'], 1);
    expect(manifestJson['asset_count'], 1);
  });

  test('同 ID 附件內容不同時會隔離非 canonical 版本', () async {
    final RecoverySetupResult setup = await harness.repository
        .setupRecoveryKey();
    const String entryId = 'entry-asset-conflict';
    const String assetId = 'asset-conflict';
    final DateTime timestamp = DateTime.parse('2026-06-20T10:00:00Z');
    await harness.repository.saveEntry(
      setup.session,
      DiaryEntry(
        id: entryId,
        vaultId: setup.session.vaultId,
        date: const DateOnly('2026-06-20'),
        createdAt: timestamp,
        updatedAt: timestamp,
        markdownBody: 'asset conflict',
        attachmentIds: const <AssetId>[assetId],
      ),
      pendingAttachments: <PendingAttachment>[
        PendingAttachment(
          assetId: assetId,
          bytes: Uint8List.fromList(_pngBytes(1)),
          mimeType: 'image/png',
          originalFilename: 'asset.png',
        ),
      ],
    );
    final String canonicalPath = await harness.pathStrategy.assetAbsolutePath(
      date: const DateOnly('2026-06-20'),
      assetId: assetId,
      extension: 'png',
    );
    final String conflictingPath = await harness.pathStrategy.assetAbsolutePath(
      date: const DateOnly('2026-07-20'),
      assetId: assetId,
      extension: 'png',
    );
    await _writeEncryptedAsset(
      harness: harness,
      setup: setup,
      path: conflictingPath,
      assetId: assetId,
      bytes: _pngBytes(9),
    );

    final String canonicalHash = (await harness.repository.loadAttachments(
      entryId,
    )).single.sha256;
    final VaultRepairReport report = await harness.repository
        .repairVaultWithReport(setup.session);

    expect(File(canonicalPath).existsSync(), isTrue);
    expect(File(conflictingPath).existsSync(), isFalse);
    expect(report.quarantinedCount, greaterThanOrEqualTo(1));
    expect(
      (await harness.repository.loadAttachments(entryId)).single.sha256,
      canonicalHash,
    );
  });

  test('同 ID 且內容相同的附件副本會在提交後清理', () async {
    final RecoverySetupResult setup = await harness.repository
        .setupRecoveryKey();
    const String entryId = 'entry-asset-copy';
    const String assetId = 'asset-copy';
    final DateTime timestamp = DateTime.parse('2026-06-20T10:00:00Z');
    await harness.repository.saveEntry(
      setup.session,
      DiaryEntry(
        id: entryId,
        vaultId: setup.session.vaultId,
        date: const DateOnly('2026-06-20'),
        createdAt: timestamp,
        updatedAt: timestamp,
        markdownBody: 'asset copy',
        attachmentIds: const <AssetId>[assetId],
      ),
      pendingAttachments: <PendingAttachment>[
        PendingAttachment(
          assetId: assetId,
          bytes: Uint8List.fromList(_pngBytes(1)),
          mimeType: 'image/png',
          originalFilename: 'asset.png',
        ),
      ],
    );
    final String canonicalPath = await harness.pathStrategy.assetAbsolutePath(
      date: const DateOnly('2026-06-20'),
      assetId: assetId,
      extension: 'png',
    );
    final String duplicatePath = await harness.pathStrategy.assetAbsolutePath(
      date: const DateOnly('2026-07-20'),
      assetId: assetId,
      extension: 'png',
    );
    await File(duplicatePath).parent.create(recursive: true);
    await File(canonicalPath).copy(duplicatePath);

    final VaultRepairReport report = await harness.repository
        .repairVaultWithReport(setup.session);

    expect(File(canonicalPath).existsSync(), isTrue);
    expect(File(duplicatePath).existsSync(), isFalse);
    expect(report.hasUnresolvedIssues, isFalse);
  });

  test('健康修復完成後會清除舊隔離目錄並保存清除數量', () async {
    final RecoverySetupResult setup = await harness.repository
        .setupRecoveryKey();
    await harness.saveSimpleEntry(setup, title: '健康日記');
    final Directory oldQuarantine = Directory(
      p.join(
        (await harness.pathStrategy.vaultRootDirectory()).path,
        'quarantine',
        'old-id',
      ),
    );
    await oldQuarantine.create(recursive: true);
    await File(p.join(oldQuarantine.path, 'dummy.bin')).writeAsBytes(<int>[1]);

    final VaultRepairReport report = await harness.repository
        .repairVaultWithReport(setup.session);
    final VaultRepairSummary? summary = await harness.repository
        .readLastRepairSummary();

    expect(oldQuarantine.existsSync(), isFalse);
    expect(report.purgedOldQuarantine, greaterThanOrEqualTo(1));
    expect(summary?.purgedOldQuarantine, greaterThanOrEqualTo(1));
  });

  test('仍有未解決日記問題時會保留舊隔離目錄', () async {
    final VaultTestHarness retainingHarness = await VaultTestHarness.create(
      repairFileOperations: _SelectiveQuarantineCopyOperations(
        failIfContains: 'broken-b',
      ),
    );
    try {
      final RecoverySetupResult setup = await retainingHarness.repository
          .setupRecoveryKey();
      final Directory root = await retainingHarness.pathStrategy
          .vaultRootDirectory();
      final Directory oldQuarantine = Directory(
        p.join(root.path, 'quarantine', 'old-repair'),
      );
      await oldQuarantine.create(recursive: true);
      await File(
        p.join(oldQuarantine.path, 'dummy.bin'),
      ).writeAsBytes(<int>[1]);
      final File corruptEntry = File(
        p.join(root.path, 'entries', '2026', '06', 'broken-b.md.enc'),
      );
      await corruptEntry.parent.create(recursive: true);
      await corruptEntry.writeAsBytes(<int>[1, 2, 3]);

      final VaultRepairReport report = await retainingHarness.repository
          .repairVaultWithReport(setup.session);

      expect(report.hasUnresolvedIssues, isTrue);
      expect(oldQuarantine.existsSync(), isTrue);
    } finally {
      await retainingHarness.dispose();
    }
  });

  test('附件 header ID 與檔名不符時會隔離並回報身份錯誤', () async {
    final RecoverySetupResult setup = await harness.repository
        .setupRecoveryKey();
    const String entryId = 'entry-bad-asset-header';
    const String assetId = 'asset-expected';
    final DateTime timestamp = DateTime.parse('2026-06-20T10:00:00Z');
    await harness.repository.saveEntry(
      setup.session,
      DiaryEntry(
        id: entryId,
        vaultId: setup.session.vaultId,
        date: const DateOnly('2026-06-20'),
        createdAt: timestamp,
        updatedAt: timestamp,
        markdownBody: 'bad header',
        attachmentIds: const <AssetId>[assetId],
      ),
      pendingAttachments: <PendingAttachment>[
        PendingAttachment(
          assetId: assetId,
          bytes: Uint8List.fromList(_pngBytes(1)),
          mimeType: 'image/png',
          originalFilename: 'asset.png',
        ),
      ],
    );
    final String assetPath = await harness.pathStrategy.assetAbsolutePath(
      date: const DateOnly('2026-06-20'),
      assetId: assetId,
      extension: 'png',
    );
    await _writeEncryptedAsset(
      harness: harness,
      setup: setup,
      path: assetPath,
      assetId: 'asset-other',
      bytes: _pngBytes(1),
    );

    final VaultRepairReport report = await harness.repository
        .repairVaultWithReport(setup.session);

    expect(File(assetPath).existsSync(), isFalse);
    expect(report.quarantinedCount, 0);
    expect(
      report.findings.any(
        (VaultFinding finding) =>
            finding.kind == VaultRepairIssueKind.assetIdentityMismatch,
      ),
      isTrue,
    );
    expect(report.entryActionLogs, hasLength(1));
    expect(report.entryActionLogs.single.purgedBadAttachments, 1);
    expect(
      report.unresolvedFindings.where(
        (VaultFinding finding) =>
            finding.kind == VaultRepairIssueKind.cleanupFailure ||
            finding.kind == VaultRepairIssueKind.assetIdentityMismatch ||
            finding.kind == VaultRepairIssueKind.unreadableAsset,
      ),
      isEmpty,
    );
    final VaultRepairSummary summary = VaultRepairSummary.fromReport(report);
    expect(summary.findings, isEmpty);
    expect(summary.entryActionLogs.single.purgedBadAttachments, 1);
    expect(await harness.repository.loadAttachments(entryId), isEmpty);
  });

  test('附件 header content type 與副檔名不符時會隔離並回報身份錯誤', () async {
    final RecoverySetupResult setup = await harness.repository
        .setupRecoveryKey();
    const String entryId = 'entry-bad-content-type';
    const String assetId = 'asset-bad-content-type';
    final DateTime timestamp = DateTime.parse('2026-06-20T10:00:00Z');
    await harness.repository.saveEntry(
      setup.session,
      DiaryEntry(
        id: entryId,
        vaultId: setup.session.vaultId,
        date: const DateOnly('2026-06-20'),
        createdAt: timestamp,
        updatedAt: timestamp,
        markdownBody: 'bad content type',
        attachmentIds: const <AssetId>[assetId],
      ),
      pendingAttachments: <PendingAttachment>[
        PendingAttachment(
          assetId: assetId,
          bytes: Uint8List.fromList(_pngBytes(1)),
          mimeType: 'image/png',
          originalFilename: 'asset.png',
        ),
      ],
    );
    final String originalPath = await harness.pathStrategy.assetAbsolutePath(
      date: const DateOnly('2026-06-20'),
      assetId: assetId,
      extension: 'png',
    );
    final String assetPath = await harness.pathStrategy.assetAbsolutePath(
      date: const DateOnly('2026-06-20'),
      assetId: assetId,
      extension: 'jpg',
    );
    await File(originalPath).rename(assetPath);

    final VaultRepairReport report = await harness.repository
        .repairVaultWithReport(setup.session);

    expect(File(assetPath).existsSync(), isFalse);
    expect(report.quarantinedCount, 0);
    expect(
      report.findings.any(
        (VaultFinding finding) =>
            finding.kind == VaultRepairIssueKind.assetIdentityMismatch,
      ),
      isTrue,
    );
    expect(
      report.unresolvedFindings.where(
        (VaultFinding finding) =>
            finding.kind == VaultRepairIssueKind.cleanupFailure ||
            finding.kind == VaultRepairIssueKind.assetIdentityMismatch ||
            finding.kind == VaultRepairIssueKind.unreadableAsset,
      ),
      isEmpty,
    );
    expect(report.entryActionLogs.single.purgedBadAttachments, 1);
    expect(await harness.repository.loadAttachments(entryId), isEmpty);
  });

  test('附件內容與宣告 MIME 不符時清除後不應再待處理', () async {
    final RecoverySetupResult setup = await harness.repository
        .setupRecoveryKey();
    const String entryId = 'entry-bad-mime-content';
    const String assetId = 'asset-bad-mime-content';
    final DateTime timestamp = DateTime.parse('2026-06-20T10:00:00Z');
    await harness.repository.saveEntry(
      setup.session,
      DiaryEntry(
        id: entryId,
        vaultId: setup.session.vaultId,
        date: const DateOnly('2026-06-20'),
        createdAt: timestamp,
        updatedAt: timestamp,
        markdownBody: 'bad mime content',
        attachmentIds: const <AssetId>[assetId],
      ),
      pendingAttachments: <PendingAttachment>[
        PendingAttachment(
          assetId: assetId,
          bytes: Uint8List.fromList(_pngBytes(1)),
          mimeType: 'image/png',
          originalFilename: 'asset.png',
        ),
      ],
    );
    final String assetPath = await harness.pathStrategy.assetAbsolutePath(
      date: const DateOnly('2026-06-20'),
      assetId: assetId,
      extension: 'png',
    );
    // 以 image/png header 包住非圖片內容，觸發內容／MIME 不符。
    await _writeEncryptedAsset(
      harness: harness,
      setup: setup,
      path: assetPath,
      assetId: assetId,
      bytes: <int>[1, 2, 3, 4, 5, 6, 7, 8],
    );

    final VaultRepairReport report = await harness.repository
        .repairVaultWithReport(setup.session);

    expect(File(assetPath).existsSync(), isFalse);
    expect(await harness.repository.loadAttachments(entryId), isEmpty);
    expect(report.entryActionLogs.single.purgedBadAttachments, 1);
    expect(
      report.unresolvedFindings.where(
        (VaultFinding finding) =>
            finding.kind == VaultRepairIssueKind.cleanupFailure ||
            finding.entryId == entryId,
      ),
      isEmpty,
    );
  });

  test('修復會依序回報階段並持久化最近摘要', () async {
    final RecoverySetupResult setup = await harness.repository
        .setupRecoveryKey();
    await harness.saveSimpleEntry(setup);
    final List<VaultRepairPhase> phases = <VaultRepairPhase>[];

    final VaultRepairReport report = await harness.repository
        .repairVaultWithReport(setup.session, onProgress: phases.add);
    final VaultRepairSummary? summary = await harness.repository
        .readLastRepairSummary();

    expect(phases, VaultRepairPhase.values);
    expect(summary, isNotNull);
    expect(summary!.entryCount, report.entryCount);
    expect(summary.finishedAt, report.finishedAt);
    expect(summary.relocatedEntries, report.relocatedEntries);
    expect(summary.removedDuplicateEntries, report.removedDuplicateEntries);
    expect(summary.relocatedAssets, report.relocatedAssets);
    expect(summary.removedOrphanAssets, report.removedOrphanAssets);
    expect(summary.issueCounts, isEmpty);
    expect(
      summary.entryActionLogs.map((log) => log.toJson()).toList(),
      report.entryActionLogs.map((log) => log.toJson()).toList(),
    );
  });

  test('一般索引重建會略過損壞日記並保存檢查狀態', () async {
    final RecoverySetupResult setup = await harness.repository
        .setupRecoveryKey();
    await harness.saveSimpleEntry(setup, title: 'Readable');
    final Directory vaultRoot = await harness.pathStrategy.vaultRootDirectory();
    final File corruptEntry = File(
      p.join(vaultRoot.path, 'entries', '2026', '06', 'broken.md.enc'),
    );
    await corruptEntry.parent.create(recursive: true);
    await corruptEntry.writeAsBytes(<int>[1, 2, 3]);

    await harness.repository.rebuildIndex(setup.session);

    expect(await harness.repository.listEntries(), hasLength(1));
    final VaultInspectSummary? summary = await harness.repository
        .readLastInspectSummary();
    expect(
      summary?.findings
          .where(
            (VaultFinding finding) =>
                finding.kind == VaultRepairIssueKind.unreadableEntry,
          )
          .length,
      1,
    );
    expect(await harness.repository.readLastRepairSummary(), isNull);
  });

  test('檢查日記庫會回報異常並重建索引，但不變更正式檔案', () async {
    final RecoverySetupResult setup = await harness.repository
        .setupRecoveryKey();
    await harness.saveSimpleEntry(setup, title: 'Readable');
    final Directory vaultRoot = await harness.pathStrategy.vaultRootDirectory();
    final File corruptEntry = File(
      p.join(vaultRoot.path, 'entries', '2026', '06', 'broken.md.enc'),
    );
    await corruptEntry.parent.create(recursive: true);
    final List<int> corruptBytes = <int>[9, 8, 7, 6];
    await corruptEntry.writeAsBytes(corruptBytes);
    final DateTime beforeModified = await corruptEntry.lastModified();

    final VaultInspectReport report = await harness.repository
        .inspectVaultWithReport(setup.session);

    expect(report.findings, isNotEmpty);
    expect(await corruptEntry.readAsBytes(), corruptBytes);
    expect(await corruptEntry.lastModified(), beforeModified);
    expect(File(corruptEntry.path).existsSync(), isTrue);
    expect(
      Directory(p.join(vaultRoot.path, 'quarantine')).existsSync(),
      isFalse,
    );
  });

  test('隔離區內檔案不會再被後續檢查回報', () async {
    final RecoverySetupResult setup = await harness.repository
        .setupRecoveryKey();
    final Directory vaultRoot = await harness.pathStrategy.vaultRootDirectory();
    final File quarantineEntry = File(
      p.join(
        vaultRoot.path,
        'quarantine',
        'repair_old',
        'entries',
        '2026',
        '06',
        'broken.md.enc',
      ),
    );
    await quarantineEntry.parent.create(recursive: true);
    await quarantineEntry.writeAsBytes(<int>[1, 2, 3]);

    final VaultInspectReport report = await harness.repository
        .inspectVaultWithReport(setup.session);

    expect(report.findings, isEmpty);
    expect(quarantineEntry.existsSync(), isTrue);
  });

  test('永久刪除異常 finding 會移除正式檔並更新摘要', () async {
    final RecoverySetupResult setup = await harness.repository
        .setupRecoveryKey();
    final Directory vaultRoot = await harness.pathStrategy.vaultRootDirectory();
    final File corruptEntry = File(
      p.join(vaultRoot.path, 'entries', '2026', '06', 'broken.md.enc'),
    );
    await corruptEntry.parent.create(recursive: true);
    await corruptEntry.writeAsBytes(<int>[1, 2, 3, 4]);

    final VaultInspectReport inspect = await harness.repository
        .inspectVaultWithReport(setup.session);
    expect(inspect.findings, isNotEmpty);
    expect(corruptEntry.existsSync(), isTrue);

    final List<VaultFinding> targets = inspect.findings
        .where(
          (VaultFinding finding) =>
              finding.kind == VaultRepairIssueKind.unreadableEntry,
        )
        .toList();
    expect(targets, isNotEmpty);

    final int deleted = await harness.repository
        .permanentlyDeleteAbnormalFindings(setup.session, findings: targets);

    expect(deleted, greaterThanOrEqualTo(1));
    expect(corruptEntry.existsSync(), isFalse);
    final VaultInspectSummary? summary = await harness.repository
        .readLastInspectSummary();
    expect(
      summary?.findings.any(
        (VaultFinding finding) =>
            finding.kind == VaultRepairIssueKind.unreadableEntry,
      ),
      isFalse,
    );
  });

  test('可驗證副本存在時會恢復引用並隔離壞檔', () async {
    final RecoverySetupResult setup = await harness.repository
        .setupRecoveryKey();
    const String entryId = 'entry-recover-asset';
    const String assetId = 'asset-recover';
    final DateTime timestamp = DateTime.parse('2026-06-20T10:00:00Z');
    await harness.repository.saveEntry(
      setup.session,
      DiaryEntry(
        id: entryId,
        vaultId: setup.session.vaultId,
        date: const DateOnly('2026-06-20'),
        createdAt: timestamp,
        updatedAt: timestamp,
        markdownBody: 'recover asset',
        attachmentIds: const <AssetId>[assetId],
      ),
      pendingAttachments: <PendingAttachment>[
        PendingAttachment(
          assetId: assetId,
          bytes: Uint8List.fromList(_pngBytes(1)),
          mimeType: 'image/png',
          originalFilename: 'asset.png',
        ),
      ],
    );
    final Directory vaultRoot = await harness.pathStrategy.vaultRootDirectory();
    final String badPath = p.join(
      vaultRoot.path,
      'assets',
      '2099',
      '01',
      '$assetId.png.enc',
    );
    await File(badPath).parent.create(recursive: true);
    await File(badPath).writeAsBytes(<int>[1, 2, 3]);

    final VaultRepairReport report = await harness.repository
        .repairVaultWithReport(setup.session);
    final DiaryEntry? entry = await harness.repository.loadEntry(
      setup.session,
      entryId,
    );

    expect(entry?.attachmentIds, contains(assetId));
    expect(File(badPath).existsSync(), isFalse);
    expect(report.quarantinedCount, 0);
    expect(
      report.unresolvedFindings.any(
        (VaultFinding finding) =>
            finding.kind == VaultRepairIssueKind.unreadableAsset ||
            finding.kind == VaultRepairIssueKind.assetIdentityMismatch,
      ),
      isFalse,
    );
    expect(
      report.appliedActions.any(
        (VaultFinding finding) =>
            finding.resolved &&
            finding.plannedAction == VaultPlannedAction.relocateToCanonical,
      ),
      isTrue,
    );
    expect(report.entryActionLogs, hasLength(1));
    expect(report.entryActionLogs.single.recoveredAttachments, 1);
  });

  test('附件實體遺失時只移除引用', () async {
    final RecoverySetupResult setup = await harness.repository
        .setupRecoveryKey();
    const String entryId = 'entry-missing-asset';
    const String assetId = 'att_missing_asset_id';
    final DateTime timestamp = DateTime.parse('2026-06-20T10:00:00Z');
    final String path = await harness.pathStrategy.entryAbsolutePath(
      date: const DateOnly('2026-06-20'),
      entryId: entryId,
    );
    await _writeEncryptedEntry(
      harness: harness,
      setup: setup,
      path: path,
      entryId: entryId,
      markdown:
          '''---
id: "$entryId"
title: "missing asset"
date: "2026-06-20"
created_at: "${timestamp.toIso8601String()}"
updated_at: "${timestamp.toIso8601String()}"
tags: []
attachment_ids:
  - "$assetId"
attachments:
  - "../assets/2026/06/$assetId.png"
---

missing asset
''',
    );

    final VaultRepairReport report = await harness.repository
        .repairVaultWithReport(setup.session);
    final DiaryEntry? entry = await harness.repository.loadEntry(
      setup.session,
      entryId,
    );

    expect(entry?.attachmentIds, isEmpty);
    expect(
      report.appliedActions.any(
        (VaultFinding finding) =>
            finding.kind == VaultRepairIssueKind.missingAsset &&
            finding.resolved &&
            finding.plannedAction == VaultPlannedAction.removeReference,
      ),
      isTrue,
    );
    expect(report.entryActionLogs, hasLength(1));
    expect(report.entryActionLogs.single.removedMissingAttachments, 1);
  });

  test('fromReport 在 unresolved 為空時不回退到已處理的 findings', () {
    final VaultRepairReport report = VaultRepairReport(
      entryCount: 1,
      duration: const Duration(milliseconds: 1),
      finishedAt: DateTime(2026, 8, 20, 10),
      relocatedEntries: 0,
      removedDuplicateEntries: 0,
      tagsAdded: 0,
      relocatedAssets: 0,
      removedOrphanAssets: 0,
      purgedBadAssets: 1,
      findings: const <VaultFinding>[
        VaultFinding(
          kind: VaultRepairIssueKind.assetIdentityMismatch,
          plannedAction: VaultPlannedAction.removeReference,
          manualAction: VaultManualAction.none,
          canOpenEntry: true,
          entryTitle: '已清掉的日記',
          entryDate: DateOnly('2026-08-01'),
          internalReference: 'assets/bad.png.enc',
        ),
      ],
      appliedActions: const <VaultFinding>[
        VaultFinding(
          kind: VaultRepairIssueKind.assetIdentityMismatch,
          plannedAction: VaultPlannedAction.removeReference,
          manualAction: VaultManualAction.none,
          canOpenEntry: true,
          entryTitle: '已清掉的日記',
          entryDate: DateOnly('2026-08-01'),
          internalReference: 'asset-bad',
          resolved: true,
        ),
      ],
      unresolvedFindings: const <VaultFinding>[],
      entryActionLogs: const <VaultRepairEntryActionLog>[
        VaultRepairEntryActionLog(
          title: '已清掉的日記',
          date: DateOnly('2026-08-01'),
          purgedBadAttachments: 1,
        ),
      ],
    );

    final VaultRepairSummary summary = VaultRepairSummary.fromReport(report);
    expect(summary.findings, isEmpty);
    expect(summary.issueCounts, isEmpty);
    expect(summary.entryActionLogs.single.purgedBadAttachments, 1);
  });

  test('修復後摘要會保存逐篇附件動作紀錄且相容舊 JSON', () async {
    final DateTime finishedAt = DateTime(2026, 8, 20, 10);
    final VaultRepairEntryActionLog log = VaultRepairEntryActionLog(
      title: '圖片修復日記',
      date: const DateOnly('2026-08-20'),
      recoveredAttachments: 1,
      purgedBadAttachments: 1,
    );
    final VaultRepairSummary summary = VaultRepairSummary(
      entryCount: 1,
      finishedAt: finishedAt,
      issueCounts: const <VaultRepairIssueKind, int>{},
      entryActionLogs: <VaultRepairEntryActionLog>[log],
      purgedOldQuarantine: 3,
    );

    final VaultRepairSummary? roundTripped = VaultRepairSummary.fromJson(
      summary.toJson(),
    );
    expect(roundTripped?.entryActionLogs.single.title, '圖片修復日記');
    expect(roundTripped?.entryActionLogs.single.recoveredAttachments, 1);
    expect(roundTripped?.entryActionLogs.single.purgedBadAttachments, 1);
    expect(roundTripped?.lastUpdatedAt, finishedAt);
    expect(roundTripped?.salvagedCount, 0);
    expect(roundTripped?.permanentlyDeletedCount, 0);
    expect(roundTripped?.purgedOldQuarantine, 3);

    final Map<String, Object?> oldJson = summary.toJson()
      ..remove('entry_action_logs');
    final VaultRepairSummary? oldSummary = VaultRepairSummary.fromJson(oldJson);
    expect(oldSummary, isNotNull);
    expect(oldSummary!.entryActionLogs, isEmpty);
    expect(oldSummary.lastUpdatedAt, finishedAt);
  });

  test('修復動作聚合會去重並區分成功與失敗事件', () {
    const DateOnly date = DateOnly('2026-08-20');
    final VaultRepairActionAggregation aggregation =
        aggregateVaultRepairActionEvents(<VaultRepairActionEvent>[
          const VaultRepairActionEvent(
            scope: VaultRepairActionScope.entry,
            type: VaultRepairActionType.recoverAttachment,
            outcome: VaultRepairActionOutcome.succeeded,
            entryTitle: '日記',
            entryDate: date,
            internalIdentity: 'asset:1',
          ),
          const VaultRepairActionEvent(
            scope: VaultRepairActionScope.entry,
            type: VaultRepairActionType.recoverAttachment,
            outcome: VaultRepairActionOutcome.succeeded,
            entryTitle: '日記',
            entryDate: date,
            internalIdentity: 'asset:1',
          ),
          const VaultRepairActionEvent(
            scope: VaultRepairActionScope.entry,
            type: VaultRepairActionType.splitAttachment,
            outcome: VaultRepairActionOutcome.succeeded,
            entryTitle: '日記',
            entryDate: date,
            internalIdentity: 'split:owner-a',
          ),
          const VaultRepairActionEvent(
            scope: VaultRepairActionScope.entry,
            type: VaultRepairActionType.splitAttachment,
            outcome: VaultRepairActionOutcome.succeeded,
            entryTitle: '日記',
            entryDate: date,
            internalIdentity: 'split:owner-b',
          ),
          const VaultRepairActionEvent(
            scope: VaultRepairActionScope.global,
            type: VaultRepairActionType.purgeBadAttachment,
            outcome: VaultRepairActionOutcome.succeeded,
            internalIdentity: 'asset:bad',
          ),
          const VaultRepairActionEvent(
            scope: VaultRepairActionScope.global,
            type: VaultRepairActionType.purgeOldQuarantine,
            outcome: VaultRepairActionOutcome.succeeded,
            internalIdentity: 'quarantine_dirs:3',
          ),
          const VaultRepairActionEvent(
            scope: VaultRepairActionScope.entry,
            type: VaultRepairActionType.cleanupFailure,
            outcome: VaultRepairActionOutcome.failed,
            entryTitle: '日記',
            entryDate: date,
            internalIdentity: 'cleanup:1',
          ),
        ]);

    expect(aggregation.recoveredAttachments, 1);
    expect(aggregation.relocatedAssets, 1);
    expect(aggregation.splitAttachments, 2);
    expect(aggregation.purgedBadAssets, 1);
    expect(aggregation.quarantinedCount, 0);
    expect(aggregation.purgedOldQuarantine, 3);
    expect(aggregation.cleanupFailures, 1);
    expect(aggregation.entryActionLogs, hasLength(1));
    expect(aggregation.entryActionLogs.single.recoveredAttachments, 1);
    expect(aggregation.entryActionLogs.single.splitAttachments, 2);
    expect(aggregation.entryActionLogs.single.cleanupFailures, 0);
  });

  test('圖片異常群組不能 salvage', () async {
    final RecoverySetupResult setup = await harness.repository
        .setupRecoveryKey();
    await harness.saveSimpleEntry(setup, title: '只有圖片異常');
    const VaultFinding finding = VaultFinding(
      kind: VaultRepairIssueKind.unreadableAsset,
      plannedAction: VaultPlannedAction.removeReference,
      manualAction: VaultManualAction.openAndReuploadAttachment,
      canOpenEntry: true,
      entryId: 'entry-image-only',
      entryTitle: '只有圖片異常',
      entryDate: DateOnly('2026-08-20'),
      internalReference: 'assets/2026/08/broken.png.enc',
    );

    expect(
      await harness.repository.canSalvageFindings(
        setup.session,
        const <VaultFinding>[finding],
      ),
      isFalse,
    );
    expect(
      await harness.repository.tryCreateSalvageDraft(
        setup.session,
        findings: const <VaultFinding>[finding],
      ),
      isNull,
    );
  });

  test('salvage 可讀內容可建立草稿；儲存成功才刪舊檔', () async {
    final RecoverySetupResult setup = await harness.repository
        .setupRecoveryKey();
    const String entryId = 'entry-salvage-source';
    final DateTime timestamp = DateTime.parse('2026-06-20T10:00:00Z');
    await harness.repository.saveEntry(
      setup.session,
      DiaryEntry(
        id: entryId,
        vaultId: setup.session.vaultId,
        title: '可搶救標題',
        date: const DateOnly('2026-06-20'),
        createdAt: timestamp,
        updatedAt: timestamp,
        markdownBody: '可搶救正文',
      ),
    );
    final String path = await harness.pathStrategy.entryAbsolutePath(
      date: const DateOnly('2026-06-20'),
      entryId: entryId,
    );
    // 讓檔案變成 identity mismatch（header fileId 不符）但內容仍可解密搶救。
    final List<int> bytes = await File(path).readAsBytes();
    final findings = <VaultFinding>[
      VaultFinding(
        kind: VaultRepairIssueKind.entryIdentityMismatch,
        plannedAction: VaultPlannedAction.quarantine,
        manualAction: VaultManualAction.restoreFromBackup,
        canOpenEntry: false,
        entryId: entryId,
        entryTitle: '可搶救標題',
        entryDate: const DateOnly('2026-06-20'),
        internalReference: await () async {
          final Directory root = await harness.pathStrategy
              .vaultRootDirectory();
          return p.relative(path, from: root.path).replaceAll('\\', '/');
        }(),
      ),
    ];

    final draft = await harness.repository.tryCreateSalvageDraft(
      setup.session,
      findings: findings,
    );
    expect(draft, isNotNull);
    expect(draft!.record.title, '可搶救標題');
    expect(draft.record.markdownBody.contains('可搶救正文'), isTrue);
    expect(File(path).existsSync(), isTrue);
    expect(bytes, isNotEmpty);

    final DiaryEntry saved = await harness.repository.saveEntry(
      setup.session,
      DiaryEntry(
        id: draft.newEntryId,
        vaultId: setup.session.vaultId,
        title: draft.record.title,
        date: DateOnly.parse(draft.record.dateValue),
        createdAt: timestamp,
        updatedAt: timestamp,
        markdownBody: draft.record.markdownBody,
      ),
      retireFindingsAfterSave: draft.sourceFindings,
    );

    expect(saved.id, draft.newEntryId);
    expect(File(path).existsSync(), isFalse);
    expect(await harness.repository.loadEntry(setup.session, entryId), isNull);
  });

  test('salvage 儲存失敗或未儲存時保留舊檔', () async {
    final RecoverySetupResult setup = await harness.repository
        .setupRecoveryKey();
    const String entryId = 'entry-salvage-keep';
    final DateTime timestamp = DateTime.parse('2026-06-20T10:00:00Z');
    await harness.repository.saveEntry(
      setup.session,
      DiaryEntry(
        id: entryId,
        vaultId: setup.session.vaultId,
        title: '保留舊檔',
        date: const DateOnly('2026-06-20'),
        createdAt: timestamp,
        updatedAt: timestamp,
        markdownBody: '正文',
      ),
    );
    final String path = await harness.pathStrategy.entryAbsolutePath(
      date: const DateOnly('2026-06-20'),
      entryId: entryId,
    );
    final Directory root = await harness.pathStrategy.vaultRootDirectory();
    final draft = await harness.repository.tryCreateSalvageDraft(
      setup.session,
      findings: <VaultFinding>[
        VaultFinding(
          kind: VaultRepairIssueKind.entryIdentityMismatch,
          plannedAction: VaultPlannedAction.quarantine,
          manualAction: VaultManualAction.restoreFromBackup,
          canOpenEntry: false,
          entryId: entryId,
          entryTitle: '保留舊檔',
          entryDate: const DateOnly('2026-06-20'),
          internalReference: p
              .relative(path, from: root.path)
              .replaceAll('\\', '/'),
        ),
      ],
    );
    expect(draft, isNotNull);
    expect(File(path).existsSync(), isTrue);
    expect(
      await harness.repository.loadEntry(setup.session, entryId),
      isNotNull,
    );
  });

  test('完全不可讀時無法 salvage', () async {
    final RecoverySetupResult setup = await harness.repository
        .setupRecoveryKey();
    final Directory vaultRoot = await harness.pathStrategy.vaultRootDirectory();
    final File corruptEntry = File(
      p.join(vaultRoot.path, 'entries', '2026', '06', 'unreadable.md.enc'),
    );
    await corruptEntry.parent.create(recursive: true);
    await corruptEntry.writeAsBytes(<int>[9, 9, 9]);

    final draft = await harness.repository.tryCreateSalvageDraft(
      setup.session,
      findings: const <VaultFinding>[
        VaultFinding(
          kind: VaultRepairIssueKind.unreadableEntry,
          plannedAction: VaultPlannedAction.quarantine,
          manualAction: VaultManualAction.restoreFromBackup,
          canOpenEntry: false,
          internalReference: 'entries/2026/06/unreadable.md.enc',
        ),
      ],
    );
    expect(draft, isNull);
  });

  test('隔離目標已存在但內容不同時不刪來源', () async {
    final _TargetExistsMismatchOperations operations =
        _TargetExistsMismatchOperations();
    final VaultTestHarness mismatchHarness = await VaultTestHarness.create(
      repairFileOperations: operations,
    );
    addTearDown(mismatchHarness.dispose);
    final RecoverySetupResult setup = await mismatchHarness.repository
        .setupRecoveryKey();
    final Directory vaultRoot = await mismatchHarness.pathStrategy
        .vaultRootDirectory();
    final File corruptEntry = File(
      p.join(vaultRoot.path, 'entries', '2026', '06', 'broken.md.enc'),
    );
    await corruptEntry.parent.create(recursive: true);
    await corruptEntry.writeAsBytes(<int>[1, 2, 3, 4]);

    final VaultRepairReport report = await mismatchHarness.repository
        .repairVaultWithReport(setup.session);

    expect(corruptEntry.existsSync(), isTrue);
    expect(report.quarantinedCount, 0);
    expect(
      report.unresolvedFindings.any(
        (VaultFinding finding) =>
            finding.kind == VaultRepairIssueKind.cleanupFailure,
      ),
      isTrue,
    );
  });

  test('隔離成功與失敗會個別標記 finding', () async {
    final _SelectiveQuarantineCopyOperations operations =
        _SelectiveQuarantineCopyOperations(failIfContains: 'broken-b');
    final VaultTestHarness selectiveHarness = await VaultTestHarness.create(
      repairFileOperations: operations,
    );
    addTearDown(selectiveHarness.dispose);
    final RecoverySetupResult selectiveSetup = await selectiveHarness.repository
        .setupRecoveryKey();
    final Directory selectiveRoot = await selectiveHarness.pathStrategy
        .vaultRootDirectory();
    final File selectiveA = File(
      p.join(selectiveRoot.path, 'entries', '2026', '06', 'broken-a.md.enc'),
    );
    final File selectiveB = File(
      p.join(selectiveRoot.path, 'entries', '2026', '06', 'broken-b.md.enc'),
    );
    await selectiveA.parent.create(recursive: true);
    await selectiveA.writeAsBytes(<int>[1, 2, 3]);
    await selectiveB.writeAsBytes(<int>[4, 5, 6]);

    final VaultRepairReport report = await selectiveHarness.repository
        .repairVaultWithReport(selectiveSetup.session);

    expect(selectiveA.existsSync(), isFalse);
    expect(selectiveB.existsSync(), isTrue);
    expect(report.quarantinedCount, 1);
    expect(
      report.unresolvedFindings.where(
        (VaultFinding finding) =>
            finding.kind == VaultRepairIssueKind.cleanupFailure,
      ),
      hasLength(1),
    );
    // 不可讀日記 finding 不會因另一個隔離成功而被整批標為已解決。
    expect(
      report.unresolvedFindings.any(
        (VaultFinding finding) =>
            finding.kind == VaultRepairIssueKind.unreadableEntry &&
            finding.internalReference.contains('broken-b'),
      ),
      isTrue,
    );
  });

  test('一般索引重建使用解密後的附件 metadata', () async {
    final RecoverySetupResult setup = await harness.repository
        .setupRecoveryKey();
    const String entryId = 'entry-rebuild-asset';
    const String assetId = 'asset-rebuild';
    final DateTime timestamp = DateTime.parse('2026-06-20T10:00:00Z');
    await harness.repository.saveEntry(
      setup.session,
      DiaryEntry(
        id: entryId,
        vaultId: setup.session.vaultId,
        date: const DateOnly('2026-06-20'),
        createdAt: timestamp,
        updatedAt: timestamp,
        markdownBody: 'rebuild asset',
        attachmentIds: const <AssetId>[assetId],
      ),
      pendingAttachments: <PendingAttachment>[
        PendingAttachment(
          assetId: assetId,
          bytes: Uint8List.fromList(_pngBytes(3)),
          mimeType: 'image/png',
          originalFilename: 'rebuild.png',
        ),
      ],
    );
    final original = (await harness.repository.loadAttachments(entryId)).single;

    await harness.repository.rebuildIndex(setup.session);

    final rebuilt = (await harness.repository.loadAttachments(entryId)).single;
    expect(rebuilt.mimeType, original.mimeType);
    expect(rebuilt.byteSize, original.byteSize);
    expect(rebuilt.sha256, original.sha256);
    expect(rebuilt.createdAt, original.createdAt);
  });

  test('安全清理前附件被替換時保留檔案且不增加移除數量', () async {
    final _ReplacingBeforeCleanupOperations operations =
        _ReplacingBeforeCleanupOperations();
    final VaultTestHarness failingHarness = await VaultTestHarness.create(
      repairFileOperations: operations,
    );
    try {
      final RecoverySetupResult setup = await failingHarness.repository
          .setupRecoveryKey();
      final String orphanPath = await failingHarness.pathStrategy
          .assetAbsolutePath(
            date: const DateOnly('2026-06-20'),
            assetId: 'orphan-delete-failure',
            extension: 'png',
          );
      await _writeEncryptedAsset(
        harness: failingHarness,
        setup: setup,
        path: orphanPath,
        assetId: 'orphan-delete-failure',
        bytes: _pngBytes(5),
      );
      operations.beforeDelete = () => _writeEncryptedAsset(
        harness: failingHarness,
        setup: setup,
        path: orphanPath,
        assetId: 'orphan-delete-failure',
        bytes: _pngBytes(6),
      );

      final VaultRepairReport report = await failingHarness.repository
          .repairVaultWithReport(setup.session);

      expect(File(orphanPath).existsSync(), isTrue);
      expect(report.removedOrphanAssets, 0);
      expect(report.issueCount(VaultRepairIssueKind.cleanupFailure), 1);
    } finally {
      await failingHarness.dispose();
    }
  });

  test('canonical 複製失敗時保留來源並繼續建立索引', () async {
    final VaultTestHarness failingHarness = await VaultTestHarness.create(
      repairFileOperations: const _FailingCopyRepairFileOperations(),
    );
    try {
      final RecoverySetupResult setup = await failingHarness.repository
          .setupRecoveryKey();
      final String entryId = await failingHarness.saveSimpleEntry(
        setup,
        date: '2026-06-21',
      );
      final String canonicalPath = await failingHarness.pathStrategy
          .entryAbsolutePath(
            date: const DateOnly('2026-06-21'),
            entryId: entryId,
          );
      final Directory root = await failingHarness.pathStrategy
          .vaultRootDirectory();
      final String sourcePath = p.join(
        root.path,
        'entries',
        'misplaced',
        '$entryId.md.enc',
      );
      await File(sourcePath).parent.create(recursive: true);
      await File(canonicalPath).rename(sourcePath);

      final VaultRepairReport report = await failingHarness.repository
          .repairVaultWithReport(setup.session);

      expect(File(sourcePath).existsSync(), isTrue);
      expect(File(canonicalPath).existsSync(), isFalse);
      expect(report.relocatedEntries, 0);
      expect(report.issueCount(VaultRepairIssueKind.cleanupFailure), 1);
      expect(
        await failingHarness.repository.loadEntry(setup.session, entryId),
        isNotNull,
      );
    } finally {
      await failingHarness.dispose();
    }
  });

  test('附件清冊固定後新增的外部檔案不會被當次清理', () async {
    final _AddingFileAfterAssetSnapshotOperations operations =
        _AddingFileAfterAssetSnapshotOperations();
    final VaultTestHarness snapshotHarness = await VaultTestHarness.create(
      repairFileOperations: operations,
    );
    try {
      final RecoverySetupResult setup = await snapshotHarness.repository
          .setupRecoveryKey();
      final String lateAssetPath = await snapshotHarness.pathStrategy
          .assetAbsolutePath(
            date: const DateOnly('2026-06-20'),
            assetId: 'late-external-asset',
            extension: 'png',
          );
      operations.afterAssetSnapshot = () => _writeEncryptedAsset(
        harness: snapshotHarness,
        setup: setup,
        path: lateAssetPath,
        assetId: 'late-external-asset',
        bytes: _pngBytes(6),
      );

      final VaultRepairReport report = await snapshotHarness.repository
          .repairVaultWithReport(setup.session);

      expect(File(lateAssetPath).existsSync(), isTrue);
      expect(report.removedOrphanAssets, 0);
    } finally {
      await snapshotHarness.dispose();
    }
  });

  test('修復與日記儲存同時觸發時會依序完成且索引不遺漏', () async {
    final RecoverySetupResult setup = await harness.repository
        .setupRecoveryKey();
    await harness.saveSimpleEntry(setup, id: 'entry-before');
    final Future<VaultRepairReport> repairing = harness.repository
        .repairVaultWithReport(setup.session);
    final Future<DiaryEntry> saving = harness.repository.saveEntry(
      setup.session,
      DiaryEntry(
        id: 'entry-during',
        vaultId: setup.session.vaultId,
        date: const DateOnly('2026-06-22'),
        createdAt: DateTime.parse('2026-06-22T10:00:00Z'),
        updatedAt: DateTime.parse('2026-06-22T10:00:00Z'),
        markdownBody: 'saved after repair',
      ),
    );

    await Future.wait<Object>(<Future<Object>>[repairing, saving]);

    expect(
      (await harness.repository.listEntries()).map((entry) => entry.id).toSet(),
      <String>{'entry-before', 'entry-during'},
    );
  });

  test('manifest 寫入失敗時不會刪除已搬移檔案的來源', () async {
    await harness.dispose();
    final _FailingManifestCryptoService crypto =
        _FailingManifestCryptoService();
    harness = await VaultTestHarness.create(cryptoService: crypto);
    final RecoverySetupResult setup = await harness.repository
        .setupRecoveryKey();
    final String entryId = await harness.saveSimpleEntry(setup);
    final String canonicalPath = await harness.pathStrategy.entryAbsolutePath(
      date: const DateOnly('2026-05-24'),
      entryId: entryId,
    );
    final Directory vaultRoot = await harness.pathStrategy.vaultRootDirectory();
    final String wrongPath = p.join(
      vaultRoot.path,
      'entries',
      'copies',
      '$entryId.md.enc',
    );
    await File(wrongPath).parent.create(recursive: true);
    await File(canonicalPath).rename(wrongPath);
    crypto.failManifestWrites = true;

    await expectLater(
      harness.repository.repairVaultWithReport(setup.session),
      throwsStateError,
    );

    expect(File(wrongPath).existsSync(), isTrue);
    expect(File(canonicalPath).existsSync(), isTrue);
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

  test('修復會同步重建人物分析', () async {
    final RecoverySetupResult setup = await harness.repository
        .setupRecoveryKey();
    final Person person = await harness.repository.createPerson(
      setup.session,
      PersonDraft(name: '張1a'),
    );
    await harness.saveSimpleEntry(setup, markdownBody: '今天跟張1a去哪。');

    await harness.repository.repairVaultWithReport(setup.session);

    expect(harness.repository.peopleAnalyticsDebugMetrics.scannedDocuments, 1);
    expect(
      (await harness.repository.allPersonMentionStats(
        setup.session,
      ))[person.id]?.mentionCount,
      1,
    );
    expect(harness.repository.peopleAnalyticsDebugMetrics.scannedDocuments, 0);
  });

  test('空日記庫修復也會完成人物分析', () async {
    final RecoverySetupResult setup = await harness.repository
        .setupRecoveryKey();

    final VaultRepairReport report = await harness.repository
        .repairVaultWithReport(setup.session);

    expect(report.entryCount, 0);
    expect(harness.repository.peopleAnalyticsDebugMetrics.scannedDocuments, 0);
    expect(
      await harness.repository.allPersonMentionStats(setup.session),
      isEmpty,
    );
  });

  test('修復會先停止既有分析再建立完整結果', () async {
    final RecoverySetupResult setup = await harness.repository
        .setupRecoveryKey();
    final Person person = await harness.repository.createPerson(
      setup.session,
      PersonDraft(name: 'test'),
    );
    for (var index = 0; index < 9; index++) {
      await harness.saveSimpleEntry(
        setup,
        date: '2026-06-${(index + 1).toString().padLeft(2, '0')}',
        markdownBody: '${List<String>.filled(12000, '內容').join()} test',
      );
    }

    final Future<PeopleAnalyticsProgress> analyzing = harness
        .repository
        .peopleAnalyticsProgress
        .firstWhere(
          (PeopleAnalyticsProgress progress) =>
              progress.state == PeopleAnalyticsProgressState.analyzing,
        );
    final Future<bool> oldAnalysisWasCancelled = harness.repository
        .allPersonMentionStats(setup.session)
        .then<bool>((_) => false, onError: (_) => true);
    await analyzing;

    await harness.repository.repairVaultWithReport(setup.session);

    expect(await oldAnalysisWasCancelled, isTrue);
    expect(harness.repository.peopleAnalyticsDebugMetrics.scannedDocuments, 9);
    expect(
      (await harness.repository.allPersonMentionStats(
        setup.session,
      ))[person.id]?.mentionCount,
      9,
    );
  });
}

List<int> _pngBytes(int marker) => <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  marker,
];

class _ReplacingBeforeCleanupOperations extends VaultRepairFileOperations {
  Future<void> Function()? beforeDelete;
  var _didReplace = false;

  @override
  Future<VaultRepairDeleteResult> deleteIfValid({
    required String path,
    required Future<bool> Function(String currentPath) validate,
  }) async {
    if (!_didReplace) {
      _didReplace = true;
      await beforeDelete?.call();
    }
    return super.deleteIfValid(path: path, validate: validate);
  }
}

class _TargetExistsMismatchOperations extends VaultRepairFileOperations {
  @override
  Future<VaultRepairCopyResult> copyAtomicallyIfAbsent({
    required String sourcePath,
    required String targetPath,
    required Future<bool> Function(String copiedPath) validate,
  }) async {
    final File target = File(targetPath);
    await target.parent.create(recursive: true);
    await target.writeAsBytes(const <int>[9, 9, 9, 9], flush: true);
    return VaultRepairCopyResult.targetExists;
  }
}

class _SelectiveQuarantineCopyOperations extends VaultRepairFileOperations {
  _SelectiveQuarantineCopyOperations({required this.failIfContains});

  final String failIfContains;

  @override
  Future<VaultRepairCopyResult> copyAtomicallyIfAbsent({
    required String sourcePath,
    required String targetPath,
    required Future<bool> Function(String copiedPath) validate,
  }) async {
    if (sourcePath.contains(failIfContains) ||
        targetPath.contains(failIfContains)) {
      throw FileSystemException('injected quarantine failure', targetPath);
    }
    return super.copyAtomicallyIfAbsent(
      sourcePath: sourcePath,
      targetPath: targetPath,
      validate: validate,
    );
  }
}

class _FailingCopyRepairFileOperations extends VaultRepairFileOperations {
  const _FailingCopyRepairFileOperations();

  @override
  Future<VaultRepairCopyResult> copyAtomicallyIfAbsent({
    required String sourcePath,
    required String targetPath,
    required Future<bool> Function(String copiedPath) validate,
  }) {
    throw FileSystemException('injected copy failure', targetPath);
  }
}

class _AddingFileAfterAssetSnapshotOperations
    extends VaultRepairFileOperations {
  Future<void> Function()? afterAssetSnapshot;

  @override
  Future<List<File>> snapshotFiles(Directory root, String suffix) async {
    final List<File> snapshot = await super.snapshotFiles(root, suffix);
    if (p.basename(root.path) == 'assets') await afterAssetSnapshot?.call();
    return snapshot;
  }
}

Future<void> _writeEncryptedAsset({
  required VaultTestHarness harness,
  required RecoverySetupResult setup,
  required String path,
  required String assetId,
  required List<int> bytes,
}) async {
  final metadata = await harness.repository.readRecoveryMetadata();
  final DateTime timestamp = DateTime.parse('2026-06-20T10:00:00Z');
  final EncryptionResult encrypted = await LocalCryptoService().encryptBytes(
    documentId: assetId,
    vaultId: setup.session.vaultId,
    plaintextBytes: bytes,
    contentType: 'image/png',
    recoveryWrapKey: setup.session.recoveryWrapKey!,
    recoverySlotKdf: metadata!.kdf,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
  final File file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(encrypted.toFileBytes(), flush: true);
}

Future<void> _writeEncryptedEntry({
  required VaultTestHarness harness,
  required RecoverySetupResult setup,
  required String path,
  required String entryId,
  required String markdown,
}) async {
  final metadata = await harness.repository.readRecoveryMetadata();
  final DateTime timestamp = DateTime.parse('2026-06-20T10:00:00Z');
  final EncryptionResult encrypted = await LocalCryptoService().encryptMarkdown(
    documentId: entryId,
    vaultId: setup.session.vaultId,
    markdown: markdown,
    recoveryWrapKey: setup.session.recoveryWrapKey!,
    recoverySlotKdf: metadata!.kdf,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
  final File file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(encrypted.toFileBytes(), flush: true);
}

String _entryMarkdown({
  required String id,
  required String title,
  required String date,
  required String updatedAt,
}) =>
    '''---
id: "$id"
title: "$title"
date: "$date"
created_at: "$updatedAt"
updated_at: "$updatedAt"
tags: []
attachment_ids: []
attachments: []
---

$title
''';

class _FailingManifestCryptoService extends LocalCryptoService {
  bool failManifestWrites = false;

  @override
  Future<EncryptionResult> encryptBytes({
    required String documentId,
    required String vaultId,
    required List<int> plaintextBytes,
    required String contentType,
    required List<int> recoveryWrapKey,
    required KdfDescriptor recoverySlotKdf,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    if (failManifestWrites && documentId == 'manifest') {
      throw StateError('manifest failure');
    }
    return super.encryptBytes(
      documentId: documentId,
      vaultId: vaultId,
      plaintextBytes: plaintextBytes,
      contentType: contentType,
      recoveryWrapKey: recoveryWrapKey,
      recoverySlotKdf: recoverySlotKdf,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
