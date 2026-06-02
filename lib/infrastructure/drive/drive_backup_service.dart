import 'dart:io';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path/path.dart' as p;

import '../../config/oauth_config.dart';

final class DriveConnectionState {
  const DriveConnectionState({
    required this.isConnected,
    this.email,
    this.displayName,
  });

  const DriveConnectionState.disconnected()
      : isConnected = false,
        email = null,
        displayName = null;

  final bool isConnected;
  final String? email;
  final String? displayName;

  String? get accountLabel {
    final String? trimmedName = displayName?.trim();
    final String? trimmedEmail = email?.trim();
    if (trimmedName != null && trimmedName.isNotEmpty) {
      if (trimmedEmail != null && trimmedEmail.isNotEmpty) {
        return '$trimmedName ($trimmedEmail)';
      }
      return trimmedName;
    }
    if (trimmedEmail != null && trimmedEmail.isNotEmpty) {
      return trimmedEmail;
    }
    return null;
  }
}

abstract interface class GoogleDriveAuthorizationHandle {
  drive.DriveApi createDriveApi(List<String> scopes);
}

abstract interface class GoogleDriveSignedInAccount {
  String get email;

  String? get displayName;

  Future<GoogleDriveAuthorizationHandle?> authorizationForScopes(
    List<String> scopes,
  );

  Future<GoogleDriveAuthorizationHandle> authorizeScopes(
    List<String> scopes,
  );
}

abstract interface class GoogleDriveSignInClient {
  Future<void> initialize({String? serverClientId});

  Future<GoogleDriveSignedInAccount?> attemptLightweightAuthentication();

  Future<GoogleDriveSignedInAccount?> authenticate({
    List<String> scopeHint = const <String>[],
  });

  Future<void> disconnect();

  Future<void> signOut();
}

final class GoogleSignInAuthorizationHandle
    implements GoogleDriveAuthorizationHandle {
  const GoogleSignInAuthorizationHandle(this._authorization);

  final GoogleSignInClientAuthorization _authorization;

  @override
  drive.DriveApi createDriveApi(List<String> scopes) {
    return drive.DriveApi(_authorization.authClient(scopes: scopes));
  }
}

final class GoogleSignInAccountHandle implements GoogleDriveSignedInAccount {
  const GoogleSignInAccountHandle(this._account);

  final GoogleSignInAccount _account;

  @override
  String get email => _account.email;

  @override
  String? get displayName => _account.displayName;

  @override
  Future<GoogleDriveAuthorizationHandle?> authorizationForScopes(
    List<String> scopes,
  ) async {
    final GoogleSignInClientAuthorization? authorization =
        await _account.authorizationClient.authorizationForScopes(scopes);
    if (authorization == null) {
      return null;
    }
    return GoogleSignInAuthorizationHandle(authorization);
  }

  @override
  Future<GoogleDriveAuthorizationHandle> authorizeScopes(
    List<String> scopes,
  ) async {
    final GoogleSignInClientAuthorization authorization =
        await _account.authorizationClient.authorizeScopes(scopes);
    return GoogleSignInAuthorizationHandle(authorization);
  }
}

final class GoogleSignInClientAdapter implements GoogleDriveSignInClient {
  GoogleSignInClientAdapter({GoogleSignIn? googleSignIn})
      : _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final GoogleSignIn _googleSignIn;

  @override
  Future<void> initialize({String? serverClientId}) {
    return _googleSignIn.initialize(serverClientId: serverClientId);
  }

  @override
  Future<GoogleDriveSignedInAccount?> attemptLightweightAuthentication() async {
    final Future<GoogleSignInAccount?>? lightweight =
        _googleSignIn.attemptLightweightAuthentication();
    final GoogleSignInAccount? account =
        lightweight == null ? null : await lightweight;
    return account == null ? null : GoogleSignInAccountHandle(account);
  }

  @override
  Future<GoogleDriveSignedInAccount?> authenticate({
    List<String> scopeHint = const <String>[],
  }) async {
    final GoogleSignInAccount account =
        await _googleSignIn.authenticate(scopeHint: scopeHint);
    return GoogleSignInAccountHandle(account);
  }

  @override
  Future<void> disconnect() {
    return _googleSignIn.disconnect();
  }

  @override
  Future<void> signOut() {
    return _googleSignIn.signOut();
  }
}

