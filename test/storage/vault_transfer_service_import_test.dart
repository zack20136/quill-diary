import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quill_diary/domain/diary/diary_entry.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/features/settings/portable_import_result_messages.dart';
import 'package:quill_diary/infrastructure/storage/external_directory_store.dart';
import 'package:quill_diary/infrastructure/storage/vault_archive_io.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';
import 'package:quill_diary/infrastructure/storage/vault_transfer_service.dart';

import '../helpers/path_provider_test_binding.dart';
import '../helpers/test_l10n.dart';
import '../helpers/vault_test_harness.dart';
import '../helpers/vault_transfer_service_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late VaultTestHarness harness;
  late VaultArchiveIo archiveIo;

  setUp(() async {
    harness = await VaultTestHarness.create();
    archiveIo = harness.createArchiveIo();
    installPathProviderTestBinding(harness.tempDir);
  });

  tearDown(() async {
    clearPathProviderTestBinding();
    await harness.dispose();
  });

  VaultTransferService buildTransferService(
    FilePickerResult? pickedResult, {
    ReadPlatformFileBytes? readPlatformFileBytes,
  }) {
    return VaultTransferService(
      archiveIo: archiveIo,
      driveBackupService: const UnusedDriveBackupService(),
      vaultRepository: harness.repository,
      externalDirectoryStore: ExternalDirectoryStore(harness.pathStrategy),
      pathStrategy: harness.pathStrategy,
      readPlatformFileBytes: readPlatformFileBytes,
      pickPortableFiles: ({
        required String dialogTitle,
        required List<String> allowedExtensions,
      }) async => pickedResult,
    );
  }

  test('bytes-only html pick can import app exported html with attachments', () async {
    final setup = await harness.repository.setupRecoveryKey();
    final Directory sourceDirectory = Directory(
      p.join(harness.tempDir.path, 'picker_html_source'),
    )..createSync(recursive: true);
    final File sourceImage = File(p.join(sourceDirectory.path, 'cover.png'))
      ..writeAsBytesSync(const <int>[1, 2, 3, 4, 5]);

    final String entryId = generateEntryId();
    await harness.repository.saveEntry(
      setup.session,
      DiaryEntry(
        id: entryId,
        vaultId: setup.session.vaultId,
        title: 'HTML Picker Roundtrip',
        date: const DateOnly('2026-05-28'),
        createdAt: DateTime.parse('2026-05-28T08:00:00Z'),
        updatedAt: DateTime.parse('2026-05-28T09:00:00Z'),
        tags: const <String>['分享', 'HTML'],
        markdownBody: '# Heading\n\nHello **world**\n\n- item',
      ),
      pendingAttachments: <PendingAttachment>[
        PendingAttachment(
          sourcePath: sourceImage.path,
          mimeType: 'image/png',
          originalFilename: 'cover.png',
        ),
      ],
    );

    final File exported = File(
      p.join(harness.tempDir.path, 'picker_roundtrip.html'),
    );
    await archiveIo.writeSelectedHtmlExport(
      session: setup.session,
      entryIds: <String>{entryId},
      target: exported,
    );
    final bytes = await exported.readAsBytes();

    final VaultTransferService transferService = buildTransferService(
      FilePickerResult(<PlatformFile>[
        PlatformFile(
          path: null,
          name: 'html_2026-05-28_08-00-00.html',
          size: bytes.length,
        ),
      ]),
      readPlatformFileBytes: (PlatformFile file) async =>
          file.name.endsWith('.html') ? bytes : null,
    );

    final PortableImportResult? result = await transferService
        .importDocumentsWithPicker(setup.session, l10n: testZhL10n);

    expect(result, isNotNull);
    expect(result!.importedEntries, 1);

    final entries = await harness.repository.listEntries();
    expect(entries, hasLength(2));

    final importedRecord = entries.firstWhere((record) => record.id != entryId);
    final DiaryEntry? imported = await harness.repository.loadEntry(
      setup.session,
      importedRecord.id,
    );
    final attachments = await harness.repository.loadAttachments(
      importedRecord.id,
    );

    expect(imported?.title, 'HTML Picker Roundtrip');
    expect(imported?.date.value, '2026-05-28');
    expect(imported?.tags, const <String>['分享', 'HTML']);
    expect(imported?.markdownBody, contains('# Heading'));
    expect(imported?.markdownBody, contains('Hello **world**'));
    expect(imported?.markdownBody, contains('- item'));
    expect(attachments, hasLength(1));
    expect(attachments.single.mimeType, 'image/png');
  });

  test('bytes-only zip pick can import portable markdown exports', () async {
    final setup = await harness.repository.setupRecoveryKey();
    await harness.repository.saveEntry(
      setup.session,
      DiaryEntry(
        id: generateEntryId(),
        vaultId: setup.session.vaultId,
        title: 'Zip Picker Import',
        date: const DateOnly('2026-05-23'),
        createdAt: DateTime.parse('2026-05-23T08:00:00Z'),
        updatedAt: DateTime.parse('2026-05-23T08:00:00Z'),
        markdownBody: 'Imported from picked zip.',
      ),
    );

    final File zipFile = File(p.join(harness.tempDir.path, 'portable_import.zip'));
    await archiveIo.writeMarkdownZip(session: setup.session, target: zipFile);
    final bytes = await zipFile.readAsBytes();

    final VaultTransferService transferService = buildTransferService(
      FilePickerResult(<PlatformFile>[
        PlatformFile(
          path: null,
          name: 'portable_import.zip',
          size: bytes.length,
        ),
      ]),
      readPlatformFileBytes: (PlatformFile file) async =>
          file.name.endsWith('.zip') ? bytes : null,
    );

    final PortableImportResult? result = await transferService
        .importDocumentsWithPicker(setup.session, l10n: testZhL10n);

    expect(result, isNotNull);
    expect(result!.importedEntries, 1);

    final entries = await harness.repository.listEntries();
    expect(entries, hasLength(2));
    expect(
      entries.map((record) => record.title).whereType<String>(),
      contains('Zip Picker Import'),
    );
  });

  test('unreadable picked files return a dedicated failure code', () async {
    final setup = await harness.repository.setupRecoveryKey();
    final VaultTransferService transferService = buildTransferService(
      FilePickerResult(<PlatformFile>[
        PlatformFile(path: null, name: 'broken.html', size: 12),
      ]),
    );

    final PortableImportResult? result = await transferService
        .importDocumentsWithPicker(setup.session, l10n: testZhL10n);

    expect(result, isNotNull);
    expect(result!.importedEntries, 0);
    expect(result.failureCode, PortableImportFailureCode.selectedFilesUnreadable);
    expect(
      result.messageWhenNoEntriesImported(testZhL10n),
      '所選檔案無法讀取，請改用本機檔案或重新選取。',
    );
  });
}
