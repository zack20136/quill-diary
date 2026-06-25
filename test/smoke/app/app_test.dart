import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/app/app.dart';
import 'package:quill_diary/features/editor/providers/editor_draft_providers.dart';
import 'package:quill_diary/features/home/pages/home_page.dart';
import 'package:quill_diary/features/session/providers/session_providers.dart';
import 'package:quill_diary/features/session/state/app_session_state.dart';
import 'package:quill_diary/features/settings/providers/personalization_providers.dart';
import 'package:quill_diary/features/settings/providers/settings_providers.dart';
import 'package:quill_diary/infrastructure/drive/drive_backup_service.dart';
import 'package:quill_diary/infrastructure/preferences/editor_typography_preferences.dart';
import 'package:quill_diary/infrastructure/preferences/personalization_preferences.dart';
import 'package:quill_diary/infrastructure/preferences/user_preferences.dart';
import 'package:quill_diary/infrastructure/security/app_unlock_mode.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/providers/core_providers.dart';
import 'package:quill_diary/shared/platform/vault_platform_support.dart';

import '../../helpers/vault/fake_entry_index_vault_repository.dart';
import '../../helpers/storage/fake_vault_transfer_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('appSupportedLocales 包含 zh 與 en', () {
    expect(appSupportedLocales, <Locale>[appZhLocale, appEnLocale]);
  });

  testWidgets('QuillDiaryApp 開機 wiring smoke test', (
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

    final MaterialApp app = tester.widget<MaterialApp>(
      find.byType(MaterialApp),
    );
    expect(app.onGenerateTitle, isNotNull);
    expect(app.routerConfig, isNotNull);
    expect(find.byType(HomePage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('App 預設使用繁中 locale', (WidgetTester tester) async {
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
}

ProviderContainer _buildSmokeTestContainer() {
  return ProviderContainer(
    overrides: [
      supportedPlatformProvider.overrideWith((Ref ref) => false),
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
