import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/features/session/providers/session_providers.dart';
import 'package:quill_diary/features/session/state/app_session_state.dart';
import 'package:quill_diary/features/settings/pages/settings_page.dart';
import 'package:quill_diary/features/settings/providers/settings_providers.dart';
import 'package:quill_diary/infrastructure/security/app_unlock_mode.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/providers/core_providers.dart';

import '../../helpers/fake_session_vault_repository.dart';
import '../../helpers/fake_vault_transfer_service.dart';
import '../../helpers/test_l10n.dart';

void main() {
  testWidgets('設定頁法律與隱私區塊顯示四個 GitHub 入口', (WidgetTester tester) async {
    await tester.pumpWidget(
      _settingsScope(
        MaterialApp(
          locale: appZhLocale,
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          supportedLocales: appSupportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const SettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text(testL10n.settingsLegalSectionTitle),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text(testL10n.settingsLegalSectionTitle), findsOneWidget);
    expect(
      find.textContaining(testL10n.settingsLegalSectionDescription),
      findsOneWidget,
    );
    expect(find.text(testL10n.settingsLegalSourceCodeTitle), findsOneWidget);
    expect(find.text(testL10n.settingsLegalPrivacyPolicyTitle), findsOneWidget);
    expect(
      find.text(testL10n.settingsLegalThirdPartyNoticesTitle),
      findsOneWidget,
    );
    expect(find.text(testL10n.settingsLegalContactAuthorTitle), findsOneWidget);
  });
}

Widget _settingsScope(Widget child) {
  return ProviderScope(
    overrides: [
      supportedPlatformProvider.overrideWith((Ref ref) => true),
      vaultRepositoryProvider.overrideWithValue(FakeSessionVaultRepository()),
      vaultTransferServiceProvider.overrideWithValue(
        FakeVaultTransferService(),
      ),
      effectiveAppSessionProvider.overrideWith(
        (Ref ref) async => const AppSessionState(status: AppLockStatus.locked),
      ),
      recoveryMetadataProvider.overrideWith((Ref ref) async => null),
      unlockModeProvider.overrideWith((Ref ref) async => AppUnlockMode.none),
    ],
    child: child,
  );
}
