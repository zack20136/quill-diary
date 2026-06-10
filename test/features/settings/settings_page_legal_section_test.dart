import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:quill_diary/app/router.dart';
import 'package:quill_diary/features/session/providers/session_providers.dart';
import 'package:quill_diary/features/session/state/app_session_state.dart';
import 'package:quill_diary/features/settings/legal_copy.dart';
import 'package:quill_diary/features/settings/pages/privacy_page.dart';
import 'package:quill_diary/features/settings/pages/settings_page.dart';
import 'package:quill_diary/features/settings/privacy_copy.dart';
import 'package:quill_diary/features/settings/providers/settings_providers.dart';
import 'package:quill_diary/infrastructure/security/app_unlock_mode.dart';
import 'package:quill_diary/shared/providers/core_providers.dart';

import '../../helpers/fake_vault_repository.dart';
import '../../helpers/fake_vault_transfer_service.dart';

void main() {
  testWidgets('設定頁法律與隱私區塊顯示開源入口', (WidgetTester tester) async {
    await tester.pumpWidget(
      _settingsScope(
        const MaterialApp(home: SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(SettingsLegalCopy.sectionTitle), findsOneWidget);
    expect(find.text(SettingsPrivacyCopy.pageTitle), findsOneWidget);
    expect(find.text(SettingsLegalCopy.sourceCodeTitle), findsOneWidget);
    expect(find.text(SettingsLegalCopy.sourceCodeSubtitle), findsOneWidget);
    expect(find.text(SettingsLegalCopy.dependencyLicensesTitle), findsOneWidget);
    expect(find.text(SettingsLegalCopy.thirdPartyNoticesTitle), findsOneWidget);
  });

  testWidgets('點隱私權政策進入 PrivacyPage', (WidgetTester tester) async {
    final GoRouter router = GoRouter(
      initialLocation: AppRouter.settingsRoute,
      routes: <RouteBase>[
        GoRoute(
          path: AppRouter.settingsRoute,
          builder: (_, _) => _settingsScope(const SettingsPage()),
        ),
        GoRoute(
          path: AppRouter.privacyRoute,
          builder: (_, _) => const PrivacyPage(),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(routerConfig: router),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(SettingsPrivacyCopy.pageTitle));
    await tester.pumpAndSettle();

    expect(find.byType(PrivacyPage), findsOneWidget);
    expect(find.text(SettingsPrivacyCopy.heroTitle), findsOneWidget);
  });
}

Widget _settingsScope(Widget child) {
  return ProviderScope(
    overrides: [
      supportedPlatformProvider.overrideWith((Ref ref) => true),
      vaultRepositoryProvider.overrideWithValue(FakeVaultRepository()),
      vaultTransferServiceProvider.overrideWithValue(FakeVaultTransferService()),
      effectiveAppSessionProvider.overrideWith(
        (Ref ref) async => const AppSessionState(status: AppLockStatus.locked),
      ),
      recoveryMetadataProvider.overrideWith((Ref ref) async => null),
      unlockModeProvider.overrideWith((Ref ref) async => AppUnlockMode.none),
    ],
    child: child,
  );
}
