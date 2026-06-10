import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/features/session/providers/session_providers.dart';
import 'package:quill_diary/features/session/state/app_session_state.dart';
import 'package:quill_diary/features/settings/legal_disclosures.dart';
import 'package:quill_diary/features/settings/pages/settings_page.dart';
import 'package:quill_diary/features/settings/providers/settings_providers.dart';
import 'package:quill_diary/infrastructure/security/app_unlock_mode.dart';
import 'package:quill_diary/shared/providers/core_providers.dart';

import '../../helpers/fake_vault_repository.dart';
import '../../helpers/fake_vault_transfer_service.dart';

void main() {
  testWidgets('設定頁法律與隱私區塊依序顯示四個 GitHub 入口', (WidgetTester tester) async {
    await tester.pumpWidget(
      _settingsScope(
        const MaterialApp(home: SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text(SettingsLegalCopy.sectionTitle),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text(SettingsLegalCopy.sectionTitle), findsOneWidget);
    expect(find.textContaining(SettingsLegalCopy.sectionDescription), findsOneWidget);
    expect(find.text(SettingsLegalCopy.sourceCodeTitle), findsOneWidget);
    expect(find.text(SettingsLegalCopy.privacyPolicyTitle), findsOneWidget);
    expect(find.text(SettingsLegalCopy.thirdPartyNoticesTitle), findsOneWidget);
    expect(find.text(SettingsLegalCopy.contactAuthorTitle), findsOneWidget);

    final List<String> titles = tester
        .widgetList<Text>(
          find.descendant(
            of: find.ancestor(
              of: find.text(SettingsLegalCopy.sectionTitle),
              matching: find.byType(Column),
            ),
            matching: find.byType(Text),
          ),
        )
        .map((Text text) => text.data!)
        .where(
          (String title) =>
              title == SettingsLegalCopy.sourceCodeTitle ||
              title == SettingsLegalCopy.privacyPolicyTitle ||
              title == SettingsLegalCopy.thirdPartyNoticesTitle ||
              title == SettingsLegalCopy.contactAuthorTitle,
        )
        .toList();

    expect(titles, <String>[
      SettingsLegalCopy.sourceCodeTitle,
      SettingsLegalCopy.privacyPolicyTitle,
      SettingsLegalCopy.thirdPartyNoticesTitle,
      SettingsLegalCopy.contactAuthorTitle,
    ]);
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
