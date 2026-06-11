import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/features/session/state/app_session_state.dart';
import 'package:quill_diary/features/settings/vault_transfer_access.dart';

void main() {
  group('VaultTransferAccess.fromContext', () {
    test('已解鎖時可備份與還原', () {
      final VaultTransferAccess access = VaultTransferAccess.fromContext(
        hasUnlockedSession: true,
        hasRecoveryKey: true,
        lockStatus: AppLockStatus.unlocked,
      );
      expect(access.canBackup, isTrue);
      expect(access.canRestore, isTrue);
      expect(access.backupDisabledReason, isNull);
      expect(access.restoreDisabledReason, isNull);
    });

    test('未解鎖且無復原金鑰時僅可還原', () {
      final VaultTransferAccess access = VaultTransferAccess.fromContext(
        hasUnlockedSession: false,
        hasRecoveryKey: false,
        lockStatus: AppLockStatus.locked,
      );
      expect(access.canBackup, isFalse);
      expect(access.canRestore, isTrue);
      expect(access.backupDisabledReason, VaultTransferCopy.needsUnlockForBackup);
      expect(access.restoreDisabledReason, isNull);
    });

    test('recoveryRequired 時可還原但不可備份', () {
      final VaultTransferAccess access = VaultTransferAccess.fromContext(
        hasUnlockedSession: false,
        hasRecoveryKey: true,
        lockStatus: AppLockStatus.recoveryRequired,
      );
      expect(access.canBackup, isFalse);
      expect(access.canRestore, isTrue);
      expect(access.restoreDisabledReason, isNull);
    });

    test('locked 且已有復原金鑰時不可還原', () {
      final VaultTransferAccess access = VaultTransferAccess.fromContext(
        hasUnlockedSession: false,
        hasRecoveryKey: true,
        lockStatus: AppLockStatus.locked,
      );
      expect(access.canBackup, isFalse);
      expect(access.canRestore, isFalse);
      expect(access.restoreDisabledReason, VaultTransferCopy.needsUnlockForRestore);
    });

    test('未解鎖且僅缺復原金鑰時備份提示建立金鑰', () {
      final VaultTransferAccess access = VaultTransferAccess.fromContext(
        hasUnlockedSession: true,
        hasRecoveryKey: false,
        lockStatus: AppLockStatus.unlocked,
      );
      expect(access.canBackup, isFalse);
      expect(access.canRestore, isTrue);
      expect(
        access.backupDisabledReason,
        VaultTransferCopy.needsRecoveryKeyForBackup,
      );
    });
  });

  group('ensureCanRestore', () {
    test('canRestore 為 false 時拋 StateError', () {
      final VaultTransferAccess access = VaultTransferAccess.fromContext(
        hasUnlockedSession: false,
        hasRecoveryKey: true,
        lockStatus: AppLockStatus.locked,
      );
      expect(
        () => access.ensureCanRestore(),
        throwsA(
          isA<StateError>().having(
            (StateError error) => error.message,
            'message',
            VaultTransferCopy.needsUnlockForRestore,
          ),
        ),
      );
    });
  });
}
