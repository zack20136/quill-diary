import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quill_diary/domain/diary/diary_entry.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/storage/tag_styles_store.dart';
import 'package:quill_diary/infrastructure/storage/vault_archive_io.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';

import '../helpers/vault_test_harness.dart';

void main() {
  late VaultTestHarness harness;
  late VaultArchiveIo archiveIo;

  setUp(() async {
    harness = await VaultTestHarness.create();
    archiveIo = harness.createArchiveIo();
  });

  tearDown(() async {
    await harness.dispose();
  });

  test('還原備份後保留 tag_styles.json 與索引內顏色', () async {
    final RecoverySetupResult setup = await harness.repository
        .setupRecoveryKey();
    const int workColor = 0xFF4C6EF5;
    await harness.repository.upsertTagAccentArgb('Work', workColor);

    await harness.repository.saveEntry(
      setup.session,
      DiaryEntry(
        id: generateEntryId(),
        vaultId: setup.session.vaultId,
        title: 'Tagged',
        date: const DateOnly('2026-05-30'),
        createdAt: DateTime.parse('2026-05-30T08:00:00Z'),
        updatedAt: DateTime.parse('2026-05-30T08:00:00Z'),
        markdownBody: 'body',
        tags: const <String>['Work'],
      ),
    );

    final File backupFile = File(p.join(harness.tempDir.path, 'tag_color.zip'));
    await archiveIo.writeBackupZip(backupFile);

    await harness.repository.upsertTagAccentArgb('Noise', 0xFFFF0000);

    await harness.repository.closeUnlockedResources();
    await archiveIo.restoreBackupZip(backupFile);

    final List<TagCatalogItem> vaultStyles = await TagStylesStore(
      harness.pathStrategy,
    ).read();
    expect(
      TagStylesStore.toAccentMap(vaultStyles)[normalizeText('Work')],
      workColor,
    );

    final UnlockedVaultSession session = await harness.repository
        .unlockWithRecoveryKey(setup.recoveryKey);
    await harness.repository.rebuildIndex(session);

    final Map<String, int> indexStyles = TagStylesStore.toAccentMap(
      await harness.repository.listTagCatalog(),
    );
    expect(indexStyles[normalizeText('Work')], workColor);
  });
}
