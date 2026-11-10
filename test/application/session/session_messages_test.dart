import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/application/session/session_messages.dart';
import 'package:quill_diary/application/session/session_state.dart';

import '../../helpers/shared/test_l10n.dart';

void main() {
  test('還原後依狀態選擇對應文案，其餘狀態視為啟動失敗', () {
    expect(
      snackbarMessageForPostRestore(testL10n, AppLockStatus.unlocked),
      testL10n.sessionRestoreSuccessUnlockedMessage,
    );
    expect(
      snackbarMessageForPostRestore(testL10n, AppLockStatus.locked),
      testL10n.sessionRestoreSuccessLockedMessage,
    );
    expect(
      snackbarMessageForPostRestore(testL10n, AppLockStatus.recoveryRequired),
      testL10n.sessionRestoreSuccessRecoveryRequiredMessage,
    );
    for (final status in [
      AppLockStatus.fatalError,
      AppLockStatus.unlocking,
      AppLockStatus.uninitialized,
    ]) {
      expect(
        snackbarMessageForPostRestore(testL10n, status),
        testL10n.sessionRestoreStartupFailedMessage,
        reason: status.name,
      );
    }
  });
}
