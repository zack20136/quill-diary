import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/application/session/state/app_session_state.dart';
import 'package:quill_diary/application/settings/vault_transfer_capabilities.dart';

import '../../helpers/shared/test_l10n.dart';

void main() {
  test('依 session、復原金鑰與鎖定狀態決定備份和還原權限', () {
    final List<
      ({
        String name,
        bool hasUnlockedSession,
        bool hasRecoveryKey,
        AppLockStatus lockStatus,
        bool canBackup,
        bool canRestore,
      })
    > cases = <
      ({
        String name,
        bool hasUnlockedSession,
        bool hasRecoveryKey,
        AppLockStatus lockStatus,
        bool canBackup,
        bool canRestore,
      })
    >[
      (
        name: '鎖定且尚未建立復原金鑰',
        hasUnlockedSession: false,
        hasRecoveryKey: false,
        lockStatus: AppLockStatus.locked,
        canBackup: false,
        canRestore: true,
      ),
      (
        name: '鎖定且已有復原金鑰',
        hasUnlockedSession: false,
        hasRecoveryKey: true,
        lockStatus: AppLockStatus.locked,
        canBackup: false,
        canRestore: false,
      ),
      (
        name: '等待輸入復原金鑰',
        hasUnlockedSession: false,
        hasRecoveryKey: true,
        lockStatus: AppLockStatus.recoveryRequired,
        canBackup: false,
        canRestore: true,
      ),
      (
        name: '已解鎖但尚未建立復原金鑰',
        hasUnlockedSession: true,
        hasRecoveryKey: false,
        lockStatus: AppLockStatus.unlocked,
        canBackup: false,
        canRestore: true,
      ),
      (
        name: '已解鎖且已有復原金鑰',
        hasUnlockedSession: true,
        hasRecoveryKey: true,
        lockStatus: AppLockStatus.unlocked,
        canBackup: true,
        canRestore: true,
      ),
    ];

    for (final caseData in cases) {
      final VaultTransferCapabilities capabilities =
          VaultTransferCapabilities.fromSessionContext(
            l10n: testL10n,
            hasUnlockedSession: caseData.hasUnlockedSession,
            hasRecoveryKey: caseData.hasRecoveryKey,
            lockStatus: caseData.lockStatus,
          );

      expect(capabilities.canBackup, caseData.canBackup, reason: caseData.name);
      expect(
        capabilities.canRestore,
        caseData.canRestore,
        reason: caseData.name,
      );
    }
  });

  test('禁止還原時會使用在地化錯誤訊息拒絕操作', () {
    final VaultTransferCapabilities capabilities =
        VaultTransferCapabilities.fromSessionContext(
          l10n: testL10n,
          hasUnlockedSession: false,
          hasRecoveryKey: true,
          lockStatus: AppLockStatus.locked,
        );

    expect(
      () => capabilities.ensureCanRestore(testL10n),
      throwsA(isA<StateError>().having(
        (StateError error) => error.message,
        'message',
        testL10n.vaultTransferNeedsUnlockForRestore,
      )),
    );
  });
}
