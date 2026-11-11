import 'dart:convert';
import 'dart:io';

import 'package:quill_diary/domain/ai/ai_failure.dart';
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
        final DiaryOrganization draft;
        try {
          await recoverFileReplacement(
            file,
            validate: (candidate) async {
              await _decode(candidate, id, session);
            },
          );
          if (!file.existsSync()) return null;
          draft = await _decode(file, id, session);
        } on Object catch (error) {
          if (isUnreadableContentError(error)) {
            throw const AiFailure(AiErrorCode.unreadable);
          }
          rethrow;
        }
        final current = await repository.loadEntry(session, id);
        if (current == null ||
            draft.stage == OrganizationStage.applied ||
            (draft.stage == OrganizationStage.applying &&
                !draft.hasUnsafeCandidate &&
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

  Future<DiaryOrganization> _decode(
    File file,
    String id,
    UnlockedVaultSession session,
  ) async {
    final draft = DiaryOrganization.fromJson(
      await readVaultJson(file, crypto, session, identity: id),
    );
    if (draft.source.id != id || draft.source.vaultId != session.vaultId) {
      throw const FormatException('整理草稿來源不符');
    }
    return draft;
  }

  Future<void> save(
    DiaryOrganization draft,
    UnlockedVaultSession session, {
    bool Function()? isCurrent,
  }) {
    if (draft.organizedBody case final body?) draft.validateBody(body);
    final bytes = utf8.encode(jsonEncode(draft.toJson()));
    return repository.runVaultMutation(() async {
      if (isCurrent != null && !isCurrent()) return;
      await repository.validateRecoverySession(session);
      if (await repository.loadEntry(session, draft.source.id) == null) {
        throw const FormatException('日記已刪除');
      }
      final file = await _file(draft.source.id);
      await recoverFileReplacement(
        file,
        validate: (candidate) async {
          await _decode(candidate, draft.source.id, session);
        },
      );
      final metadata = await repository.readRecoveryMetadata();
      if (metadata == null ||
          metadata.vaultId != session.vaultId ||
          session.recoveryWrapKey == null) {
        throw const FormatException('日記庫已變更');
      }
      final now = DateTime.now();
      if (isCurrent != null && !isCurrent()) return;
      await writeEncryptedVaultJson(
        file: file,
        crypto: crypto,
        session: session,
        metadata: metadata,
        documentId: draft.source.id,
        plaintextBytes: bytes,
        createdAt: draft.source.createdAt,
        updatedAt: now,
        commitWhen: isCurrent,
        validateTemporary: (temporary) async {
          await _decode(temporary, draft.source.id, session);
        },
        beforeCommit: () {
          if (isCurrent != null && !isCurrent()) {
            throw const FormatException('整理工作已失效');
          }
        },
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
    draft.validateBody(draft.currentBody);
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
