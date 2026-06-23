import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/recovery/kdf_descriptor.dart';
import 'package:quill_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/features/editor/application/editor_actions.dart';
import 'package:quill_diary/features/editor/pages/editor_page.dart';
import 'package:quill_diary/features/session/presentation/session_locked_pane.dart';
import 'package:quill_diary/features/session/providers/session_providers.dart';
import 'package:quill_diary/features/settings/providers/settings_providers.dart';
import 'package:quill_diary/l10n/l10n.dart';

import '../../helpers/fake_editor_actions.dart';
import '../../helpers/mutable_app_session.dart';

void main() {
  final UnlockedVaultSession session = UnlockedVaultSession(
    vaultId: 'vault-1',
    trustedDevice: false,
    recoveryWrapKey: List<int>.generate(32, (int index) => index),
  );
  final RecoveryMetadata recoveryMetadata = RecoveryMetadata(
    vaultId: 'vault-1',
    recoveryEnabled: true,
    recoveryKeyVersion: 1,
    recoveryKeyHint: 'hint',
    createdAt: DateTime(2026, 6, 18, 9),
    kdf: KdfDescriptor.argon2idRecovery(
      saltBytes: List<int>.generate(16, (int index) => index),
    ),
  );

  testWidgets('編輯中鎖定後解鎖不顯示草稿還原對話框', (WidgetTester tester) async {
    final ProviderContainer container = buildMutableAppSessionContainer(
      overrides: [
        sessionSupportedPlatformProvider.overrideWith((Ref ref) => true),
        recoveryMetadataProvider.overrideWith(
          (Ref ref) async => recoveryMetadata,
        ),
        editorActionsProvider.overrideWith((Ref ref) => FakeEditorActions()),
      ],
    );
    addTearDown(container.dispose);
    container.read(mutableAppSessionProvider.notifier).unlock(session);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: appZhLocale,
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          supportedLocales: appSupportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const EditorPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.enterText(find.byType(TextField).at(1), '鎖定前內容');
    await tester.pump();

    container.read(mutableAppSessionProvider.notifier).lock();
    await tester.pump();
    await tester.pump();

    expect(find.byType(SessionBlockedPane), findsOneWidget);

    container.read(mutableAppSessionProvider.notifier).unlock(session);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('發現未完成的草稿'), findsNothing);
    expect(find.text('鎖定前內容'), findsOneWidget);
  });
}
