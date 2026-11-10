import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/editor/editor_actions.dart';
import 'package:quill_diary/application/session/session_providers.dart';
import 'package:quill_diary/application/session/session_state.dart';
import 'package:quill_diary/application/settings/settings_providers.dart';
import 'package:quill_diary/application/vault/vault_providers.dart';
import 'package:quill_diary/domain/recovery/kdf_descriptor.dart';
import 'package:quill_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/editor/pages/editor_page.dart';

import '../../helpers/app_test_theme.dart';
import '../../helpers/presentation/editor/fake_editor_actions.dart';
import '../../helpers/shared/test_l10n.dart';

void main() {
  testWidgets('捨棄新增日記的草稿後，再次新增不會跳出還原草稿', (tester) async {
    final FakeEditorActions actions = FakeEditorActions();
    const UnlockedVaultSession session = UnlockedVaultSession(
      vaultId: 'vault-1',
      trustedDevice: true,
    );
    final GoRouter router = GoRouter(
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => context.push('/editor'),
                child: const Text('新增'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/editor',
          builder: (BuildContext context, GoRouterState state) =>
              const EditorPage(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          editorActionsProvider.overrideWithValue(actions),
          vaultRepositoryProvider.overrideWithValue(actions.repository),
          effectiveAppSessionProvider.overrideWith(
            (Ref ref) async => const AppSessionState(
              status: AppLockStatus.unlocked,
              session: session,
            ),
          ),
          recoveryMetadataProvider.overrideWith(
            (Ref ref) async => _recoveryMetadata,
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: appTestTheme(),
          locale: appZhLocale,
          supportedLocales: appSupportedLocales,
          localizationsDelegates: appLocalizationsDelegates,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('新增'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).first, '準備捨棄的標題');
    await tester.pump();
    await tester.tap(find.byKey(const Key('editor-top-bar-close')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(testL10n.editorDiscardDraftConfirm));
    await tester.pumpAndSettle();

    expect(find.byType(EditorPage), findsNothing);
    expect(actions.draft, isNull);

    await tester.tap(find.text('新增'));
    await tester.pumpAndSettle();

    expect(find.byType(EditorPage), findsOneWidget);
    expect(find.text(testL10n.editorRestoreDraftTitle), findsNothing);
  });
}

final RecoveryMetadata _recoveryMetadata = RecoveryMetadata(
  vaultId: 'vault-1',
  recoveryEnabled: true,
  recoveryKeyVersion: 1,
  recoveryKeyHint: 'hint',
  createdAt: DateTime(2026, 6, 18),
  kdf: KdfDescriptor.argon2idRecovery(
    saltBytes: List<int>.generate(16, (int index) => index),
  ),
);
