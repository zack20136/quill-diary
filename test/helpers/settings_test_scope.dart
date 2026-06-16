import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_diary/features/session/providers/session_providers.dart';
import 'package:quill_diary/features/session/state/app_session_state.dart';
import 'package:quill_diary/features/settings/providers/settings_providers.dart';
import 'package:quill_diary/features/settings/pages/settings_page.dart';
import 'package:quill_diary/features/settings/widgets/settings_sections.dart';
import 'package:quill_diary/infrastructure/drive/drive_backup_service.dart';
import 'package:quill_diary/infrastructure/security/app_unlock_mode.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/providers/core_providers.dart';

import 'fake_session_vault_repository.dart';
import 'fake_vault_transfer_service.dart';

/// 建立 Settings 相關 widget 測試用的 ProviderScope。
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
  return ProviderScope(
    overrides: [
      supportedPlatformProvider.overrideWith((Ref ref) => true),
      vaultRepositoryProvider.overrideWithValue(
        repository ?? FakeSessionVaultRepository(metadata: recoveryMetadata),
      ),
      vaultTransferServiceProvider.overrideWithValue(
        transferService ?? FakeVaultTransferService(),
      ),
      effectiveAppSessionProvider.overrideWith((Ref ref) async => sessionState),
      recoveryMetadataProvider.overrideWith(
        (Ref ref) async => recoveryMetadata,
      ),
      unlockModeProvider.overrideWith((Ref ref) async => AppUnlockMode.none),
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
