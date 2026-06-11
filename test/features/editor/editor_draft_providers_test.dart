import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/recovery/kdf_descriptor.dart';
import 'package:quill_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/features/editor/editor_draft.dart';
import 'package:quill_diary/features/editor/providers/editor_draft_providers.dart';
import 'package:quill_diary/features/session/providers/session_providers.dart';
import 'package:quill_diary/features/session/state/app_session_state.dart';
import 'package:quill_diary/infrastructure/crypto/crypto_service.dart';
import 'package:quill_diary/infrastructure/storage/editor_draft_store.dart';
import 'package:quill_diary/infrastructure/storage/vault_path_strategy.dart';
import 'package:quill_diary/shared/providers/core_providers.dart';

void main() {
  late Directory rootDir;
  late _TestPathStrategy pathStrategy;
  late EditorDraftStore draftStore;
  late UnlockedVaultSession session;

  setUp(() async {
    rootDir = await Directory.systemTemp.createTemp('editor_draft_providers_test_');
    pathStrategy = _TestPathStrategy(rootDir);
    draftStore = EditorDraftStore(
      pathStrategy: pathStrategy,
      cryptoService: LocalCryptoService(),
    );
    await pathStrategy.ensureBaseDirectories();

    final RecoveryMetadata metadata = RecoveryMetadata(
      vaultId: 'vault-draft-provider',
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

  ProviderContainer buildContainer({required bool unlocked}) {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        vaultPathStrategyProvider.overrideWithValue(pathStrategy),
        editorDraftStoreProvider.overrideWithValue(draftStore),
        effectiveAppSessionProvider.overrideWith(
          (Ref ref) async => unlocked
              ? AppSessionState(
                  status: AppLockStatus.unlocked,
                  session: session,
                )
              : const AppSessionState(status: AppLockStatus.locked),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  EditorDraftRecord buildRecord(String provisionalEntryId) {
    return EditorDraftRecord(
      title: 'draft',
      dateValue: '2026-06-09',
      entryHour: 9,
      entryMinute: 0,
      tags: const <String>[],
      markdownBody: 'body',
      keptAttachmentIds: const <String>[],
      pendingAttachments: const <EditorDraftPendingAttachment>[],
      provisionalEntryId: provisionalEntryId,
      createdAt: DateTime(2026, 6, 9, 9),
      updatedAt: DateTime(2026, 6, 9, 9),
    );
  }

  test('未解鎖 session 時回傳空集合', () async {
    final ProviderContainer container = buildContainer(unlocked: false);

    final Set<String> keys = await container.read(editorDraftKeysProvider.future);

    expect(keys, isEmpty);
  });

  test('已解鎖 session 時回傳 listDraftKeys 結果', () async {
    final ProviderContainer container = buildContainer(unlocked: true);
    await draftStore.write('entry-a', buildRecord('entry-a'), session);
    await draftStore.write('entry-b', buildRecord('entry-b'), session);

    final Set<String> keys = await container.read(editorDraftKeysProvider.future);

    expect(keys, containsAll(<String>{'entry-a', 'entry-b'}));
  });
}

class _TestPathStrategy extends VaultPathStrategy {
  _TestPathStrategy(this.rootDir);

  final Directory rootDir;

  @override
  Future<Directory> appRootDirectory() async => rootDir;
}
