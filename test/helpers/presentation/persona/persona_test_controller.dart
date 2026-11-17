import 'package:quill_diary/application/persona/persona_controller.dart';
import 'package:quill_diary/domain/ai/private_text.dart';
import 'package:quill_diary/domain/persona/persona.dart';
import 'package:quill_diary/domain/persona/persona_chat_import.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';

class PersonaTestController extends PersonaController {
  PersonaTestController(super.ref, super.personId, PersonaRecord value) {
    record = value;
    session = const UnlockedVaultSession(vaultId: 'vault', trustedDevice: true);
  }
  @override
  Future<void> load() async {}
  @override
  Future<void> persist({void Function()? ensureCurrent}) async {
    ensureCurrent?.call();
  }

  @override
  Future<void> updateImport(
    PersonaChatImport value, {
    Map<String, List<PrivateTextRange>>? hidden,
    Map<String, List<PrivateTextRange>>? revealed,
    Set<String>? excluded,
  }) async {
    final source = draft!.chats.singleWhere(
      (c) => c.importId == value.importId,
    );
    if (hidden != null) {
      source.hidden
        ..clear()
        ..addAll(hidden);
    }
    if (revealed != null) {
      source.revealed
        ..clear()
        ..addAll(revealed);
    }
    if (excluded != null) {
      source.excluded
        ..clear()
        ..addAll(excluded);
    }
    imports[value.importId] = value;
    resetToMaterials();
  }

  @override
  Future<void> selectDiary(String id, bool selected) async {
    if (selected) {
      if (!draft!.diaries.any((d) => d.entryId == id)) {
        draft!.diaries.add(PersonaDiarySource(entryId: id, bodyHash: '0' * 64));
      }
    } else {
      draft!.diaries.removeWhere((d) => d.entryId == id);
    }
    notifyListeners();
  }
}
