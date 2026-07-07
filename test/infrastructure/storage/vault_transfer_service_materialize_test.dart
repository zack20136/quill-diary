import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/infrastructure/crypto/crypto_service.dart';
import 'package:quill_diary/infrastructure/database/index_database_manager.dart';
import 'package:quill_diary/infrastructure/markdown/front_matter_codec.dart';
import 'package:quill_diary/infrastructure/storage/editor_draft_store.dart';
import 'package:quill_diary/infrastructure/storage/external_directory_store.dart';
import 'package:quill_diary/infrastructure/storage/shared/picked_file_materializer.dart';
import 'package:quill_diary/infrastructure/storage/vault_archive_io.dart';
import 'package:quill_diary/infrastructure/storage/vault_transfer_service.dart';

import '../../helpers/shared/test_l10n.dart';
import '../../helpers/storage/path_provider_test_binding.dart';
import '../../helpers/storage/vault_transfer_service_test_helpers.dart';
import '../../helpers/vault/vault_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late VaultTestHarness harness;
  late PickedFileMaterializer materializer;
  late Directory workDir;

  PickedFileMaterializer createMaterializer({
    bool allowBytesFallback = false,
    CopyAndroidUriToPath? copyAndroidUriToPath,
    ReadPlatformFileBytes? readPlatformFileBytes,
  }) {
    return PickedFileMaterializer(
      allowBytesFallback: allowBytesFallback,
      copyAndroidUriToPath: copyAndroidUriToPath,
      readPlatformFileBytes: readPlatformFileBytes,
    );
  }

  VaultTransferService createTransferService({
    CopyAndroidUriToPath? copyAndroidUriToPath,
    PickPortableFiles? pickPortableFiles,
    VaultArchiveIo? archiveIo,
    PickedFileMaterializer? pickedFileMaterializer,
  }) {
    return VaultTransferService(
      archiveIo: archiveIo ?? harness.createArchiveIo(),
      driveBackupService: const UnusedDriveBackupService(),
      vaultRepository: harness.repository,
      externalDirectoryStore: ExternalDirectoryStore(harness.pathStrategy),
      pathStrategy: harness.pathStrategy,
      copyAndroidUriToPath: copyAndroidUriToPath,
      pickPortableFiles: pickPortableFiles,
      pickedFileMaterializer: pickedFileMaterializer,
    );
  }

  setUp(() async {
    harness = await VaultTestHarness.create();
    workDir = await Directory.systemTemp.createTemp('qld_materialize_test_');
    installPathProviderTestBinding(workDir);
    materializer = createMaterializer();
  });

  tearDown(() async {
    clearPathProviderTestBinding();
    if (workDir.existsSync()) {
      await workDir.delete(recursive: true);
    }
    await harness.dispose();
  });

  group('PickedFileMaterializer', () {
    test('cached path 可用時不觸發 URI 與 bytes', () async {
      final File source = File('${workDir.path}/backup.quillvault');
      await source.writeAsBytes(<int>[1, 2, 3]);

      var uriCalled = false;
      var bytesCalled = false;
      materializer = createMaterializer(
        copyAndroidUriToPath:
            ({required sourceUri, required destinationFile}) async {
              uriCalled = true;
            },
        readPlatformFileBytes: (PlatformFile file) async {
          bytesCalled = true;
          return Uint8List.fromList(<int>[9]);
        },
      );

      final MaterializedPickedFile result = await materializer.materialize(
        PlatformFile(name: 'backup.quillvault', size: 3, path: source.path),
        fallbackBaseName: 'backup.quillvault',
        alwaysCopyToTemp: false,
      );

      expect(result.sourceKind, PickedFileSourceKind.localPath);
      expect(result.file.path, source.path);
      expect(result.shouldDeleteAfterUse, isFalse);
      expect(uriCalled, isFalse);
      expect(bytesCalled, isFalse);
    });

    test(
      '還原 cached path 時會 copy 到 app temp 且 shouldDeleteAfterUse 為 true',
      () async {
        final File source = File('${workDir.path}/restore.quillvault');
        await source.writeAsBytes(<int>[1]);

        final MaterializedPickedFile materialized = await materializer
            .materialize(
              PlatformFile(
                name: 'restore.quillvault',
                size: 1,
                path: source.path,
              ),
              fallbackBaseName: 'restore.quillvault',
              alwaysCopyToTemp: true,
            );
        expect(materialized.shouldDeleteAfterUse, isTrue);
        expect(materialized.file.path, isNot(source.path));
        expect(await materialized.file.readAsBytes(), <int>[1]);
        await materialized.file.delete();
      },
    );

    test('僅 safHandle 含 content URI 時走 URI 複製', () async {
      String? copiedUri;
      materializer = createMaterializer(
        copyAndroidUriToPath:
            ({required sourceUri, required destinationFile}) async {
              copiedUri = sourceUri;
              await destinationFile.writeAsBytes(<int>[8, 9]);
            },
      );

      final MaterializedPickedFile result = await materializer.materialize(
        AndroidPlatformFile(
          file: PlatformFile(name: 'saf.quillvault', size: 2),
          safHandle: AndroidSAFHandle(
            uri: Uri.parse(
              'content://com.android.providers.downloads.documents/document/123',
            ),
            accessMode: AndroidSAFAccessMode.readOnly,
          ),
        ),
        fallbackBaseName: 'saf.quillvault',
        alwaysCopyToTemp: true,
      );

      expect(
        copiedUri,
        'content://com.android.providers.downloads.documents/document/123',
      );
      expect(result.sourceKind, PickedFileSourceKind.androidContentUri);
      expect(result.file.existsSync(), isTrue);
      expect(result.shouldDeleteAfterUse, isTrue);
      await result.file.delete();
    });

    test('僅 identifier 為 content URI 時走 URI 複製', () async {
      String? copiedUri;
      materializer = createMaterializer(
        copyAndroidUriToPath:
            ({required sourceUri, required destinationFile}) async {
              copiedUri = sourceUri;
              await destinationFile.writeAsBytes(<int>[4, 5, 6]);
            },
      );

      final MaterializedPickedFile result = await materializer.materialize(
        PlatformFile(
          name: 'drive.zip',
          size: 3,
          identifier: 'content://com.google.android.apps.docs/document/abc',
        ),
        fallbackBaseName: 'drive.zip',
        alwaysCopyToTemp: true,
      );

      expect(copiedUri, 'content://com.google.android.apps.docs/document/abc');
      expect(result.sourceKind, PickedFileSourceKind.androidContentUri);
      expect(result.file.existsSync(), isTrue);
      expect(result.shouldDeleteAfterUse, isTrue);
      await result.file.delete();
    });

    test('path 為 content URI 字串時不走 File path', () async {
      var uriCalled = false;
      materializer = createMaterializer(
        copyAndroidUriToPath:
            ({required sourceUri, required destinationFile}) async {
              uriCalled = true;
              await destinationFile.writeAsBytes(<int>[7]);
            },
      );

      final MaterializedPickedFile result = await materializer.materialize(
        PlatformFile(
          name: 'backup.quillvault',
          size: 1,
          path: 'content://provider/backup.quillvault',
        ),
        fallbackBaseName: 'backup.quillvault',
        alwaysCopyToTemp: false,
      );

      expect(uriCalled, isTrue);
      expect(result.sourceKind, PickedFileSourceKind.androidContentUri);
      await result.file.delete();
    });

    test('無 path 無 URI 時拋出 unreadable', () async {
      var bytesCalled = false;
      materializer = createMaterializer(
        readPlatformFileBytes: (PlatformFile file) async {
          bytesCalled = true;
          return Uint8List.fromList(<int>[1]);
        },
      );

      expect(
        () => materializer.materialize(
          PlatformFile(name: 'missing.zip', size: 1),
          fallbackBaseName: 'missing.zip',
          alwaysCopyToTemp: true,
        ),
        throwsA(
          isA<PickedFileMaterializationException>().having(
            (PickedFileMaterializationException error) => error.failure,
            'failure',
            PickedFileMaterializationFailure.unreadable,
          ),
        ),
      );
      expect(bytesCalled, isFalse);
    });

    test('大於 64 MiB 的 content URI 仍可 materialize', () async {
      const int largeSize = kPickedFileBytesFallbackMaxBytes + 1024;
      materializer = createMaterializer(
        copyAndroidUriToPath:
            ({required sourceUri, required destinationFile}) async {
              await destinationFile.writeAsBytes(List<int>.filled(16, 9));
            },
      );

      final MaterializedPickedFile result = await materializer.materialize(
        PlatformFile(
          name: 'large.quillvault',
          size: largeSize,
          identifier: 'content://provider/large.quillvault',
        ),
        fallbackBaseName: 'large.quillvault',
        alwaysCopyToTemp: true,
      );

      expect(result.sourceKind, PickedFileSourceKind.androidContentUri);
      await result.file.delete();
    });

    test('URI 複製失敗時刪除 destination 暫存檔', () async {
      materializer = createMaterializer(
        copyAndroidUriToPath:
            ({required sourceUri, required destinationFile}) async {
              await destinationFile.writeAsBytes(<int>[1]);
              throw StateError('複製失敗');
            },
      );

      await expectLater(
        materializer.materialize(
          PlatformFile(
            name: 'bad.zip',
            size: 1,
            identifier: 'content://provider/bad.zip',
          ),
          fallbackBaseName: 'bad.zip',
          alwaysCopyToTemp: true,
        ),
        throwsA(isA<PickedFileMaterializationException>()),
      );

      final List<FileSystemEntity> leftovers = workDir.listSync();
      expect(leftovers, isEmpty);
    });
  });

  group('bytesFallback 保底', () {
    test('小於 64 MiB 的 bytes 可寫入 temp', () async {
      materializer = createMaterializer(
        allowBytesFallback: true,
        readPlatformFileBytes: (PlatformFile file) async {
          return Uint8List.fromList(<int>[1, 2, 3, 4]);
        },
      );

      final MaterializedPickedFile result = await materializer.materialize(
        PlatformFile(name: 'tiny.md', size: 4),
        fallbackBaseName: 'tiny.md',
        alwaysCopyToTemp: true,
      );

      expect(result.sourceKind, PickedFileSourceKind.bytesFallback);
      expect(
        await result.file.readAsBytes(),
        Uint8List.fromList(<int>[1, 2, 3, 4]),
      );
      await result.file.delete();
    });

    test('大於 64 MiB 拒絕 bytes fallback', () async {
      materializer = createMaterializer(
        allowBytesFallback: true,
        readPlatformFileBytes: (PlatformFile file) async {
          return Uint8List(8);
        },
      );

      expect(
        () => materializer.materialize(
          PlatformFile(
            name: 'huge.zip',
            size: kPickedFileBytesFallbackMaxBytes + 1,
          ),
          fallbackBaseName: 'huge.zip',
          alwaysCopyToTemp: true,
        ),
        throwsA(
          isA<PickedFileMaterializationException>().having(
            (PickedFileMaterializationException error) => error.failure,
            'failure',
            PickedFileMaterializationFailure.tooLargeForBytesFallback,
          ),
        ),
      );
    });
  });

  group('VaultTransferService 整合', () {
    test('zip 匯入失敗後暫存檔已刪除', () async {
      File? materializedZip;
      final VaultTransferService service = createTransferService(
        archiveIo: _ThrowingZipImportArchiveIo(harness),
        copyAndroidUriToPath:
            ({required sourceUri, required destinationFile}) async {
              materializedZip = destinationFile;
              await destinationFile.writeAsBytes(<int>[1, 2, 3]);
            },
        pickPortableFiles:
            ({
              required String dialogTitle,
              required List<String> allowedExtensions,
            }) async {
              return FilePickerResult(<PlatformFile>[
                PlatformFile(
                  name: 'import.zip',
                  size: 3,
                  identifier: 'content://provider/import.zip',
                ),
              ]);
            },
      );

      final UnlockedVaultSession session =
          (await harness.repository.setupRecoveryKey()).session;

      await expectLater(
        service.importDocumentsWithPicker(session, l10n: testL10n),
        throwsA(isA<StateError>()),
      );

      expect(materializedZip, isNotNull);
      expect(materializedZip!.existsSync(), isFalse);
    });
  });
}

class _ThrowingZipImportArchiveIo extends VaultArchiveIo {
  _ThrowingZipImportArchiveIo(VaultTestHarness harness)
    : super(
        pathStrategy: harness.pathStrategy,
        repository: harness.repository,
        frontMatterCodec: const FrontMatterCodec(),
        indexDatabaseManager: IndexDatabaseManager(harness.pathStrategy),
        editorDraftStore: EditorDraftStore(
          pathStrategy: harness.pathStrategy,
          cryptoService: LocalCryptoService(),
        ),
      );

  @override
  Future<PortableImportResult> importDocumentsFromZip({
    required UnlockedVaultSession session,
    required File zipFile,
  }) async {
    throw StateError('匯入失敗');
  }
}
