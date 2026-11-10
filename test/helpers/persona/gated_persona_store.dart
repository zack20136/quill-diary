import 'dart:async';

import 'package:quill_diary/domain/persona/persona.dart';
import 'package:quill_diary/domain/persona/persona_chat_import.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/infrastructure/persona/persona_store.dart';

class GatedPersonaStore extends PersonaStore {
  GatedPersonaStore({
    required super.paths,
    required super.crypto,
    required super.repository,
  });

  Future<void>? loadGate;
  Completer<void>? loadStarted;
  Future<void>? importCommittedGate;
  Completer<void>? importCommitted;

  @override
  Future<PersonaRecord?> load(
    String personId,
    UnlockedVaultSession session,
  ) async {
    final gate = loadGate;
    final started = loadStarted;
    final value = await super.load(personId, session);
    started?.complete();
    await gate;
    return value;
  }

  @override
  Future<PersonaRecord> saveImport(
    PersonaChatImport value,
    UnlockedVaultSession session, {
    required PersonaDraft draft,
    void Function()? ensureCurrent,
  }) async {
    final saved = await super.saveImport(
      value,
      session,
      draft: draft,
      ensureCurrent: ensureCurrent,
    );
    importCommitted?.complete();
    await importCommittedGate;
    return saved;
  }
}
