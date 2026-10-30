import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/application/session/session_state.dart';
import 'package:quill_diary/application/settings/settings_capabilities.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';

void main() {
  const UnlockedVaultSession session = UnlockedVaultSession(
    vaultId: 'vlt_settings_caps',
    trustedDevice: true,
    recoveryWrapKey: <int>[1],
  );

  test('尚無復原金鑰時允許管理 Drive 帳號，已有金鑰且未解鎖時禁止', () {
    final SettingsPageCapabilities firstLaunch =
        SettingsPageCapabilities.fromSessionState(
          sessionState: const AppSessionState(status: AppLockStatus.unlocked),
          hasRecoveryKey: false,
        );
    expect(firstLaunch.canManageDriveAccount, isTrue);

    final SettingsPageCapabilities lockedVault =
        SettingsPageCapabilities.fromSessionState(
          sessionState: const AppSessionState(status: AppLockStatus.locked),
          hasRecoveryKey: true,
        );
    expect(lockedVault.canManageDriveAccount, isFalse);

    final SettingsPageCapabilities recoveryRequired =
        SettingsPageCapabilities.fromSessionState(
          sessionState: const AppSessionState(
            status: AppLockStatus.recoveryRequired,
          ),
          hasRecoveryKey: true,
        );
    expect(recoveryRequired.canManageDriveAccount, isFalse);

    final SettingsPageCapabilities unlocked =
        SettingsPageCapabilities.fromSessionState(
          sessionState: const AppSessionState(
            status: AppLockStatus.unlocked,
            session: session,
          ),
          hasRecoveryKey: true,
        );
    expect(unlocked.canManageDriveAccount, isTrue);
  });
}
