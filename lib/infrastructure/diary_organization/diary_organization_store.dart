import 'dart:convert';
import 'dart:io';

import 'package:quill_diary/domain/diary/diary_entry.dart';
import 'package:quill_diary/domain/diary_organization/diary_organization.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/infrastructure/crypto/crypto_service.dart';
import 'package:quill_diary/infrastructure/storage/shared/vault_file_ops.dart';
import 'package:quill_diary/infrastructure/storage/vault_path_strategy.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';

class DiaryOrganizationStore {
  DiaryOrganizationStore({
    required this.paths,
    required this.crypto,
    required this.repository,
  });
  final VaultPathStrategy paths;
  final CryptoService crypto;
  final VaultRepository repository;

  Future<File> _file(String id) async => File(
    '${(await paths.organizationDraftDirectory(id)).path}/session.json.enc',
  );

  Future<DiaryOrganization?> load(String id, UnlockedVaultSession session) =>
      repository.runVaultMutation(() async {
        await repository.validateRecoverySession(session);
        final file = await _file(id);
        await recoverFileReplacement(file);
        if (!file.existsSync()) return null;
        final parsed = crypto.parseFileBytes(await file.readAsBytes());
        if (parsed.header.vaultId != session.vaultId) {
          throw const FormatException('日記庫不符');
        }
        final bytes = await crypto.decryptBytes(
          headerBytes: parsed.headerBytes,
          ciphertextBytes: parsed.ciphertextBytes,
          context: DecryptionContext(
            vaultId: session.vaultId,
            trustedDevice: session.trustedDevice,
            recoveryWrapKey: session.recoveryWrapKey,
            deviceSlotId: session.deviceSlotId,
          ),
        );
        final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
        final draft = DiaryOrganization.fromJson(json);
        if (draft.source.id != id || draft.source.vaultId != session.vaultId) {
          throw const FormatException('整理草稿來源不符');
        }
        final current = await repository.loadEntry(session, id);
        if (current == null ||
            draft.stage == OrganizationStage.applied ||
            (draft.stage == OrganizationStage.applying &&
                organizationEntrySignature(current) ==
                    organizationEntrySignature(
                      draft.source.copyWith(markdownBody: draft.restoredBody),
                    ))) {
          await _delete(id);
          return null;
        }
        if (draft.stage == OrganizationStage.applying) {
          draft.stage = OrganizationStage.review;
        }
        return draft;
      });

  Future<void> save(
    DiaryOrganization draft,
    UnlockedVaultSession session, {
    bool Function()? isCurrent,
  }) {
    final bytes = utf8.encode(jsonEncode(draft.toJson()));
    return repository.runVaultMutation(() async {
      if (isCurrent != null && !isCurrent()) return;
      await repository.validateRecoverySession(session);
      if (await repository.loadEntry(session, draft.source.id) == null) {
        throw const FormatException('日記已刪除');
      }
      final metadata = await repository.readRecoveryMetadata();
      if (metadata == null ||
          metadata.vaultId != session.vaultId ||
          session.recoveryWrapKey == null) {
        throw const FormatException('日記庫已變更');
      }
      final now = DateTime.now();
      final encrypted = await crypto.encryptBytes(
        documentId: draft.source.id,
        vaultId: session.vaultId,
        plaintextBytes: bytes,
        contentType: 'application/json',
        recoveryWrapKey: session.recoveryWrapKey!,
        recoverySlotKdf: metadata.kdf,
        createdAt: draft.source.createdAt,
        updatedAt: now,
      );
      if (isCurrent != null && !isCurrent()) return;
      await replaceFileBytesRecoverably(
        await _file(draft.source.id),
        encrypted.toFileBytes(),
      );
      draft.persisted = true;
    });
  }

  Future<void> delete(String id) =>
      repository.runVaultMutation(() => _delete(id));

  Future<void> _delete(String id) async {
    final directory = await paths.organizationDraftDirectory(id);
    if (directory.existsSync()) await directory.delete(recursive: true);
  }

  Future<DiaryEntry?> apply(
    DiaryOrganization draft,
    UnlockedVaultSession session, {
    void Function()? ensureCurrent,
  }) async {
    draft.stage = OrganizationStage.applying;
    await save(draft, session);
    ensureCurrent?.call();
    final saved = await repository.applyOrganizedBody(
      session,
      source: draft.source,
      body: draft.restoredBody,
      ensureCurrent: ensureCurrent,
    );
    if (saved == null) {
      draft.stage = OrganizationStage.review;
      await save(draft, session);
      return null;
    }
    draft.stage = OrganizationStage.applied;
    // 即使清理中斷，載入時仍可由 applying 狀態與目標內文辨識已完成套用。
    try {
      await delete(draft.source.id);
    } on FileSystemException {
      /* 下次載入繼續清理。 */
    }
    return saved;
  }
}
