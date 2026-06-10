import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/features/session/session_messages.dart';
import 'package:quill_diary/features/session/state/app_session_state.dart';
import 'package:quill_diary/infrastructure/security/device_key_manager.dart';

void main() {
  test('DeviceKeyAuthFailedException maps to retry verification message', () {
    expect(
      friendlySessionErrorMessage(const DeviceKeyAuthFailedException('bio failed')),
      kLockedRetryVerificationMessage,
    );
  });

  test('DeviceKeyUserCancelledException maps to retry verification message', () {
    expect(
      friendlySessionErrorMessage(const DeviceKeyUserCancelledException()),
      kLockedRetryVerificationMessage,
    );
  });

  test('DeviceKeyAuthTimeoutException maps to retry verification message', () {
    expect(
      friendlySessionErrorMessage(const DeviceKeyAuthTimeoutException()),
      kLockedRetryVerificationMessage,
    );
  });

  test('DeviceKeyNoDeviceCredentialException surfaces its message', () {
    const DeviceKeyNoDeviceCredentialException exception =
        DeviceKeyNoDeviceCredentialException();
    expect(
      friendlySessionErrorMessage(exception),
      exception.message,
    );
  });

  test('technical StateError falls back to generic unlock failure message', () {
    expect(
      friendlySessionErrorMessage(StateError('java.lang.IllegalStateException')),
      kUnlockFailedMessage,
    );
  });

  test('fatal restore snackbar does not append raw session message', () {
    expect(
      snackbarMessageForPostRestore(
        AppLockStatus.fatalError,
        sessionMessage: 'java.lang.RuntimeException: keystore exploded',
      ),
      kRestoreStartupFailedMessage,
    );
  });

  test('fatal restore snackbar maps index unreadable to recovery guidance', () {
    expect(
      snackbarMessageForPostRestore(
        AppLockStatus.fatalError,
        sessionMessage: kIndexDatabaseUnreadableMessage,
      ),
      kRestoreSuccessRecoveryRequiredMessage,
    );
  });

  test('fatal restore snackbar surfaces user-facing session message', () {
    expect(
      snackbarMessageForPostRestore(
        AppLockStatus.fatalError,
        sessionMessage: '可信裝置資料已失效，請重新使用復原金鑰解鎖。',
      ),
      '可信裝置資料已失效，請重新使用復原金鑰解鎖。',
    );
  });
}
