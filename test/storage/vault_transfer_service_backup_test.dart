import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quill_diary/domain/diary/diary_entry.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/storage/backup_task_progress.dart';
import 'package:quill_diary/infrastructure/storage/external_directory_store.dart';
import 'package:quill_diary/infrastructure/storage/vault_archive_io.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';
import 'package:quill_diary/infrastructure/storage/vault_transfer_service.dart';

import '../helpers/path_provider_test_binding.dart';
import '../helpers/vault_test_harness.dart';
import '../helpers/vault_transfer_service_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late VaultTestHarness harness;
  late VaultTransferService transferService;

  setUp(() async {
    harness = await VaultTestHarness.create();
    installPathProviderTestBinding(harness.tempDir);
    final VaultArchiveIo archiveIo = harness.createArchiveIo();
    transferService = VaultTransferService(
      archiveIo: archiveIo,
      driveBackupService: const UnusedDriveBackupService(),
      vaultRepository: harness.repository,
      externalDirectoryStore: ExternalDirectoryStore(harness.pathStrategy),
      pathStrategy: harness.pathStrategy,
    );
  });

  tearDown(() async {
    clearPathProviderTestBinding();
    await harness.dispose();
  });

  Future<void> seedVaultForBackup() async {
    final RecoverySetupResult setup = await harness.repository
        .setupRecoveryKey();
    await harness.repository.saveEntry(
      setup.session,
      DiaryEntry(
        id: generateEntryId(),
        vaultId: setup.session.vaultId,
        title: 'Pipeline Backup',
        date: const DateOnly('2026-06-03'),
        createdAt: DateTime.parse('2026-06-03T08:00:00Z'),
        updatedAt: DateTime.parse('2026-06-03T08:00:00Z'),
        markdownBody: 'pipeline backup body',
      ),
    );
  }

  test(
    'runInspectedBackupPipelineForTesting succeeds when deliver returns path',
    () async {
      await seedVaultForBackup();
      final Directory deliverDirectory = Directory(
        p.join(harness.tempDir.path, 'deliver'),
      );
      await deliverDirectory.create(recursive: true);

      final BackupPersistResult result = await transferService
          .runInspectedBackupPipelineForTesting(
            deliver:
                (
                  File stagingZip,
                  String fileName,
                  BackupTaskProgressListener? deliverProgress,
                ) async {
                  final String destinationPath = p.join(
                    deliverDirectory.path,
                    fileName,
                  );
                  await stagingZip.copy(destinationPath);
                  return destinationPath;
                },
          );

      expect(result.status, BackupPersistStatus.success);
      expect(result.savedPath, isNotNull);
      expect(File(result.savedPath!).existsSync(), isTrue);
      expect(result.message, isNotEmpty);
    },
  );

  test(
    'runInspectedBackupPipelineForTesting returns cancelled when deliver returns null',
    () async {
      await seedVaultForBackup();

      final BackupPersistResult result = await transferService
          .runInspectedBackupPipelineForTesting(
            deliver:
                (
                  File stagingZip,
                  String fileName,
                  BackupTaskProgressListener? deliverProgress,
                ) async => null,
          );

      expect(result.status, BackupPersistStatus.cancelled);
      expect(result.savedPath, isNull);
    },
  );

  test(
    'runInspectedBackupPipelineForTesting returns inspectFailed when inspect fails',
    () async {
      await seedVaultForBackup();
      final InspectFailingTransferService failingService =
          InspectFailingTransferService(
            archiveIo: harness.createArchiveIo(),
            vaultRepository: harness.repository,
            externalDirectoryStore: ExternalDirectoryStore(
              harness.pathStrategy,
            ),
            pathStrategy: harness.pathStrategy,
          );
      var deliverCalls = 0;

      final BackupPersistResult result = await failingService
          .runInspectedBackupPipelineForTesting(
            deliver:
                (
                  File stagingZip,
                  String fileName,
                  BackupTaskProgressListener? deliverProgress,
                ) async {
                  deliverCalls++;
                  return p.join(harness.tempDir.path, fileName);
                },
          );

      expect(result.status, BackupPersistStatus.inspectFailed);
      expect(result.savedPath, isNull);
      expect(deliverCalls, 0);
    },
  );
}
