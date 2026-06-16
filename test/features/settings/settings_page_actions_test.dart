import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/recovery/kdf_descriptor.dart';
import 'package:quill_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/features/session/state/app_session_state.dart';
import 'package:quill_diary/features/settings/legal_disclosures.dart';
import 'package:quill_diary/features/settings/pages/settings_page.dart';
import 'package:quill_diary/features/settings/settings_copy.dart';
import 'package:quill_diary/infrastructure/drive/drive_backup_service.dart';
import 'package:quill_diary/l10n/app_localizations.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../helpers/fake_vault_transfer_service.dart';
import '../../helpers/settings_test_scope.dart';

class _FakeUrlLauncher extends UrlLauncherPlatform {
  bool launchResult = false;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async => launchResult;
}

void main() {
  late _FakeUrlLauncher urlLauncher;
  late UrlLauncherPlatform originalLauncher;

  final RecoveryMetadata recoveryMetadata = RecoveryMetadata(
    vaultId: 'vlt_settings_actions',
    recoveryEnabled: true,
    recoveryKeyVersion: 1,
    recoveryKeyHint: 'WXYZ',
    createdAt: DateTime.parse('2026-05-19T00:00:00Z'),
    kdf: KdfDescriptor.argon2idRecovery(
      saltBytes: List<int>.filled(16, 1),
    ),
  );

  final UnlockedVaultSession unlockedSession = UnlockedVaultSession(
    vaultId: 'vlt_settings_actions',
    trustedDevice: true,
    recoveryWrapKey: const <int>[1, 2, 3],
  );

  const DriveConnectionState connectedState = DriveConnectionState(
    isConnected: true,
    email: 'writer@example.com',
    displayName: 'Writer',
  );

  setUp(() {
    originalLauncher = UrlLauncherPlatform.instance;
    urlLauncher = _FakeUrlLauncher();
    UrlLauncherPlatform.instance = urlLauncher;
  });

  tearDown(() {
    UrlLauncherPlatform.instance = originalLauncher;
  });

  Future<void> pumpSettingsActionsPage(
    WidgetTester tester, {
    required FakeVaultTransferService transferService,
    AppSessionState? sessionState,
  }) async {
    await tester.pumpWidget(
      settingsTestScope(
        transferService: transferService,
        driveConnectionState: connectedState,
        recoveryMetadata: recoveryMetadata,
        sessionState: sessionState ??
            AppSessionState(
              status: AppLockStatus.unlocked,
              session: unlockedSession,
            ),
        child: MaterialApp(
          locale: appZhTwLocale,
          supportedLocales: appSupportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const SettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('legal link failure shows fallback message', (WidgetTester tester) async {
    urlLauncher.launchResult = false;

    await pumpSettingsActionsPage(
      tester,
      transferService: FakeVaultTransferService(connectionState: connectedState),
    );

    await scrollSettingsPageUntilVisible(
      tester,
      find.text(SettingsLegalCopy.sourceCodeTitle),
    );
    await tester.tap(find.text(SettingsLegalCopy.sourceCodeTitle));
    await tester.pumpAndSettle();

    expect(
      find.text(LegalDisclosures.externalLinkUnavailableMessage),
      findsOneWidget,
    );
  });

  testWidgets('disconnect cancel does not call service', (WidgetTester tester) async {
    final FakeVaultTransferService transferService = FakeVaultTransferService(
      connectionState: connectedState,
    );

    await pumpSettingsActionsPage(tester, transferService: transferService);

    await scrollSettingsPageUntilVisible(
      tester,
      settingsActionButton(SettingsDriveBackupCopy.disconnectButton),
    );
    await tester.tap(settingsActionButton(SettingsDriveBackupCopy.disconnectButton));
    await tester.pumpAndSettle();

    expect(find.text(SettingsDriveBackupCopy.disconnectConfirmTitle), findsOneWidget);
    await tester.tap(find.text(SettingsCopy.actionCancel));
    await tester.pumpAndSettle();

    expect(transferService.disconnectCalls, 0);
    expect(find.text(SettingsDriveBackupCopy.disconnectSuccess), findsNothing);
  });

  testWidgets('disconnect confirm calls service and shows success', (WidgetTester tester) async {
    final FakeVaultTransferService transferService = FakeVaultTransferService(
      connectionState: connectedState,
    );

    await pumpSettingsActionsPage(tester, transferService: transferService);

    await scrollSettingsPageUntilVisible(
      tester,
      settingsActionButton(SettingsDriveBackupCopy.disconnectButton),
    );
    await tester.tap(settingsActionButton(SettingsDriveBackupCopy.disconnectButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text(SettingsDriveBackupCopy.disconnectButton).last);
    await tester.pumpAndSettle();

    expect(transferService.disconnectCalls, 1);
    expect(find.text(SettingsDriveBackupCopy.disconnectSuccess), findsOneWidget);
  });

  testWidgets('drive restore error deletes temp backup file', (WidgetTester tester) async {
    final Directory tempDir = Directory.systemTemp.createTempSync('settings_restore_test');
    addTearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });
    File? downloadedFile;

    final FakeVaultTransferService transferService = FakeVaultTransferService(
      connectionState: connectedState,
      driveBackups: const <DriveBackupFile>[
        DriveBackupFile(
          id: 'drive_backup_1',
          name: 'quill-backup.zip',
          createdAt: null,
        ),
      ],
      downloadToTemp: (DriveBackupFile backup) {
        downloadedFile = File('${tempDir.path}/${backup.name}');
        downloadedFile!.writeAsStringSync('backup bytes');
        return downloadedFile!;
      },
      precheckRestoreError: StateError('restore precheck failed'),
    );

    await pumpSettingsActionsPage(tester, transferService: transferService);

    await scrollSettingsPageUntilVisible(
      tester,
      settingsActionButton(SettingsDriveBackupCopy.restoreButton),
    );
    await tester.tap(settingsActionButton(SettingsDriveBackupCopy.restoreButton));
    await tester.pumpAndSettle();

    await tester.tap(find.text('quill-backup.zip'));
    await tester.pumpAndSettle();

    expect(find.text('restore precheck failed'), findsOneWidget);
    expect(downloadedFile, isNotNull);
    expect(downloadedFile!.existsSync(), isFalse);
    expect(transferService.downloadDriveBackupToTempFileCalls, 1);
    expect(transferService.precheckRestoreCalls, 1);
  });
}
