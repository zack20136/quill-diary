import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/features/session/state/app_session_state.dart';
import 'package:quill_diary/features/settings/settings_page_access.dart';
import 'package:quill_diary/l10n/l10n.dart';

void main() {
  final AppLocalizations zhL10n = lookupAppLocalizations(appZhLocale);
  const UnlockedVaultSession sampleSession = UnlockedVaultSession(
    vaultId: 'vlt_test',
    trustedDevice: true,
    recoveryWrapKey: <int>[1, 2, 3, 4],
    deviceSlotId: 'slot-a',
  );

  group('SettingsPageAccess.fromSession', () {
    test('已解鎖時敏感操作皆可用', () {
      final SettingsPageAccess access = SettingsPageAccess.fromSession(
        l10n: zhL10n,
        sessionState: const AppSessionState(
          status: AppLockStatus.unlocked,
          session: sampleSession,
        ),
        hasRecoveryKey: true,
      );

      expect(access.hasUnlockedSession, isTrue);
      expect(access.canCreateRecoveryKey, isFalse);
      expect(access.canManageDriveAccount, isTrue);
      expect(access.canChangeSessionTimeout, isTrue);
      expect(access.vaultTransfer.canBackup, isTrue);
      expect(access.vaultTransfer.canRestore, isTrue);
    });

    test('新 App 尚未建立 RK 時可建立（unlocked 但無 session）', () {
      final SettingsPageAccess access = SettingsPageAccess.fromSession(
        l10n: zhL10n,
        sessionState: const AppSessionState(status: AppLockStatus.unlocked),
        hasRecoveryKey: false,
      );

      expect(access.hasUnlockedSession, isFalse);
      expect(access.canCreateRecoveryKey, isTrue);
      expect(access.canChangeSessionTimeout, isFalse);
    });

    test('locked 且無復原金鑰時仍可建立 RK', () {
      final SettingsPageAccess access = SettingsPageAccess.fromSession(
        l10n: zhL10n,
        sessionState: const AppSessionState(status: AppLockStatus.locked),
        hasRecoveryKey: false,
      );

      expect(access.canCreateRecoveryKey, isTrue);
      expect(access.canManageDriveAccount, isFalse);
    });

    test('locked 且已有復原金鑰時停用敏感操作', () {
      final SettingsPageAccess access = SettingsPageAccess.fromSession(
        l10n: zhL10n,
        sessionState: const AppSessionState(status: AppLockStatus.locked),
        hasRecoveryKey: true,
      );

      expect(access.hasUnlockedSession, isFalse);
      expect(access.canCreateRecoveryKey, isFalse);
      expect(access.canManageDriveAccount, isFalse);
      expect(access.canChangeSessionTimeout, isFalse);
      expect(access.vaultTransfer.canBackup, isFalse);
      expect(access.vaultTransfer.canRestore, isFalse);
    });

    test('locked 且無復原金鑰時仍允許還原', () {
      final SettingsPageAccess access = SettingsPageAccess.fromSession(
        l10n: zhL10n,
        sessionState: const AppSessionState(status: AppLockStatus.locked),
        hasRecoveryKey: false,
      );

      expect(access.vaultTransfer.canRestore, isTrue);
      expect(access.canManageDriveAccount, isFalse);
    });

    test('recoveryRequired 時可還原但不可建立 RK', () {
      final SettingsPageAccess access = SettingsPageAccess.fromSession(
        l10n: zhL10n,
        sessionState: const AppSessionState(
          status: AppLockStatus.recoveryRequired,
        ),
        hasRecoveryKey: true,
      );

      expect(access.canCreateRecoveryKey, isFalse);
      expect(access.vaultTransfer.canRestore, isTrue);
    });
  });
}
