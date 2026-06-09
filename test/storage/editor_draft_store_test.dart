import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/recovery/kdf_descriptor.dart';
import 'package:quill_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/features/editor/editor_draft.dart';
import 'package:quill_diary/infrastructure/crypto/crypto_service.dart';
import 'package:quill_diary/infrastructure/security/device_key_manager.dart';
import 'package:quill_diary/infrastructure/storage/editor_draft_store.dart';
import 'package:quill_diary/infrastructure/storage/vault_path_strategy.dart';

void main() {
  late Directory rootDir;
  late _TestPathStrategy pathStrategy;
  late EditorDraftStore store;
  late UnlockedVaultSession session;

  setUp(() async {
    rootDir = await Directory.systemTemp.createTemp('editor_draft_store_test_');
    pathStrategy = _TestPathStrategy(rootDir);
    store = EditorDraftStore(
      pathStrategy: pathStrategy,
      cryptoService: LocalCryptoService(
        deviceKeyManager: const UnsupportedDeviceKeyManager(),
      ),
    );
    await pathStrategy.ensureBaseDirectories();

    final RecoveryMetadata metadata = RecoveryMetadata(
      vaultId: 'vault-test',
      recoveryEnabled: true,
      recoveryKeyVersion: 1,
      recoveryKeyHint: 'hint',
      createdAt: DateTime(2026, 6, 9, 12),
      kdf: KdfDescriptor.argon2idRecovery(
        saltBytes: List<int>.generate(16, (int index) => index),
      ),
    );
    await File(await pathStrategy.recoveryMetadataPath()).writeAsString(
      jsonEncode(metadata.toJson()),
    );
    session = UnlockedVaultSession(
      vaultId: metadata.vaultId,
      trustedDevice: false,
      recoveryWrapKey: List<int>.generate(32, (int index) => index),
    );
  });

  tearDown(() async {
    if (rootDir.existsSync()) {
      await rootDir.delete(recursive: true);
    }
  });

  test('write/read roundtrip and listDraftKeys', () async {
    final EditorDraftRecord record = EditorDraftRecord(
      title: '草稿標題',
      dateValue: '2026-06-09',
      entryHour: 9,
      entryMinute: 30,
      tags: <String>['工作', '心情'],
      markdownBody: 'draft body',
      keptAttachmentIds: <String>['asset-1'],
      pendingAttachments: <EditorDraftPendingAttachment>[],
      provisionalEntryId: 'entry-provisional',
      createdAt: DateTime(2026, 6, 9, 9, 30),
      updatedAt: DateTime(2026, 6, 9, 10, 0),
    );

    await store.write('__new__', record, session);

    final EditorDraftRecord? restored = await store.read('__new__', session);
    final Set<String> draftKeys = await store.listDraftKeys();

    expect(restored, isNotNull);
    expect(restored!.title, '草稿標題');
    expect(restored.tags, <String>['工作', '心情']);
    expect(restored.provisionalEntryId, 'entry-provisional');
    expect(draftKeys, contains('__new__'));
  });

  test('stagePendingFile, write record, then delete removes files', () async {
    final File sourceFile = File('${rootDir.path}\\picked.txt');
    await sourceFile.writeAsString('hello');

    final String relativePath = await store.stagePendingFile('entry-1', sourceFile.path);
    final String stagedPath = await store.pendingAbsolutePath('entry-1', relativePath);

    expect(File(stagedPath).existsSync(), isTrue);
    expect(relativePath, startsWith('pending/'));

    final EditorDraftRecord record = EditorDraftRecord(
      title: null,
      dateValue: '2026-06-09',
      entryHour: 11,
      entryMinute: 45,
      tags: const <String>[],
      markdownBody: '',
      keptAttachmentIds: const <String>[],
      pendingAttachments: <EditorDraftPendingAttachment>[
        EditorDraftPendingAttachment(
          relativePath: relativePath,
          mimeType: 'text/plain',
          originalFilename: 'picked.txt',
        ),
      ],
      provisionalEntryId: 'entry-1',
      createdAt: DateTime(2026, 6, 9, 11, 45),
      updatedAt: DateTime(2026, 6, 9, 11, 45),
    );
    await store.write('entry-1', record, session);

    expect(await store.hasDraft('entry-1'), isTrue);

    await store.delete('entry-1');

    expect(await store.hasDraft('entry-1'), isFalse);
    expect(
      (await pathStrategy.editorDraftDirectory('entry-1')).existsSync(),
      isFalse,
    );
  });
}

class _TestPathStrategy extends VaultPathStrategy {
  _TestPathStrategy(this.rootDir);

  final Directory rootDir;

  @override
  Future<Directory> appRootDirectory() async => rootDir;
}
