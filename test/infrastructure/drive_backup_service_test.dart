import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:quill_diary/infrastructure/drive/drive_backup_service.dart';
import 'package:quill_diary/l10n/l10n.dart';

void main() {
  final AppLocalizations zhTwL10n = lookupAppLocalizations(appZhLocale);

  group('isVisibleDriveBackupFileName', () {
    test('accepts visible backup names', () {
      expect(isVisibleDriveBackupFileName('backup_2026-05-26.zip'), isTrue);
    });

    test('rejects names that download step would block', () {
      expect(isVisibleDriveBackupFileName(null), isFalse);
      expect(isVisibleDriveBackupFileName('backup.zip.tmp'), isFalse);
      expect(isVisibleDriveBackupFileName('../backup.zip'), isFalse);
      expect(isVisibleDriveBackupFileName(r'C:\temp\backup.zip'), isFalse);
    });
  });

  group('sanitizeDriveBackupFileName', () {
    test('accepts safe zip backup file names', () {
      expect(
        sanitizeDriveBackupFileName('backup_2026-05-26.zip'),
        'backup_2026-05-26.zip',
      );
      expect(
        sanitizeDriveBackupFileName('my_diary_backup.zip'),
        'my_diary_backup.zip',
      );
    });

    test('rejects path traversal and absolute-looking names', () {
      expect(
        () => sanitizeDriveBackupFileName('../backup.zip'),
        throwsA(isA<StateError>()),
      );
      expect(
        () => sanitizeDriveBackupFileName(r'C:\temp\backup.zip'),
        throwsA(isA<StateError>()),
      );
      expect(
        () => sanitizeDriveBackupFileName('/tmp/backup.zip'),
        throwsA(isA<StateError>()),
      );
    });

    test('rejects non zip extensions', () {
      expect(
        () => sanitizeDriveBackupFileName('backup_2026-05-26.txt'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('Drive backup retention', () {
    test(
      'sortDriveBackupsNewestFirst keeps null createdAt at the stale end',
      () {
        final List<DriveBackupFile> sorted =
            sortDriveBackupsNewestFirst(<DriveBackupFile>[
              DriveBackupFile(
                id: 'unknown',
                name: 'backup_unknown.zip',
                createdAt: null,
              ),
              DriveBackupFile(
                id: 'old',
                name: 'backup_old.zip',
                createdAt: DateTime.parse('2026-05-01T00:00:00Z'),
              ),
              DriveBackupFile(
                id: 'new',
                name: 'backup_new.zip',
                createdAt: DateTime.parse('2026-05-03T00:00:00Z'),
              ),
            ]);

        expect(sorted.map((DriveBackupFile file) => file.id), <String>[
          'new',
          'old',
          'unknown',
        ]);
      },
    );

    test('driveBackupsToPrune returns backups after retained newest files', () {
      final List<DriveBackupFile> backups = <DriveBackupFile>[
        for (int day = 1; day <= 12; day++)
          DriveBackupFile(
            id: 'backup_$day',
            name: 'backup_2026-05-${day.toString().padLeft(2, '0')}.zip',
            createdAt: DateTime.utc(2026, 5, day),
          ),
      ];

      final List<DriveBackupFile> stale = driveBackupsToPrune(
        backups,
        retainCount: 10,
      );

      expect(stale.map((DriveBackupFile file) => file.id), <String>[
        'backup_2',
        'backup_1',
      ]);
    });

    test('driveBackupsToPrune validates retain count', () {
      expect(
        () => driveBackupsToPrune(const <DriveBackupFile>[], retainCount: 0),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('GoogleDriveBackupService connection state', () {
    test(
      'getConnectionState returns connected account info after authorization exists',
      () async {
        final FakeGoogleDriveSignInClient signInClient =
            FakeGoogleDriveSignInClient(
              lightweightAccount: FakeGoogleDriveSignedInAccount(
                email: 'writer@example.com',
                displayName: 'Writer',
                existingAuthorization:
                    const FakeGoogleDriveAuthorizationHandle(),
              ),
            );
        final GoogleDriveBackupService service = GoogleDriveBackupService(
          signInClient: signInClient,
        );

        final DriveConnectionState state = await service.getConnectionState();

        expect(state.isConnected, isTrue);
        expect(state.email, 'writer@example.com');
        expect(state.displayName, 'Writer');
        expect(
          state.accountLabel(zhTwL10n),
          'Writer · writer@example.com',
        );
      },
    );

    test('getConnectionState 使用 Android 快照時不呼叫輕量登入', () async {
      final FakeGoogleDriveSignInClient signInClient =
          FakeGoogleDriveSignInClient(
            lightweightAccount: FakeGoogleDriveSignedInAccount(
              email: 'writer@example.com',
              displayName: 'Writer',
              existingAuthorization: const FakeGoogleDriveAuthorizationHandle(),
            ),
          );
      final GoogleDriveBackupService service = GoogleDriveBackupService(
        signInClient: signInClient,
        androidConnectionSnapshotOverride: () async => null,
      );

      final DriveConnectionState state = await service.getConnectionState();

      expect(state.isConnected, isFalse);
      expect(signInClient.lightweightCalls, 0);
      expect(signInClient.initializeCalls, 0);
    });

    test('getConnectionState 使用 Android 快照回傳已連結帳號', () async {
      final FakeGoogleDriveSignInClient signInClient =
          FakeGoogleDriveSignInClient();
      final GoogleDriveBackupService service = GoogleDriveBackupService(
        signInClient: signInClient,
        androidConnectionSnapshotOverride: () async =>
            const DriveConnectionState(
              isConnected: true,
              email: 'writer@example.com',
              displayName: 'Writer',
            ),
      );

      final DriveConnectionState state = await service.getConnectionState();

      expect(state.isConnected, isTrue);
      expect(state.email, 'writer@example.com');
      expect(state.displayName, 'Writer');
      expect(signInClient.lightweightCalls, 0);
    });

    test(
      'getConnectionState returns disconnected when account has no Drive authorization',
      () async {
        final FakeGoogleDriveSignInClient signInClient =
            FakeGoogleDriveSignInClient(
              lightweightAccount: FakeGoogleDriveSignedInAccount(
                email: 'writer@example.com',
                displayName: 'Writer',
              ),
            );
        final GoogleDriveBackupService service = GoogleDriveBackupService(
          signInClient: signInClient,
        );

        final DriveConnectionState state = await service.getConnectionState();

        expect(state.isConnected, isFalse);
        expect(state.email, isNull);
        expect(state.displayName, isNull);
      },
    );

    test(
      'switchAccount resets session and returns latest account info',
      () async {
        final FakeGoogleDriveSignedInAccount reconnectedAccount =
            FakeGoogleDriveSignedInAccount(
              email: 'after@example.com',
              displayName: 'After',
              authorizedAccount: FakeGoogleDriveSignedInAccount(
                email: 'after@example.com',
                displayName: 'After',
                existingAuthorization:
                    const FakeGoogleDriveAuthorizationHandle(),
              ),
            );
        final FakeGoogleDriveSignInClient signInClient =
            FakeGoogleDriveSignInClient(
              lightweightAccount: FakeGoogleDriveSignedInAccount(
                email: 'before@example.com',
                displayName: 'Before',
                existingAuthorization:
                    const FakeGoogleDriveAuthorizationHandle(),
              ),
              interactiveAccount: reconnectedAccount,
            );
        final GoogleDriveBackupService service = GoogleDriveBackupService(
          signInClient: signInClient,
        );

        final DriveConnectionState state = await service.switchAccount();

        expect(signInClient.disconnectCalls, 1);
        expect(signInClient.signOutCalls, 0);
        expect(signInClient.authenticateCalls, 1);
        expect(state.isConnected, isTrue);
        expect(state.email, 'after@example.com');
        expect(state.displayName, 'After');
      },
    );

    test(
      'connect recovers when plugin reports canceled but session is already authorized',
      () async {
        final FakeGoogleDriveSignedInAccount authorizedAccount =
            FakeGoogleDriveSignedInAccount(
              email: 'writer@example.com',
              displayName: 'Writer',
              existingAuthorization: const FakeGoogleDriveAuthorizationHandle(),
            );
        final FakeGoogleDriveSignInClient signInClient =
            FakeGoogleDriveSignInClient(
              lightweightAccounts: <GoogleDriveSignedInAccount?>[
                null,
                authorizedAccount,
              ],
              authenticateError: const GoogleSignInException(
                code: GoogleSignInExceptionCode.canceled,
              ),
            );
        final GoogleDriveBackupService service = GoogleDriveBackupService(
          signInClient: signInClient,
        );

        final DriveConnectionState state = await service.connect();

        expect(signInClient.authenticateCalls, 1);
        expect(state.isConnected, isTrue);
        expect(state.email, 'writer@example.com');
        expect(state.displayName, 'Writer');
      },
    );

    test(
      'connect recovers by authorizing recovered account after canceled callback',
      () async {
        final FakeGoogleDriveSignedInAccount recoveredAccount =
            FakeGoogleDriveSignedInAccount(
              email: 'writer@example.com',
              displayName: 'Writer',
              authorizedAccount: FakeGoogleDriveSignedInAccount(
                email: 'writer@example.com',
                displayName: 'Writer',
                existingAuthorization:
                    const FakeGoogleDriveAuthorizationHandle(),
              ),
            );
        final FakeGoogleDriveSignInClient signInClient =
            FakeGoogleDriveSignInClient(
              lightweightAccounts: <GoogleDriveSignedInAccount?>[
                null,
                recoveredAccount,
              ],
              authenticateError: const GoogleSignInException(
                code: GoogleSignInExceptionCode.canceled,
                description: 'Account auth failed.',
              ),
            );
        final GoogleDriveBackupService service = GoogleDriveBackupService(
          signInClient: signInClient,
        );

        final DriveConnectionState state = await service.connect();

        expect(signInClient.authenticateCalls, 1);
        expect(state.isConnected, isTrue);
        expect(state.email, 'writer@example.com');
        expect(recoveredAccount.authorizeScopesCalls, 1);
      },
    );
  });
}

final class FakeGoogleDriveSignInClient implements GoogleDriveSignInClient {
  FakeGoogleDriveSignInClient({
    this.lightweightAccount,
    this.lightweightAccounts,
    this.interactiveAccount,
    this.authenticateError,
  });

  GoogleDriveSignedInAccount? lightweightAccount;
  final List<GoogleDriveSignedInAccount?>? lightweightAccounts;
  GoogleDriveSignedInAccount? interactiveAccount;
  final Object? authenticateError;
  int initializeCalls = 0;
  int authenticateCalls = 0;
  int disconnectCalls = 0;
  int signOutCalls = 0;
  int lightweightCalls = 0;

  @override
  Future<GoogleDriveSignedInAccount?> attemptLightweightAuthentication() async {
    final List<GoogleDriveSignedInAccount?>? sequence = lightweightAccounts;
    if (sequence != null && lightweightCalls < sequence.length) {
      return sequence[lightweightCalls++];
    }
    lightweightCalls++;
    return lightweightAccount;
  }

  @override
  Future<GoogleDriveSignedInAccount?> authenticate({
    List<String> scopeHint = const <String>[],
  }) async {
    authenticateCalls++;
    final Object? error = authenticateError;
    if (error != null) {
      throw error;
    }
    return interactiveAccount;
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls++;
    lightweightAccount = null;
  }

  @override
  Future<void> initialize({String? serverClientId}) async {
    initializeCalls++;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
  }
}

final class FakeGoogleDriveSignedInAccount
    implements GoogleDriveSignedInAccount {
  FakeGoogleDriveSignedInAccount({
    required this.email,
    this.displayName,
    this.existingAuthorization,
    this.authorizedAccount,
  });

  @override
  final String email;

  @override
  final String? displayName;

  final GoogleDriveAuthorizationHandle? existingAuthorization;
  final GoogleDriveSignedInAccount? authorizedAccount;
  int authorizeScopesCalls = 0;

  @override
  Future<GoogleDriveAuthorizationHandle?> authorizationForScopes(
    List<String> scopes,
  ) async {
    return existingAuthorization;
  }

  @override
  Future<GoogleDriveAuthorizationHandle> authorizeScopes(
    List<String> scopes,
  ) async {
    authorizeScopesCalls++;
    final GoogleDriveSignedInAccount target = authorizedAccount ?? this;
    final GoogleDriveAuthorizationHandle? authorization = await target
        .authorizationForScopes(scopes);
    if (authorization == null) {
      throw StateError('No authorization configured for test account.');
    }
    return authorization;
  }
}

final class FakeGoogleDriveAuthorizationHandle
    implements GoogleDriveAuthorizationHandle {
  const FakeGoogleDriveAuthorizationHandle();

  @override
  Never createDriveApi(List<String> scopes) {
    throw UnimplementedError('DriveApi creation is not needed in this test.');
  }
}
