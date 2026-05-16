import 'dart:io';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../config/oauth_config.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path/path.dart' as p;

final class DriveBackupFile {
  const DriveBackupFile({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  final String id;
  final String name;
  final DateTime? createdAt;
}

abstract class DriveBackupService {
  Future<void> ensureSignedIn();

  /// 清除本機 Google 登入狀態，讓下次重試時重新顯示登入／同意畫面。
  Future<void> resetSignInSessionForConsentRetry();

  /// 完成登入與 Drive 授權，供長時間作業重用同一個 client。
  Future<drive.DriveApi> createAuthorizedDriveApi();

  Future<String> uploadBackup(File backupFile, {drive.DriveApi? reuseApi});

  Future<List<DriveBackupFile>> listBackups();

  Future<File> downloadBackupById({
    required String fileId,
    required String fileName,
    required Directory destinationDirectory,
    drive.DriveApi? reuseApi,
  });
}

class GoogleDriveBackupService implements DriveBackupService {
  GoogleDriveBackupService({GoogleSignIn? googleSignIn})
      : _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final GoogleSignIn _googleSignIn;
  bool _initialized = false;

  static const List<String> _scopes = <String>[drive.DriveApi.driveAppdataScope];

  Future<void> _ensureInitialized() async {
    if (_initialized) {
      return;
    }
    final String serverClientId = (await OAuthConfig.resolveServerClientId()).trim();
    if (Platform.isAndroid && serverClientId.isEmpty) {
      throw StateError(
        'Android 的 Google 雲端備份需要 Web OAuth Client ID。\n'
        '請設定 android/app/src/main/res/values/oauth_config.xml 的 oauth_request_id_token，'
        '或使用 --dart-define=GOOGLE_SERVER_CLIENT_ID=... 覆寫；詳見 docs/google_drive_oauth_setup.md。',
      );
    }
    if (Platform.isIOS) {
      await _googleSignIn.initialize();
    } else {
      await _googleSignIn.initialize(
        serverClientId: serverClientId.isEmpty ? null : serverClientId,
      );
    }
    _initialized = true;
  }

  @override
  Future<void> resetSignInSessionForConsentRetry() async {
    try {
      await _ensureInitialized();
    } on Object {
      return;
    }
    try {
      await _googleSignIn.disconnect();
    } on Object {
      try {
        await _googleSignIn.signOut();
      } on Object {
        // best-effort
      }
    }
  }

  Future<GoogleSignInClientAuthorization> _authorization({
    required bool interactive,
  }) async {
    try {
      await _ensureInitialized();
      final Future<GoogleSignInAccount?>? lightweight =
          _googleSignIn.attemptLightweightAuthentication();
      final GoogleSignInAccount? existing =
          lightweight == null ? null : await lightweight;
      GoogleSignInAccount? account = existing;
      if (account == null && interactive) {
        account = await _googleSignIn.authenticate(scopeHint: _scopes);
      }
      if (account == null) {
        throw StateError('請先登入 Google 帳號。');
      }
      final GoogleSignInClientAuthorization authorization =
          await account.authorizationClient.authorizationForScopes(_scopes) ??
              await account.authorizationClient.authorizeScopes(_scopes);
      return authorization;
    } on GoogleSignInException catch (e) {
      throw StateError(_userMessageForGoogleSignIn(e));
    }
  }

  static String _userMessageForGoogleSignIn(GoogleSignInException e) {
    switch (e.code) {
      case GoogleSignInExceptionCode.canceled:
        return '已取消或未同意 Google 雲端備份所需權限。若要使用雲端備份，請完成登入並允許應用程式存取 Google Drive。';
      case GoogleSignInExceptionCode.interrupted:
        return '登入流程被中斷，請再試一次。';
      case GoogleSignInExceptionCode.uiUnavailable:
        return '目前無法開啟登入畫面，請稍後再試。';
      case GoogleSignInExceptionCode.clientConfigurationError:
      case GoogleSignInExceptionCode.providerConfigurationError:
        final String? detail = e.description;
        return 'Google 登入設定有誤。請確認 oauth_config.xml 的 Client ID 與 Cloud Console 的套件名稱、SHA-1 是否正確。'
            '${detail != null && detail.isNotEmpty ? '\n（$detail）' : ''}';
      case GoogleSignInExceptionCode.userMismatch:
        return '帳號狀態不符，請改用正確的 Google 帳號或稍後再試。';
      case GoogleSignInExceptionCode.unknownError:
        final String? detail = e.description;
        if (detail != null &&
            detail.toLowerCase().contains('no credential')) {
          return 'Google 登入無法取得憑證（常見於 iOS 未設定 Google Sign-In）。\n'
              '請確認 Google Cloud 的 iOS OAuth 用戶端與 ios/Runner/Info.plist 設定；詳見 docs/google_drive_oauth_setup.md。';
        }
        return 'Google 登入發生錯誤。'
            '${detail != null && detail.isNotEmpty ? '\n$detail' : ''}';
    }
  }

  @override
  Future<drive.DriveApi> createAuthorizedDriveApi() async {
    final GoogleSignInClientAuthorization authorization = await _authorization(
      interactive: true,
    );
    return drive.DriveApi(authorization.authClient(scopes: _scopes));
  }

  @override
  Future<void> ensureSignedIn() async {
    await _authorization(interactive: true);
  }

  @override
  Future<String> uploadBackup(File backupFile, {drive.DriveApi? reuseApi}) async {
    final drive.DriveApi api = reuseApi ?? await createAuthorizedDriveApi();
    final drive.File metadata = drive.File(
      name: p.basename(backupFile.path),
      parents: const <String>['appDataFolder'],
    );
    final drive.File created = await api.files.create(
      metadata,
      uploadMedia: drive.Media(
        backupFile.openRead(),
        await backupFile.length(),
      ),
    );
    if (created.id == null || created.id!.isEmpty) {
      throw StateError('Google Drive 沒有回傳備份檔案識別碼。');
    }
    return created.id!;
  }

  @override
  Future<List<DriveBackupFile>> listBackups() async {
    final drive.DriveApi api = await createAuthorizedDriveApi();
    final drive.FileList list = await api.files.list(
      spaces: 'appDataFolder',
      q: "name contains '.jbackup' and trashed = false",
      orderBy: 'createdTime desc',
      $fields: 'files(id,name,createdTime)',
    );
    return (list.files ?? const <drive.File>[])
        .where((drive.File file) => file.id != null && file.name != null)
        .map(
          (drive.File file) => DriveBackupFile(
            id: file.id!,
            name: file.name!,
            createdAt: file.createdTime,
          ),
        )
        .toList();
  }

  @override
  Future<File> downloadBackupById({
    required String fileId,
    required String fileName,
    required Directory destinationDirectory,
    drive.DriveApi? reuseApi,
  }) async {
    final drive.DriveApi api = reuseApi ?? await createAuthorizedDriveApi();
    await destinationDirectory.create(recursive: true);
    final File output = File(p.join(destinationDirectory.path, fileName));
    final drive.Media media = await api.files.get(
          fileId,
          downloadOptions: drive.DownloadOptions.fullMedia,
        ) as drive.Media;
    IOSink? sink;
    try {
      sink = output.openWrite();
      await media.stream.pipe(sink);
      await sink.flush();
    } finally {
      await sink?.close();
    }
    return output;
  }
}
