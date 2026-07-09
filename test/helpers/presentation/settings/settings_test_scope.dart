import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_diary/application/session/providers/session_providers.dart';
import 'package:quill_diary/application/session/state/app_session_state.dart';
import 'package:quill_diary/application/settings/settings_providers.dart';
import 'package:quill_diary/presentation/settings/pages/settings_page.dart';
import 'package:quill_diary/presentation/settings/widgets/settings_sections.dart';
import 'package:quill_diary/infrastructure/crypto/crypto_service.dart';
import 'package:quill_diary/infrastructure/database/index_database_manager.dart';
import 'package:quill_diary/infrastructure/drive/drive_backup_service.dart';
import 'package:quill_diary/infrastructure/markdown/front_matter_codec.dart';
import 'package:quill_diary/infrastructure/security/app_unlock_mode.dart';
import 'package:quill_diary/infrastructure/storage/backup_status_store.dart';
import 'package:quill_diary/infrastructure/storage/editor_draft_store.dart';
import 'package:quill_diary/infrastructure/storage/external_directory_store.dart';
import 'package:quill_diary/infrastructure/storage/restore_precheck.dart';
import 'package:quill_diary/infrastructure/storage/storage_providers.dart';
import 'package:quill_diary/infrastructure/storage/vault_archive_io.dart';
import 'package:quill_diary/infrastructure/storage/vault_backup_service.dart';
import 'package:quill_diary/infrastructure/storage/vault_restore_service.dart';
import 'package:quill_diary/infrastructure/storage/vault_transfer_service.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/platform/vault_platform_support.dart';

import '../../app_test_theme.dart';
import '../../session/fake_session_vault_repository.dart';
import '../../storage/fake_vault_transfer_service.dart';
import '../../vault/test_vault_path_strategy.dart';

class _SettingsBackupServiceAdapter extends VaultBackupService {
  _SettingsBackupServiceAdapter(this._transferService)
    : super(
        archiveIo: VaultArchiveIo(
          pathStrategy: DummyVaultPathStrategy(),
          repository: FakeSessionVaultRepository(),
          frontMatterCodec: const FrontMatterCodec(),
          indexDatabaseManager: IndexDatabaseManager(DummyVaultPathStrategy()),
          editorDraftStore: EditorDraftStore(
            pathStrategy: DummyVaultPathStrategy(),
            cryptoService: LocalCryptoService(),
          ),
        ),
        driveBackupService: _UnusedDriveBackupService(),
        externalDirectoryStore: ExternalDirectoryStore(
          DummyVaultPathStrategy(),
        ),
        pathStrategy: DummyVaultPathStrategy(),
      );

  final FakeVaultTransferService _transferService;

  @override
  Future<DriveConnectionState> getGoogleDriveConnectionState() {
    return _transferService.getGoogleDriveConnectionState();
  }

  @override
  Future<DriveConnectionState> linkGoogleDrive() {
    return _transferService.linkGoogleDrive();
  }

  @override
  Future<DriveConnectionState> switchGoogleDrive() {
    return _transferService.switchGoogleDrive();
  }

  @override
  Future<void> disconnectGoogleDrive() {
    return _transferService.disconnectGoogleDrive();
  }

  @override
  Future<List<DriveBackupFile>> listDriveBackups() {
    return _transferService.listDriveBackups();
  }

  @override
  Future<void> deleteDriveBackup(DriveBackupFile backup) {
    return _transferService.deleteDriveBackup(backup);
  }

  @override
  Future<void> deleteAppLocalBackup(LocalBackupFile backup) {
    return _transferService.deleteAppLocalBackup(backup);
  }
}

class _SettingsRestoreServiceAdapter extends VaultRestoreService {
  _SettingsRestoreServiceAdapter(this._transferService)
    : super(
        archiveIo: VaultArchiveIo(
          pathStrategy: DummyVaultPathStrategy(),
          repository: FakeSessionVaultRepository(),
          frontMatterCodec: const FrontMatterCodec(),
          indexDatabaseManager: IndexDatabaseManager(DummyVaultPathStrategy()),
          editorDraftStore: EditorDraftStore(
            pathStrategy: DummyVaultPathStrategy(),
            cryptoService: LocalCryptoService(),
          ),
        ),
        vaultRepository: FakeSessionVaultRepository(),
        backupService: _SettingsBackupServiceAdapter(_transferService),
        pathStrategy: DummyVaultPathStrategy(),
      );

  final FakeVaultTransferService _transferService;

  @override
  Future<PickedBackupFile?> pickLocalBackupFile(AppLocalizations l10n) {
    return _transferService.pickLocalBackupFile(l10n);
  }

  @override
  Future<RestorePrecheck> precheckRestore(File backupFile) {
    return _transferService.precheckRestore(backupFile);
  }

