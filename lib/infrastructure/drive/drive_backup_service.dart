import 'dart:io';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path/path.dart' as p;

import '../../config/app_identifiers.dart';
import '../../domain/shared/vault_backup_policy.dart';
import '../../config/oauth_config.dart';
import '../../shared/presentation/display_format.dart';
import '../storage/backup_task_progress.dart';
import 'google_drive_oauth_errors.dart';

/// 設定與備份流程顯示的目前 Google Drive 連線快照。
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
        return DisplayFormat.formatGoogleAccountLabel(trimmedName, trimmedEmail);
      }
      return trimmedName;
    }
    if (trimmedEmail != null && trimmedEmail.isNotEmpty) {
      return trimmedEmail;
    }
    return null;
  }
}

/// 與具體 Google Sign-In SDK 解耦的已授權 Drive API 工廠。
abstract interface class GoogleDriveAuthorizationHandle {
  drive.DriveApi createDriveApi(List<String> scopes);
}

/// 用於保持 Drive 程式可測試的已登入 Google 帳號抽象。
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

/// Drive 備份支援所需的最小 Google Sign-In 介面。
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
  if (p.extension(basename).toLowerCase() != '.${VaultBackupPolicy.fileExtension}') {
    throw StateError('Google Drive 備份檔必須是 zip 格式。');
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

int? _parseDriveFileSize(String? rawSize) {
  if (rawSize == null || rawSize.trim().isEmpty) {
    return null;
  }
  return int.tryParse(rawSize.trim());
}

final class DriveBackupFile {
  const DriveBackupFile({
    required this.id,
    required this.name,
    required this.createdAt,
    this.sizeBytes,
  });

  final String id;
  final String name;
  final DateTime? createdAt;
  final int? sizeBytes;
}

/// 以 Google Drive appDataFolder 為後端的遠端備份服務。
abstract class DriveBackupService {
  Future<DriveConnectionState> getConnectionState();

  Future<DriveConnectionState> connect();

  Future<DriveConnectionState> switchAccount();

  Future<void> disconnect();

  Future<String> uploadBackup(
    File backupFile, {
    BackupTaskProgressListener? onProgress,
  });

  Future<List<DriveBackupFile>> listBackups();

  Future<void> deleteBackup(String fileId);

  Future<List<DriveBackupFile>> pruneBackups({required int retainCount});

  Future<File> downloadBackupById({
    required String fileId,
    required String fileName,
    required Directory destinationDirectory,
    int? totalBytes,
    BackupTaskProgressListener? onProgress,
  });
}

/// 含 Android 原生驗證後備處理的 Google Drive 實作。
class GoogleDriveBackupService implements DriveBackupService {
  GoogleDriveBackupService({
    GoogleDriveSignInClient? signInClient,
    Future<DriveConnectionState?> Function()? androidConnectionSnapshotOverride,
  }) : _signInClient = signInClient ?? GoogleSignInClientAdapter(),
       _androidConnectionSnapshotOverride = androidConnectionSnapshotOverride;

  /// 測試用：覆寫 Android 連線快照，不觸發 [attemptLightweightAuthentication]。
  final Future<DriveConnectionState?> Function()? _androidConnectionSnapshotOverride;

  static const MethodChannel _androidDriveAuthChannel = MethodChannel(
    AppIdentifiers.oauthChannel,
  );
  static const String _oauthSetupDocPath = GoogleDriveOAuthFingerprints.oauthSetupDocPath;
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
        // 僅盡力而為。
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
      throw StateError(
        userMessageForGoogleSignIn(error, oauthSetupDocPath: _oauthSetupDocPath),
      );
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

  DriveConnectionState? _connectionStateFromNativePayload(Object? payload) {
    if (payload is! Map<Object?, Object?>) {
      return null;
    }
    final String? email = payload['email'] as String?;
    if (email == null || email.trim().isEmpty) {
      return null;
    }
    final String? trimmedName = (payload['displayName'] as String?)?.trim();
    return DriveConnectionState(
      isConnected: true,
      email: email.trim(),
      displayName:
          trimmedName != null && trimmedName.isNotEmpty ? trimmedName : null,
    );
  }

  Future<DriveConnectionState?> _readAndroidConnectionSnapshot() async {
    if (_androidConnectionSnapshotOverride != null) {
      return _androidConnectionSnapshotOverride();
    }
    if (!Platform.isAndroid) {
      return null;
    }
    try {
      final Object? payload = await _androidDriveAuthChannel.invokeMethod<Object?>(
        'getGoogleDriveConnectionSnapshot',
      );
      return _connectionStateFromNativePayload(payload);
    } on Object {
      return null;
    }
  }

  Future<DriveConnectionState> _getAndroidConnectionState() async {
    final DriveConnectionState? snapshot = await _readAndroidConnectionSnapshot();
    return snapshot ?? const DriveConnectionState.disconnected();
  }

  Future<DriveConnectionState> _getPluginConnectionState() async {
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
  }

  @override
  Future<DriveConnectionState> getConnectionState() async {
    try {
      // Android：僅讀取本機已授權帳號快照。不可呼叫 attemptLightweightAuthentication，
      // 否則憑證管理員會在設定頁載入時彈出 Google 登入介面。
      if (Platform.isAndroid || _androidConnectionSnapshotOverride != null) {
        return _getAndroidConnectionState();
      }
      return _getPluginConnectionState();
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
  Future<DriveConnectionState> switchAccount() async {
    final ({
      GoogleDriveSignedInAccount account,
      GoogleDriveAuthorizationHandle authorization,
    }) authorized = await _authorization(
      interactive: true,
      resetSession: true,
    );
    return _connectedStateForAccount(authorized.account);
  }

  @override
  Future<void> disconnect() async {
    await _resetSignInSession();
  }

  Future<drive.DriveApi> _createAuthorizedDriveApi() async {
    final ({
      GoogleDriveSignedInAccount account,
      GoogleDriveAuthorizationHandle authorization,
    }) authorized = await _authorization(interactive: true);
    return authorized.authorization.createDriveApi(_scopes);
  }

  @override
  Future<String> uploadBackup(
    File backupFile, {
    BackupTaskProgressListener? onProgress,
  }) async {
    final drive.DriveApi api = await _createAuthorizedDriveApi();
    final drive.File metadata = drive.File(
      name: p.basename(backupFile.path),
      parents: const <String>['appDataFolder'],
    );
    final int totalBytes = await backupFile.length();
    onProgress?.call(
      const BackupTaskProgress(phase: BackupTaskPhase.uploadingDrive),
    );
    final Stream<List<int>> monitoredStream = reportByteStreamProgress(
      backupFile.openRead(),
      totalBytes: totalBytes,
      phase: BackupTaskPhase.uploadingDrive,
      onProgress: onProgress,
    );
    final drive.File created = await api.files.create(
      metadata,
      uploadMedia: drive.Media(
        monitoredStream,
        totalBytes,
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
      q: "name contains '.zip' and trashed = false",
      orderBy: 'createdTime desc',
      $fields: 'files(id,name,createdTime,size)',
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
            sizeBytes: _parseDriveFileSize(file.size),
          ),
        )
        .toList();
  }

  @override
  Future<void> deleteBackup(String fileId) async {
    final String trimmedFileId = fileId.trim();
    if (trimmedFileId.isEmpty) {
      throw StateError('Google Drive 備份檔案 ID 不可為空。');
    }
    final drive.DriveApi api = await _createAuthorizedDriveApi();
    await api.files.delete(trimmedFileId);
  }

  @override
  Future<List<DriveBackupFile>> pruneBackups({required int retainCount}) async {
    if (retainCount < 1) {
      throw ArgumentError.value(retainCount, 'retainCount', 'retainCount must be positive.');
    }
    final List<DriveBackupFile> staleBackups = driveBackupsToPrune(
      await listBackups(),
      retainCount: retainCount,
    );
    for (final DriveBackupFile backup in staleBackups) {
      await deleteBackup(backup.id);
    }
    return staleBackups;
  }

  @override
  Future<File> downloadBackupById({
    required String fileId,
    required String fileName,
    required Directory destinationDirectory,
    int? totalBytes,
    BackupTaskProgressListener? onProgress,
  }) async {
    final drive.DriveApi api = await _createAuthorizedDriveApi();
    await destinationDirectory.create(recursive: true);
    final String safeFileName = sanitizeDriveBackupFileName(fileName);
    final File output = File(p.join(destinationDirectory.path, safeFileName));
    _ensurePathInsideDirectory(
      directory: destinationDirectory,
      file: output,
    );
    onProgress?.call(
      const BackupTaskProgress(phase: BackupTaskPhase.downloadingDrive),
    );
    final drive.Media media = await api.files.get(
          fileId,
          downloadOptions: drive.DownloadOptions.fullMedia,
        ) as drive.Media;
    IOSink? sink;
    try {
      sink = output.openWrite();
      await for (final List<int> chunk in reportByteStreamProgress(
        media.stream,
        totalBytes: totalBytes ?? 0,
        phase: BackupTaskPhase.downloadingDrive,
        onProgress: onProgress,
      )) {
        sink.add(chunk);
      }
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

List<DriveBackupFile> sortDriveBackupsNewestFirst(
  Iterable<DriveBackupFile> backups,
) {
  return List<DriveBackupFile>.from(backups)..sort(compareDriveBackupsNewestFirst);
}

List<DriveBackupFile> driveBackupsToPrune(
  Iterable<DriveBackupFile> backups, {
  required int retainCount,
}) {
  if (retainCount < 1) {
    throw ArgumentError.value(retainCount, 'retainCount', 'retainCount must be positive.');
  }
  final List<DriveBackupFile> sorted = sortDriveBackupsNewestFirst(backups);
  if (sorted.length <= retainCount) {
    return const <DriveBackupFile>[];
  }
  return sorted.skip(retainCount).toList();
}

int compareDriveBackupsNewestFirst(DriveBackupFile a, DriveBackupFile b) {
  final DateTime? aCreated = a.createdAt;
  final DateTime? bCreated = b.createdAt;
  if (aCreated == null && bCreated == null) {
    return b.name.compareTo(a.name);
  }
  if (aCreated == null) {
    return 1;
  }
  if (bCreated == null) {
    return -1;
  }
  final int createdOrder = bCreated.compareTo(aCreated);
  if (createdOrder != 0) {
    return createdOrder;
  }
  return b.name.compareTo(a.name);
}
