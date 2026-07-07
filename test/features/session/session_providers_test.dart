import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/recovery/kdf_descriptor.dart';
import 'package:quill_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/features/session/providers/session_providers.dart';
import 'package:quill_diary/features/session/state/app_session_state.dart';
import 'package:quill_diary/features/settings/providers/personalization_providers.dart';
import 'package:quill_diary/infrastructure/preferences/editor_typography_preferences.dart';
import 'package:quill_diary/infrastructure/preferences/personalization_preferences.dart';
import 'package:quill_diary/infrastructure/preferences/user_preferences.dart';
import 'package:quill_diary/shared/platform/vault_platform_support.dart';
import 'package:quill_diary/shared/providers/core_providers.dart';

import '../../helpers/session/fake_session_vault_repository.dart';

void main() {
  test('effectiveAppSessionProvider 會優先回傳本地 session state', () async {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        supportedPlatformProvider.overrideWith((Ref ref) => true),
        vaultRepositoryProvider.overrideWithValue(
          FakeSessionVaultRepository(metadata: null),
        ),
        personalizationPreferencesProvider.overrideWith(
          _FixedPersonalizationPreferencesController.new,
        ),
      ],
    );
    addTearDown(container.dispose);

    container.read(appSessionProvider.notifier).activateSession(
      const UnlockedVaultSession(
        vaultId: 'vault-local',
        trustedDevice: true,
        recoveryWrapKey: <int>[1],
      ),
    );

    final AppSessionState state = await container.read(
      effectiveAppSessionProvider.future,
    );

    expect(state.status, AppLockStatus.unlocked);
    expect(state.session?.vaultId, 'vault-local');
  });

  test('sessionStartupProvider 在沒有 recovery metadata 時回傳 unlocked 提示', () async {
    final FakeSessionVaultRepository repository = FakeSessionVaultRepository(
      metadata: null,
    );
    final ProviderContainer container = _buildSessionContainer(repository);
    addTearDown(container.dispose);

    final AppSessionState state = await container.read(
      sessionStartupProvider.future,
    );

    expect(state.status, AppLockStatus.unlocked);
    expect(state.message, isNotEmpty);
  });

  test('sessionStartupProvider 在 trusted device 可用時會完成 trusted unlock', () async {
    final FakeSessionVaultRepository repository = FakeSessionVaultRepository(
      metadata: _fakeMetadata(),
      hasTrustedDevice: true,
      openTrustedSessionResult: const UnlockedVaultSession(
        vaultId: 'vault-1',
        trustedDevice: true,
        recoveryWrapKey: <int>[1, 2, 3],
      ),
    );
    final ProviderContainer container = _buildSessionContainer(repository);
    addTearDown(container.dispose);

    final AppSessionState state = await container.read(
      sessionStartupProvider.future,
    );

    expect(state.status, AppLockStatus.unlocked);
    expect(state.session, isNotNull);
    expect(repository.openTrustedSessionCalls, 1);
  });
}

ProviderContainer _buildSessionContainer(FakeSessionVaultRepository repository) {
  return ProviderContainer(
    overrides: [
      supportedPlatformProvider.overrideWith((Ref ref) => true),
      vaultRepositoryProvider.overrideWithValue(repository),
      personalizationPreferencesProvider.overrideWith(
        _FixedPersonalizationPreferencesController.new,
      ),
    ],
  );
}

RecoveryMetadata _fakeMetadata() {
  return RecoveryMetadata(
    vaultId: 'vault-1',
    recoveryEnabled: true,
    recoveryKeyVersion: 1,
    recoveryKeyHint: '1234',
    createdAt: DateTime(2024, 1, 1),
    kdf: KdfDescriptor.argon2idRecovery(
      saltBytes: List<int>.filled(16, 1),
    ),
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
