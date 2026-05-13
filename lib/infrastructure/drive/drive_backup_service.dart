import 'dart:io';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path/path.dart' as p;

abstract class DriveBackupService {
  Future<String?> uploadBackup(File backupFile);

  Future<List<String>> listBackups();

  Future<File?> downloadLatestBackup({
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
    await _googleSignIn.initialize();
    _initialized = true;
  }

  Future<drive.DriveApi> _driveApi() async {
    await _ensureInitialized();
    final GoogleSignInAccount? existing =
        await (_googleSignIn.attemptLightweightAuthentication() ?? Future<GoogleSignInAccount?>.value());
    final GoogleSignInAccount account =
        existing ?? await _googleSignIn.authenticate(scopeHint: _scopes);
    final GoogleSignInClientAuthorization authorization =
        await account.authorizationClient.authorizationForScopes(_scopes) ??
            await account.authorizationClient.authorizeScopes(_scopes);
    return drive.DriveApi(authorization.authClient(scopes: _scopes));
  }

  @override
  Future<String?> uploadBackup(File backupFile) async {
    try {
      final drive.DriveApi api = await _driveApi();
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
      return created.id;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<String>> listBackups() async {
    try {
      final drive.DriveApi api = await _driveApi();
      final drive.FileList list = await api.files.list(
        spaces: 'appDataFolder',
        q: "name contains '.jbackup'",
        orderBy: 'createdTime desc',
      );
      return (list.files ?? const <drive.File>[])
          .map((drive.File file) => file.name ?? file.id ?? 'unknown')
          .toList();
    } catch (_) {
      return const <String>[];
    }
  }

  @override
  Future<File?> downloadLatestBackup({
    required Directory destinationDirectory,
  }) async {
    try {
      final drive.DriveApi api = await _driveApi();
      final drive.FileList list = await api.files.list(
        spaces: 'appDataFolder',
        q: "name contains '.jbackup'",
        orderBy: 'createdTime desc',
        $fields: 'files(id,name)',
      );
      final List<drive.File> files = list.files ?? const <drive.File>[];
      if (files.isEmpty || files.first.id == null || files.first.name == null) {
        return null;
      }
      final drive.File latest = files.first;
      await destinationDirectory.create(recursive: true);
      final File output = File(p.join(destinationDirectory.path, latest.name!));
      final drive.Media media = await api.files.get(
            latest.id!,
            downloadOptions: drive.DownloadOptions.fullMedia,
          ) as drive.Media;
      final IOSink sink = output.openWrite();
      await media.stream.pipe(sink);
      await sink.flush();
      await sink.close();
      return output;
    } catch (_) {
      return null;
    }
  }
}
