import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:quill_diary/domain/persona/persona.dart';
import 'package:quill_diary/domain/persona/persona_chat_import.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/crypto/crypto_service.dart';
import 'package:quill_diary/infrastructure/storage/shared/vault_file_ops.dart';
import 'package:quill_diary/infrastructure/storage/vault_path_strategy.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';

class PersonaStore {
  PersonaStore({
    required this.paths,
    required this.crypto,
    required this.repository,
  });
  final VaultPathStrategy paths;
  final CryptoService crypto;
  final VaultRepository repository;
  final Set<String> pendingCleanup = {};

  Future<Directory> directory(String personId) async {
    if (!isPrefixedId(personId, 'per')) throw const FormatException('無效的人物識別');
    return Directory(
      p.join((await paths.vaultRootDirectory()).path, 'personas', personId),
    );
  }

  Future<File> _state(String personId) async =>
      File(p.join((await directory(personId)).path, 'state.json.enc'));

  Future<PersonaRecord?> _load(
    String personId,
    UnlockedVaultSession session,
  ) async {
    final file = await _state(personId);
    if (!file.existsSync()) {
      if (File('${file.path}.previous').existsSync() ||
          File('${file.path}.tmp').existsSync()) {
        throw const FormatException('分身狀態需要復原，未自動採用舊副本');
      }
      return null;
    }
    final record = PersonaRecord.fromJson(
      await readVaultJson(
        file,
        crypto,
        session,
        identity: personaStateIdentity(personId),
      ),
    );
    if (record.personId != personId || record.vaultId != session.vaultId) {
      throw const FormatException('分身所屬日記庫或人物不符');
    }
    return record;
  }

  Future<PersonaRecord?> load(String personId, UnlockedVaultSession session) =>
      repository.runVaultMutation(() async {
        await repository.validateRecoverySession(session);
        final record = await _load(personId, session);
        if (record == null) return null;
        if (record.deleting) {
          await _finishDelete(personId);
          return null;
        }
        await _cleanup(record);
        return record;
      });

  Future<List<PersonaRecord>> list(UnlockedVaultSession session) async {
    final root = Directory(
      p.join((await paths.vaultRootDirectory()).path, 'personas'),
    );
    if (!root.existsSync()) return [];
    final result = <PersonaRecord>[];
    await for (final item in root.list(followLinks: false)) {
      if (item is! Directory || !isPrefixedId(p.basename(item.path), 'per')) {
        continue;
      }
      try {
        final record = await load(p.basename(item.path), session);
        if (record?.available == true) result.add(record!);
      } on Object {
        continue;
      }
    }
    return result;
  }

  /// 呼叫端須已持有日記庫修改序列，避免備份期間讀到不同次提交的內容。
  /// 正式卡片去除草稿後重新加密，不改寫使用中的檔案。
  Future<Map<String, Uint8List>> createBackupFiles(
    UnlockedVaultSession session,
  ) async {
    await repository.validateRecoverySession(session);
    final root = Directory(
      p.join((await paths.vaultRootDirectory()).path, 'personas'),
    );
    if (!root.existsSync()) return {};
    final metadata = await repository.readRecoveryMetadata();
    if (metadata == null || metadata.vaultId != session.vaultId) {
      throw const FormatException('日記庫已變更');
    }
    final files = <String, Uint8List>{};
    await for (final item in root.list(followLinks: false)) {
      if (item is! Directory || !isPrefixedId(p.basename(item.path), 'per')) {
        continue;
      }
      final record = await _load(p.basename(item.path), session);
      if (record == null || !record.available) continue;
      final published = record.withDraft(null);
      published.validate();
      final now = DateTime.now();
      final encrypted = await crypto.encryptBytes(
        documentId: personaStateIdentity(record.personId),
        vaultId: session.vaultId,
        plaintextBytes: utf8.encode(jsonEncode(published.toJson())),
        contentType: 'application/json',
        recoveryWrapKey: requireRecoveryWrapKey(session),
        recoverySlotKdf: metadata.kdf,
        createdAt: now,
        updatedAt: now,
      );
      files['personas/${record.personId}/state.json.enc'] = encrypted
          .toFileBytes();
    }
    return files;
  }

  Future<void> _write(
    File file,
    String identity,
    Map<String, Object?> json,
    UnlockedVaultSession session, {
    void Function()? ensureCurrent,
    void Function(Map<String, dynamic>)? validate,
  }) async {
    await repository.validateRecoverySession(session);
    final metadata = await repository.readRecoveryMetadata();
    if (metadata == null || metadata.vaultId != session.vaultId) {
      throw const FormatException('日記庫已變更');
    }
    final now = DateTime.now();
    await writeEncryptedVaultJson(
      file: file,
      crypto: crypto,
      session: session,
      metadata: metadata,
      documentId: identity,
      plaintextBytes: utf8.encode(jsonEncode(json)),
      createdAt: now,
      updatedAt: now,
      validateTemporary: (temporary) async {
        final decoded = await readVaultJson(
          temporary,
          crypto,
          session,
          identity: identity,
        );
        validate?.call(decoded);
        if (jsonEncode(decoded) != jsonEncode(json)) {
          throw const FormatException('分身寫入驗證失敗');
        }
      },
      beforeCommit: ensureCurrent,
    );
  }

