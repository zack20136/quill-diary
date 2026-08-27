import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quill_diary/domain/diary/diary_entry.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/markdown/front_matter_codec.dart';
import 'package:quill_diary/infrastructure/storage/portable/portable_import_io.dart';
import 'package:quill_diary/infrastructure/storage/portable/portable_import_preview.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';

import '../../helpers/vault/vault_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late VaultTestHarness harness;
  late RecoverySetupResult setup;
  late PortableImportIo importIo;

  setUp(() async {
    harness = await VaultTestHarness.create();
    setup = await harness.repository.setupRecoveryKey();
    importIo = PortableImportIo(
      pathStrategy: harness.pathStrategy,
      repository: harness.repository,
      frontMatterCodec: const FrontMatterCodec(),
    );
  });

  tearDown(() async {
    await harness.dispose();
  });

  Future<Directory> writeMarkdownEntries(
    List<({String fileName, String title, String date, String body})> docs,
  ) async {
    final Directory root = await Directory.systemTemp.createTemp(
      'qld_import_preview_',
    );
    for (final ({String fileName, String title, String date, String body})
        doc in docs) {
      await File(p.join(root.path, doc.fileName)).writeAsString(
        '---\n'
        'title: ${doc.title}\n'
        'date: ${doc.date}\n'
        '---\n'
        '${doc.body}\n',
      );
    }
    return root;
  }

  test('分析預覽會標出可能重複並回報略過檔數', () async {
    await harness.repository.saveEntry(
      setup.session,
      DiaryEntry(
        id: generateEntryId(),
        vaultId: setup.session.vaultId,
        title: '已有標題',
        date: const DateOnly('2026-08-18'),
        createdAt: DateTime(2026, 8, 18, 12),
        updatedAt: DateTime(2026, 8, 18, 12),
        markdownBody: '庫內原文',
      ),
    );

    final Directory root = await writeMarkdownEntries(<
      ({String fileName, String title, String date, String body})
    >[
      (
        fileName: 'a.md',
        title: '已有標題',
        date: '2026-08-18',
        body: '要匯入的重複候補',
      ),
      (
        fileName: 'b.md',
        title: '全新標題',
        date: '2026-08-19',
        body: '新內容',
      ),
    ]);
    await File(p.join(root.path, 'bad.html')).writeAsString('<html></html>');

    try {
      final AnalyzedPortableImport analyzed = await importIo.analyzeDocuments(
        session: setup.session,
        rootDirectory: root,
      );

      expect(analyzed.preview.entryCount, 2);
      expect(analyzed.preview.skippedFiles, 1);
      expect(analyzed.preview.likelyDuplicateCount, 1);
      expect(
        analyzed.preview.entries
            .where((PortableImportPreviewEntry e) => e.likelyDuplicate)
            .single
            .displayTitle,
        '已有標題',
      );

      final entriesBefore = await harness.repository.listEntries();
      expect(entriesBefore, hasLength(1));
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('只寫入勾選篇；取消選取的篇不會寫入', () async {
    final Directory root = await writeMarkdownEntries(<
      ({String fileName, String title, String date, String body})
    >[
      (
        fileName: 'keep.md',
        title: '保留篇',
        date: '2026-08-18',
        body: '保留內容',
      ),
      (
        fileName: 'skip.md',
        title: '略過篇',
        date: '2026-08-19',
        body: '不應寫入',
      ),
    ]);

    try {
      final AnalyzedPortableImport analyzed = await importIo.analyzeDocuments(
        session: setup.session,
        rootDirectory: root,
      );
      expect(analyzed.preview.entryCount, 2);

      final keep = analyzed.preview.entries.firstWhere(
        (PortableImportPreviewEntry e) => e.displayTitle == '保留篇',
      );

      final result = await importIo.persistAnalyzedImport(
        session: setup.session,
        analyzed: analyzed,
        selectedPreviewIndices: <int>{keep.previewIndex},
      );

      expect(result.importedEntries, 1);
      final entries = await harness.repository.listEntries();
      expect(entries, hasLength(1));
      expect(entries.single.title, '保留篇');
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('分析後不 persist 時庫內不會新增', () async {
    final Directory root = await writeMarkdownEntries(<
      ({String fileName, String title, String date, String body})
    >[
      (
        fileName: 'only.md',
        title: '取消不寫入',
        date: '2026-08-18',
        body: '內容',
      ),
    ]);

    try {
      final AnalyzedPortableImport analyzed = await importIo.analyzeDocuments(
        session: setup.session,
        rootDirectory: root,
      );
      expect(analyzed.hasImportableEntries, isTrue);

      final entries = await harness.repository.listEntries();
      expect(entries, isEmpty);
    } finally {
      await root.delete(recursive: true);
    }
  });
}
