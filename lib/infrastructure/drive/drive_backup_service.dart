import 'dart:io';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path/path.dart' as p;

import '../../config/oauth_config.dart';

String sanitizeDriveBackupFileName(String fileName) {
  final String trimmed = fileName.trim();
  final String normalizedSeparators = trimmed.replaceAll('\\', '/');
  final String basename = p.posix.basename(normalizedSeparators);
  final bool hasPathSegments = basename != normalizedSeparators;
  final bool hasUnsafeCharacters = RegExp(r'[<>:"/\\|?*\x00-\x1F]').hasMatch(basename);
  if (trimmed.isEmpty ||
      hasPathSegments ||
      basename == '.' ||
      basename == '..' ||
      hasUnsafeCharacters ||
      basename.endsWith('.') ||
      basename.endsWith(' ')) {
    throw StateError('Google Drive 備份檔名不安全，已停止下載。');
  }
  if (p.extension(basename).toLowerCase() != '.jbackup') {
    throw StateError('Google Drive 備份檔副檔名不正確。');
  }
  return basename;
}

bool isVisibleDriveBackupFileName(String? fileName) {
  if (fileName == null) {
    return false;
  }
  try {
    sanitizeDriveBackupFileName(fileName);
    return true;
  } on StateError {
    return false;
  }
}

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
  Future<bool> isConnected();

  Future<void> connect();

  Future<void> reconnect();

  Future<String> uploadBackup(File backupFile);

  Future<List<DriveBackupFile>> listBackups();

  Future<File> downloadBackupById({
    required String fileId,
    required String fileName,
    required Directory destinationDirectory,
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
        'Android 的 Google Drive OAuth 尚未設定 Web OAuth Client ID。'
        '\n請設定 android/app/src/main/res/values/oauth_config.xml 的 oauth_request_id_token，'
        '\n或使用 --dart-define=GOOGLE_SERVER_CLIENT_ID=... 覆寫。'
        '\n詳見 docs/Google-Drive-OAuth-設定.md。',
      );
    }
    if (Platform.isIOS) {
      if (OAuthConfig.googleIosClientId.trim().isEmpty) {
        throw StateError(
          'iOS Google Drive 備份尚未設定 OAuth Client ID。'
          '\n請提供 GOOGLE_IOS_CLIENT_ID 與 GOOGLE_IOS_REVERSED_CLIENT_ID。',
        );
      }
      await _googleSignIn.initialize();
    } else {
      await _googleSignIn.initialize(
        serverClientId: serverClientId.isEmpty ? null : serverClientId,
      );
    }
    _initialized = true;
  }

  Future<void> _resetSignInSession() async {
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
    bool resetSession = false,
  }) async {
    try {
      await _ensureInitialized();
      if (resetSession) {
        await _resetSignInSession();
      }
      final Future<GoogleSignInAccount?>? lightweight =
          _googleSignIn.attemptLightweightAuthentication();
      final GoogleSignInAccount? existing =
          lightweight == null ? null : await lightweight;
      GoogleSignInAccount? account = existing;
      if (account == null && interactive) {
        account = await _googleSignIn.authenticate(scopeHint: _scopes);
      }
      if (account == null) {
        throw StateError('你尚未完成 Google 登入。');
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
    final String? detail = e.description?.trim();
    final String detailLine =
        detail != null && detail.isNotEmpty ? '\n技術資訊：$detail' : '';
    final String lowerDetail = detail?.toLowerCase() ?? '';

    if (lowerDetail.contains('admin_policy_enforced')) {
      return 'Google 帳號所屬的組織政策拒絕了這次登入或授權。'
          '\n如果你使用的是公司或學校帳號，請管理員允許這個 App 使用 Google 登入與 Drive 權限。'
          '$detailLine';
    }
    if (lowerDetail.contains('access_denied')) {
      return 'Google 直接拒絕了這次授權。'
          '\n若你在選完帳號後完全沒有看到 Google Drive 權限頁，請優先檢查 oauth_config.xml 的 Web Client ID、Cloud Console 的 Android OAuth client、套件名稱與 SHA-1 是否一致。'
          '$detailLine';
    }

    switch (e.code) {
      case GoogleSignInExceptionCode.canceled:
        return '你已取消 Google 登入或沒有同意 Google Drive 所需權限。'
            '\n若要使用 Google Drive 備份，請重新登入並允許應用程式存取 Google Drive。'
            '$detailLine';
      case GoogleSignInExceptionCode.interrupted:
        return 'Google 登入流程被中斷，請稍後再試。$detailLine';
      case GoogleSignInExceptionCode.uiUnavailable:
        return '目前裝置無法顯示 Google 登入畫面，請確認 Google Play 服務與系統元件可正常使用。$detailLine';
      case GoogleSignInExceptionCode.clientConfigurationError:
      case GoogleSignInExceptionCode.providerConfigurationError:
        return 'Google 登入設定有誤。'
            '\n請確認 oauth_config.xml 的 Client ID 是否為同一個 GCP 專案下的 Web OAuth client，並確認 Cloud Console 的 Android OAuth client、套件名稱與 SHA-1 都正確。'
            '$detailLine';
      case GoogleSignInExceptionCode.userMismatch:
        return '目前登入的 Google 帳號與流程預期不一致，請重新選擇帳號後再試。$detailLine';
      case GoogleSignInExceptionCode.unknownError:
        if (lowerDetail.contains('no credential')) {
          return 'Google 沒有提供可用的登入憑證。'
              '\n若你是在選完帳號後、完全沒有看到 Google Drive 權限頁就失敗，通常要優先檢查 Android 的 Google Sign-In / OAuth 設定與 SHA-1。'
              '\n詳見 docs/Google-Drive-OAuth-設定.md。'
              '$detailLine';
        }
        return 'Google 登入發生未知錯誤。'
            '\n若帳號選擇器有出現，但 Google Drive 權限頁完全沒有出現，請優先檢查 OAuth 設定，而不是只重試帳號授權。'
            '$detailLine';
    }
  }

  @override
  Future<bool> isConnected() async {
    try {
      await _ensureInitialized();
      final Future<GoogleSignInAccount?>? lightweight =
          _googleSignIn.attemptLightweightAuthentication();
      final GoogleSignInAccount? account =
          lightweight == null ? null : await lightweight;
      if (account == null) {
        return false;
      }
      final GoogleSignInClientAuthorization? authorization =
          await account.authorizationClient.authorizationForScopes(_scopes);
      return authorization != null;
    } on Object {
      return false;
    }
  }

  Future<drive.DriveApi> _createAuthorizedDriveApi({
    bool resetSession = false,
  }) async {
    final GoogleSignInClientAuthorization authorization = await _authorization(
      interactive: true,
      resetSession: resetSession,
    );
    return drive.DriveApi(authorization.authClient(scopes: _scopes));
  }

  @override
  Future<void> connect() async {
    await _createAuthorizedDriveApi();
  }

  @override
  Future<void> reconnect() async {
    await _createAuthorizedDriveApi(resetSession: true);
  }

  @override
  Future<String> uploadBackup(File backupFile) async {
    final drive.DriveApi api = await _createAuthorizedDriveApi();
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
    final drive.DriveApi api = await _createAuthorizedDriveApi();
    final drive.FileList list = await api.files.list(
      spaces: 'appDataFolder',
      q: "name contains '.jbackup' and trashed = false",
      orderBy: 'createdTime desc',
      $fields: 'files(id,name,createdTime)',
    );
    return (list.files ?? const <drive.File>[])
        .where(
          (drive.File file) =>
              file.id != null &&
              file.name != null &&
              isVisibleDriveBackupFileName(file.name),
        )
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
  }) async {
    final drive.DriveApi api = await _createAuthorizedDriveApi();
    await destinationDirectory.create(recursive: true);
    final String safeFileName = sanitizeDriveBackupFileName(fileName);
    final File output = File(p.join(destinationDirectory.path, safeFileName));
    _ensurePathInsideDirectory(
      directory: destinationDirectory,
      file: output,
    );
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

  void _ensurePathInsideDirectory({
    required Directory directory,
    required File file,
  }) {
    final String root = p.normalize(directory.absolute.path);
    final String target = p.normalize(file.absolute.path);
    if (target != root && !p.isWithin(root, target)) {
      throw StateError('Google Drive 備份下載路徑不安全。');
    }
  }
}
