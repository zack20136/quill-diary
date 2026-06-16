import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quill_diary/domain/diary/diary_entry.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/database/index_database.dart';
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

  test(
    'restoreBackupZip preserveTrusted 保留受信任裝置並可 openTrustedSession',
    () async {
      final RecoverySetupResult setup = await harness.repository
          .setupRecoveryKey();
      await harness.repository.saveEntry(
        setup.session,
        DiaryEntry(
          id: generateEntryId(),
          vaultId: setup.session.vaultId,
          title: 'Trusted Restore',
          date: const DateOnly('2026-05-28'),
          createdAt: DateTime.parse('2026-05-28T09:00:00Z'),
          updatedAt: DateTime.parse('2026-05-28T09:00:00Z'),
          markdownBody: 'trusted restore body',
        ),
      );

      expect(await harness.repository.hasTrustedDeviceAccess(), isTrue);

      final File backupFile = File(p.join(harness.tempDir.path, 'trusted.zip'));
      await archiveIo.writeBackupZip(backupFile);

      await harness.repository.saveEntry(
        setup.session,
        DiaryEntry(
          id: generateEntryId(),
          vaultId: setup.session.vaultId,
          title: 'Noise After Backup',
          date: const DateOnly('2026-05-29'),
          createdAt: DateTime.parse('2026-05-29T10:00:00Z'),
          updatedAt: DateTime.parse('2026-05-29T10:00:00Z'),
          markdownBody: 'noise',
        ),
      );

      await harness.repository.closeUnlockedResources();
      await archiveIo.restoreBackupZip(
        backupFile,
        preserveTrustedDeviceAccess: true,
      );

      expect(await harness.repository.hasTrustedDeviceAccess(), isTrue);

      final UnlockedVaultSession session = await harness.repository
          .openTrustedSession();
      expect(session.vaultId, setup.session.vaultId);
      await harness.repository.rebuildIndex(session);
      final List<EntryIndexRecord> entries = await harness.repository
          .listEntries();
      expect(entries, hasLength(1));
      expect(entries.single.title, 'Trusted Restore');
    },
  );

  test(
    'resumeUnlockedSessionAfterRestore 沿用 prior wrap key 且不經 keystore 解包',
    () async {
      final RecoverySetupResult setup = await harness.repository
          .setupRecoveryKey();
      await harness.repository.saveEntry(
        setup.session,
        DiaryEntry(
          id: generateEntryId(),
          vaultId: setup.session.vaultId,
          title: 'Resume Restore',
          date: const DateOnly('2026-05-28'),
          createdAt: DateTime.parse('2026-05-28T09:00:00Z'),
          updatedAt: DateTime.parse('2026-05-28T09:00:00Z'),
          markdownBody: 'resume restore body',
        ),
      );

      final File backupFile = File(p.join(harness.tempDir.path, 'resume.zip'));
      await archiveIo.writeBackupZip(backupFile);

      await harness.repository.closeUnlockedResources();
      await archiveIo.restoreBackupZip(
        backupFile,
        preserveTrustedDeviceAccess: true,
      );

      final UnlockedVaultSession session = await harness.repository
          .resumeUnlockedSessionAfterRestore(setup.session);
      expect(session.vaultId, setup.session.vaultId);
      await harness.repository.rebuildIndex(session);
      final List<EntryIndexRecord> entries = await harness.repository
          .listEntries();
      expect(entries, hasLength(1));
      expect(entries.single.title, 'Resume Restore');
    },
  );

  test('restoreBackupZip 預設會清除受信任裝置', () async {
    await harness.repository.setupRecoveryKey();
    final File backupFile = File(
      p.join(harness.tempDir.path, 'clear_trusted.zip'),
    );
    await archiveIo.writeBackupZip(backupFile);

    await harness.repository.closeUnlockedResources();
    await archiveIo.restoreBackupZip(backupFile);

    expect(await harness.repository.hasTrustedDeviceAccess(), isFalse);
  });
}
