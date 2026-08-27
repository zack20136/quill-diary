import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/recovery/kdf_descriptor.dart';
import 'package:quill_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_diary/application/session/state/app_session_state.dart';
import 'package:quill_diary/presentation/settings/pages/settings_page.dart';
import 'package:quill_diary/application/settings/settings_providers.dart';
import 'package:quill_diary/application/settings/vault_transfer_capabilities.dart';
import 'package:quill_diary/presentation/settings/widgets/drive_backup_section.dart';
import 'package:quill_diary/infrastructure/drive/drive_backup_service.dart';

import '../../helpers/presentation/settings/settings_test_scope.dart';
import '../../helpers/shared/test_l10n.dart';
import '../../helpers/shared/widget_test_app.dart';
import '../../helpers/storage/fake_vault_transfer_service.dart';

void main() {
  Future<void> pumpDriveSection(
    WidgetTester tester, {
    required DriveConnectionState connectionState,
    required VaultTransferCapabilities access,
    Key? scopeKey,
    bool canManageDriveAccount = false,
    bool busy = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        key: scopeKey,
        overrides: [
          settingsDriveConnectionProvider.overrideWith(
            (Ref ref) async => connectionState,
          ),
        ],
        child: widgetTestApp(
          center: false,
          includeDarkTheme: true,
          child: DriveBackupSection(
            access: access,
            canManageDriveAccount: canManageDriveAccount,
            isGoogleDriveConfigured: true,
            busy: busy,
            onLink: () {},
            onSwitchAccount: () {},
            onDisconnect: () {},
            onUpload: () {},
            onRestore: () {},
            onCancelUpload: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  VaultTransferCapabilities lockedAccess({required bool hasRecoveryKey}) {
    return VaultTransferCapabilities.fromSessionContext(
      l10n: testL10n,
      hasUnlockedSession: false,
      hasRecoveryKey: hasRecoveryKey,
      lockStatus: AppLockStatus.locked,
    );
  }

  testWidgets('帳號與備份操作會套用存取權限', (WidgetTester tester) async {
    const DriveConnectionState connectedState = DriveConnectionState(
      isConnected: true,
      email: 'writer@example.com',
      displayName: 'Writer',
    );

    await pumpDriveSection(
      tester,
      connectionState: connectedState,
      access: lockedAccess(hasRecoveryKey: false),
      scopeKey: const ValueKey<String>('connected-drive-section'),
    );

    final String accountLabel = connectedState.accountLabel(testL10n)!;
    expect(find.text(accountLabel), findsOneWidget);
    expect(
      find.text(testL10n.settingsDriveBackupFallbackAccountLabel),
      findsNothing,
    );
    expect(
      readAppActionButton(
        tester,
        testL10n.settingsDriveBackupUploadButton,
      ).onPressed,
      isNull,
    );
    expect(
      readAppActionButton(
        tester,
        testL10n.settingsDriveBackupRestoreButton,
      ).onPressed,
      isNotNull,
    );
    expect(
      readAppActionButton(
        tester,
        testL10n.settingsDriveBackupSwitchAccountButton,
      ).onPressed,
      isNull,
    );
    expect(
      readAppActionButton(
        tester,
        testL10n.settingsDriveBackupDisconnectButton,
      ).onPressed,
      isNull,
    );

    await pumpDriveSection(
      tester,
      connectionState: const DriveConnectionState.disconnected(),
      access: lockedAccess(hasRecoveryKey: false),
      scopeKey: const ValueKey<String>('disconnected-drive-section'),
    );

    expect(
      readAppActionButton(
        tester,
        testL10n.settingsDriveBackupLinkButton,
      ).onPressed,
      isNull,
    );
  });

  testWidgets('Drive 連線讀取失敗時顯示錯誤狀態與重新載入按鈕', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsDriveConnectionProvider.overrideWith(
            (Ref ref) async => throw StateError('drive connection failed'),
          ),
        ],
        child: widgetTestApp(
          center: false,
          includeDarkTheme: true,
          child: DriveBackupSection(
            access: lockedAccess(hasRecoveryKey: false),
            canManageDriveAccount: true,
            isGoogleDriveConfigured: true,
            busy: false,
            onLink: () {},
            onSwitchAccount: () {},
            onDisconnect: () {},
            onUpload: () {},
            onRestore: () {},
            onCancelUpload: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(testL10n.settingsDriveBackupConnectionErrorLabel),
      findsOneWidget,
    );
    expect(
      find.text(testL10n.settingsDriveBackupDisconnectedLabel),
      findsNothing,
    );
    expect(
      readAppActionButton(
        tester,
        testL10n.settingsDriveBackupConnectionRetryButton,
      ).onPressed,
      isNotNull,
    );
    expect(find.text('drive connection failed'), findsOneWidget);
  });

  testWidgets('鎖定且已有復原金鑰時會停用輪替復原金鑰', (WidgetTester tester) async {
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
        child: const SettingsPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      readAppActionButton(
        tester,
        testL10n.settingsSecurityOverviewRotateRecoveryKeyButton,
      ).onPressed,
      isNull,
    );
  });
}
