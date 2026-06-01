import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quill_lock_diary/domain/attachment/asset_attachment.dart';
import 'package:quill_lock_diary/domain/diary/diary_entry.dart';
import 'package:quill_lock_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_lock_diary/domain/shared/value_objects.dart';
import 'package:quill_lock_diary/infrastructure/database/index_database.dart';
import 'package:quill_lock_diary/infrastructure/database/index_database_manager.dart';
import 'package:quill_lock_diary/infrastructure/markdown/front_matter_codec.dart';
import 'package:quill_lock_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_lock_diary/infrastructure/storage/restore_precheck.dart';
import 'package:quill_lock_diary/infrastructure/storage/vault_archive_io.dart';
import 'package:quill_lock_diary/infrastructure/storage/vault_repository.dart';

import '../helpers/vault_test_harness.dart';

// 本檔驗證 VaultArchiveIo 的匯出、可攜式匯入與備份／還原。
//
// 匯入 fixture 與 production 辨識規則一致：
// - 本 App Markdown：`.md` + YAML front matter
// - 本 App HTML：`<article class="… entry …">`
// - Easy Diary 完整備份 zip：見 easy_diary_backup_*_test.dart

Future<Uint8List?> _readDecryptedAttachmentBytes({
  required VaultTestHarness harness,
  required UnlockedVaultSession session,
  required DiaryEntry entry,
  required AssetAttachment attachment,
}) async {
  final String extension =
      p.extension(attachment.safeFilename).replaceFirst('.', '');
  final String assetPath = await harness.pathStrategy.assetAbsolutePath(
    date: entry.date,
    assetId: attachment.id,
    extension: extension.isEmpty ? 'bin' : extension,
  );
  return harness.repository.readDecryptedAssetBytes(session, assetPath);
}

