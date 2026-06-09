import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/features/session/providers/session_providers.dart';
import 'package:quill_diary/features/session/state/app_session_state.dart';
import 'package:quill_diary/features/settings/pages/settings_page.dart';
import 'package:quill_diary/features/settings/providers/settings_providers.dart';
import 'package:quill_diary/features/settings/settings_copy.dart';
import 'package:quill_diary/infrastructure/drive/drive_backup_service.dart';
import 'package:quill_diary/infrastructure/security/app_unlock_mode.dart';
import 'package:quill_diary/shared/providers/core_providers.dart';

import '../../helpers/fake_vault_repository.dart';
import '../../helpers/fake_vault_transfer_service.dart';

void main() {
  Future<void> ensureVisibleText(
    WidgetTester tester,
    String text,
  ) async {
    final Finder textFinder = find.text(text, skipOffstage: false);
    if (textFinder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        textFinder,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
    }
  }

  Future<ButtonStyleButton> findButtonByLabel(
    WidgetTester tester,
    String label,
  ) async {
    await ensureVisibleText(tester, label);

    final Finder labelFinder = find.text(label, skipOffstage: false);
    expect(labelFinder, findsOneWidget);

    final Finder buttonFinder = find.ancestor(
      of: labelFinder,
      matching: find.byWidgetPredicate(
        (Widget widget) => widget is ButtonStyleButton,
      ),
    );
    expect(buttonFinder, findsAtLeastNWidgets(1));
    return tester.widget<ButtonStyleButton>(buttonFinder.first);
  }

  Future<void> pumpSettingsPage(
    WidgetTester tester, {
    required DriveConnectionState connectionState,
    required AppSessionState sessionState,
    required FakeVaultTransferService transferService,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supportedPlatformProvider.overrideWith((Ref ref) => true),
          vaultRepositoryProvider.overrideWithValue(FakeVaultRepository()),
          vaultTransferServiceProvider.overrideWithValue(transferService),
          effectiveAppSessionProvider.overrideWith(
            (Ref ref) async => sessionState,
          ),
          recoveryMetadataProvider.overrideWith(
            (Ref ref) async => null,
          ),
          unlockModeProvider.overrideWith(
            (Ref ref) async => AppUnlockMode.none,
          ),
          settingsDriveConnectionProvider.overrideWith(
            (Ref ref) async => connectionState,
          ),
        ],
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('disconnected state can connect Google Drive', (WidgetTester tester) async {
    final FakeVaultTransferService transferService = FakeVaultTransferService(
      connectionState: const DriveConnectionState.disconnected(),
    );

    await pumpSettingsPage(
      tester,
      connectionState: const DriveConnectionState.disconnected(),
      sessionState: const AppSessionState(status: AppLockStatus.locked),
      transferService: transferService,
    );

    final ButtonStyleButton connectButton = await findButtonByLabel(
      tester,
      SettingsDriveBackupCopy.connectButton,
    );

    expect(connectButton.onPressed, isNotNull);
  });

  testWidgets('locked state disables connected Drive transfer actions',
      (WidgetTester tester) async {
    final DriveConnectionState connectedState = const DriveConnectionState(
      isConnected: true,
      email: 'writer@example.com',
      displayName: 'Writer',
    );
    final FakeVaultTransferService transferService = FakeVaultTransferService(
      connectionState: connectedState,
    );

    await pumpSettingsPage(
      tester,
      connectionState: connectedState,
      sessionState: const AppSessionState(status: AppLockStatus.locked),
      transferService: transferService,
    );

    final ButtonStyleButton uploadButton = await findButtonByLabel(
      tester,
      SettingsDriveBackupCopy.uploadButton,
    );
    final ButtonStyleButton restoreButton = await findButtonByLabel(
      tester,
      SettingsDriveBackupCopy.restoreButton,
    );

    expect(uploadButton.onPressed, isNull);
    expect(restoreButton.onPressed, isNull);
  });

  testWidgets('connected state shows Drive account label', (WidgetTester tester) async {
    final DriveConnectionState connectedState = const DriveConnectionState(
      isConnected: true,
      email: 'writer@example.com',
      displayName: 'Writer',
    );

    await pumpSettingsPage(
      tester,
      connectionState: connectedState,
      sessionState: const AppSessionState(status: AppLockStatus.locked),
      transferService: FakeVaultTransferService(connectionState: connectedState),
    );

    final String connectedHint = SettingsDriveBackupCopy.connectedHint(
      connectedState.accountLabel,
    );
    await ensureVisibleText(tester, connectedHint);

    expect(
      find.text(connectedHint, skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('local backup section shows app-managed and external backup actions',
      (WidgetTester tester) async {
    await pumpSettingsPage(
      tester,
      connectionState: const DriveConnectionState.disconnected(),
      sessionState: const AppSessionState(status: AppLockStatus.locked),
      transferService: FakeVaultTransferService(
        connectionState: const DriveConnectionState.disconnected(),
      ),
    );

    await ensureVisibleText(tester, SettingsLocalBackupCopy.createButton);
    await ensureVisibleText(tester, SettingsLocalBackupCopy.restoreButton);
    await ensureVisibleText(tester, SettingsLocalBackupCopy.exportToExternalButton);
    await ensureVisibleText(tester, SettingsLocalBackupCopy.importFromExternalButton);

    expect(find.text(SettingsLocalBackupCopy.createButton, skipOffstage: false), findsOneWidget);
    expect(find.text(SettingsLocalBackupCopy.restoreButton, skipOffstage: false), findsOneWidget);
    expect(
      find.text(SettingsLocalBackupCopy.exportToExternalButton, skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.text(SettingsLocalBackupCopy.importFromExternalButton, skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('security overview removes duplicated unlock status card',
      (WidgetTester tester) async {
    await pumpSettingsPage(
      tester,
      connectionState: const DriveConnectionState.disconnected(),
      sessionState: const AppSessionState(status: AppLockStatus.unlocked),
      transferService: FakeVaultTransferService(
        connectionState: const DriveConnectionState.disconnected(),
      ),
    );

    expect(find.text(SettingsSecurityOverviewCopy.unlockStatusTitle), findsNothing);
  });
}
