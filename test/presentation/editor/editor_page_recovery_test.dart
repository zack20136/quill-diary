import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/application/editor/editor_actions.dart';
import 'package:quill_diary/application/session/providers/session_providers.dart';
import 'package:quill_diary/application/session/state/app_session_state.dart';
import 'package:quill_diary/application/settings/settings_providers.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/presentation/editor/pages/editor_page.dart';
import 'package:quill_diary/shared/presentation/widgets/app_state_card.dart';

import '../../helpers/presentation/editor/editor_test_scope.dart';
import '../../helpers/presentation/editor/fake_editor_actions.dart';
import '../../helpers/shared/test_l10n.dart';

void main() {
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
    expect(
      find.text(testL10n.sessionBlockedRecoveryRequiredTitle),
      findsOneWidget,
    );
    expect(find.text(testL10n.editorNeedsRecoveryKeyMessage), findsOneWidget);
    expect(find.text(testL10n.homeGoToSettings), findsOneWidget);
  });
}
