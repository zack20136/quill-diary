import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/app/app.dart';
import 'package:quill_diary/application/editor/editor_draft_providers.dart';
import 'package:quill_diary/application/session/providers/session_providers.dart';
import 'package:quill_diary/application/session/session_navigation_coordinator.dart';
import 'package:quill_diary/application/session/state/app_session_state.dart';
import 'package:quill_diary/application/settings/personalization_providers.dart';
import 'package:quill_diary/application/settings/settings_providers.dart';
import 'package:quill_diary/infrastructure/drive/drive_backup_service.dart';
import 'package:quill_diary/infrastructure/preferences/editor_typography_preferences.dart';
import 'package:quill_diary/infrastructure/preferences/personalization_preferences.dart';
import 'package:quill_diary/infrastructure/preferences/user_preferences.dart';
import 'package:quill_diary/infrastructure/security/app_unlock_mode.dart';
import 'package:quill_diary/infrastructure/storage/storage_providers.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/home/pages/home_page.dart';
import 'package:quill_diary/presentation/settings/pages/settings_page.dart';
import 'package:quill_diary/shared/platform/vault_platform_support.dart';

import '../../helpers/storage/fake_vault_transfer_service.dart';
import '../../helpers/vault/fake_entry_index_vault_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('appSupportedLocales 包含中英文', () {
    expect(appSupportedLocales, <Locale>[appZhLocale, appEnLocale]);
  });

  testWidgets('QuillDiaryApp 可以正常建立 router 與首頁', (WidgetTester tester) async {
    final ProviderContainer container = _buildSmokeTestContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const QuillDiaryApp(),
      ),
    );
    await tester.pump();
    await tester.pump();

    final MaterialApp app = tester.widget<MaterialApp>(
      find.byType(MaterialApp),
    );
    expect(app.onGenerateTitle, isNotNull);
    expect(app.routerConfig, isNotNull);
    expect(find.byType(HomePage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('App 會套用儲存的預設 locale', (WidgetTester tester) async {
    final ProviderContainer container = _buildSmokeTestContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const QuillDiaryApp(),
      ),
    );
    await tester.pump();
    await tester.pump();

    final MaterialApp app = tester.widget<MaterialApp>(
      find.byType(MaterialApp),
    );
    expect(app.locale, appZhLocale);
  });

  testWidgets('QuillDiaryApp 會處理 session navigation request 導頁', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = _buildSmokeTestContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const QuillDiaryApp(),
      ),
    );
    await tester.pump();
    await tester.pump();

    container
        .read(sessionNavigationRequestProvider.notifier)
        .publish(const SessionNavigationRequest.restore('/settings'));

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.byType(SettingsPage), findsOneWidget);
  });
}

ProviderContainer _buildSmokeTestContainer() {
  return ProviderContainer(
    overrides: [
      vaultPlatformSupportProvider.overrideWith((Ref ref) => false),
      vaultRepositoryProvider.overrideWithValue(
        FakeEntryIndexVaultRepository(),
      ),
      vaultTransferServiceProvider.overrideWithValue(
        FakeVaultTransferService(),
      ),
      effectiveAppSessionProvider.overrideWith(
        (Ref ref) async => const AppSessionState(status: AppLockStatus.locked),
      ),
      recoveryMetadataProvider.overrideWith((Ref ref) async => null),
      unlockModeProvider.overrideWith((Ref ref) async => AppUnlockMode.none),
      settingsDriveConnectionProvider.overrideWith(
        (Ref ref) async => const DriveConnectionState.disconnected(),
      ),
      editorDraftKeysProvider.overrideWith((Ref ref) async => <String>{}),
      personalizationPreferencesProvider.overrideWith(
        _FixedPersonalizationPreferencesController.new,
      ),
    ],
  );
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
