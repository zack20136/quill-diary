import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/session/session_providers.dart';
import 'package:quill_diary/application/session/session_state.dart';
import 'package:quill_diary/application/settings/settings_providers.dart';
import 'package:quill_diary/application/transfer/vault_backup_providers.dart';
import 'package:quill_diary/application/vault/vault_providers.dart';
import 'package:quill_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_diary/infrastructure/drive/drive_backup_service.dart';
import 'package:quill_diary/infrastructure/security/app_unlock_mode.dart';
import 'package:quill_diary/infrastructure/storage/backup_status_store.dart';
import 'package:quill_diary/shared/platform/vault_platform_support.dart';
import 'package:quill_diary/shared/presentation/widgets/app_action_button.dart';

import '../../session/fake_session_vault_repository.dart';
import '../../shared/widget_test_app.dart';
import '../../storage/fake_vault_transfer_services.dart';

Widget settingsTestScope({
  required Widget child,
  FakeSessionVaultRepository? repository,
  FakeVaultBackupService? backupService,
  FakeVaultRestoreService? restoreService,
  AppSessionState sessionState = const AppSessionState(
    status: AppLockStatus.locked,
  ),
  RecoveryMetadata? recoveryMetadata,
  DriveConnectionState? driveConnectionState,
  bool wrapMaterialApp = true,
  bool includeDarkTheme = true,
}) {
  final Widget appChild = wrapMaterialApp
      ? widgetTestApp(
          center: false,
          includeDarkTheme: includeDarkTheme,
          child: child,
        )
      : child;
  return ProviderScope(
    overrides: [
      vaultPlatformSupportProvider.overrideWith((Ref ref) => true),
      vaultRepositoryProvider.overrideWithValue(
        repository ?? FakeSessionVaultRepository(metadata: recoveryMetadata),
      ),
      vaultBackupServiceProvider.overrideWithValue(
        backupService ?? FakeVaultBackupService(),
      ),
      vaultRestoreServiceProvider.overrideWithValue(
        restoreService ?? FakeVaultRestoreService(),
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
    child: appChild,
  );
}

Finder appActionButton(String label) {
  return find.byWidgetPredicate(
    (Widget widget) => widget is AppActionButton && widget.label == label,
  );
}

AppActionButton readAppActionButton(WidgetTester tester, String label) {
  return tester.widget<AppActionButton>(appActionButton(label));
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
