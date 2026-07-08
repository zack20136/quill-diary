import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:quill_diary/app/router.dart';
import 'package:quill_diary/application/editor/editor_draft_providers.dart';
import 'package:quill_diary/application/session/providers/session_providers.dart';
import 'package:quill_diary/application/session/state/app_session_state.dart';
import 'package:quill_diary/application/settings/personalization_providers.dart';
import 'package:quill_diary/application/settings/settings_providers.dart';
import 'package:quill_diary/infrastructure/drive/drive_backup_service.dart';
import 'package:quill_diary/infrastructure/preferences/editor_typography_preferences.dart';
import 'package:quill_diary/infrastructure/preferences/personalization_preferences.dart';
import 'package:quill_diary/infrastructure/preferences/user_preferences.dart';
import 'package:quill_diary/infrastructure/security/app_unlock_mode.dart';
import 'package:quill_diary/infrastructure/storage/backup_status_store.dart';
import 'package:quill_diary/infrastructure/storage/storage_providers.dart';
import 'package:quill_diary/l10n/app_localizations.dart';
import 'package:quill_diary/presentation/editor/pages/editor_page.dart';
import 'package:quill_diary/presentation/home/pages/home_page.dart';
import 'package:quill_diary/presentation/settings/pages/about_page.dart';
import 'package:quill_diary/presentation/settings/pages/personalization_page.dart';
import 'package:quill_diary/presentation/settings/pages/settings_page.dart';
import 'package:quill_diary/presentation/settings/pages/support_page.dart';
import 'package:quill_diary/shared/platform/vault_platform_support.dart';

import '../../helpers/app_test_theme.dart';
import '../../helpers/storage/fake_vault_transfer_service.dart';
import '../../helpers/vault/fake_entry_index_vault_repository.dart';

void main() {
  late GoRouter router;

  setUp(() {
    router = AppRouter.createRouter();
  });

  Widget wrapRouterApp() {
    return ProviderScope(
      overrides: [
        vaultPlatformSupportProvider.overrideWith((Ref ref) => true),
        vaultRepositoryProvider.overrideWithValue(
          FakeEntryIndexVaultRepository(),
        ),
        vaultTransferServiceProvider.overrideWithValue(
          FakeVaultTransferService(),
        ),
        effectiveAppSessionProvider.overrideWith(
          (Ref ref) async =>
              const AppSessionState(status: AppLockStatus.locked),
        ),
        recoveryMetadataProvider.overrideWith((Ref ref) async => null),
        unlockModeProvider.overrideWith((Ref ref) async => AppUnlockMode.none),
        settingsDriveConnectionProvider.overrideWith(
          (Ref ref) async => const DriveConnectionState.disconnected(),
        ),
        backupStatusProvider.overrideWith(
          (Ref ref) async => const BackupStatusSnapshot(),
        ),
        trustedDeviceAccessProvider.overrideWith((Ref ref) async => false),
        editorDraftKeysProvider.overrideWith((Ref ref) async => <String>{}),
        personalizationPreferencesProvider.overrideWith(
          _FixedPersonalizationPreferencesController.new,
        ),
      ],
      child: MaterialApp.router(
        theme: appTestTheme(),
        darkTheme: appTestTheme(brightness: Brightness.dark),
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }

  Future<void> pumpRoute(WidgetTester tester, String location) async {
    router.go(location);
    await tester.pumpWidget(wrapRouterApp());
    await tester.pumpAndSettle();
  }

  testWidgets('首頁路由會建立 HomePage', (WidgetTester tester) async {
    await pumpRoute(tester, AppRouter.homeRoute);
    expect(find.byType(HomePage), findsOneWidget);
  });

  testWidgets('編輯器路由未帶 entryId 時會建立 EditorPage', (WidgetTester tester) async {
    await pumpRoute(tester, AppRouter.editorRoute);
    final EditorPage page = tester.widget<EditorPage>(find.byType(EditorPage));
    expect(page.entryId, isNull);
    expect(page.startInEditMode, isFalse);
  });

  testWidgets('編輯器詳細路由會傳遞 entryId', (WidgetTester tester) async {
    await pumpRoute(tester, '/editor/abc');
    final EditorPage page = tester.widget<EditorPage>(find.byType(EditorPage));
    expect(page.entryId, 'abc');
    expect(page.startInEditMode, isFalse);
  });

  testWidgets('編輯器詳細路由帶 edit=1 時會直接進入編輯模式', (WidgetTester tester) async {
    await pumpRoute(tester, '/editor/abc?edit=1');
    final EditorPage page = tester.widget<EditorPage>(find.byType(EditorPage));
    expect(page.entryId, 'abc');
    expect(page.startInEditMode, isTrue);
  });

  testWidgets('設定相關路由都會建立對應頁面', (WidgetTester tester) async {
    await pumpRoute(tester, AppRouter.settingsRoute);
    expect(find.byType(SettingsPage), findsOneWidget);

    await pumpRoute(tester, AppRouter.aboutRoute);
    expect(find.byType(SettingsAboutPage), findsOneWidget);

    await pumpRoute(tester, AppRouter.personalizationRoute);
    expect(find.byType(PersonalizationPage), findsOneWidget);

    await pumpRoute(tester, AppRouter.supportRoute);
    expect(find.byType(SupportPage), findsOneWidget);
  });
}

class _FixedPersonalizationPreferencesController
    extends PersonalizationPreferencesController {
  @override
  Future<PersonalizationPreferences> build() async {
    return const PersonalizationPreferences(
      imageCompressPreset: ImageCompressPreset.standard,
      typography: EditorTypographyPreferences.defaults,
      themeMode: AppThemeModePreference.system,
      sessionTimeoutMinutes: SessionBackgroundTimeoutMinutes.three,
      locale: AppLanguage.zh,
    );
  }
}
