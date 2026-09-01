import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/infrastructure/drive/google_drive_error.dart';
import 'package:quill_diary/shared/utils/user_facing_error.dart';

import '../../helpers/shared/test_l10n.dart';

void main() {
  test('Google Drive 錯誤依 App 語言顯示對應文案', () {
    const GoogleDriveException error = GoogleDriveException(
      GoogleDriveErrorCode.oauthConfiguration,
    );

    expect(error.localizedMessage(testZhL10n), contains('Google 登入設定'));
    expect(error.localizedMessage(testEnL10n), contains('Google sign-in'));
  });

  test('清理失敗文案保留數量，不顯示底層錯誤', () {
    const GoogleDriveException error = GoogleDriveException(
      GoogleDriveErrorCode.pruneFailed,
      failedCount: 2,
      totalCount: 5,
    );

    expect(error.localizedMessage(testZhL10n), '部分舊備份刪除失敗（2/5）。');
    expect(
      error.localizedMessage(testEnL10n),
      'Some old backups could not be deleted (2/5).',
    );
  });

  test('原生 OAuth error code 會轉成穩定的本地化錯誤', () {
    final GoogleDriveException? error = googleDriveExceptionForNativeAuthCode(
      'google_drive_auth_network',
    );

    expect(error, isNotNull);
    expect(error!.localizedMessage(testZhL10n), '目前無法連上 Google 服務，請檢查網路後再試。');
    expect(
      error.localizedMessage(testEnL10n),
      'Google services are unavailable. Check your connection and try again.',
    );
  });

  test('原生 OAuth 設定錯誤會顯示設定提示', () {
    final GoogleDriveException? error = googleDriveExceptionForNativeAuthCode(
      'google_drive_auth_configuration',
    );

    expect(error?.localizedMessage(testZhL10n), contains('設定'));
    expect(error?.localizedMessage(testEnL10n), contains('configured'));
  });

  test('未分類的原生例外不會直接顯示原始內容', () {
    final PlatformException error = PlatformException(
      code: 'unknown',
      message: 'HTTP 503: C:\\private\\backup.zip',
    );

    expect(userFacingErrorMessage(error, l10n: testZhL10n), '操作失敗，請稍後再試。');
    expect(
      userFacingErrorMessage(error, l10n: testEnL10n),
      'The operation failed. Please try again later.',
    );
  });
}
