import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_diary/application/editor/editor_actions.dart';
import 'package:quill_diary/application/editor/editor_draft_models.dart';
import 'package:quill_diary/application/editor/editor_flow_controller.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';

import '../../helpers/presentation/editor/fake_editor_actions.dart';

void main() {
  final UnlockedVaultSession session = UnlockedVaultSession(
    vaultId: 'vault-1',
    trustedDevice: true,
  );

  EditorDraftRecord draft() => EditorDraftRecord(
    title: '搶救標題',
    dateValue: '2026-08-20',
    entryHour: 10,
    entryMinute: 30,
    tags: const <String>[],
    markdownBody: '搶救正文',
    attachmentIds: const <String>[],
    pendingAttachments: const <EditorDraftPendingAttachment>[],
    provisionalEntryId: 'salvage-entry',
    createdAt: DateTime(2026, 8, 20),
    updatedAt: DateTime(2026, 8, 20),
  );

  test('salvage 草稿直接接受決定後會還原', () async {
    final FakeEditorActions actions = FakeEditorActions(draft: draft());
    final ProviderContainer container = ProviderContainer(
      overrides: [editorActionsProvider.overrideWithValue(actions)],
    );
    addTearDown(container.dispose);
    var decideRestoreCalls = 0;

    // EditorPage 的 salvageToken 路徑會把 decideRestore 直接回傳 true。
    final EditorDraftRestoreDecision decision = await container
        .read(editorFlowControllerProvider)
        .restoreDraftIfNeeded(
          draftKey: 'salvage-draft',
          session: session,
          existingEntry: null,
          decideRestore: (_) async {
            decideRestoreCalls++;
            return true;
          },
        );

    expect(decideRestoreCalls, 1);
    expect(decision.kind, EditorDraftRestoreKind.restored);
    expect(decision.record?.title, '搶救標題');
  });

  test('一般草稿決定為 false 或 null 時會捨棄', () async {
    for (final bool? answer in <bool?>[false, null]) {
      final FakeEditorActions actions = FakeEditorActions(draft: draft());
      final ProviderContainer container = ProviderContainer(
        overrides: [editorActionsProvider.overrideWithValue(actions)],
      );
      addTearDown(container.dispose);

      final EditorDraftRestoreDecision decision = await container
          .read(editorFlowControllerProvider)
          .restoreDraftIfNeeded(
            draftKey: 'normal-draft',
            session: session,
            existingEntry: null,
            decideRestore: (_) async => answer,
          );

      expect(decision.kind, EditorDraftRestoreKind.discarded);
    }
  });
}
