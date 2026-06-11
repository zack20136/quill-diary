import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/features/session/providers/session_providers.dart';
import 'package:quill_diary/features/session/state/app_session_state.dart';
import 'package:quill_diary/features/settings/pages/settings_page.dart';
import 'package:quill_diary/features/settings/providers/settings_providers.dart';
import 'package:quill_diary/domain/recovery/kdf_descriptor.dart';
import 'package:quill_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_diary/features/settings/settings_copy.dart';
import 'package:quill_diary/features/settings/vault_transfer_access.dart';
import 'package:quill_diary/infrastructure/drive/drive_backup_service.dart';
import 'package:quill_diary/infrastructure/security/app_unlock_mode.dart';
import 'package:quill_diary/shared/providers/core_providers.dart';

import '../../helpers/fake_vault_transfer_service.dart';
import '../../helpers/fake_vault_repository.dart';

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

  final RecoveryMetadata sampleRecoveryMetadata = RecoveryMetadata(
    vaultId: 'vlt_test',
    recoveryEnabled: true,
    recoveryKeyVersion: 1,
    recoveryKeyHint: 'WXYZ',
    createdAt: DateTime.parse('2026-05-19T00:00:00Z'),
    kdf: KdfDescriptor.argon2idRecovery(
      saltBytes: List<int>.filled(16, 1),
    ),
  );

  Future<void> pumpSettingsPage(
    WidgetTester tester, {
    required DriveConnectionState connectionState,
    required AppSessionState sessionState,
    required FakeVaultTransferService transferService,
    RecoveryMetadata? recoveryMetadata,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supportedPlatformProvider.overrideWith((Ref ref) => true),
          vaultRepositoryProvider.overrideWithValue(
            FakeVaultRepository(metadata: recoveryMetadata),
          ),
          vaultTransferServiceProvider.overrideWithValue(transferService),
          effectiveAppSessionProvider.overrideWith(
            (Ref ref) async => sessionState,
          ),
          recoveryMetadataProvider.overrideWith(
            (Ref ref) async => recoveryMetadata,
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

  testWidgets('disconnected state can link Google account', (WidgetTester tester) async {
    final FakeVaultTransferService transferService = FakeVaultTransferService(
      connectionState: const DriveConnectionState.disconnected(),
    );

    await pumpSettingsPage(
      tester,
      connectionState: const DriveConnectionState.disconnected(),
      sessionState: const AppSessionState(status: AppLockStatus.locked),
      transferService: transferService,
    );

    final ButtonStyleButton linkButton = await findButtonByLabel(
      tester,
      SettingsDriveBackupCopy.linkButton,
    );

    expect(linkButton.onPressed, isNotNull);
    expect(
      find.text(SettingsDriveBackupCopy.disconnectedLabel, skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('locked without recovery key keeps Drive restore available',
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
    expect(restoreButton.onPressed, isNotNull);
  });

  testWidgets('locked with recovery key disables Drive restore',
      (WidgetTester tester) async {
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
      recoveryMetadata: sampleRecoveryMetadata,
    );

    final ButtonStyleButton restoreButton = await findButtonByLabel(
      tester,
      SettingsDriveBackupCopy.restoreButton,
    );
    expect(restoreButton.onPressed, isNull);
  });

  testWidgets('connected state shows account label and account actions',
      (WidgetTester tester) async {
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

    final String accountLabel = connectedState.accountLabel!;
    await ensureVisibleText(tester, accountLabel);
    await ensureVisibleText(
      tester,
      VaultTransferCopy.driveSectionDescriptionBackupLocked,
    );

    expect(find.text(accountLabel, skipOffstage: false), findsOneWidget);
    expect(find.text('已連結', skipOffstage: false), findsNothing);

    final ButtonStyleButton switchButton = await findButtonByLabel(
      tester,
      SettingsDriveBackupCopy.switchAccountButton,
    );
    final ButtonStyleButton disconnectButton = await findButtonByLabel(
      tester,
      SettingsDriveBackupCopy.disconnectButton,
    );

    expect(switchButton.onPressed, isNotNull);
    expect(disconnectButton.onPressed, isNotNull);
  });

  testWidgets('local backup section keeps external import available without recovery key',
      (WidgetTester tester) async {
    await pumpSettingsPage(
      tester,
      connectionState: const DriveConnectionState.disconnected(),
      sessionState: const AppSessionState(status: AppLockStatus.locked),
      transferService: FakeVaultTransferService(
        connectionState: const DriveConnectionState.disconnected(),
      ),
    );

    final ButtonStyleButton createButton = await findButtonByLabel(
      tester,
      SettingsLocalBackupCopy.createButton,
    );
    final ButtonStyleButton restoreButton = await findButtonByLabel(
      tester,
      SettingsLocalBackupCopy.restoreButton,
    );
    final ButtonStyleButton exportButton = await findButtonByLabel(
      tester,
      SettingsLocalBackupCopy.exportToExternalButton,
    );
    final ButtonStyleButton importButton = await findButtonByLabel(
      tester,
      SettingsLocalBackupCopy.importFromExternalButton,
    );

    expect(createButton.onPressed, isNull);
    expect(restoreButton.onPressed, isNull);
    expect(exportButton.onPressed, isNull);
    expect(importButton.onPressed, isNotNull);
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
