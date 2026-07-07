import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quill_diary/domain/attachment/asset_attachment.dart';
import 'package:quill_diary/domain/diary/diary_entry.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/database/index_database.dart';
import 'package:quill_diary/infrastructure/database/index_database_manager.dart';
import 'package:quill_diary/infrastructure/markdown/front_matter_codec.dart';
import 'package:quill_diary/infrastructure/security/app_lock_service.dart';
import 'package:quill_diary/infrastructure/security/device_key_manager.dart';
import 'package:quill_diary/infrastructure/storage/portable/portable_export_io.dart';
import 'package:quill_diary/infrastructure/storage/portable/html_import_parser.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';

import '../../helpers/vault/stub_crypto_service.dart';
import '../../helpers/vault/test_vault_path_strategy.dart';

void main() {
  test('任務清單 markdown 可透過 HTML 匯出與匯入往返', () {
    const String markdown = '前言\n- [ ] 買牛奶\n- [x] 回覆信件\n結尾';
    final String html = exportMarkdownBodyToHtml(markdown);
    expect(html, contains('class="task-list"'));
    expect(html, contains('type="checkbox"'));

    final String imported = exportHtmlBodyToMarkdown(html);
    expect(imported, contains('- [ ] 買牛奶'));
    expect(imported, contains('- [x] 回覆信件'));
    expect(imported, contains('前言'));
    expect(imported, contains('結尾'));
    expect(imported, isNot(contains('- 買牛奶')));
    expect(imported, markdown);
  });

  test('任務清單夾雜段落往返後不會多出空白行', () {
    const String markdown =
        '- [ ] dfgsdfgsdfgdfgs\n- [ ] dfgh\n- [ ] fghd\n45453453\n- [ ] dfghd';
    final String imported = exportHtmlBodyToMarkdown(
      exportMarkdownBodyToHtml(markdown),
    );
    expect(imported, markdown);
  });

  test('匯入 pretty-print HTML 時任務項目間不插入空白行', () {
    const String html = '''
<ul class="task-list">
  <li class="task-list-item"><label><input type="checkbox" disabled> 一</label></li>

  <li class="task-list-item"><label><input type="checkbox" checked disabled> 二</label></li>
</ul>
''';

    final String imported = exportHtmlBodyToMarkdown(html);
    expect(imported, '- [ ] 一\n- [x] 二');
  });

  test('匯入未標記 class 的 checkbox 清單仍保留任務格式', () {
    const String html = '''
<ul>
  <li><label><input type="checkbox"> 買牛奶</label></li>
  <li><label><input type="checkbox" checked> 回覆信件</label></li>
</ul>
''';

    final String imported = exportHtmlBodyToMarkdown(html);
    expect(imported, contains('- [ ] 買牛奶'));
    expect(imported, contains('- [x] 回覆信件'));
    expect(imported, isNot(contains('- 買牛奶')));
    expect(imported, isNot(contains('- 回覆信件')));
  });

  test('完整 HTML 匯出會移除任務清單預設圓點', () async {
    final Directory tempRoot = await Directory.systemTemp.createTemp(
      'quill_diary_html_export_',
    );
    try {
      final _FakePortableExportVaultRepository repository =
          _FakePortableExportVaultRepository();
      final PortableExportIo io = PortableExportIo(
        pathStrategy: DummyVaultPathStrategy(),
        repository: repository,
        frontMatterCodec: const FrontMatterCodec(),
      );
      final File target = File(p.join(tempRoot.path, 'export.html'));
      await io.writeSelectedHtmlExport(
        session: const UnlockedVaultSession(
          vaultId: 'vlt_test',
          trustedDevice: true,
        ),
        entryIds: <EntryId>{'ent_test'},
        target: target,
      );

      final String html = await target.readAsString();
      expect(html, contains('.entry-body ul.task-list {'));
      expect(html, contains('list-style: none;'));
      expect(html, contains('padding-left: 0;'));
      expect(html, contains('line-height: 1.55;'));
      expect(html, contains('.entry-body p { margin: 0 0 0.65em; }'));
      expect(html, contains('type="checkbox"'));
      expect(html, isNot(contains('<ul class="task-list">\n<li>•')));
    } finally {
      await tempRoot.delete(recursive: true);
    }
  });
}

class _FakePortableExportVaultRepository extends VaultRepository {
  _FakePortableExportVaultRepository()
    : super(
        pathStrategy: DummyVaultPathStrategy(),
        frontMatterCodec: const FrontMatterCodec(),
        cryptoService: StubCryptoService(),
        indexDatabaseManager: IndexDatabaseManager(DummyVaultPathStrategy()),
        deviceKeyManager: const UnsupportedDeviceKeyManager(),
        appLockService: const UnsupportedAppLockService(),
      );

  @override
  Future<List<EntryIndexRecord>> listEntries({
    String? searchQuery,
    DateOnly? date,
  }) async {
    return <EntryIndexRecord>[
      EntryIndexRecord(
        id: 'ent_test',
        vaultId: 'vlt_test',
        filePath: 'ignored',
        title: '測試日記',
        previewText: '前言 買牛奶 回覆信件 結尾',
        previewMarkdown: '',
        date: DateOnly.parse('2026-07-03'),
        createdAt: DateTime.parse('2026-07-03T10:28:00.000'),
        updatedAt: DateTime.parse('2026-07-03T10:28:00.000'),
        tags: const <String>[],
        wordCount: 4,
        charCount: 10,
        attachmentCount: 0,
      ),
    ];
  }

  @override
  Future<DiaryEntry?> loadEntry(
    UnlockedVaultSession session,
    EntryId entryId,
  ) async {
    return DiaryEntry(
      id: 'ent_test',
      vaultId: 'vlt_test',
      title: '測試日記',
      date: const DateOnly('2026-07-03'),
      createdAt: DateTime.parse('2026-07-03T10:28:00.000'),
      updatedAt: DateTime.parse('2026-07-03T10:28:00.000'),
      markdownBody: '前言\n- [ ] 買牛奶\n- [x] 回覆信件\n結尾',
    );
  }

  @override
  Future<List<AssetAttachment>> loadAttachments(EntryId entryId) async {
    return const <AssetAttachment>[];
  }

  @override
  Future<Uint8List?> readDecryptedAssetBytes(
    UnlockedVaultSession session,
    String encryptedAbsolutePath, {
    int maxEncryptedFileBytes = 32 << 20,
  }) async {
    return null;
  }
}
