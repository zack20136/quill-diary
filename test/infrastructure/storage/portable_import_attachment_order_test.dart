import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quill_diary/domain/attachment/asset_attachment.dart';
import 'package:quill_diary/infrastructure/markdown/front_matter_codec.dart';
import 'package:quill_diary/infrastructure/storage/import/easy_diary/easy_diary_backup_import.dart';
import 'package:quill_diary/infrastructure/storage/portable/portable_import_io.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';

import '../../helpers/vault/vault_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late VaultTestHarness harness;
  late RecoverySetupResult setup;
  late Directory importRoot;

  setUp(() async {
    harness = await VaultTestHarness.create();
    setup = await harness.repository.setupRecoveryKey();
    importRoot = await Directory.systemTemp.createTemp('qld_import_order_');
  });

  tearDown(() async {
    await harness.dispose();
    if (importRoot.existsSync()) {
      await importRoot.delete(recursive: true);
    }
  });

  test('Markdown 匯入維持附件出現順序', () async {
    await _writeImportImages(importRoot);
    await File(p.join(importRoot.path, 'entry.md')).writeAsString('''
# Markdown 日記

![第二張](second.png)
![第一張](first.png)
''');

    await _portableImporter(
      harness,
    ).importDocuments(session: setup.session, rootDirectory: importRoot);

    expect(await _importedAttachmentNames(harness), <String>[
      'second.png',
      'first.png',
    ]);
  });

  test('HTML 匯入維持附件出現順序', () async {
    await _writeImportImages(importRoot);
    await File(p.join(importRoot.path, 'entry.html')).writeAsString('''
<!doctype html>
<html><body>
  <article class="entry">
    <h2>HTML 日記</h2>
    <section class="entry-body"><p>內容</p></section>
    <section class="embedded-images">
      <img src="second.png">
      <img src="first.png">
    </section>
  </article>
</body></html>
''');

    await _portableImporter(
      harness,
    ).importDocuments(session: setup.session, rootDirectory: importRoot);

    expect(await _importedAttachmentNames(harness), <String>[
      'second.png',
      'first.png',
    ]);
  });

  test('Easy Diary 匯入維持相片陣列順序', () async {
    final Directory databaseDirectory = Directory(
      p.join(importRoot.path, 'Backup', 'Database'),
    )..createSync(recursive: true);
    final Directory photosDirectory = Directory(
      p.join(importRoot.path, 'Photos'),
    )..createSync(recursive: true);
    File(p.join(importRoot.path, 'preference.json')).writeAsStringSync('{}');
    File(
      p.join(databaseDirectory.path, 'diary.realm'),
    ).writeAsBytesSync(<int>[1]);
    await _writeImage(File(p.join(photosDirectory.path, 'second')));
    await _writeImage(File(p.join(photosDirectory.path, 'first')));

    const MethodChannel channel = MethodChannel('test.easy_diary.order');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          expect(call.method, 'readDiaryBackup');
          return <String, Object?>{
            'entries': <Object?>[
              <String, Object?>{
                'title': 'Easy Diary 日記',
                'contents': '內容',
                'dateString': '2026-08-18',
                'currentTimeMillis': 1787011200000,
                'isEncrypt': false,
                'photos': <Object?>[
                  <String, Object?>{
                    'photoKey': 'second',
                    'mimeType': 'image/png',
                  },
                  <String, Object?>{
                    'photoKey': 'first',
                    'mimeType': 'image/png',
                  },
                ],
              },
            ],
          };
        });

    try {
      await EasyDiaryBackupImporter(
        realmChannel: channel,
      ).tryImportFromExtractedRoot(
        session: setup.session,
        repository: harness.repository,
        extractedRoot: importRoot,
      );
    } finally {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    }

    expect(await _importedAttachmentNames(harness), <String>[
      'second.png',
      'first.png',
    ]);
  });
}

PortableImportIo _portableImporter(VaultTestHarness harness) {
  return PortableImportIo(
    pathStrategy: harness.pathStrategy,
    repository: harness.repository,
    frontMatterCodec: const FrontMatterCodec(),
  );
}

Future<void> _writeImportImages(Directory directory) async {
  await _writeImage(File(p.join(directory.path, 'second.png')));
  await _writeImage(File(p.join(directory.path, 'first.png')));
}

Future<void> _writeImage(File file) async {
  // 1×1 透明 PNG（Easy Diary 匯入會驗證可解碼）
  await file.writeAsBytes(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
    ),
  );
}

Future<List<String>> _importedAttachmentNames(VaultTestHarness harness) async {
  final entries = await harness.repository.listEntries();
  final List<AssetAttachment> attachments = await harness.repository
      .loadAttachments(entries.single.id);
  return attachments
      .map(
        (AssetAttachment attachment) =>
            attachment.originalFilename ?? attachment.safeFilename,
      )
      .toList();
}
