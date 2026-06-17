import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/features/session/state/app_session_state.dart';
import 'package:quill_diary/features/settings/pages/settings_page.dart';
import 'package:quill_diary/features/settings/providers/settings_providers.dart';
import 'package:quill_diary/features/settings/vault_transfer_access.dart';
import 'package:quill_diary/features/settings/widgets/drive_backup_section.dart';
import 'package:quill_diary/features/settings/widgets/local_backup_section.dart';
import 'package:quill_diary/features/settings/widgets/settings_sections.dart';
import 'package:quill_diary/infrastructure/drive/drive_backup_service.dart';
import 'package:quill_diary/l10n/l10n.dart';

import '../../helpers/fake_vault_transfer_service.dart';
import '../../helpers/settings_test_scope.dart';
import '../../helpers/test_l10n.dart';

void main() {
  Future<void> pumpDriveSection(
    WidgetTester tester, {
    required DriveConnectionState connectionState,
    required VaultTransferAccess access,
    bool busy = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsDriveConnectionProvider.overrideWith(
            (Ref ref) async => connectionState,
          ),
        ],
        child: MaterialApp(
          locale: appZhLocale,
          supportedLocales: appSupportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: DriveBackupSection(
              access: access,
              isGoogleDriveConfigured: true,
              busy: busy,
              onLink: () {},
              onSwitchAccount: () {},
              onDisconnect: () {},
              onUpload: () {},
              onRestore: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  VaultTransferAccess lockedAccess({required bool hasRecoveryKey}) {
    return VaultTransferAccess.fromContext(
      l10n: testL10n,
      hasUnlockedSession: false,
      hasRecoveryKey: hasRecoveryKey,
      lockStatus: AppLockStatus.locked,
    );
  }

  testWidgets('disconnected state can link Google account', (
    WidgetTester tester,
  ) async {
    await pumpDriveSection(
      tester,
      connectionState: const DriveConnectionState.disconnected(),
      access: lockedAccess(hasRecoveryKey: false),
    );

    expect(
      find.text(testL10n.settingsDriveBackupDisconnectedLabel),
      findsOneWidget,
    );
    expect(
      readSettingsActionButton(
        tester,
        testL10n.settingsDriveBackupLinkButton,
      ).onPressed,
      isNotNull,
    );
  });

  testWidgets('locked without recovery key keeps Drive restore available', (
    WidgetTester tester,
  ) async {
    const DriveConnectionState connectedState = DriveConnectionState(
      isConnected: true,
      email: 'writer@example.com',
      displayName: 'Writer',
    );

    await pumpDriveSection(
      tester,
      connectionState: connectedState,
      access: lockedAccess(hasRecoveryKey: false),
    );

    expect(
      readSettingsActionButton(
        tester,
        testL10n.settingsDriveBackupUploadButton,
      ).onPressed,
      isNull,
    );
    expect(
      readSettingsActionButton(
        tester,
        testL10n.settingsDriveBackupRestoreButton,
      ).onPressed,
      isNotNull,
    );
  });

  testWidgets('locked with recovery key disables Drive restore', (
    WidgetTester tester,
  ) async {
    const DriveConnectionState connectedState = DriveConnectionState(
      isConnected: true,
      email: 'writer@example.com',
      displayName: 'Writer',
    );

    await pumpDriveSection(
      tester,
      connectionState: connectedState,
      access: lockedAccess(hasRecoveryKey: true),
    );

    expect(
      readSettingsActionButton(
        tester,
        testL10n.settingsDriveBackupRestoreButton,
      ).onPressed,
      isNull,
    );
  });

  testWidgets('connected state shows account label and account actions', (
    WidgetTester tester,
  ) async {
    const DriveConnectionState connectedState = DriveConnectionState(
      isConnected: true,
      email: 'writer@example.com',
      displayName: 'Writer',
    );

    await pumpDriveSection(
      tester,
      connectionState: connectedState,
      access: lockedAccess(hasRecoveryKey: false),
    );

    final String accountLabel = connectedState.accountLabel(testL10n)!;
    expect(find.text(accountLabel), findsOneWidget);
    expect(find.text('已連結'), findsNothing);
    expect(
      readSettingsActionButton(
        tester,
        testL10n.settingsDriveBackupSwitchAccountButton,
      ).onPressed,
      isNotNull,
    );
    expect(
      readSettingsActionButton(
        tester,
        testL10n.settingsDriveBackupDisconnectButton,
      ).onPressed,
      isNotNull,
    );
  });

  testWidgets(
    'local backup section keeps external import available without recovery key',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: appZhLocale,
          supportedLocales: appSupportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: LocalBackupSection(
              access: lockedAccess(hasRecoveryKey: false),
              busy: false,
              onCreate: () {},
              onRestore: () {},
              onExport: () {},
              onImport: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        readSettingsActionButton(
          tester,
          testL10n.settingsLocalBackupCreateButton,
        ).onPressed,
        isNull,
      );
      expect(
        readSettingsActionButton(
          tester,
          testL10n.settingsLocalBackupRestoreButton,
        ).onPressed,
        isNull,
      );
      expect(
        readSettingsActionButton(
          tester,
          testL10n.settingsLocalBackupExportToExternalButton,
        ).onPressed,
        isNull,
      );
      expect(
        readSettingsActionButton(
          tester,
          testL10n.settingsLocalBackupImportFromExternalButton,
        ).onPressed,
        isNotNull,
      );
    },
  );

  testWidgets('security overview removes duplicated unlock status card', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      settingsTestScope(
        sessionState: const AppSessionState(status: AppLockStatus.unlocked),
        transferService: FakeVaultTransferService(
          connectionState: const DriveConnectionState.disconnected(),
        ),
        child: MaterialApp(
          locale: appZhLocale,
          supportedLocales: appSupportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const SettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SettingsSecurityOverview), findsOneWidget);
    expect(
      find.text(testL10n.settingsSecurityOverviewUnlockStatusTitle),
      findsNothing,
    );
  });
}