  Future<void> saveDraft(
    PersonaRecord record,
    UnlockedVaultSession session, {
    bool create = false,
    void Function()? ensureCurrent,
  }) async {
    final snapshot = PersonaRecord.fromJson(
      jsonDecode(jsonEncode(record.toJson())) as Map<String, dynamic>,
    );
    return repository.runVaultMutation(() async {
      ensureCurrent?.call();
      final record = snapshot;
      final current = await _load(record.personId, session);
      if (record.vaultId != session.vaultId ||
          current == null && !create ||
          current?.deleting == true ||
          current != null && current.personaId != record.personaId ||
          !(await repository.listPeople(session))
              .any((p) => p.id == record.personId)) {
        throw const FormatException('分身已刪除或變更');
      }
      final next = PersonaRecord(
        vaultId: session.vaultId,
        personId: record.personId,
        personaId: record.personaId,
        cards: current?.cards,
        draft: record.draft,
      );
      for (final entry
          in record.draft?.baseUpdatedAt.entries ??
              <MapEntry<PersonaCardKind, DateTime?>>[]) {
        if (!personaTimesMatch(
          current?.cards?[entry.key]?.updatedAt,
          entry.value,
        )) {
          throw const FormatException('分身內容已在別處更新');
        }
      }
      next.validate();
      await _write(
        await _state(next.personId),
        personaStateIdentity(next.personId),
        next.toJson(),
        session,
        ensureCurrent: ensureCurrent,
        validate: (j) => PersonaRecord.fromJson(j),
      );
    });
  }

  Future<PersonaRecord> publish(
    String personId,
    String personaId,
    UnlockedVaultSession session, {
    void Function()? ensureCurrent,
  }) => repository.runVaultMutation(() async {
    ensureCurrent?.call();
    final current = await _load(personId, session);
    if (current == null ||
        current.deleting ||
        current.personaId != personaId ||
        current.draft?.candidate == null ||
        !(await repository.listPeople(session)).any((p) => p.id == personId)) {
      throw const FormatException('分身更新已失效');
    }
    final draft = current.draft!;
    final cards = {...?current.cards};
    for (final kind in draft.target.kinds) {
      if (!personaTimesMatch(
        current.cards?[kind]?.updatedAt,
        draft.baseUpdatedAt[kind],
      )) {
        throw const FormatException('分身內容已在別處更新');
      }
      final candidate = draft.candidate![kind]!;
      candidate.validate(kind);
      cards[kind] = PersonaCard(
        text: candidate.text,
        tokens: {
          for (final e in candidate.tokens.entries)
            if (candidate.text.contains(e.key)) e.key: e.value,
        },
        updatedAt: DateTime.now().toUtc(),
        selectedDiaryIds: draft.manualEdit
            ? current.cards![kind]!.selectedDiaryIds
            : draft.diaries.map((d) => d.entryId).toList(),
      );
    }
    final next = PersonaRecord(
      vaultId: current.vaultId,
      personId: personId,
      personaId: personaId,
      cards: cards,
    );
    next.validate();
    await _write(
      await _state(personId),
      personaStateIdentity(personId),
      next.toJson(),
      session,
      ensureCurrent: ensureCurrent,
      validate: (j) => PersonaRecord.fromJson(j),
    );
    await _cleanup(next);
    return next;
  });

  Future<File> _importFile(
    String personId,
    String importId,
    String contentId,
  ) async {
    if (!isPrefixedId(importId, 'pim') || !isPrefixedId(contentId, 'pco')) {
      throw const FormatException('無效的匯入內容識別');
    }
    return File(
      p.join(
        (await directory(personId)).path,
        'pending_imports',
        '$importId.$contentId.json.enc',
      ),
    );
  }

