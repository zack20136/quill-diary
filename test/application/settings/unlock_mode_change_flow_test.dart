import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/application/session/providers/session_providers.dart';
import 'package:quill_diary/application/session/state/app_session_state.dart';
import 'package:quill_diary/application/settings/unlock_mode_change_flow.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/infrastructure/security/app_unlock_mode.dart';
import 'package:quill_diary/infrastructure/security/security_providers.dart';
import 'package:quill_diary/infrastructure/storage/storage_providers.dart';

import '../../helpers/session/fake_app_lock_service.dart';
import '../../helpers/session/fake_session_vault_repository.dart';

final _unlockModeChangeResultProvider = FutureProvider.family
    .autoDispose<UnlockModeChangeOutcome, AppUnlockMode>((Ref ref, mode) async {
      return applyUnlockModeChange(ref: ref, mode: mode);
    });

class _LockedAppSession extends AppSessionController {
  @override
  AppSessionState build() =>
      const AppSessionState(status: AppLockStatus.locked);
}

class _UnlockedAppSession extends AppSessionController {
  _UnlockedAppSession(this._session);

  final UnlockedVaultSession _session;

  @override
  AppSessionState build() =>
      AppSessionState(status: AppLockStatus.unlocked, session: _session);
}

class _TrackingSessionVaultRepository extends FakeSessionVaultRepository {
  _TrackingSessionVaultRepository({required this.nextSession});

  final UnlockedVaultSession nextSession;
  AppUnlockMode? lastTargetMode;

  @override
  Future<UnlockedVaultSession> ensureKeystoreMatchesUnlockMode(
    UnlockedVaultSession session, {
    AppUnlockMode? targetMode,
  }) async {
    lastTargetMode = targetMode;
    return nextSession;
  }
}

void main() {
  group('applyUnlockModeChange', () {
    test('沒有解鎖中的 session 時回傳 requiresUnlockedSession', () async {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          appSessionProvider.overrideWith(_LockedAppSession.new),
          effectiveAppSessionProvider.overrideWith(
            (Ref ref) async => ref.watch(appSessionProvider),
          ),
        ],
      );
      addTearDown(container.dispose);

      final UnlockModeChangeOutcome outcome = await container.read(
        _unlockModeChangeResultProvider(AppUnlockMode.deviceLock).future,
      );

      expect(outcome, isA<UnlockModeChangeMessage>());
      expect(
        (outcome as UnlockModeChangeMessage).kind,
        UnlockModeChangeMessageKind.requiresUnlockedSession,
      );
    });

    test('成功切換時會套用新模式並更新 session', () async {
      final UnlockedVaultSession originalSession = UnlockedVaultSession(
        vaultId: 'vault-unlock-mode-test',
        trustedDevice: true,
        recoveryWrapKey: const <int>[1, 2, 3],
      );
      final UnlockedVaultSession syncedSession = UnlockedVaultSession(
        vaultId: 'vault-unlock-mode-test',
        trustedDevice: false,
        recoveryWrapKey: const <int>[4, 5, 6],
      );
      final FakeAppLockService appLock = FakeAppLockService(
        unlockMode: AppUnlockMode.deviceLock,
      );
      final _TrackingSessionVaultRepository repository =
          _TrackingSessionVaultRepository(nextSession: syncedSession);
      final ProviderContainer container = ProviderContainer(
        overrides: [
          appLockServiceProvider.overrideWithValue(appLock),
          vaultRepositoryProvider.overrideWithValue(repository),
          appSessionProvider.overrideWith(
            () => _UnlockedAppSession(originalSession),
          ),
          effectiveAppSessionProvider.overrideWith(
            (Ref ref) async => ref.watch(appSessionProvider),
          ),
        ],
      );
      addTearDown(container.dispose);

      final UnlockModeChangeOutcome outcome = await container.read(
        _unlockModeChangeResultProvider(AppUnlockMode.none).future,
      );

      expect(outcome, isA<UnlockModeChangeSucceeded>());
      expect(repository.lastTargetMode, AppUnlockMode.none);
      expect(await appLock.getUnlockMode(), AppUnlockMode.none);
      expect(container.read(appSessionProvider).session, same(syncedSession));
    });
  });
}
