import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/features/session/session_messages.dart';
import 'package:quill_diary/features/session/state/app_session_state.dart';
import 'package:quill_diary/infrastructure/security/device_key_manager.dart';

import '../helpers/test_l10n.dart';

void main() {
  test('DeviceKeyAuthFailedException maps to retry verification message', () {
    expect(
      friendlySessionErrorMessage(
        testL10n,
        const DeviceKeyAuthFailedException('bio failed'),
      ),
      sessionLockedRetryVerificationMessage(testL10n),
    );
  });

  test(
    'DeviceKeyUserCancelledException maps to retry verification message',
    () {
      expect(
        friendlySessionErrorMessage(
          testL10n,
          const DeviceKeyUserCancelledException(),
        ),
        sessionLockedRetryVerificationMessage(testL10n),
      );
    },
  );

  test('DeviceKeyAuthTimeoutException maps to retry verification message', () {
    expect(
      friendlySessionErrorMessage(
        testL10n,
        const DeviceKeyAuthTimeoutException(),
      ),
      sessionLockedRetryVerificationMessage(testL10n),
    );
  });

  test('DeviceKeyNoDeviceCredentialException surfaces its message', () {
    const DeviceKeyNoDeviceCredentialException exception =
        DeviceKeyNoDeviceCredentialException();
    expect(friendlySessionErrorMessage(testL10n, exception), exception.message);
  });

  test('technical StateError falls back to generic unlock failure message', () {
    expect(
      friendlySessionErrorMessage(
        testL10n,
        StateError('java.lang.IllegalStateException'),
      ),
      sessionUnlockFailedMessage(testL10n),
    );
  });

  test('fatal restore snackbar does not append raw session message', () {
    expect(
      snackbarMessageForPostRestore(
        testL10n,
        AppLockStatus.fatalError,
        sessionMessage: 'java.lang.RuntimeException: keystore exploded',
      ),
      sessionRestoreStartupFailedMessage(testL10n),
    );
  });

  test('fatal restore snackbar maps index unreadable to recovery guidance', () {
    expect(
      snackbarMessageForPostRestore(
        testL10n,
        AppLockStatus.fatalError,
        sessionMessage: sessionIndexDatabaseUnreadableMessage(testL10n),
      ),
      sessionRestoreSuccessRecoveryRequiredMessage(testL10n),
    );
  });

  test('fatal restore snackbar surfaces user-facing session message', () {
    expect(
      snackbarMessageForPostRestore(
        testL10n,
        AppLockStatus.fatalError,
        sessionMessage: '可信裝置資料已失效，請重新使用復原金鑰解鎖。',
      ),
      '可信裝置資料已失效，請重新使用復原金鑰解鎖。',
    );
  });
}
