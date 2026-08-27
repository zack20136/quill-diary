import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/diary/diary_entry.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/markdown/front_matter_codec.dart';
import 'package:quill_diary/infrastructure/storage/portable/portable_export_io.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';

import '../../helpers/vault/vault_test_harness.dart';

final Uint8List _pngBytes = Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
  ),
);

void main() {
  group('HtmlExportEstimate', () {
    final HtmlExportEstimate full = HtmlExportEstimate(
      entries: <HtmlExportEntrySummary>[
        const HtmlExportEntrySummary(
          id: 'a',
          date: DateOnly('2026-08-01'),
          title: '一',
          imageCount: 2,
          imageBytes: 100,
          textBytes: 10,
        ),
        const HtmlExportEntrySummary(
          id: 'b',
          date: DateOnly('2026-08-10'),
          title: '二',
          imageCount: 1,
          imageBytes: 50,
          textBytes: 20,
        ),
        const HtmlExportEntrySummary(
          id: 'c',
          date: DateOnly('2026-08-17'),
          title: null,
          imageCount: 0,
          imageBytes: 0,
          textBytes: 5,
        ),
      ],
    );

    test('彙總篇數、圖片與日期範圍', () {
      expect(full.entryCount, 3);
      expect(full.imageCount, 3);
      expect(full.imageBytes, 150);
      expect(full.firstDate?.value, '2026-08-01');
      expect(full.lastDate?.value, '2026-08-17');
      expect(
        full.estimatedExportBytes(includeImages: true),
        10 + 20 + 5 + ((150 * 4 + 2) ~/ 3),
      );
    });

    test('forSelected 依選中篇重算並維持順序', () {
      final HtmlExportEstimate subset = full.forSelected(<String>{'c', 'a'});
      expect(subset.entries.map((HtmlExportEntrySummary e) => e.id), <String>[
        'a',
        'c',
      ]);
      expect(subset.entryCount, 2);
      expect(subset.imageCount, 2);
      expect(subset.imageBytes, 100);
      expect(subset.firstDate?.value, '2026-08-01');
      expect(subset.lastDate?.value, '2026-08-17');
    });

    test('estimatedExportBytes 依是否內嵌圖片計算', () {
      expect(
        full.estimatedExportBytes(includeImages: true),
        10 + 20 + 5 + ((150 * 4 + 2) ~/ 3),
      );
      expect(full.estimatedExportBytes(includeImages: false), 10 + 20 + 5);
    });
  });

  group('estimateSelectedHtmlExport', () {
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

    test('回傳每篇 summary 且選取後可只匯出部分篇', () async {
      final DiaryEntry withImage = await harness.repository.saveEntry(
        setup.session,
        DiaryEntry(
          id: generateEntryId(),
          vaultId: setup.session.vaultId,
          title: '有圖',
          date: const DateOnly('2026-08-01'),
          createdAt: DateTime(2026, 8, 1, 10),
          updatedAt: DateTime(2026, 8, 1, 10),
          markdownBody: '圖',
        ),
        pendingAttachments: <PendingAttachment>[
          PendingAttachment(
            assetId: generateAssetId(),
            bytes: _pngBytes,
            mimeType: 'image/png',
            originalFilename: 'a.png',
          ),
        ],
      );
      final DiaryEntry plain = await harness.repository.saveEntry(
        setup.session,
        DiaryEntry(
          id: generateEntryId(),
          vaultId: setup.session.vaultId,
          title: '純文字',
          date: const DateOnly('2026-08-02'),
          createdAt: DateTime(2026, 8, 2, 10),
          updatedAt: DateTime(2026, 8, 2, 10),
          markdownBody: '文',
        ),
      );

      final PortableExportIo exportIo = PortableExportIo(
        pathStrategy: harness.pathStrategy,
        repository: harness.repository,
        frontMatterCodec: const FrontMatterCodec(),
      );
      final HtmlExportEstimate estimate = await exportIo
          .estimateSelectedHtmlExport(
            entryIds: <String>{withImage.id, plain.id},
          );

      expect(estimate.entryCount, 2);
      expect(estimate.imageCount, 1);
      expect(
        estimate.entries.map((HtmlExportEntrySummary e) => e.title).toSet(),
        <String>{'有圖', '純文字'},
      );

      final HtmlExportEstimate selected = estimate.forSelected(<String>{
        plain.id,
      });
      expect(selected.entryCount, 1);
      expect(selected.imageCount, 0);
      expect(selected.entries.single.title, '純文字');
    });
  });
}
