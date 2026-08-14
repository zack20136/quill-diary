import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/application/editor/editor_actions.dart';
import 'package:quill_diary/application/editor/editor_entry_providers.dart';
import 'package:quill_diary/application/session/providers/session_providers.dart';
import 'package:quill_diary/domain/diary/diary_entry.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';

import '../../helpers/presentation/editor/fake_editor_actions.dart';

void main() {
  test('索引修訂後會重新載入日記內容以反映批次標籤變更', () async {
    const UnlockedVaultSession session = UnlockedVaultSession(
      vaultId: 'vault-1',
      trustedDevice: true,
      recoveryWrapKey: <int>[1, 2, 3],
    );
    final FakeEditorActions actions = FakeEditorActions();
    final ProviderContainer container = ProviderContainer(
      overrides: [
        activeVaultSessionProvider.overrideWith((Ref ref) async => session),
        editorActionsProvider.overrideWithValue(actions),
      ],
    );
    addTearDown(container.dispose);

    final DiaryEntry before = (await container.read(
      entryProvider('entry-1').future,
    ))!;
    expect(before.tags, isNotEmpty);
    expect(actions.loadEntryCallCount, 1);

    actions.existingEntry = before.copyWith(tags: const <String>[]);
    container.read(entryIndexRevisionProvider.notifier).bump();

    final DiaryEntry after = (await container.read(
      entryProvider('entry-1').future,
    ))!;
    expect(after.tags, isEmpty);
    expect(actions.loadEntryCallCount, 2);
  });
}
