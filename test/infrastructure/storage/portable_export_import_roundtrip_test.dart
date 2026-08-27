import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quill_diary/domain/attachment/asset_attachment.dart';
import 'package:quill_diary/domain/diary/diary_entry.dart';
import 'package:quill_diary/domain/people/person.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/markdown/front_matter_codec.dart';
import 'package:quill_diary/infrastructure/storage/portable/portable_export_io.dart';
import 'package:quill_diary/infrastructure/storage/portable/portable_import_io.dart';
import 'package:quill_diary/infrastructure/storage/portable/html_import_parser.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';

import '../../helpers/vault/vault_test_harness.dart';

final Uint8List _pngBytes = Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
  ),
);

final Uint8List _webpBytes = Uint8List.fromList(
  base64Decode('UklGRiIAAABXRUJQVlA4IBYAAAAwAQCdASoBAAEADsD+JaQAA3AAAAAA'),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late VaultTestHarness harness;
  late RecoverySetupResult setup;

  setUp(() async {
    harness = await VaultTestHarness.create();
    setup = await harness.repository.setupRecoveryKey();
  });

  tearDown(() async {
    await harness.dispose();
  });

  test('Markdown 匯出後可再匯入標題、標籤、任務清單與圖片', () async {
    final DiaryEntry saved = await harness.repository.saveEntry(
      setup.session,
      DiaryEntry(
        id: generateEntryId(),
        vaultId: setup.session.vaultId,
        title: '往返標題',
        date: const DateOnly('2026-08-18'),
        createdAt: DateTime(2026, 8, 18, 12, 30),
        updatedAt: DateTime(2026, 8, 18, 12, 30),
        markdownBody: '前言\n- [ ] 買牛奶\n- [x] 回覆\n結尾',
        tags: const <String>['筆記'],
      ),
      pendingAttachments: <PendingAttachment>[
        PendingAttachment(
          assetId: generateAssetId(),
          bytes: _pngBytes,
          mimeType: 'image/png',
          originalFilename: 'photo.png',
        ),
      ],
    );

    final Directory exportRoot = await Directory.systemTemp.createTemp(
      'qld_md_export_',
    );
    final Directory importRoot = await Directory.systemTemp.createTemp(
      'qld_md_import_',
    );
    try {
      final PortableExportIo exportIo = PortableExportIo(
        pathStrategy: harness.pathStrategy,
        repository: harness.repository,
        frontMatterCodec: const FrontMatterCodec(),
      );
      await exportIo.exportMarkdown(
        session: setup.session,
        parentDirectory: exportRoot,
      );

      // 清空後再匯入，避免與原篇混淆
      await harness.repository.deleteEntry(setup.session, saved.id);

      final PortableImportIo importIo = PortableImportIo(
        pathStrategy: harness.pathStrategy,
        repository: harness.repository,
        frontMatterCodec: const FrontMatterCodec(),
      );
      final result = await importIo.importDocuments(
        session: setup.session,
        rootDirectory: exportRoot,
      );
      expect(result.importedEntries, 1);

      final entries = await harness.repository.listEntries();
      final DiaryEntry? imported = await harness.repository.loadEntry(
        setup.session,
        entries.single.id,
      );
      expect(imported, isNotNull);
      expect(imported!.normalizedTitle, '往返標題');
      expect(imported.tags, <String>['筆記']);
      expect(imported.markdownBody, contains('- [ ] 買牛奶'));
      expect(imported.markdownBody, contains('- [x] 回覆'));
      expect(imported.date.value, '2026-08-18');

      final List<AssetAttachment> attachments = await harness.repository
          .loadAttachments(imported.id);
      expect(attachments, hasLength(1));
      expect(attachments.single.mimeType, 'image/png');
    } finally {
      await exportRoot.delete(recursive: true);
      await importRoot.delete(recursive: true);
    }
  });

  test('HTML 匯出後可再匯入日期時間、標題、標籤與任務清單', () async {
    await harness.repository.saveEntry(
      setup.session,
      DiaryEntry(
        id: generateEntryId(),
        vaultId: setup.session.vaultId,
        title: 'HTML 往返',
        date: const DateOnly('2026-10-31'),
        createdAt: DateTime(2026, 10, 31, 10, 14),
        updatedAt: DateTime(2026, 10, 31, 10, 14),
        markdownBody: '- [ ] 一\n- [x] 二',
        tags: const <String>['筆記'],
      ),
    );

    final Directory tempRoot = await Directory.systemTemp.createTemp(
      'qld_html_roundtrip_',
    );
    try {
      final PortableExportIo exportIo = PortableExportIo(
        pathStrategy: harness.pathStrategy,
        repository: harness.repository,
        frontMatterCodec: const FrontMatterCodec(),
      );
      final File htmlFile = File(p.join(tempRoot.path, 'export.html'));
      final entries = await harness.repository.listEntries();
      await exportIo.writeSelectedHtmlExport(
        session: setup.session,
        entryIds: entries.map((e) => e.id).toSet(),
        target: htmlFile,
      );

      final String html = await htmlFile.readAsString();
      expect(html, contains('2026-10-31 星期六 10:14'));
      expect(isQuillDiaryExportHtml(html), isTrue);

      for (final entry in entries) {
        await harness.repository.deleteEntry(setup.session, entry.id);
      }

      final PortableImportIo importIo = PortableImportIo(
        pathStrategy: harness.pathStrategy,
        repository: harness.repository,
        frontMatterCodec: const FrontMatterCodec(),
      );
      final result = await importIo.importDocuments(
        session: setup.session,
        rootDirectory: tempRoot,
      );
      expect(result.importedEntries, 1);

      final importedEntries = await harness.repository.listEntries();
      final DiaryEntry? imported = await harness.repository.loadEntry(
        setup.session,
        importedEntries.single.id,
      );
      expect(imported, isNotNull);
      expect(imported!.normalizedTitle, 'HTML 往返');
      expect(imported.tags, <String>['筆記']);
      expect(imported.date.value, '2026-10-31');
      expect(imported.createdAt.hour, 10);
      expect(imported.createdAt.minute, 14);
      expect(imported.markdownBody, contains('- [ ] 一'));
      expect(imported.markdownBody, contains('- [x] 二'));
    } finally {
      await tempRoot.delete(recursive: true);
    }
  });

  test('HTML 匯出含圖片時用通用標籤並保留 MIME 副檔名', () async {
    await harness.repository.saveEntry(
      setup.session,
      DiaryEntry(
        id: generateEntryId(),
        vaultId: setup.session.vaultId,
        title: '圖片篇',
        date: const DateOnly('2026-08-18'),
        createdAt: DateTime(2026, 8, 18, 12, 0),
        updatedAt: DateTime(2026, 8, 18, 12, 0),
        markdownBody: '有圖',
      ),
      pendingAttachments: <PendingAttachment>[
        PendingAttachment(
          assetId: generateAssetId(),
          bytes: _pngBytes,
          mimeType: 'image/png',
          originalFilename: 'secret-name.png',
        ),
        PendingAttachment(
          assetId: generateAssetId(),
          bytes: _webpBytes,
          mimeType: 'image/webp',
          originalFilename: 'keep-me.webp',
        ),
      ],
    );

    final Directory tempRoot = await Directory.systemTemp.createTemp(
      'qld_html_img_',
    );
    try {
      final PortableExportIo exportIo = PortableExportIo(
        pathStrategy: harness.pathStrategy,
        repository: harness.repository,
        frontMatterCodec: const FrontMatterCodec(),
      );
      final File htmlFile = File(p.join(tempRoot.path, 'export.html'));
      final entries = await harness.repository.listEntries();
      await exportIo.writeSelectedHtmlExport(
        session: setup.session,
        entryIds: entries.map((e) => e.id).toSet(),
        target: htmlFile,
      );

      final String html = await htmlFile.readAsString();
      expect(html, contains('alt="image-1.png"'));
      expect(html, contains('alt="image-2.webp"'));
      expect(html, isNot(contains('secret-name')));
      expect(html, isNot(contains('keep-me')));
      expect(html, contains('data:image/png;base64,'));
      expect(html, contains('data:image/webp;base64,'));

      for (final entry in entries) {
        await harness.repository.deleteEntry(setup.session, entry.id);
      }

      final PortableImportIo importIo = PortableImportIo(
        pathStrategy: harness.pathStrategy,
        repository: harness.repository,
        frontMatterCodec: const FrontMatterCodec(),
      );
      final result = await importIo.importDocuments(
        session: setup.session,
        rootDirectory: tempRoot,
      );
      expect(result.importedEntries, 1);

      final importedEntries = await harness.repository.listEntries();
      final List<AssetAttachment> attachments = await harness.repository
          .loadAttachments(importedEntries.single.id);
      expect(attachments, hasLength(2));
      expect(
        attachments.map((AssetAttachment a) => a.mimeType).toSet(),
        <String>{'image/png', 'image/webp'},
      );
    } finally {
      await tempRoot.delete(recursive: true);
    }
  });

  test('HTML 關閉匯出圖片時也不輸出附件清單', () async {
    await harness.repository.saveEntry(
      setup.session,
      DiaryEntry(
        id: generateEntryId(),
        vaultId: setup.session.vaultId,
        title: '無媒體篇',
        date: const DateOnly('2026-08-18'),
        createdAt: DateTime(2026, 8, 18, 12, 0),
        updatedAt: DateTime(2026, 8, 18, 12, 0),
        markdownBody: '純文字',
      ),
      pendingAttachments: <PendingAttachment>[
        PendingAttachment(
          assetId: generateAssetId(),
          bytes: _pngBytes,
          mimeType: 'image/png',
          originalFilename: 'photo.png',
        ),
        PendingAttachment(
          assetId: generateAssetId(),
          bytes: Uint8List.fromList(utf8.encode('hello')),
          mimeType: 'text/plain',
          originalFilename: 'note.txt',
        ),
      ],
    );

    final Directory tempRoot = await Directory.systemTemp.createTemp(
      'qld_html_no_media_',
    );
    try {
      final PortableExportIo exportIo = PortableExportIo(
        pathStrategy: harness.pathStrategy,
        repository: harness.repository,
        frontMatterCodec: const FrontMatterCodec(),
      );
      final File htmlFile = File(p.join(tempRoot.path, 'export.html'));
      final entries = await harness.repository.listEntries();
      await exportIo.writeSelectedHtmlExport(
        session: setup.session,
        entryIds: entries.map((e) => e.id).toSet(),
        target: htmlFile,
        options: const HtmlExportOptions(includeImages: false),
      );

      final String html = await htmlFile.readAsString();
      expect(html, isNot(contains('class="embedded-images"')));
      expect(html, isNot(contains('class="attachment-list"')));
      expect(html, isNot(contains('data:image')));
      expect(html, isNot(contains('未內嵌附件')));
      expect(html, isNot(contains('note.txt')));
      expect(html, isNot(contains('photo.png')));
      expect(html, contains('純文字'));
    } finally {
      await tempRoot.delete(recursive: true);
    }
  });

  test('HTML 隱藏人物名稱後匯出內容不含原名', () async {
    await harness.repository.createPerson(
      setup.session,
      PersonDraft(name: '王小明', aliases: const <String>['阿明']),
    );
    await harness.repository.saveEntry(
      setup.session,
      DiaryEntry(
        id: generateEntryId(),
        vaultId: setup.session.vaultId,
        title: '與王小明吃飯',
        date: const DateOnly('2026-08-18'),
        createdAt: DateTime(2026, 8, 18, 12, 0),
        updatedAt: DateTime(2026, 8, 18, 12, 0),
        markdownBody: '阿明說下次再約',
      ),
    );

    final Directory tempRoot = await Directory.systemTemp.createTemp(
      'qld_html_anon_',
    );
    try {
      final PortableExportIo exportIo = PortableExportIo(
        pathStrategy: harness.pathStrategy,
        repository: harness.repository,
        frontMatterCodec: const FrontMatterCodec(),
      );
      final File htmlFile = File(p.join(tempRoot.path, 'export.html'));
      final entries = await harness.repository.listEntries();
      await exportIo.writeSelectedHtmlExport(
        session: setup.session,
        entryIds: entries.map((e) => e.id).toSet(),
        target: htmlFile,
        options: const HtmlExportOptions(hidePersonNames: true),
      );

      final String html = await htmlFile.readAsString();
      expect(html, contains('人物A'));
      expect(html, isNot(contains('王小明')));
      expect(html, isNot(contains('阿明')));
    } finally {
      await tempRoot.delete(recursive: true);
    }
  });

  test('Markdown 可只匯出選中篇並隱藏人物名稱', () async {
    await harness.repository.createPerson(
      setup.session,
      PersonDraft(name: '王小明', aliases: const <String>['阿明']),
    );
    final DiaryEntry keep = await harness.repository.saveEntry(
      setup.session,
      DiaryEntry(
        id: generateEntryId(),
        vaultId: setup.session.vaultId,
        title: '與王小明吃飯',
        date: const DateOnly('2026-08-18'),
        createdAt: DateTime(2026, 8, 18, 12, 0),
        updatedAt: DateTime(2026, 8, 18, 12, 0),
        markdownBody: '阿明說下次再約',
        tags: const <String>['阿明'],
      ),
    );
    await harness.repository.saveEntry(
      setup.session,
      DiaryEntry(
        id: generateEntryId(),
        vaultId: setup.session.vaultId,
        title: '略過這篇',
        date: const DateOnly('2026-08-19'),
        createdAt: DateTime(2026, 8, 19, 12, 0),
        updatedAt: DateTime(2026, 8, 19, 12, 0),
        markdownBody: '不應出現',
      ),
    );

    final Directory exportRoot = await Directory.systemTemp.createTemp(
      'qld_md_select_',
    );
    try {
      final PortableExportIo exportIo = PortableExportIo(
        pathStrategy: harness.pathStrategy,
        repository: harness.repository,
        frontMatterCodec: const FrontMatterCodec(),
      );
      final MarkdownExportEstimate estimate =
          await exportIo.estimateMarkdownExport();
      expect(estimate.entryCount, 2);

      await exportIo.exportMarkdown(
        session: setup.session,
        parentDirectory: exportRoot,
        entryIds: <EntryId>{keep.id},
        options: const MarkdownExportOptions(hidePersonNames: true),
      );

      final List<File> indexFiles = exportRoot
          .listSync(recursive: true)
          .whereType<File>()
          .where((File f) => p.basename(f.path) == 'index.md')
          .toList(growable: false);
      expect(indexFiles, hasLength(1));

      final String markdown = await indexFiles.single.readAsString();
      expect(markdown, contains('人物A'));
      expect(markdown, isNot(contains('王小明')));
      expect(markdown, isNot(contains('阿明')));
      expect(markdown, isNot(contains('略過這篇')));
      expect(markdown, isNot(contains('不應出現')));
    } finally {
      await exportRoot.delete(recursive: true);
    }
  });
}