  @override
  Future<File> downloadDriveBackupToTempFile(
    DriveBackupFile backup, {
    dynamic onProgress,
  }) {
    return _transferService.downloadDriveBackupToTempFile(
      backup,
      onProgress: onProgress,
    );
  }

  @override
  Future<void> verifyBackupRecoveryKey(File backupFile, String recoveryKey) {
    return _transferService.verifyBackupRecoveryKey(backupFile, recoveryKey);
  }

  @override
  Future<void> restoreFromBackupFile(
    File backupFile, {
    bool preserveTrustedDeviceAccess = false,
    dynamic onProgress,
  }) {
    return _transferService.restoreFromBackupFile(
      backupFile,
      preserveTrustedDeviceAccess: preserveTrustedDeviceAccess,
      onProgress: onProgress,
    );
  }
}

class _UnusedDriveBackupService implements DriveBackupService {
  @override
  Future<DriveConnectionState> connect() => throw UnimplementedError();

  @override
  Future<void> deleteBackup(String fileId) => throw UnimplementedError();

  @override
  Future<File> downloadBackupById({
    required String fileId,
    required String fileName,
    required Directory destinationDirectory,
    int? totalBytes,
    dynamic onProgress,
  }) => throw UnimplementedError();

  @override
  Future<void> disconnect() => throw UnimplementedError();

  @override
  Future<DriveConnectionState> getConnectionState() =>
      throw UnimplementedError();

  @override
  Future<List<DriveBackupFile>> listBackups() => throw UnimplementedError();

  @override
  Future<List<DriveBackupFile>> pruneBackups({required int retainCount}) =>
      throw UnimplementedError();

  @override
  Future<DriveConnectionState> switchAccount() => throw UnimplementedError();

  @override
  Future<String> uploadBackup(File backupFile, {dynamic onProgress}) =>
      throw UnimplementedError();
}

Widget settingsTestScope({
  required Widget child,
  FakeSessionVaultRepository? repository,
  FakeVaultTransferService? transferService,
  AppSessionState sessionState = const AppSessionState(
    status: AppLockStatus.locked,
  ),
  RecoveryMetadata? recoveryMetadata,
  DriveConnectionState? driveConnectionState,
}) {
  final FakeVaultTransferService resolvedTransferService =
      transferService ?? FakeVaultTransferService();
  return ProviderScope(
    overrides: [
      vaultPlatformSupportProvider.overrideWith((Ref ref) => true),
      vaultRepositoryProvider.overrideWithValue(
        repository ?? FakeSessionVaultRepository(metadata: recoveryMetadata),
      ),
      vaultTransferServiceProvider.overrideWithValue(resolvedTransferService),
      vaultBackupServiceProvider.overrideWithValue(
        _SettingsBackupServiceAdapter(resolvedTransferService),
      ),
      vaultRestoreServiceProvider.overrideWithValue(
        _SettingsRestoreServiceAdapter(resolvedTransferService),
      ),
      effectiveAppSessionProvider.overrideWith((Ref ref) async => sessionState),
      recoveryMetadataProvider.overrideWith(
        (Ref ref) async => recoveryMetadata,
      ),
      unlockModeProvider.overrideWith((Ref ref) async => AppUnlockMode.none),
      trustedDeviceAccessProvider.overrideWith((Ref ref) async => false),
      backupStatusProvider.overrideWith(
        (Ref ref) async => const BackupStatusSnapshot(),
      ),
      if (driveConnectionState != null)
        settingsDriveConnectionProvider.overrideWith(
          (Ref ref) async => driveConnectionState,
        ),
    ],
    child: child,
  );
}

Future<void> pumpSettingsPage(
  WidgetTester tester, {
  required DriveConnectionState connectionState,
  required AppSessionState sessionState,
  required FakeVaultTransferService transferService,
  RecoveryMetadata? recoveryMetadata,
}) async {
  await tester.pumpWidget(
    settingsTestScope(
      driveConnectionState: connectionState,
      sessionState: sessionState,
      transferService: transferService,
      recoveryMetadata: recoveryMetadata,
      child: MaterialApp(
        theme: appTestTheme(),
        darkTheme: appTestTheme(brightness: Brightness.dark),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsPage(),
      ),
    ),
  );
}

Finder settingsActionButton(String label) {
  return find.byWidgetPredicate(
    (Widget widget) => widget is SettingsActionButton && widget.label == label,
  );
}

SettingsActionButton readSettingsActionButton(
  WidgetTester tester,
  String label,
) {
  return tester.widget<SettingsActionButton>(settingsActionButton(label));
}

Future<void> scrollSettingsPageUntilVisible(
  WidgetTester tester,
  Finder finder,
) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }
}

Future<File> createTempBackupFile(
  Directory tempDir, {
  String name = 'drive-backup.zip',
}) async {
  final File file = File('${tempDir.path}/$name');
  await file.writeAsString('backup');
  return file;
}
