import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/application/chat_diary/chat_diary_providers.dart';
import 'package:quill_diary/application/editor/editor_actions.dart';
import 'package:quill_diary/application/session/session_providers.dart';
import 'package:quill_diary/application/session/session_state.dart';
import 'package:quill_diary/application/settings/settings_providers.dart';
import 'package:quill_diary/application/vault/vault_providers.dart';
import 'package:quill_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/presentation/editor/pages/editor_page.dart';
import 'package:quill_diary/presentation/editor/widgets/editor_hybrid_body.dart';
import 'package:quill_diary/shared/presentation/widgets/app_state_card.dart';

import '../../helpers/presentation/editor/editor_test_scope.dart';
import '../../helpers/presentation/editor/fake_editor_actions.dart';
import '../../helpers/shared/test_l10n.dart';

void main() {
  testWidgets('已解鎖的既有日記可在等待復原中繼資料時檢視並切換編輯', (tester) async {
    const session = UnlockedVaultSession(
      vaultId: 'vault-1',
      trustedDevice: true,
      recoveryWrapKey: <int>[1, 2, 3],
    );
    final entry = FakeEditorActions.defaultEntry.copyWith(attachmentIds: []);
    final actions = FakeEditorActions(existingEntry: entry, attachments: []);
    final metadata = Completer<RecoveryMetadata?>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          editorActionsProvider.overrideWithValue(actions),
          vaultRepositoryProvider.overrideWithValue(actions.repository),
          effectiveAppSessionProvider.overrideWith(
            (ref) async => const AppSessionState(
              status: AppLockStatus.unlocked,
              session: session,
            ),
          ),
          recoveryMetadataProvider.overrideWith((ref) => metadata.future),
          chatDiaryForEntryProvider.overrideWith((ref, entryId) async => null),
        ],
        child: editorTestApp(child: EditorPage(entryId: entry.id)),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text(entry.markdownBody), findsOneWidget);

    await tester.tap(find.byTooltip(testL10n.editorTooltipEdit));
    await tester.pumpAndSettle();

    final editor = tester.widget<EditorHybridBody>(
      find.byType(EditorHybridBody),
    );
    expect(editor.bodyController.text, entry.markdownBody);
    expect(actions.loadEntryCallCount, 1);
  });

  testWidgets('缺少復原金鑰時顯示前往設定 CTA', (WidgetTester tester) async {
    const UnlockedVaultSession session = UnlockedVaultSession(
      vaultId: 'vault-1',
      trustedDevice: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          editorActionsProvider.overrideWithValue(FakeEditorActions()),
          effectiveAppSessionProvider.overrideWith(
            (Ref ref) async => const AppSessionState(
              status: AppLockStatus.unlocked,
              session: session,
            ),
          ),
          recoveryMetadataProvider.overrideWith((Ref ref) async => null),
        ],
        child: editorTestApp(child: const EditorPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppStateView), findsOneWidget);
    expect(find.text(testL10n.homeGoToSettings), findsOneWidget);
  });
}
