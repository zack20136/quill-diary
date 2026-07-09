import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/application/session/app_lifecycle_session_bridge.dart';
import 'package:quill_diary/application/session/app_session_controller.dart';
import 'package:quill_diary/application/session/providers/session_providers.dart';
import 'package:quill_diary/application/session/state/app_session_state.dart';
import 'package:quill_diary/application/session/state/session_lock_reason.dart';
import 'package:quill_diary/domain/recovery/kdf_descriptor.dart';
import 'package:quill_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/application/settings/personalization_providers.dart';
import 'package:quill_diary/infrastructure/preferences/editor_typography_preferences.dart';
import 'package:quill_diary/infrastructure/preferences/personalization_preferences.dart';
import 'package:quill_diary/infrastructure/preferences/user_preferences.dart';
import 'package:quill_diary/infrastructure/storage/storage_providers.dart';
import 'package:quill_diary/shared/platform/vault_platform_support.dart';

import '../../helpers/session/fake_session_vault_repository.dart';

void main() {
  testWidgets('background 後 resumed 會透過真實 controller 觸發 trusted unlock', (
    WidgetTester tester,
  ) async {
    late WidgetRef ref;
    final FakeSessionVaultRepository repository = FakeSessionVaultRepository(
      metadata: _fakeMetadata(),
      hasTrustedDevice: true,
      openTrustedSessionResult: const UnlockedVaultSession(
        vaultId: 'vault-resume-unlock',
        trustedDevice: true,
        recoveryWrapKey: <int>[1, 2, 3],
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vaultPlatformSupportProvider.overrideWith((Ref ref) => true),
          vaultRepositoryProvider.overrideWithValue(repository),
          personalizationPreferencesProvider.overrideWith(
            _FixedPersonalizationPreferencesController.new,
          ),
        ],
        child: Consumer(
          builder: (BuildContext context, WidgetRef widgetRef, Widget? child) {
            ref = widgetRef;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final AppSessionController controller = ref.read(
      appSessionProvider.notifier,
    );
    controller.adoptBootstrapState(
      const AppSessionState(
        status: AppLockStatus.locked,
        lockReason: SessionLockReason.inactivity,
      ),
    );
    controller.markTrustedUnlockBootstrapFinished();
    controller.armLifecycleResumeUnlock();

    final AppLifecycleSessionBridge bridge = AppLifecycleSessionBridge(
      ref,
      resumeUnlockDelay: Duration.zero,
    );
    addTearDown(bridge.detach);
    bridge.attach();

    bridge.didChangeAppLifecycleState(AppLifecycleState.paused);
    await tester.pump();
    bridge.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();

    expect(repository.openTrustedSessionCalls, 1);
    expect(ref.read(appSessionProvider).status, AppLockStatus.unlocked);
  });

  testWidgets('startup cycle 改變會取消舊的 pending resume unlock', (
    WidgetTester tester,
  ) async {
    late WidgetRef ref;
    final FakeSessionVaultRepository repository = FakeSessionVaultRepository(
      metadata: _fakeMetadata(),
      hasTrustedDevice: true,
      openTrustedSessionResult: const UnlockedVaultSession(
        vaultId: 'vault-cancel-unlock',
        trustedDevice: true,
        recoveryWrapKey: <int>[4, 5, 6],
      ),
    )..openTrustedSessionDelay = const Duration(milliseconds: 5);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vaultPlatformSupportProvider.overrideWith((Ref ref) => true),
          vaultRepositoryProvider.overrideWithValue(repository),
          personalizationPreferencesProvider.overrideWith(
            _FixedPersonalizationPreferencesController.new,
          ),
        ],
        child: Consumer(
          builder: (BuildContext context, WidgetRef widgetRef, Widget? child) {
            ref = widgetRef;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final AppSessionController controller = ref.read(
      appSessionProvider.notifier,
    );
    controller.adoptBootstrapState(
      const AppSessionState(
        status: AppLockStatus.locked,
        lockReason: SessionLockReason.inactivity,
      ),
    );
    controller.markTrustedUnlockBootstrapFinished();
    controller.armLifecycleResumeUnlock();

    final AppLifecycleSessionBridge bridge = AppLifecycleSessionBridge(
      ref,
      resumeUnlockDelay: const Duration(milliseconds: 20),
    );
    addTearDown(bridge.detach);
    bridge.attach();

    bridge.didChangeAppLifecycleState(AppLifecycleState.paused);
    await tester.pump();
    bridge.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();

    await controller.beginPostRestoreStartup();
    controller.markTrustedUnlockBootstrapFinished();
    bridge.didChangeAppLifecycleState(AppLifecycleState.inactive);
    await tester.pump(const Duration(milliseconds: 30));

    expect(repository.openTrustedSessionCalls, 0);
    expect(ref.read(appSessionProvider).status, AppLockStatus.unlocking);
  });
}

RecoveryMetadata _fakeMetadata() {
  return RecoveryMetadata(
    vaultId: 'vault-lifecycle',
    recoveryEnabled: true,
    recoveryKeyVersion: 1,
    recoveryKeyHint: '1234',
    createdAt: DateTime(2024, 1, 1),
    kdf: KdfDescriptor.argon2idRecovery(saltBytes: List<int>.filled(16, 1)),
  );
}

class _FixedPersonalizationPreferencesController
    extends PersonalizationPreferencesController {
  @override
  Future<PersonalizationPreferences> build() async {
    return const PersonalizationPreferences(
      imageCompressPreset: ImageCompressPreset.standard,
      typography: EditorTypographyPreferences.defaults,
      themeMode: AppThemeModePreference.system,
      sessionTimeoutMinutes: SessionBackgroundTimeoutMinutes.three,
      locale: AppLanguage.zh,
    );
  }
}
