import 'dart:io';

import 'package:quill_diary/infrastructure/database/index_database_manager.dart';
import 'package:quill_diary/infrastructure/markdown/front_matter_codec.dart';
import 'package:quill_diary/infrastructure/storage/vault_archive_io.dart';

import 'vault_test_harness.dart';

class VaultArchiveIoTestHarness {
  VaultArchiveIoTestHarness._(this.harness, this.archiveIo);

  final VaultTestHarness harness;
  final VaultArchiveIo archiveIo;

  static Future<VaultArchiveIoTestHarness> create() async {
    final VaultTestHarness harness = await VaultTestHarness.create();
    final VaultArchiveIo archiveIo = VaultArchiveIo(
      pathStrategy: harness.pathStrategy,
      repository: harness.repository,
      frontMatterCodec: const FrontMatterCodec(),
      indexDatabaseManager: IndexDatabaseManager(harness.pathStrategy),
    );
    return VaultArchiveIoTestHarness._(harness, archiveIo);
  }

  Future<void> dispose() async {
    await harness.dispose();
  }

  Directory get tempDir => harness.tempDir;
}
