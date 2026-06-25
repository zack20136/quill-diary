import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/recovery/kdf_descriptor.dart';
import 'package:quill_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_diary/features/session/state/app_session_state.dart';
import 'package:quill_diary/features/settings/pages/settings_page.dart';
import 'package:quill_diary/features/settings/providers/settings_providers.dart';
import 'package:quill_diary/features/settings/vault_transfer_access.dart';
import 'package:quill_diary/features/settings/widgets/drive_backup_section.dart';
import 'package:quill_diary/features/settings/widgets/local_backup_section.dart';
import 'package:quill_diary/features/settings/widgets/settings_sections.dart';
import 'package:quill_diary/infrastructure/drive/drive_backup_service.dart';
import 'package:quill_diary/l10n/l10n.dart';

import '../../../helpers/storage/fake_vault_transfer_service.dart';
import '../../../helpers/features/settings/settings_test_scope.dart';
import '../../../helpers/shared/test_l10n.dart';

void main() {
  Future<void> pumpDriveSection(
    WidgetTester tester, {
    required DriveConnectionState connectionState,
    required VaultTransferAccess access,
    bool canManageDriveAccount = false,
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
              canManageDriveAccount: canManageDriveAccount,
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

  testWidgets('鎖定且未連線時會停用雲端連結', (WidgetTester tester) async {
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
      isNull,
    );
  });

  testWidgets('鎖定但沒有復原金鑰時仍可進行雲端還原', (WidgetTester tester) async {
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

  testWidgets('鎖定且已有復原金鑰時會停用雲端還原', (WidgetTester tester) async {
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

  testWidgets('鎖定且已連線時會停用帳號操作', (WidgetTester tester) async {
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
    expect(
      find.text(testL10n.settingsDriveBackupFallbackAccountLabel),
      findsNothing,
    );
    expect(
      readSettingsActionButton(
        tester,
        testL10n.settingsDriveBackupSwitchAccountButton,
      ).onPressed,
      isNull,
    );
    expect(
      readSettingsActionButton(
        tester,
        testL10n.settingsDriveBackupDisconnectButton,
      ).onPressed,
      isNull,
    );
  });

  testWidgets('本機備份區塊在沒有復原金鑰時仍可匯入外部備份', (WidgetTester tester) async {
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
  });

  testWidgets('安全性總覽不會重複顯示解鎖狀態卡片', (WidgetTester tester) async {
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

  testWidgets(
    'locked without recovery key keeps create recovery key available',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        settingsTestScope(
          sessionState: const AppSessionState(status: AppLockStatus.locked),
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

      expect(
        readSettingsActionButton(
          tester,
          testL10n.settingsSecurityOverviewCreateRecoveryKeyButton,
        ).onPressed,
        isNotNull,
      );
    },
  );

  testWidgets('鎖定且已有復原金鑰時會停用建立復原金鑰', (WidgetTester tester) async {
    await tester.pumpWidget(
      settingsTestScope(
        sessionState: const AppSessionState(status: AppLockStatus.locked),
        recoveryMetadata: RecoveryMetadata(
          vaultId: 'vlt_test',
          recoveryEnabled: true,
          recoveryKeyVersion: 1,
          recoveryKeyHint: 'ABCD',
          createdAt: DateTime.utc(2026, 1, 1),
          kdf: KdfDescriptor.argon2idRecovery(
            saltBytes: List<int>.filled(16, 1),
          ),
        ),
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

    expect(
      readSettingsActionButton(
        tester,
        testL10n.settingsSecurityOverviewRotateRecoveryKeyButton,
      ).onPressed,
      isNull,
    );
  });
}
