import 'package:flutter_test/flutter_test.dart';
import 'package:quill_lock_diary/features/session/session_messages.dart';
import 'package:quill_lock_diary/features/session/state/app_session_state.dart';
import 'package:quill_lock_diary/infrastructure/security/device_key_manager.dart';

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
}
