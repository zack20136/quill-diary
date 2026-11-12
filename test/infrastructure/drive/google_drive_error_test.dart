import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/application/errors/user_facing_error.dart';
import 'package:quill_diary/application/transfer/transfer_feedback.dart';
import 'package:quill_diary/infrastructure/drive/google_drive_error.dart';

import '../../helpers/shared/test_l10n.dart';

void main() {
  test('同一 Google Drive 錯誤依 App 語言切換文案', () {
    const GoogleDriveException error = GoogleDriveException(
      GoogleDriveErrorCode.oauthConfiguration,
    );

    expect(
      error.localizedMessage(testZhL10n),
      isNot(error.localizedMessage(testEnL10n)),
    );
  });

  test('清理失敗文案保留數量，不顯示底層錯誤', () {
    const GoogleDriveException error = GoogleDriveException(
      GoogleDriveErrorCode.pruneFailed,
      failedCount: 2,
      totalCount: 5,
    );

    expect(
      error.localizedMessage(testZhL10n),
      testZhL10n.driveErrorPruneFailed(2, 5),
    );
    expect(
      error.localizedMessage(testEnL10n),
      testEnL10n.driveErrorPruneFailed(2, 5),
    );
  });

  test('原生 OAuth error code 對應到固定錯誤碼', () {
    expect(
      googleDriveExceptionForNativeAuthCode('google_drive_auth_network')?.code,
      GoogleDriveErrorCode.oauthNetwork,
    );
    expect(
      googleDriveExceptionForNativeAuthCode('google_drive_auth_configuration')
          ?.code,
      GoogleDriveErrorCode.oauthConfiguration,
    );
  });

  test('未分類的原生例外不會直接顯示原始內容', () {
    final PlatformException error = PlatformException(
      code: 'unknown',
      message: 'HTTP 503: C:\\private\\backup.zip',
    );

    expect(
      userFacingErrorMessage(error, l10n: testZhL10n),
      testZhL10n.userFacingErrorDefaultMessage,
    );
    expect(
      userFacingErrorMessage(error, l10n: testEnL10n),
      testEnL10n.userFacingErrorDefaultMessage,
    );
  });
}
