import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/recovery/kdf_descriptor.dart';
import 'package:quill_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/features/session/state/app_session_state.dart';
import 'package:quill_diary/features/settings/pages/personalization_page.dart';
import 'package:quill_diary/features/settings/providers/personalization_providers.dart';
import 'package:quill_diary/features/settings/widgets/personalization_sections.dart';
import 'package:quill_diary/infrastructure/preferences/editor_typography_preferences.dart';
import 'package:quill_diary/infrastructure/preferences/personalization_preferences.dart';
import 'package:quill_diary/infrastructure/preferences/user_preferences.dart';
import 'package:quill_diary/l10n/l10n.dart';

import '../../helpers/settings_test_scope.dart';
import '../../helpers/test_l10n.dart';

class _FixedPersonalizationPreferencesController
    extends PersonalizationPreferencesController {
  @override
  Future<PersonalizationPreferences> build() async {
    return PersonalizationPreferences(
      imageCompressPreset: ImageCompressPreset.standard,
      typography: EditorTypographyPreferences.defaults,
      themeMode: AppThemeModePreference.system,
      sessionTimeoutMinutes: SessionBackgroundTimeoutMinutes.three,
      locale: AppLanguage.zh,
    );
  }
}

void main() {
  const UnlockedVaultSession sampleSession = UnlockedVaultSession(
    vaultId: 'vlt_test',
    trustedDevice: true,
    recoveryWrapKey: <int>[1, 2, 3, 4],
    deviceSlotId: 'slot-a',
  );

  final RecoveryMetadata sampleRecoveryMetadata = RecoveryMetadata(
    vaultId: 'vlt_test',
    recoveryEnabled: true,
    recoveryKeyVersion: 1,
    recoveryKeyHint: 'ABCD',
    createdAt: DateTime.parse('2026-05-19T00:00:00Z'),
    kdf: KdfDescriptor.argon2idRecovery(
      saltBytes: List<int>.filled(16, 1),
    ),
  );

  Future<void> pumpPersonalizationPage(
    WidgetTester tester, {
    required AppSessionState sessionState,
    RecoveryMetadata? recoveryMetadata,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          personalizationPreferencesProvider.overrideWith(
            _FixedPersonalizationPreferencesController.new,
          ),
        ],
        child: settingsTestScope(
          sessionState: sessionState,
          recoveryMetadata: recoveryMetadata,
          child: MaterialApp(
            locale: appZhLocale,
            supportedLocales: appSupportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: const PersonalizationPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('locked session disables timeout but keeps image compress editable', (
    WidgetTester tester,
  ) async {
    await pumpPersonalizationPage(
      tester,
      sessionState: const AppSessionState(status: AppLockStatus.locked),
      recoveryMetadata: sampleRecoveryMetadata,
    );

    expect(
      tester
          .widget<PersonalizationSessionTimeoutSectionBody>(
            find.byType(PersonalizationSessionTimeoutSectionBody),
          )
          .enabled,
      isFalse,
    );
    expect(
      find.byType(PersonalizationImageCompressSectionBody),
      findsOneWidget,
    );
    expect(
      find.text(testL10n.settingsUnlockRequiredToChangeSettingMessage),
      findsOneWidget,
    );
  });

  testWidgets('new app onboarding disables timeout until recovery key exists', (
    WidgetTester tester,
  ) async {
    await pumpPersonalizationPage(
      tester,
      sessionState: const AppSessionState(status: AppLockStatus.unlocked),
    );

    expect(
      tester
          .widget<PersonalizationSessionTimeoutSectionBody>(
            find.byType(PersonalizationSessionTimeoutSectionBody),
          )
          .enabled,
      isFalse,
    );
    expect(
      find.byType(PersonalizationImageCompressSectionBody),
      findsOneWidget,
    );
    expect(
      find.text(testL10n.settingsUnlockRequiredToChangeSettingMessage),
      findsNothing,
    );
  });

  testWidgets('unlocked session keeps timeout and image compress editable', (
    WidgetTester tester,
  ) async {
    await pumpPersonalizationPage(
      tester,
      sessionState: const AppSessionState(
        status: AppLockStatus.unlocked,
        session: sampleSession,
      ),
      recoveryMetadata: sampleRecoveryMetadata,
    );

    expect(
      tester
          .widget<PersonalizationSessionTimeoutSectionBody>(
            find.byType(PersonalizationSessionTimeoutSectionBody),
          )
          .enabled,
      isTrue,
    );
    expect(
      find.byType(PersonalizationImageCompressSectionBody),
      findsOneWidget,
    );
    expect(
      find.text(testL10n.settingsUnlockRequiredToChangeSettingMessage),
      findsNothing,
    );
  });
}