void main() {
  late VaultTestHarness harness;
  late VaultArchiveIo archiveIo;

  setUp(() async {
    harness = await VaultTestHarness.create();
    archiveIo = VaultArchiveIo(
      pathStrategy: harness.pathStrategy,
      repository: harness.repository,
      frontMatterCodec: const FrontMatterCodec(),
      indexDatabaseManager: IndexDatabaseManager(harness.pathStrategy),
    );
  });

  tearDown(() async {
    await harness.dispose();
  });

  group('匯出：Markdown', () {
  test('Markdown 匯出會把 index.md 與附件放在同一個資料夾', () async {
    final RecoverySetupResult setup = await harness.repository.setupRecoveryKey();
    final Directory sourceDirectory = Directory(p.join(harness.tempDir.path, 'source'))
      ..createSync(recursive: true);
    final File sourceAttachment = File(p.join(sourceDirectory.path, 'photo.jpg'))
      ..writeAsBytesSync(const <int>[1, 2, 3, 4]);

    await harness.repository.saveEntry(
      setup.session,
      DiaryEntry(
        id: generateEntryId(),
        vaultId: setup.session.vaultId,
        title: 'Morning Note',
        date: const DateOnly('2026-05-19'),
        createdAt: DateTime.parse('2026-05-19T08:00:00Z'),
        updatedAt: DateTime.parse('2026-05-19T08:00:00Z'),
        markdownBody: '# Morning Note\n\nHello export',
      ),
      pendingAttachments: <PendingAttachment>[
        PendingAttachment(
          sourcePath: sourceAttachment.path,
          mimeType: 'image/jpeg',
          originalFilename: 'photo.jpg',
        ),
      ],
    );

    final Directory exportParent = Directory(p.join(harness.tempDir.path, 'exports'))
      ..createSync(recursive: true);
    final Directory output = await archiveIo.exportMarkdown(
      session: setup.session,
      parentDirectory: exportParent,
    );

    final File exportedIndex = File(
      p.join(output.path, '2026-05-19', 'Morning Note', 'index.md'),
    );
    final File exportedAttachment = File(
      p.join(output.path, '2026-05-19', 'Morning Note', 'photo.jpg'),
    );

    expect(exportedIndex.existsSync(), isTrue);
    expect(exportedAttachment.existsSync(), isTrue);
    expect(await exportedIndex.readAsString(), contains('  - "./photo.jpg"'));
    expect(await exportedAttachment.readAsBytes(), const <int>[1, 2, 3, 4]);
  });
  });

  group('匯入：Markdown / zip', () {
  test('可匯入單篇 Markdown 與同資料夾附件', () async {
    final RecoverySetupResult setup = await harness.repository.setupRecoveryKey();
    final Directory importRoot = Directory(p.join(harness.tempDir.path, 'import_md'))
      ..createSync(recursive: true);
    final Directory entryDirectory = Directory(
      p.join(importRoot.path, '2026-05-20', 'Trip Note'),
    )..createSync(recursive: true);

    File(p.join(entryDirectory.path, 'image.png')).writeAsBytesSync(const <int>[9, 8, 7]);
    File(p.join(entryDirectory.path, 'index.md')).writeAsStringSync('''---
title: "Trip Note"
date: "2026-05-20"
attachments:
  - "./image.png"
---

# Trip Note

Imported from markdown.
''');

    final PortableImportResult result = await archiveIo.importDocuments(
      session: setup.session,
      rootDirectory: importRoot,
    );

    expect(result.importedEntries, 1);

    final entries = await harness.repository.listEntries();
    expect(entries, hasLength(1));

    final DiaryEntry? imported = await harness.repository.loadEntry(
      setup.session,
      entries.single.id,
    );
    final attachments = await harness.repository.loadAttachments(entries.single.id);

    expect(imported?.title, 'Trip Note');
    expect(imported?.date.value, '2026-05-20');
    expect(imported?.markdownBody, contains('Imported from markdown.'));
    expect(attachments, hasLength(1));
    expect(attachments.single.safeFilename, 'image.png');
  });

  test('非本 App 的 Easy Diary 匯出 HTML 會略過', () async {
    final RecoverySetupResult setup = await harness.repository.setupRecoveryKey();
    final Directory importRoot = Directory(p.join(harness.tempDir.path, 'import_ed_html_skip'))
      ..createSync(recursive: true);

    File(p.join(importRoot.path, 'easy-diary.html')).writeAsStringSync('''
<html><body>
  <div class='title-right'>Easy Diary Entry</div>
  <div class='contents'><p>Hello</p></div>
</body></html>
''');

    final PortableImportResult result = await archiveIo.importDocuments(
      session: setup.session,
      rootDirectory: importRoot,
    );

    expect(result.importedEntries, 0);
    expect(result.skippedFiles, 1);
    expect(await harness.repository.listEntries(), isEmpty);
  });
  });


  group('匯出：Markdown', () {
  test('Markdown 匯出 zip 會保留 index.md 與附件路徑', () async {
    final RecoverySetupResult setup = await harness.repository.setupRecoveryKey();
    final Directory sourceDirectory = Directory(p.join(harness.tempDir.path, 'zip_source'))
      ..createSync(recursive: true);
    final File sourceAttachment = File(p.join(sourceDirectory.path, 'receipt.pdf'))
      ..writeAsBytesSync(const <int>[7, 7, 7]);

    await harness.repository.saveEntry(
      setup.session,
      DiaryEntry(
        id: generateEntryId(),
        vaultId: setup.session.vaultId,
        title: 'Zip Export',
        date: const DateOnly('2026-05-22'),
        createdAt: DateTime.parse('2026-05-22T09:00:00Z'),
        updatedAt: DateTime.parse('2026-05-22T09:00:00Z'),
        markdownBody: 'Zip body',
      ),
      pendingAttachments: <PendingAttachment>[
        PendingAttachment(
          sourcePath: sourceAttachment.path,
          mimeType: 'application/pdf',
          originalFilename: 'receipt.pdf',
        ),
      ],
    );

    final File zipFile = File(p.join(harness.tempDir.path, 'portable_export.zip'));
    await archiveIo.writePortableExportZip(
      session: setup.session,
      target: zipFile,
    );

    final Archive archive = ZipDecoder().decodeBytes(await zipFile.readAsBytes());
    final List<String> names = archive.files.map((ArchiveFile file) => file.name).toList();

    expect(
      names,
      contains(
        allOf(contains('2026-05-22'), contains('Zip Export'), contains('index.md')),
      ),
    );
    expect(
      names,
      contains(
        allOf(contains('2026-05-22'), contains('Zip Export'), contains('receipt.pdf')),
      ),
    );
  });
  });

  group('匯出：HTML', () {
  test('選取日記可合併匯出單一 HTML 並內嵌圖片', () async {
    final RecoverySetupResult setup = await harness.repository.setupRecoveryKey();
    final Directory sourceDirectory = Directory(p.join(harness.tempDir.path, 'html_source'))
      ..createSync(recursive: true);
    final File sourceImage = File(p.join(sourceDirectory.path, 'cover.png'))
      ..writeAsBytesSync(const <int>[1, 2, 3, 4, 5]);
    final File sourcePdf = File(p.join(sourceDirectory.path, 'note.pdf'))
      ..writeAsBytesSync(const <int>[6, 7, 8]);

    final String selectedId = generateEntryId();
    await harness.repository.saveEntry(
      setup.session,
      DiaryEntry(
        id: selectedId,
        vaultId: setup.session.vaultId,
        title: 'HTML <Export>',
        date: const DateOnly('2026-05-28'),
        createdAt: DateTime.parse('2026-05-28T08:00:00Z'),
        updatedAt: DateTime.parse('2026-05-28T09:00:00Z'),
        tags: const <String>['分享', 'HTML'],
        mood: '開心 & 安心',
        markdownBody: '# Heading\n\nHello <script>alert(1)</script>\n\n- item',
      ),
      pendingAttachments: <PendingAttachment>[
        PendingAttachment(
          sourcePath: sourceImage.path,
          mimeType: 'image/png',
          originalFilename: 'cover.png',
        ),
        PendingAttachment(
          sourcePath: sourcePdf.path,
          mimeType: 'application/pdf',
          originalFilename: 'note.pdf',
        ),
      ],
    );
    await harness.repository.saveEntry(
      setup.session,
      DiaryEntry(
        id: generateEntryId(),
        vaultId: setup.session.vaultId,
        title: 'Not selected',
        date: const DateOnly('2026-05-29'),
        createdAt: DateTime.parse('2026-05-29T08:00:00Z'),
        updatedAt: DateTime.parse('2026-05-29T08:00:00Z'),
        markdownBody: 'should not export',
      ),
    );

    final HtmlExportEstimate estimate = await archiveIo.estimateSelectedHtmlExport(
      entryIds: <String>{selectedId},
    );
    final File output = File(p.join(harness.tempDir.path, 'selected.html'));
    await archiveIo.writeSelectedHtmlExport(
      session: setup.session,
      entryIds: <String>{selectedId},
      target: output,
    );

    final String html = await output.readAsString();
    expect(estimate.entryCount, 1);
    expect(estimate.imageCount, 1);
    expect(estimate.imageBytes, 5);
    expect(estimate.estimatedHtmlBytes, greaterThan(5));
    expect(html, contains('HTML &lt;Export&gt;'));
    expect(html, contains('開心 &amp; 安心'));
    expect(html, contains('<h1>Heading</h1>'));
    expect(html, contains('&lt;script&gt;alert(1)&lt;/script&gt;'));
    expect(html, contains('data:image/png;base64,AQIDBAU='));
    expect(html, isNot(contains('<h1>QuillLockDiary 匯出</h1>')));
    expect(html, isNot(contains('<figcaption>cover.png</figcaption>')));
    expect(html, contains('note.pdf · application/pdf'));
    expect(html, isNot(contains('Not selected')));
  });
  });

  group('匯入：QuillLockDiary HTML', () {
  test('可匯入 QuillLockDiary 匯出的 HTML', () async {
    final RecoverySetupResult setup = await harness.repository.setupRecoveryKey();
    final Directory sourceDirectory = Directory(p.join(harness.tempDir.path, 'roundtrip_source'))
      ..createSync(recursive: true);
    final File sourceImage = File(p.join(sourceDirectory.path, 'cover.png'))
      ..writeAsBytesSync(const <int>[1, 2, 3, 4, 5]);

    final String selectedId = generateEntryId();
    await harness.repository.saveEntry(
      setup.session,
      DiaryEntry(
        id: selectedId,
        vaultId: setup.session.vaultId,
        title: 'HTML Roundtrip',
        date: const DateOnly('2026-05-28'),
        createdAt: DateTime.parse('2026-05-28T08:00:00Z'),
        updatedAt: DateTime.parse('2026-05-28T09:00:00Z'),
        tags: const <String>['分享', 'HTML'],
        mood: '開心 & 安心',
        markdownBody: '# Heading\n\nHello **world**\n\n- item',
      ),
      pendingAttachments: <PendingAttachment>[
        PendingAttachment(
          sourcePath: sourceImage.path,
          mimeType: 'image/png',
          originalFilename: 'cover.png',
        ),
      ],
    );

    final File exported = File(p.join(harness.tempDir.path, 'roundtrip.html'));
    await archiveIo.writeSelectedHtmlExport(
      session: setup.session,
      entryIds: <String>{selectedId},
      target: exported,
    );

    final PortableImportResult result = await archiveIo.importDocuments(
      session: setup.session,
      rootDirectory: harness.tempDir,
    );

    expect(result.importedEntries, 1);

    final entries = await harness.repository.listEntries();
    expect(entries, hasLength(2));

    final EntryIndexRecord importedRecord = entries.firstWhere(
      (EntryIndexRecord record) => record.id != selectedId,
    );
    final DiaryEntry? imported = await harness.repository.loadEntry(
      setup.session,
      importedRecord.id,
    );
    final attachments = await harness.repository.loadAttachments(importedRecord.id);

    expect(imported?.title, 'HTML Roundtrip');
    expect(imported?.date.value, '2026-05-28');
    expect(imported?.tags, const <String>['分享', 'HTML']);
    expect(imported?.mood, '開心 & 安心');
    expect(imported?.markdownBody, contains('# Heading'));
    expect(imported?.markdownBody, contains('Hello **world**'));
    expect(imported?.markdownBody, contains('- item'));
    expect(imported?.markdownBody, isNot(contains('![image]')));
    expect(attachments, hasLength(1));
    expect(attachments.single.mimeType, 'image/png');
  });

  test('可從 QuillLockDiary 匯出的單一 HTML 匯入多篇日記', () async {
    final RecoverySetupResult setup = await harness.repository.setupRecoveryKey();
    final Directory sourceDirectory = Directory(p.join(harness.tempDir.path, 'multi_roundtrip_source'))
      ..createSync(recursive: true);
    final File sourceImage = File(p.join(sourceDirectory.path, 'snap.png'))
      ..writeAsBytesSync(const <int>[9, 8, 7]);

    final String firstId = generateEntryId();
    final String secondId = generateEntryId();
    await harness.repository.saveEntry(
      setup.session,
      DiaryEntry(
        id: firstId,
        vaultId: setup.session.vaultId,
        title: '第一篇',
        date: const DateOnly('2026-05-17'),
        createdAt: DateTime.parse('2026-05-17T10:28:28Z'),
        updatedAt: DateTime.parse('2026-05-17T10:28:28Z'),
        markdownBody: '第一篇內容',
      ),
      pendingAttachments: <PendingAttachment>[
        PendingAttachment(
          sourcePath: sourceImage.path,
          mimeType: 'image/png',
          originalFilename: 'snap.png',
        ),
      ],
    );
    await harness.repository.saveEntry(
      setup.session,
      DiaryEntry(
        id: secondId,
        vaultId: setup.session.vaultId,
        title: '第二篇',
        date: const DateOnly('2026-04-18'),
        createdAt: DateTime.parse('2026-04-18T02:01:15Z'),
        updatedAt: DateTime.parse('2026-04-18T02:01:15Z'),
        markdownBody: '第二篇內容',
      ),
    );

    final File exported = File(p.join(harness.tempDir.path, 'multi_roundtrip.html'));
    await archiveIo.writeSelectedHtmlExport(
      session: setup.session,
      entryIds: <String>{firstId, secondId},
      target: exported,
    );

    final PortableImportResult result = await archiveIo.importDocuments(
      session: setup.session,
      rootDirectory: harness.tempDir,
    );

    expect(result.importedEntries, 2);

    final entries = await harness.repository.listEntries();
    expect(entries, hasLength(4));

    final List<DiaryEntry> imported = <DiaryEntry>[];
    for (final EntryIndexRecord record in entries) {
      if (record.id == firstId || record.id == secondId) {
        continue;
      }
      final DiaryEntry? entry = await harness.repository.loadEntry(setup.session, record.id);
      if (entry != null) {
        imported.add(entry);
      }
    }

    expect(imported.map((DiaryEntry entry) => entry.title).toList(),
        containsAll(<String>['第一篇', '第二篇']));
    expect(imported.map((DiaryEntry entry) => entry.date.value).toList(),
        containsAll(<String>['2026-05-17', '2026-04-18']));
    expect(imported.map((DiaryEntry entry) => entry.markdownBody).toList(),
        containsAll(<String>['第一篇內容', '第二篇內容']));

    final DiaryEntry firstImported =
        imported.firstWhere((DiaryEntry entry) => entry.title == '第一篇');
    final attachments = await harness.repository.loadAttachments(firstImported.id);
    expect(attachments, hasLength(1));
    expect(attachments.single.mimeType, 'image/png');
  });
  });

  group('匯出：HTML', () {
  test('HTML 匯出沒有可用日記時回報錯誤', () async {
    final RecoverySetupResult setup = await harness.repository.setupRecoveryKey();
    final File output = File(p.join(harness.tempDir.path, 'empty.html'));

    expect(
      () => archiveIo.writeSelectedHtmlExport(
        session: setup.session,
        entryIds: <String>{'jrn_NOT_FOUND'},
        target: output,
      ),
      throwsA(
        isA<StateError>().having(
          (StateError error) => error.message,
          'message',
          '沒有可匯出的日記。',
        ),
      ),
    );
  });
  });

  group('匯入：Markdown / zip', () {
  test('可從 zip 匯入 Markdown 與附件', () async {
    final RecoverySetupResult setup = await harness.repository.setupRecoveryKey();
    final File zipFile = File(p.join(harness.tempDir.path, 'portable_import.zip'));
    final Archive archive = Archive()
      ..addFile(
        ArchiveFile.string(
          'diary_export_123/2026-05-23/Zip Import/index.md',
          '''---
title: "Zip Import"
date: "2026-05-23"
attachments:
  - "./photo.png"
---

# Zip Import

Imported from zip.
''',
        ),
      )
      ..addFile(
        ArchiveFile(
          'diary_export_123/2026-05-23/Zip Import/photo.png',
          3,
          const <int>[6, 5, 4],
        ),
      );

    await zipFile.writeAsBytes(ZipEncoder().encode(archive));

    final PortableImportResult result = await archiveIo.importDocumentsFromZip(
      session: setup.session,
      zipFile: zipFile,
    );

    expect(result.importedEntries, 1);

    final entries = await harness.repository.listEntries();
    expect(entries, hasLength(1));

    final DiaryEntry? imported = await harness.repository.loadEntry(
      setup.session,
      entries.single.id,
    );
    final attachments = await harness.repository.loadAttachments(entries.single.id);

    expect(imported?.title, 'Zip Import');
    expect(imported?.date.value, '2026-05-23');
    expect(imported?.markdownBody, contains('Imported from zip.'));
    expect(attachments, hasLength(1));
    expect(attachments.single.safeFilename, 'photo.png');
  });
  });

  group('備份與還原', () {
  test('peekBackupRecovery 可讀取備份內 recovery.json', () async {
    final RecoverySetupResult setup = await harness.repository.setupRecoveryKey();
    await harness.repository.saveEntry(
      setup.session,
      DiaryEntry(
        id: generateEntryId(),
        vaultId: setup.session.vaultId,
        title: 'Backup Entry',
        date: const DateOnly('2026-05-24'),
        createdAt: DateTime.parse('2026-05-24T10:00:00Z'),
        updatedAt: DateTime.parse('2026-05-24T10:00:00Z'),
        markdownBody: 'backup body',
      ),
    );

    final File backupFile = File(p.join(harness.tempDir.path, 'test.jbackup'));
    await archiveIo.writeBackupZip(backupFile);

    final BackupRecoveryPreview preview = await archiveIo.peekBackupRecovery(backupFile);
    expect(preview.hasRecovery, isTrue);
    expect(preview.metadata?.vaultId, setup.session.vaultId);
    expect(preview.metadata?.recoveryKeyHint, isNotEmpty);
  });

  test('checkBackupHealth accepts a readable vault backup', () async {
    final RecoverySetupResult setup = await harness.repository.setupRecoveryKey();
    await harness.repository.saveEntry(
      setup.session,
      DiaryEntry(
        id: generateEntryId(),
        vaultId: setup.session.vaultId,
        title: 'Healthy Backup',
        date: const DateOnly('2026-05-30'),
        createdAt: DateTime.parse('2026-05-30T10:00:00Z'),
        updatedAt: DateTime.parse('2026-05-30T10:00:00Z'),
        markdownBody: 'healthy backup body',
      ),
    );

    final File backupFile = File(p.join(harness.tempDir.path, 'healthy.jbackup'));
    await archiveIo.writeBackupZip(backupFile);

    final BackupHealthReport report = await archiveIo.checkBackupHealth(backupFile);

    expect(report.ok, isTrue);
    expect(report.hasRecoveryMetadata, isTrue);
    expect(report.hasManifest || report.entrySampleFound, isTrue);
  });

  test('checkBackupHealth rejects an invalid zip', () async {
    final File backupFile = File(p.join(harness.tempDir.path, 'invalid.jbackup'))
      ..writeAsBytesSync(const <int>[1, 2, 3, 4]);

    final BackupHealthReport report = await archiveIo.checkBackupHealth(backupFile);

    expect(report.ok, isFalse);
    expect(report.message, contains('.jbackup'));
  });

  test('restoreBackupZip 會在覆寫前拒絕缺少加密資料的備份', () async {
    final RecoverySetupResult setup = await harness.repository.setupRecoveryKey();
    final RecoveryMetadata metadata =
        await harness.repository.readRecoveryMetadata() ??
            (throw StateError('測試前置失敗：缺少 recovery metadata。'));
    await harness.repository.saveEntry(
      setup.session,
      DiaryEntry(
        id: generateEntryId(),
        vaultId: setup.session.vaultId,
        title: 'Keep Me',
        date: const DateOnly('2026-05-31'),
        createdAt: DateTime.parse('2026-05-31T08:00:00Z'),
        updatedAt: DateTime.parse('2026-05-31T08:00:00Z'),
        markdownBody: 'keep',
      ),
    );

    final File incompleteBackup = File(p.join(harness.tempDir.path, 'incomplete.jbackup'));
    final Archive archive = Archive()
      ..addFile(
        ArchiveFile.string(
          'recovery.json',
          jsonEncode(metadata.toJson()),
        ),
      );
    await incompleteBackup.writeAsBytes(ZipEncoder().encode(archive));

    expect(
      () => archiveIo.restoreBackupZip(incompleteBackup),
      throwsA(
        isA<StateError>().having(
          (StateError error) => error.message,
          'message',
          contains('缺少必要的加密資料'),
        ),
      ),
    );

    final List<EntryIndexRecord> entries = await harness.repository.listEntries();
    expect(entries, hasLength(1));
  });

  test('restoreBackupZip 可還原日記並保留 recovery metadata', () async {
    final RecoverySetupResult setup = await harness.repository.setupRecoveryKey();
    final String entryId = generateEntryId();
    await harness.repository.saveEntry(
      setup.session,
      DiaryEntry(
        id: entryId,
        vaultId: setup.session.vaultId,
        title: 'Restore Me',
        date: const DateOnly('2026-05-25'),
        createdAt: DateTime.parse('2026-05-25T11:00:00Z'),
        updatedAt: DateTime.parse('2026-05-25T11:00:00Z'),
        markdownBody: 'restore body',
      ),
    );

    final File backupFile = File(p.join(harness.tempDir.path, 'restore.jbackup'));
    await archiveIo.writeBackupZip(backupFile);

    await harness.repository.saveEntry(
      setup.session,
      DiaryEntry(
        id: generateEntryId(),
        vaultId: setup.session.vaultId,
        title: 'After Backup Noise',
        date: const DateOnly('2026-05-26'),
        createdAt: DateTime.parse('2026-05-26T12:00:00Z'),
        updatedAt: DateTime.parse('2026-05-26T12:00:00Z'),
        markdownBody: 'noise',
      ),
    );

    await harness.repository.closeUnlockedResources();
    await archiveIo.restoreBackupZip(backupFile);

    final RecoveryMetadata? metadata = await harness.repository.readRecoveryMetadata();
    expect(metadata?.vaultId, setup.session.vaultId);

    final UnlockedVaultSession session =
        await harness.repository.unlockWithRecoveryKey(setup.recoveryKey);
    await harness.repository.rebuildIndex(session);
    final List<EntryIndexRecord> entries = await harness.repository.listEntries();
    expect(entries, hasLength(1));
    final DiaryEntry? restored = await harness.repository.loadEntry(session, entryId);
    expect(restored?.title, 'Restore Me');
  });

  test('損壞的備份 zip 不應清空現有 vault', () async {
    final RecoverySetupResult setup = await harness.repository.setupRecoveryKey();
    await harness.repository.saveEntry(
      setup.session,
      DiaryEntry(
        id: generateEntryId(),
        vaultId: setup.session.vaultId,
        title: 'Keep Me',
        date: const DateOnly('2026-05-27'),
        createdAt: DateTime.parse('2026-05-27T08:00:00Z'),
        updatedAt: DateTime.parse('2026-05-27T08:00:00Z'),
        markdownBody: 'keep',
      ),
    );

    final File badBackup = File(p.join(harness.tempDir.path, 'bad.jbackup'))
      ..writeAsBytesSync(const <int>[1, 2, 3, 4]);

    expect(
      () => archiveIo.restoreBackupZip(badBackup),
      throwsA(
        isA<StateError>().having(
          (StateError error) => error.message,
          'message',
          anyOf(contains('無法讀取備份檔'), contains('備份檔內容不完整')),
        ),
      ),
    );

    final List<EntryIndexRecord> entries = await harness.repository.listEntries();
    expect(entries, hasLength(1));
  });
  });
}
