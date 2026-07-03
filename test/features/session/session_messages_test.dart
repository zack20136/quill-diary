import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/features/session/session_messages.dart';
import 'package:quill_diary/features/session/state/app_session_state.dart';

import '../../helpers/shared/test_l10n.dart';

void main() {
  test('snackbarMessageForPostRestore 已解鎖時回傳成功文案', () {
    expect(
      snackbarMessageForPostRestore(testL10n, AppLockStatus.unlocked),
      testL10n.sessionRestoreSuccessUnlockedMessage,
    );
  });

  test('snackbarMessageForPostRestore 鎖定時回傳鎖定文案', () {
    expect(
      snackbarMessageForPostRestore(testL10n, AppLockStatus.locked),
      testL10n.sessionRestoreSuccessLockedMessage,
    );
  });

  test('snackbarMessageForPostRestore 需復原金鑰時回傳對應文案', () {
    expect(
      snackbarMessageForPostRestore(testL10n, AppLockStatus.recoveryRequired),
      testL10n.sessionRestoreSuccessRecoveryRequiredMessage,
    );
  });

  test('snackbarMessageForPostRestore fatalError 時回傳啟動失敗文案', () {
    expect(
      snackbarMessageForPostRestore(testL10n, AppLockStatus.fatalError),
      testL10n.sessionRestoreStartupFailedMessage,
    );
  });

  test('snackbarMessageForPostRestore 中間態不會回傳已解鎖成功文案', () {
    expect(
      snackbarMessageForPostRestore(testL10n, AppLockStatus.unlocking),
      testL10n.sessionRestoreStartupFailedMessage,
    );
    expect(
      snackbarMessageForPostRestore(testL10n, AppLockStatus.uninitialized),
      testL10n.sessionRestoreStartupFailedMessage,
    );
  });
}