  Future<PersonaRecord> saveImport(
    PersonaChatImport value,
    UnlockedVaultSession session, {
    required PersonaDraft draft,
    void Function()? ensureCurrent,
  }) {
    final payload =
        jsonDecode(jsonEncode(value.toJson())) as Map<String, dynamic>;
    final imported = PersonaChatImport.fromJson(payload);
    final nextDraft = PersonaDraft.fromJson(
      jsonDecode(jsonEncode(draft.toJson())) as Map<String, dynamic>,
    );
    final source = nextDraft.chats.singleWhere(
      (c) => c.importId == imported.importId,
    );
    source.contentId = generatePersonaContentId();
    nextDraft.candidate = null;
    nextDraft.step = PersonaStep.materials;
    return repository.runVaultMutation(() async {
      ensureCurrent?.call();
      final current = await _load(imported.personId, session);
      if (current == null ||
          current.deleting ||
          current.personaId != imported.personaId ||
          current.draft == null ||
          imported.vaultId != session.vaultId ||
          !(await repository.listPeople(session))
              .any((p) => p.id == imported.personId)) {
        throw const FormatException('匯入工作已失效');
      }
      for (final entry in nextDraft.baseUpdatedAt.entries) {
        if (!personaTimesMatch(
          current.cards?[entry.key]?.updatedAt,
          entry.value,
        )) {
          throw const FormatException('分身內容已在別處更新');
        }
      }
      final next = current.withDraft(nextDraft);
      next.validate();
      final ids = imported.messages.map((m) => m.id).toSet();
      if (source.hidden.keys.any((id) => !ids.contains(id)) ||
          source.excluded.any((id) => !ids.contains(id))) {
        throw const FormatException('聊天選取包含不存在的訊息');
      }
      for (final message in imported.messages) {
        validatePersonaRanges(message.text, source.hidden[message.id] ?? []);
      }
      // 狀態檔是提交點；新內容寫入成功前，不切換指標或隱藏區間。
      await _write(
        await _importFile(
          imported.personId,
          imported.importId,
          source.contentId,
        ),
        personaImportIdentity(
          imported.personId,
          imported.importId,
          source.contentId,
        ),
        payload,
        session,
        ensureCurrent: ensureCurrent,
        validate: (j) => PersonaChatImport.fromJson(j),
      );
      await _write(
        await _state(next.personId),
        personaStateIdentity(next.personId),
        next.toJson(),
        session,
        ensureCurrent: ensureCurrent,
        validate: (j) => PersonaRecord.fromJson(j),
      );
      await _cleanup(next);
      return next;
    });
  }

  Future<PersonaChatImport> readImport(
    String personId,
    String personaId,
    PersonaChatSource source,
    UnlockedVaultSession session,
  ) async {
    final importId = source.importId;
    final contentId = source.contentId;
    final hidden = {
      for (final entry in source.hidden.entries)
        entry.key: List.of(entry.value),
    };
    final excluded = Set.of(source.excluded);
    final value = PersonaChatImport.fromJson(
      await readVaultJson(
        await _importFile(personId, importId, contentId),
        crypto,
        session,
        identity: personaImportIdentity(personId, importId, contentId),
      ),
    );
    if (value.personId != personId ||
        value.personaId != personaId ||
        value.importId != importId ||
        value.vaultId != session.vaultId) {
      throw const FormatException('匯入材料所屬分身不符');
    }
    final ids = value.messages.map((message) => message.id).toSet();
    if (hidden.keys.any((id) => !ids.contains(id)) ||
        excluded.any((id) => !ids.contains(id))) {
      throw const FormatException('匯入聊天選取參照不存在的訊息');
    }
    for (final message in value.messages) {
      validatePersonaRanges(message.text, hidden[message.id] ?? const []);
    }
    return value;
  }

  Future<void> _cleanup(PersonaRecord record) async {
    var clean = true;
    final state = await _state(record.personId);
    for (final suffix in ['.previous', '.tmp']) {
      try {
        final f = File('${state.path}$suffix');
        if (f.existsSync()) await f.delete();
      } on FileSystemException {
        clean = false;
      }
    }
    final pending = Directory(
      p.join((await directory(record.personId)).path, 'pending_imports'),
    );
    final keep = {
      for (final c in record.draft?.chats ?? <PersonaChatSource>[])
        '${c.importId}.${c.contentId}.json.enc',
    };
    if (pending.existsSync()) {
      try {
        await for (final item in pending.list(followLinks: false)) {
          if (item is! File || keep.contains(p.basename(item.path))) continue;
          try {
            await item.delete();
          } on FileSystemException {
            clean = false;
          }
        }
      } on FileSystemException {
        clean = false;
      }
    }
    if (clean) {
      pendingCleanup.remove(record.personId);
    } else {
      pendingCleanup.add(record.personId);
    }
  }

  Future<void> delete(String personId, UnlockedVaultSession session) =>
      repository.runVaultMutation(() async {
        await repository.validateRecoverySession(session);
        final file = await _state(personId);
        final tombstone = PersonaRecord(
          vaultId: session.vaultId,
          personId: personId,
          personaId: generatePersonaId(),
          deleting: true,
        );
        // 刪除也是明確的復原選擇；損毀資料不會阻止使用者清除自己的分身。
        if (file.existsSync()) {
          for (final suffix in ['.previous', '.tmp']) {
            final f = File('${file.path}$suffix');
            if (f.existsSync()) await f.delete();
          }
        }
        await _write(
          file,
          personaStateIdentity(personId),
          tombstone.toJson(),
          session,
        );
        await _finishDelete(personId);
      });

  Future<void> _finishDelete(String personId) async {
    final dir = await directory(personId);
    if (!dir.existsSync()) return;
    final state = await _state(personId);
    await for (final child in dir.list(followLinks: false)) {
      if (child.path == state.path) continue;
      await child.delete(recursive: child is Directory);
    }
    if (state.existsSync()) await state.delete();
    if (dir.existsSync()) await dir.delete();
    pendingCleanup.remove(personId);
  }
}
