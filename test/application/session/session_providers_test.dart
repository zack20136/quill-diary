import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/application/restore/post_restore_session.dart';
import 'package:quill_diary/application/session/session_providers.dart';
import 'package:quill_diary/application/session/session_state.dart';
import 'package:quill_diary/application/settings/personalization_providers.dart';
import 'package:quill_diary/application/settings/settings_providers.dart';
import 'package:quill_diary/application/vault/vault_providers.dart';
import 'package:quill_diary/domain/preferences/personalization_preferences.dart';
import 'package:quill_diary/domain/recovery/kdf_descriptor.dart';
import 'package:quill_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/infrastructure/security/app_unlock_mode.dart';
import 'package:quill_diary/shared/platform/vault_platform_support.dart';

import '../../helpers/session/fake_session_vault_repository.dart';

void main() {
  test('effectiveAppSessionProvider 會優先回傳本地 session state', () async {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        vaultPlatformSupportProvider.overrideWith((Ref ref) => true),
        vaultRepositoryProvider.overrideWithValue(
          FakeSessionVaultRepository(metadata: null),
        ),
        personalizationPreferencesProvider.overrideWith(
          _FixedPersonalizationPreferencesController.new,
        ),
      ],
    );
    addTearDown(container.dispose);

    container
        .read(appSessionProvider.notifier)
        .activateSession(
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

  test(
    'sessionStartupProvider 在沒有 recovery metadata 時回傳 unlocked 提示',
    () async {
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
    },
  );

  test(
    'sessionStartupProvider 在 trusted device 可用時會完成 trusted unlock',
    () async {
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
    },
  );

  test('讀取已啟動的日記庫中繼資料不會再次初始化', () async {
    final metadata = _fakeMetadata();
    final repository = FakeSessionVaultRepository(
      metadata: metadata,
      initializeError: StateError('不可再次初始化'),
    );
    final container = _buildSessionContainer(repository);
    addTearDown(container.dispose);
    container
        .read(appSessionProvider.notifier)
        .adoptBootstrapState(
          const AppSessionState(status: AppLockStatus.recoveryRequired),
        );
    expect(
      await container.read(recoveryMetadataProvider.future),
      same(metadata),
    );
  });

  test('提交後裝置信任更新失敗時保留已驗證的復原工作階段', () async {
    final repository = _UnavailableDeviceTrustRepository();
    final container = _buildSessionContainer(repository);
    addTearDown(container.dispose);
    const restored = UnlockedVaultSession(
      vaultId: 'vault-restored',
      trustedDevice: false,
      recoveryWrapKey: <int>[1, 2, 3],
    );
    final postRestore = Provider(
      (ref) =>
          () => finishRestoreSession(ref, restored),
    );

    await container.read(postRestore)();

    expect(container.read(appSessionProvider).status, AppLockStatus.unlocked);
    expect(
      (await container.read(effectiveAppSessionProvider.future)).session,
      same(restored),
    );
  });
}

ProviderContainer _buildSessionContainer(
  FakeSessionVaultRepository repository,
) {
  return ProviderContainer(
    overrides: [
      vaultPlatformSupportProvider.overrideWith((Ref ref) => true),
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
    kdf: KdfDescriptor.argon2idRecovery(saltBytes: List<int>.filled(16, 1)),
  );
}

class _UnavailableDeviceTrustRepository extends FakeSessionVaultRepository {
  @override
  Future<UnlockedVaultSession> ensureKeystoreMatchesUnlockMode(
    UnlockedVaultSession session, {
    AppUnlockMode? targetMode,
  }) async {
    throw StateError('裝置信任更新失敗');
  }
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
