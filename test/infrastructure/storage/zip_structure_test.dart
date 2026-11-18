import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/infrastructure/storage/shared/archive_extract.dart';

import '../../helpers/storage/zip_record_fixture.dart';

void main() {
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('quill_zip_structure_');
  });
  tearDown(() async {
    await root.delete(recursive: true);
  });
  Future<OpenedZipArchive> open(
    List<int> bytes, {
    ArchiveExtractionBudget budget = ArchiveExtractionBudget.standard,
  }) async {
    final file = File('${root.path}/source.zip');
    await file.writeAsBytes(bytes);
    return openZipArchive(file, budget: budget);
  }

  for (final zip64 in [false, true]) {
    for (final signature in [false, true]) {
      test(
        '合法 ${zip64 ? 'ZIP64' : 'ZIP32'} Bit 3 描述子${signature ? '有' : '無'}簽章可解壓',
        () async {
          final archive = await open(
            zipRecordFixture(
              ['目錄/image.enc'],
              zip64: zip64,
              descriptor: true,
              descriptorSignature: signature,
            ),
          );
          try {
            await extractArchiveToDirectory(
              zip: archive,
              targetDirectory: Directory('${root.path}/output'),
            );
            expect(
              await File('${root.path}/output/目錄/image.enc').readAsBytes(),
              [1, 2, 3],
            );
          } finally {
            await archive.close();
          }
        },
      );
    }
  }
  test('合法 ZIP64 無描述子可讀且歷史 ZIP 不受影響', () async {
    final archive = await open(zipRecordFixture(['image.enc'], zip64: true));
    expect(archive.archive.files.single.readBytes(), [1, 2, 3]);
    await archive.close();
    for (final iteration in [2, 3]) {
      final legacy = await openZipArchive(
        File('test/fixtures/security/iterations_$iteration.zip'),
      );
      expect(legacy.archive.files, isNotEmpty);
      await legacy.close();
    }
  });
  for (final names in [
    ['a', 'a'],
    ['a/b', 'a\\b'],
    ['A', 'a'],
    ['a', 'a/b'],
    ['folder/../escape'],
    ['/absolute'],
    ['C:/escape'],
  ]) {
    test('原始記錄拒絕不安全或衝突路徑 $names', () async {
      await expectLater(open(zipRecordFixture(names)), throwsFormatException);
    });
  }
  test('Unicode 額外路徑不能繞過重複與穿越檢查', () async {
    await expectLater(
      open(zipRecordFixture(['first', 'second'], unicodePath: 'same')),
      throwsFormatException,
    );
    await expectLater(
      open(zipRecordFixture(['safe'], unicodePath: '../escape')),
      throwsFormatException,
    );
    final archive = await open(zipRecordFixture(['legacy'], unicodePath: '中文'));
    expect(archive.archive.files.single.name, '中文');
    await archive.close();
  });
  test('非 UTF-8 的歷史 CP437 檔名與解碼器一致', () async {
    final bytes = zipRecordFixture(['x']);
    final data = ByteData.sublistView(bytes);
    final directory = data.getUint32(bytes.length - 6, Endian.little);
    data.setUint16(6, 0, Endian.little);
    data.setUint16(directory + 8, 0, Endian.little);
    bytes[30] = 0x82;
    bytes[directory + 46] = 0x82;
    final archive = await open(bytes);
    expect(archive.archive.files.single.name, 'é');
    await archive.close();
  });
  test('Local Header 與中央記錄不一致或區段重疊時拒絕', () async {
    final bytes = zipRecordFixture(['first', 'second']);
    final data = ByteData.sublistView(bytes);
    data.setUint16(6, 1, Endian.little);
    await expectLater(open(bytes), throwsFormatException);
    final overlap = zipRecordFixture(['first', 'second']);
    final view = ByteData.sublistView(overlap);
    final directory = view.getUint32(overlap.length - 6, Endian.little);
    view.setUint32(directory + 46 + 'first'.length + 42, 0, Endian.little);
    await expectLater(open(overlap), throwsFormatException);
  });
  test('截斷、尾隨資料、錯誤描述子及連結不會被接受', () async {
    final original = zipRecordFixture(['entry']);
    for (final length in [0, 3, 29, original.length - 1]) {
      await expectLater(
        open(original.sublist(0, length)),
        throwsFormatException,
      );
    }
    await expectLater(open([...original, 0]), throwsFormatException);
    final descriptor = zipRecordFixture(['entry'], descriptor: true);
    descriptor[30 + 'entry'.length + 3 + 4] ^= 1;
    await expectLater(open(descriptor), throwsFormatException);
    final link = zipRecordFixture(['link']);
    final data = ByteData.sublistView(link);
    final directory = data.getUint32(link.length - 6, Endian.little);
    data.setUint32(directory + 38, 0xa1ff0000, Endian.little);
    await expectLater(open(link), throwsFormatException);
  });
  test('資源限制在合併項目前執行且 CRC 損壞解壓失敗', () async {
    await expectLater(
      open(
        zipRecordFixture(['one', 'two']),
        budget: const ArchiveExtractionBudget(maxEntries: 1),
      ),
      throwsA(isA<ArchiveExtractionLimitException>()),
    );
    await expectLater(
      open(
        zipRecordFixture(['one']),
        budget: const ArchiveExtractionBudget(maxEntryBytes: 2),
      ),
      throwsA(isA<ArchiveExtractionLimitException>()),
    );
    final corrupt = zipRecordFixture(['entry']);
    corrupt[30 + 'entry'.length] ^= 1;
    final archive = await open(corrupt);
    try {
      await expectLater(
        extractArchiveToDirectory(
          zip: archive,
          targetDirectory: Directory('${root.path}/output'),
        ),
        throwsA(isA<Exception>()),
      );
    } finally {
      await archive.close();
    }
  });
  test('註解內的第二個結束記錄不能讓解碼器改讀另一份 ZIP', () async {
    final original = zipRecordFixture(['entry']);
    ByteData.sublistView(original)
        .setUint16(original.length - 2, 22, Endian.little);
    final alternateEnd = Uint8List(22);
    ByteData.sublistView(alternateEnd).setUint32(0, 0x06054b50, Endian.little);
    await expectLater(
      open([...original, ...alternateEnd]),
      throwsFormatException,
    );
  });
  test('ZIP metadata 上限包含本機標頭與中央目錄的總和', () async {
    final bytes = zipRecordFixture(['one', 'two']);
    final metadataBytes = bytes.length - 6;
    await expectLater(
      open(
        bytes,
        budget: ArchiveExtractionBudget(maxMetadataBytes: metadataBytes - 1),
      ),
      throwsA(isA<ArchiveExtractionLimitException>()),
    );
    final archive = await open(
      bytes,
      budget: ArchiveExtractionBudget(maxMetadataBytes: metadataBytes),
    );
    await archive.close();
  });
  test('壓縮內容大於宣告時預覽與解壓都受實際輸出限制', () async {
    final bytes = zipRecordFixture(
      ['recovery.json'],
      payload: List.filled(100000, 65),
      deflate: true,
      declaredSize: 16,
    );
    final preview = await open(bytes);
    try {
      expect(
        () => readZipEntry(preview.archive, relativePath: 'recovery.json'),
        throwsA(isA<Exception>()),
      );
    } finally {
      await preview.close();
    }
    final archive = await open(bytes);
    try {
      await expectLater(
        extractArchiveToDirectory(
          zip: archive,
          targetDirectory: Directory('${root.path}/output'),
        ),
        throwsA(isA<Exception>()),
      );
      final output = File('${root.path}/output/recovery.json');
      expect(
        output.existsSync() ? output.lengthSync() : 0,
        lessThanOrEqualTo(16),
      );
    } finally {
      await archive.close();
    }
  });
}
