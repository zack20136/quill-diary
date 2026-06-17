import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:quill_diary/app/router.dart';
import 'package:quill_diary/features/editor/pages/editor_page.dart';
import 'package:quill_diary/features/editor/providers/editor_draft_providers.dart';
import 'package:quill_diary/features/home/pages/home_page.dart';
import 'package:quill_diary/features/session/providers/session_providers.dart';
import 'package:quill_diary/features/session/state/app_session_state.dart';
import 'package:quill_diary/features/settings/pages/about_page.dart';
import 'package:quill_diary/features/settings/pages/personalization_page.dart';
import 'package:quill_diary/features/settings/pages/settings_page.dart';
import 'package:quill_diary/features/settings/pages/support_page.dart';
import 'package:quill_diary/features/settings/providers/personalization_providers.dart';
import 'package:quill_diary/features/settings/providers/settings_providers.dart';
import 'package:quill_diary/infrastructure/drive/drive_backup_service.dart';
import 'package:quill_diary/infrastructure/preferences/editor_typography_preferences.dart';
import 'package:quill_diary/infrastructure/preferences/personalization_preferences.dart';
import 'package:quill_diary/infrastructure/preferences/user_preferences.dart';
import 'package:quill_diary/l10n/app_localizations.dart';
import 'package:quill_diary/infrastructure/security/app_unlock_mode.dart';
import 'package:quill_diary/shared/providers/core_providers.dart';

import '../helpers/fake_entry_index_vault_repository.dart';
import '../helpers/fake_vault_transfer_service.dart';

void main() {
  late GoRouter router;

  setUp(() {
    router = AppRouter.createRouter();
  });

  Widget wrapRouterApp() {
    return ProviderScope(
      overrides: [
        supportedPlatformProvider.overrideWith((Ref ref) => true),
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
        editorDraftKeysProvider.overrideWith((Ref ref) async => <String>{}),
        personalizationPreferencesProvider.overrideWith(() {
          return _FixedPersonalizationPreferencesController();
        }),
      ],
      child: MaterialApp.router(
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

  testWidgets('home route builds HomePage', (WidgetTester tester) async {
    await pumpRoute(tester, AppRouter.homeRoute);
    expect(find.byType(HomePage), findsOneWidget);
  });

  testWidgets('editor route without entryId builds EditorPage', (
    WidgetTester tester,
  ) async {
    await pumpRoute(tester, AppRouter.editorRoute);
    final EditorPage page = tester.widget<EditorPage>(find.byType(EditorPage));
    expect(page.entryId, isNull);
    expect(page.startInEditMode, isFalse);
  });

  testWidgets('editor detail route passes entryId', (
    WidgetTester tester,
  ) async {
    await pumpRoute(tester, '/editor/abc');
    final EditorPage page = tester.widget<EditorPage>(find.byType(EditorPage));
    expect(page.entryId, 'abc');
    expect(page.startInEditMode, isFalse);
  });

  testWidgets('editor detail route with edit=1 starts in edit mode', (
    WidgetTester tester,
  ) async {
    await pumpRoute(tester, '/editor/abc?edit=1');
    final EditorPage page = tester.widget<EditorPage>(find.byType(EditorPage));
    expect(page.entryId, 'abc');
    expect(page.startInEditMode, isTrue);
  });

  testWidgets('settings routes build expected pages', (
    WidgetTester tester,
  ) async {
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
