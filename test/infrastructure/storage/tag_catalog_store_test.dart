import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/application/tag/tag_defaults.dart';
import 'package:quill_diary/domain/recovery/recovery_key_identity.dart';
import 'package:quill_diary/domain/tag/tag.dart';
import 'package:quill_diary/infrastructure/crypto/crypto_service.dart';
import 'package:quill_diary/infrastructure/storage/shared/archive_extract.dart';
import 'package:quill_diary/infrastructure/storage/shared/vault_file_ops.dart';
import 'package:quill_diary/infrastructure/storage/tag_catalog_store.dart';
import 'package:quill_diary/l10n/l10n.dart';

import '../../helpers/vault/vault_test_harness.dart';

void main() {
  test('加密暫存無法寫入時保留明文，排除阻擋後可重試', () async {
    final harness = await VaultTestHarness.create();
    addTearDown(harness.dispose);
    await harness.repository.setupRecoveryKey();
    final legacy = File(await harness.pathStrategy.legacyTagCatalogPath());
    await legacy.writeAsString('[{"label":"保留標籤"}]');
    final obstruction = Directory(
      '${await harness.pathStrategy.tagCatalogPath()}.tmp',
    );
    await obstruction.create();
    await expectLater(
      harness.repository.listTagCatalog(),
      throwsA(isA<TagCatalogException>()),
    );
    expect(legacy.existsSync(), isTrue);
    await obstruction.delete();
    await harness.repository.retryTagCatalog();
    expect((await harness.repository.listTagCatalog()).single.label, '保留標籤');
  });

  test('修復前保全加密封裝損壞明文且不覆寫原加密標籤', () async {
    final harness = await VaultTestHarness.create();
    addTearDown(harness.dispose);
    final setup = await harness.repository.setupRecoveryKey();
    await harness.repository.upsertTagCatalogItem('原加密標籤');
    final encrypted = File(await harness.pathStrategy.tagCatalogPath());
    final originalEncrypted = await encrypted.readAsBytes();
    final legacy = File(await harness.pathStrategy.legacyTagCatalogPath());
    await legacy.writeAsString('{損壞原始內容');
    final zip = File('${harness.tempDir.path}/preservation.zip');
    final backup = harness.createTransferIo().backup;
    await expectLater(
      backup.writeBackupZip(zip),
      throwsA(isA<TagCatalogException>()),
    );
    await backup.writeBackupZip(zip, purpose: VaultBackupPurpose.preservation);
    final archive = await openZipArchive(zip);
    try {
      expect(archive.archive.findFile('tag_styles.json'), isNull);
      expect(
        archive.archive.findFile('tag_styles.json.enc')!.readBytes(),
        originalEncrypted,
      );
      final preserved = archive.archive.files.singleWhere(
        (entry) => entry.name.startsWith('preservation/'),
      );
      final crypto = LocalCryptoService();
      final parsed = crypto.parseFileBytes(preserved.readBytes()!);
      expect(
        utf8.decode(
          await crypto.decryptBytes(
            headerBytes: parsed.headerBytes,
            ciphertextBytes: parsed.ciphertextBytes,
            context: vaultDecryptionContext(setup.session),
          ),
        ),
        '{損壞原始內容',
      );
    } finally {
      await archive.close();
    }
    expect(legacy.existsSync(), isTrue);
  });
  test('已有標籤時不建立預設目錄也不修改既有顏色', () async {
    final VaultTestHarness harness = await VaultTestHarness.create();
    addTearDown(harness.dispose);
    await harness.repository.setupRecoveryKey();
    await harness.repository.upsertTagCatalogItem(
      '既有標籤',
      accentArgb: 0xFF123456,
      accentIsCustom: true,
    );

    final bool seeded = await harness.repository.seedDefaultTagCatalogIfEmpty(
      defaultTagCatalogForLocale(appZhLocale),
    );

    expect(seeded, isFalse);
    final TagCatalogItem existing =
        (await harness.repository.listTagCatalog()).single;
    expect(existing.label, '既有標籤');
    expect(existing.accentArgb, 0xFF123456);
    expect(existing.accentIsCustom, isTrue);
  });

  test('舊明文加密並核對後才移除且保留標籤樣式', () async {
    final harness = await VaultTestHarness.create();
    addTearDown(harness.dispose);
    final setup = await harness.repository.setupRecoveryKey();
    final original = utf8.encode(
      '[{"label":"舊標籤","accent_argb":4279312947,"accent_is_custom":true}]',
    );
    final legacy = File(await harness.pathStrategy.legacyTagCatalogPath());
    await legacy.writeAsBytes(original);
    await File('${legacy.path}.previous').writeAsString('[{"label":"舊副本"}]');
    await File('${legacy.path}.tmp').writeAsString('{');
    final items = await harness.repository.listTagCatalog();
    expect(items.single.accentArgb, 4279312947);
    expect(legacy.existsSync(), isFalse);
    final encrypted = File(await harness.pathStrategy.tagCatalogPath());
    final crypto = LocalCryptoService();
    final parsed = crypto.parseFileBytes(await encrypted.readAsBytes());
    expect(
      await crypto.decryptBytes(
        headerBytes: parsed.headerBytes,
        ciphertextBytes: parsed.ciphertextBytes,
        context: vaultDecryptionContext(setup.session),
      ),
      original,
    );
    expect(File('${legacy.path}.tmp').existsSync(), isFalse);
    expect(File('${legacy.path}.previous').existsSync(), isFalse);
  });

  test('標籤目錄損壞保留原檔並停止目錄寫入但正文仍可儲存', () async {
    final harness = await VaultTestHarness.create();
    addTearDown(harness.dispose);
    final setup = await harness.repository.setupRecoveryKey();
    final file = File(await harness.pathStrategy.legacyTagCatalogPath());
    await file.writeAsString('{');
    await expectLater(
      harness.repository.listTagCatalog(),
      throwsA(isA<TagCatalogException>()),
    );
    await expectLater(
      harness.repository.seedDefaultTagCatalogIfEmpty(
        defaultTagCatalogForLocale(appZhLocale),
      ),
      throwsA(isA<TagCatalogException>()),
    );
    await harness.saveSimpleEntry(setup, tags: ['正文標籤']);
    expect(await harness.repository.listEntries(), hasLength(1));
    expect(await file.readAsString(), '{');
    expect(harness.repository.tagCatalogNeedsRetry.value, isTrue);
    await harness.saveSimpleEntry(setup);
    expect(harness.repository.tagCatalogNeedsRetry.value, isTrue);
    await file.writeAsString('[{"label":"重試標籤"}]');
    await harness.repository.retryTagCatalog();
    expect(harness.repository.tagCatalogNeedsRetry.value, isFalse);
    expect((await harness.repository.listTagCatalog()).single.label, '重試標籤');
  });

  test('明文與加密副本衝突保留兩份且不覆寫', () async {
    final harness = await VaultTestHarness.create();
    addTearDown(harness.dispose);
    await harness.repository.setupRecoveryKey();
    await harness.repository.upsertTagCatalogItem('加密標籤');
    final encrypted = File(await harness.pathStrategy.tagCatalogPath());
    final before = await encrypted.readAsBytes();
    final previous = File('${encrypted.path}.previous');
    await previous.writeAsBytes(before);
    final legacy = File(await harness.pathStrategy.legacyTagCatalogPath());
    await legacy.writeAsString('[{"label":"衝突標籤"}]');
    await expectLater(
      harness.repository.listTagCatalog(),
      throwsA(isA<TagCatalogException>()),
    );
    expect(await encrypted.readAsBytes(), before);
    expect(await previous.readAsBytes(), before);
    expect(legacy.existsSync(), isTrue);
  });

  test('中斷留下的加密暫存可恢復再核對舊明文', () async {
    final harness = await VaultTestHarness.create();
    addTearDown(harness.dispose);
    final setup = await harness.repository.setupRecoveryKey();
    await harness.repository.upsertTagCatalogItem('暫存標籤');
    final encrypted = File(await harness.pathStrategy.tagCatalogPath());
    final crypto = LocalCryptoService();
    final parsed = crypto.parseFileBytes(await encrypted.readAsBytes());
    final bytes = await crypto.decryptBytes(
      headerBytes: parsed.headerBytes,
      ciphertextBytes: parsed.ciphertextBytes,
      context: vaultDecryptionContext(setup.session),
    );
    final legacy = File(await harness.pathStrategy.legacyTagCatalogPath());
    await legacy.writeAsBytes(bytes);
    await encrypted.rename('${encrypted.path}.tmp');
    await harness.repository.retryTagCatalog();
    expect(encrypted.existsSync(), isTrue);
    expect(legacy.existsSync(), isFalse);
    expect(File('${encrypted.path}.tmp').existsSync(), isFalse);
  });
}