String sanitizeDriveBackupFileName(String fileName) {
  final String trimmed = fileName.trim();
  final String normalizedSeparators = trimmed.replaceAll('\\', '/');
  final String basename = p.posix.basename(normalizedSeparators);
  final bool hasPathSegments = basename != normalizedSeparators;
  final bool hasUnsafeCharacters =
      RegExp(r'[<>:"/\\|?*\x00-\x1F]').hasMatch(basename);
  if (trimmed.isEmpty ||
      hasPathSegments ||
      basename == '.' ||
      basename == '..' ||
      hasUnsafeCharacters ||
      basename.endsWith('.') ||
      basename.endsWith(' ')) {
    throw StateError('Google Drive 備份檔名無效，請重新建立備份。');
  }
  if (p.extension(basename).toLowerCase() != '.jbackup') {
    throw StateError('Google Drive 備份檔必須是 .jbackup 格式。');
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
  Future<DriveConnectionState> getConnectionState();

  Future<DriveConnectionState> connect();

  Future<DriveConnectionState> reconnect();

  Future<String> uploadBackup(File backupFile);

  Future<List<DriveBackupFile>> listBackups();

  Future<File> downloadBackupById({
    required String fileId,
    required String fileName,
    required Directory destinationDirectory,
  });
}

class GoogleDriveBackupService implements DriveBackupService {
  GoogleDriveBackupService({GoogleDriveSignInClient? signInClient})
      : _signInClient = signInClient ?? GoogleSignInClientAdapter();

  static const MethodChannel _androidDriveAuthChannel = MethodChannel(
    'quill_lock_diary/oauth_config',
  );
  static const String _oauthSetupDocPath = 'docs/Google-Drive-OAuth-設定.md';
  static const List<String> _scopes = <String>[drive.DriveApi.driveAppdataScope];

  final GoogleDriveSignInClient _signInClient;
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) {
      return;
    }

    final String serverClientId = (await OAuthConfig.resolveServerClientId()).trim();
    if (Platform.isAndroid && serverClientId.isEmpty) {
      throw StateError(
        'Android 尚未完成 Google Drive OAuth 設定。\n'
        '請先確認 `android/app/src/main/res/values/oauth_config.xml` 內的 '
        '`oauth_request_id_token`，或以 `--dart-define=GOOGLE_SERVER_CLIENT_ID=...` 提供 Web Client ID。\n'
        '詳細設定請參考 $_oauthSetupDocPath。',
      );
    }

    if (Platform.isIOS) {
      if (OAuthConfig.googleIosClientId.trim().isEmpty) {
        throw StateError(
          'iOS 尚未完成 Google Drive OAuth 設定。\n'
          '請先提供 `GOOGLE_IOS_CLIENT_ID` 與 `GOOGLE_IOS_REVERSED_CLIENT_ID`。',
        );
      }
      await _signInClient.initialize();
    } else {
      await _signInClient.initialize(
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
      await _signInClient.disconnect();
    } on Object {
      try {
        await _signInClient.signOut();
      } on Object {
        // Best effort only.
      }
    }
  }

  Future<({
    GoogleDriveSignedInAccount account,
    GoogleDriveAuthorizationHandle authorization,
  })> _authorization({
    required bool interactive,
    bool resetSession = false,
  }) async {
    try {
      await _ensureInitialized();
      if (Platform.isAndroid && interactive) {
        final ({
          GoogleDriveSignedInAccount account,
          GoogleDriveAuthorizationHandle authorization,
        })? nativeAuthorized = await _tryNativeAndroidAuthorization(
          resetSession: resetSession,
        );
        if (nativeAuthorized != null) {
          return nativeAuthorized;
        }
      }
      if (resetSession) {
        await _resetSignInSession();
      }

      GoogleDriveSignedInAccount? account =
          await _signInClient.attemptLightweightAuthentication();
      if (account == null && interactive) {
        account = await _signInClient.authenticate(scopeHint: _scopes);
      }
      if (account == null) {
        throw StateError('尚未完成 Google 帳號登入。');
      }

      final GoogleDriveAuthorizationHandle authorization =
          await account.authorizationForScopes(_scopes) ??
              await account.authorizeScopes(_scopes);
      return (account: account, authorization: authorization);
    } on GoogleSignInException catch (error) {
      final ({
        GoogleDriveSignedInAccount account,
        GoogleDriveAuthorizationHandle authorization,
      })? recovered =
          await _tryRecoverAuthorizedSessionAfterInteractiveError(error);
      if (recovered != null) {
        return recovered;
      }
      throw StateError(_userMessageForGoogleSignIn(error));
    }
  }

  Future<({
    GoogleDriveSignedInAccount account,
    GoogleDriveAuthorizationHandle authorization,
  })?> _tryNativeAndroidAuthorization({
    required bool resetSession,
  }) async {
    try {
      final String serverClientId = (await OAuthConfig.resolveServerClientId()).trim();
      if (serverClientId.isEmpty) {
        return null;
      }

      await _androidDriveAuthChannel.invokeMethod<Object?>(
        'signInGoogleDrive',
        <String, Object>{
          'serverClientId': serverClientId,
          'resetSession': resetSession,
        },
      );

      final GoogleDriveSignedInAccount? account =
          await _signInClient.attemptLightweightAuthentication();
      if (account == null) {
        return null;
      }

      final GoogleDriveAuthorizationHandle authorization =
          await account.authorizationForScopes(_scopes) ??
              await account.authorizeScopes(_scopes);
      return (account: account, authorization: authorization);
    } on PlatformException catch (error) {
      final String? message = error.message?.trim();
      if (message != null && message.isNotEmpty) {
        throw StateError(message);
      }
      return null;
    } on GoogleSignInException {
      return null;
    } on Object {
      return null;
    }
  }

  Future<({
    GoogleDriveSignedInAccount account,
    GoogleDriveAuthorizationHandle authorization,
  })?> _tryRecoverAuthorizedSessionAfterInteractiveError(
    GoogleSignInException exception,
  ) async {
    try {
      if (!_shouldAttemptPostErrorRecovery(exception)) {
        return null;
      }

      final GoogleDriveSignedInAccount? recoveredAccount =
          await _signInClient.attemptLightweightAuthentication();
      if (recoveredAccount == null) {
        return null;
      }

      GoogleDriveAuthorizationHandle? recoveredAuthorization =
          await recoveredAccount.authorizationForScopes(_scopes);
      recoveredAuthorization ??= await _tryAuthorizeRecoveredAccount(
        recoveredAccount,
      );
      if (recoveredAuthorization == null) {
        return null;
      }

      return (
        account: recoveredAccount,
        authorization: recoveredAuthorization,
      );
    } on Object {
      return null;
    }
  }

  bool _shouldAttemptPostErrorRecovery(GoogleSignInException exception) {
    if (exception.code == GoogleSignInExceptionCode.canceled ||
        exception.code == GoogleSignInExceptionCode.interrupted) {
      return true;
    }

    final String lowerDescription = exception.description?.toLowerCase() ?? '';
    return lowerDescription.contains('account auth failed');
  }

  Future<GoogleDriveAuthorizationHandle?> _tryAuthorizeRecoveredAccount(
    GoogleDriveSignedInAccount account,
  ) async {
    try {
      return await account.authorizeScopes(_scopes);
    } on GoogleSignInException {
      return null;
    } on Object {
      return null;
    }
  }

  static String _userMessageForGoogleSignIn(GoogleSignInException error) {
    final String? detail = error.description?.trim();
    final String detailLine =
        detail != null && detail.isNotEmpty ? '\n詳細資訊：$detail' : '';
    final String lowerDetail = detail?.toLowerCase() ?? '';

    if (lowerDetail.contains('admin_policy_enforced')) {
      return '這個 Google 帳號受到組織政策限制，暫時無法授權 Google Drive 給此 App。\n'
          '請改用可自行授權的個人帳號，或請管理員確認是否允許此 App 使用 Drive 權限。'
          '$detailLine';
    }
    if (lowerDetail.contains('access_denied')) {
      return 'Google Drive 權限授權沒有完成。\n'
          '如果你在選完帳號後沒有看到 Drive 權限頁，請優先檢查 Web Client ID、Android OAuth client、package name 與 SHA-1 是否設定正確。\n'
          '詳細設定請參考 $_oauthSetupDocPath。'
          '$detailLine';
    }

    switch (error.code) {
      case GoogleSignInExceptionCode.canceled:
        return '你已取消 Google 登入，尚未連結 Google Drive。\n'
            '請重新按一次「連結 Google Drive」，並完成帳號選擇與授權。'
            '$detailLine';
      case GoogleSignInExceptionCode.interrupted:
        return 'Google 登入流程被中斷，請稍後再試一次。$detailLine';
      case GoogleSignInExceptionCode.uiUnavailable:
        return '目前裝置無法顯示 Google 登入畫面。\n'
            '請先確認 Google Play 服務可正常使用，再重新嘗試。'
            '$detailLine';
      case GoogleSignInExceptionCode.clientConfigurationError:
      case GoogleSignInExceptionCode.providerConfigurationError:
        return 'Google 登入設定有誤。\n'
            '請確認 `oauth_config.xml` 的 Client ID 正確，且 Google Cloud Console 內的 Web OAuth client、Android OAuth client、package name 與 SHA-1 都屬於同一個專案。\n'
            '詳細設定請參考 $_oauthSetupDocPath。'
            '$detailLine';
      case GoogleSignInExceptionCode.userMismatch:
        return '目前登入中的 Google 帳號與授權帳號不一致。\n'
            '請重新連結 Google Drive，並確認選擇的是同一個帳號。'
            '$detailLine';
      case GoogleSignInExceptionCode.unknownError:
        if (lowerDetail.contains('no credential')) {
          return '目前找不到可用的 Google 登入憑證。\n'
              '請檢查 Android 端的 Google Sign-In / OAuth 設定，特別是 package name、SHA-1 與 Web Client ID。\n'
              '詳細設定請參考 $_oauthSetupDocPath。'
              '$detailLine';
        }
        if (lowerDetail.contains('account auth failed')) {
          return 'Google 帳號驗證沒有完成。\n'
              '這通常代表 OAuth 設定或裝置端登入狀態有問題，請先確認 Google Cloud Console 的 Android OAuth client、SHA-1 與目前安裝包一致。\n'
              '詳細設定請參考 $_oauthSetupDocPath。'
              '$detailLine';
        }
        return 'Google 登入發生未預期錯誤，請稍後再試一次。\n'
            '如果問題持續發生，請優先檢查 OAuth 設定是否完整。'
            '$detailLine';
    }
  }

  @override
  Future<DriveConnectionState> getConnectionState() async {
    try {
      await _ensureInitialized();
      final GoogleDriveSignedInAccount? account =
          await _signInClient.attemptLightweightAuthentication();
      if (account == null) {
        return const DriveConnectionState.disconnected();
      }
      final GoogleDriveAuthorizationHandle? authorization =
          await account.authorizationForScopes(_scopes);
      if (authorization == null) {
        return const DriveConnectionState.disconnected();
      }
      return _connectedStateForAccount(account);
    } on Object {
      return const DriveConnectionState.disconnected();
    }
  }

  @override
  Future<DriveConnectionState> connect() async {
    final ({
      GoogleDriveSignedInAccount account,
      GoogleDriveAuthorizationHandle authorization,
    }) authorized = await _authorization(interactive: true);
    return _connectedStateForAccount(authorized.account);
  }

  @override
  Future<DriveConnectionState> reconnect() async {
    final ({
      GoogleDriveSignedInAccount account,
      GoogleDriveAuthorizationHandle authorization,
    }) authorized = await _authorization(
      interactive: true,
      resetSession: true,
    );
    return _connectedStateForAccount(authorized.account);
  }

  Future<drive.DriveApi> _createAuthorizedDriveApi() async {
    final ({
      GoogleDriveSignedInAccount account,
      GoogleDriveAuthorizationHandle authorization,
    }) authorized = await _authorization(interactive: true);
    return authorized.authorization.createDriveApi(_scopes);
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
      throw StateError('Google Drive 上傳完成後沒有回傳有效檔案 ID。');
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

  DriveConnectionState _connectedStateForAccount(
    GoogleDriveSignedInAccount account,
  ) {
    return DriveConnectionState(
      isConnected: true,
      email: account.email,
      displayName: account.displayName,
    );
  }

  void _ensurePathInsideDirectory({
    required Directory directory,
    required File file,
  }) {
    final String root = p.normalize(directory.absolute.path);
    final String target = p.normalize(file.absolute.path);
    if (target != root && !p.isWithin(root, target)) {
      throw StateError('Google Drive 備份下載路徑無效。');
    }
  }
}
