import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:quill_lock_diary/infrastructure/drive/google_drive_oauth_errors.dart';

void main() {
  group('looksLikeGoogleOAuthMisconfiguration', () {
    test('detects CredentialManager misreported cancellation', () {
      expect(
        looksLikeGoogleOAuthMisconfiguration('Activity is cancelled by the user'),
        isTrue,
      );
      expect(
        looksLikeGoogleOAuthMisconfiguration('[16] Account reauth failed.'),
        isTrue,
      );
    });

    test('does not treat empty detail as misconfiguration', () {
      expect(looksLikeGoogleOAuthMisconfiguration(null), isFalse);
      expect(looksLikeGoogleOAuthMisconfiguration(''), isFalse);
    });
  });

  group('userMessageForGoogleSignIn', () {
    test('canceled with reauth detail shows SHA-1 checklist', () {
      final String message = userMessageForGoogleSignIn(
        const GoogleSignInException(
          code: GoogleSignInExceptionCode.canceled,
          description: 'Account reauth failed.',
        ),
      );

      expect(message, contains(GoogleDriveOAuthFingerprints.releaseUploadSha1));
      expect(message, isNot(contains('你已取消 Google 登入')));
    });

    test('canceled without detail shows short cancellation message', () {
      final String message = userMessageForGoogleSignIn(
        const GoogleSignInException(
          code: GoogleSignInExceptionCode.canceled,
        ),
      );

      expect(message, contains('你已取消 Google 登入'));
      expect(message, isNot(contains(GoogleDriveOAuthFingerprints.releaseUploadSha1)));
    });

    test('clientConfigurationError includes release SHA-1', () {
      final String message = userMessageForGoogleSignIn(
        const GoogleSignInException(
          code: GoogleSignInExceptionCode.clientConfigurationError,
        ),
      );

      expect(message, contains(GoogleDriveOAuthFingerprints.releaseUploadSha1));
      expect(message, contains('oauth_config.xml'));
    });
  });
}
