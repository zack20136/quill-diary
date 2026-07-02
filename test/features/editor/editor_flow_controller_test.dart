import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/features/editor/application/editor_actions.dart';
import 'package:quill_diary/features/editor/application/editor_flow_controller.dart';

import '../../helpers/features/editor/fake_editor_actions.dart';

void main() {
  test('saveEntry normalizes checkbox markdown before persisting', () async {
    final FakeEditorActions actions = FakeEditorActions();
    final ProviderContainer container = ProviderContainer(
      overrides: [
        editorActionsProvider.overrideWithValue(actions),
      ],
    );
    addTearDown(container.dispose);

    final EditorFlowController controller =
        container.read(editorFlowControllerProvider);
    final UnlockedVaultSession session = UnlockedVaultSession(
      vaultId: 'vault-1',
      trustedDevice: true,
    );

    await controller.saveEntry(
      EditorSaveRequest(
        draftKey: 'draft-1',
        session: session,
        existingEntry: null,
        titleRaw: '標題',
        dateValue: '2026-06-18',
        entryTime: const TimeOfDay(hour: 8, minute: 0),
        tagsRaw: '標籤',
        markdownBodyRaw: '前言\n- [ ] 待辦',
        keptAttachmentIds: const <AssetId>[],
        pendingAttachments: const <PendingAttachment>[],
        provisionalEntryId: 'entry-new',
        switchToPreview: true,
      ),
    );

    expect(actions.saveEntryCallCount, 1);
    expect(actions.savedEntryDraft?.markdownBody, '前言\n- [ ] 待辦\n');
  });
}
