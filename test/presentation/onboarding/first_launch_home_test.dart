import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/onboarding/onboarding_providers.dart';
import 'package:quill_diary/application/session/session_providers.dart';
import 'package:quill_diary/application/session/session_state.dart';
import 'package:quill_diary/application/settings/personalization_providers.dart';
import 'package:quill_diary/domain/preferences/personalization_preferences.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/home/pages/home_page.dart';
import 'package:quill_diary/presentation/home/widgets/home_circle_action_button.dart';
import 'package:quill_diary/presentation/home/widgets/home_shared_widgets.dart';
import 'package:quill_diary/presentation/home/widgets/home_tab_stack.dart';
import 'package:quill_diary/presentation/onboarding/first_launch_home_pane.dart';
import 'package:quill_diary/presentation/settings/widgets/recovery_key_save_dialog.dart';
import 'package:quill_diary/shared/navigation/app_routes.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_shell.dart';

import '../../helpers/app_test_theme.dart';
import '../../helpers/presentation/settings/settings_test_scope.dart';
import '../../helpers/session/fake_session_vault_repository.dart';
import '../../helpers/shared/test_l10n.dart';
import '../../helpers/shared/widget_test_app.dart';

class _CompletedOnboardingIntroController extends OnboardingIntroController {
  @override
  Future<bool> build() async => true;
}

class _CreatingVaultRepository extends FakeSessionVaultRepository {
  final Completer<void> _creation = Completer<void>();
  int creations = 0;

  void completeCreation() => _creation.complete();

  @override
  Future<RecoverySetupResult> setupRecoveryKey() async {
    creations++;
    await _creation.future;
    return const RecoverySetupResult(
      recoveryKey: '0123-4567-89AB-CDEF-GHJK-MNPQ',
      session: UnlockedVaultSession(vaultId: 'vault', trustedDevice: true),
    );
  }
}

class _PendingOnboardingIntroController extends OnboardingIntroController {
  @override
  Future<bool> build() async => false;

  @override
  Future<void> markCompleted() async {
    state = const AsyncData<bool>(true);
  }
}

class _NoopPersonalizationController
    extends PersonalizationPreferencesController {
  @override
  Future<PersonalizationPreferences> build() async {
    return PersonalizationPreferences.defaults;
  }

  @override
  Future<void> seedDeviceLocaleIfUnset(Locale deviceLocale) async {}
}

int _seedAttempts = 0;

class _FailsOncePersonalizationController
    extends PersonalizationPreferencesController {
  @override
  Future<PersonalizationPreferences> build() async {
    return PersonalizationPreferences.defaults;
  }

  @override
  Future<void> seedDeviceLocaleIfUnset(Locale deviceLocale) async {
    _seedAttempts += 1;
    if (_seedAttempts == 1) {
      throw StateError('seed failed');
    }
  }
}

List _emptyVaultOverrides({
  required OnboardingIntroController Function() intro,
}) {
  return [
    hasSeenOnboardingIntroProvider.overrideWith(intro),
    personalizationPreferencesProvider.overrideWith(
      _NoopPersonalizationController.new,
    ),
    effectiveAppSessionProvider.overrideWith(
      (Ref ref) async => const AppSessionState(status: AppLockStatus.unlocked),
    ),
  ];
}

void main() {
  Future<void> pumpIntroFrames(WidgetTester tester) async {
    for (int i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  testWidgets('尚無日記庫且已看過介紹時顯示兩張操作卡，並隱藏分頁、新增按鈕與介紹 Dialog', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._emptyVaultOverrides(
            intro: _CompletedOnboardingIntroController.new,
          ),
        ],
        child: widgetTestApp(
          center: false,
          wrapScaffold: false,
          child: const HomePage(),
        ),
      ),
    );
    await pumpIntroFrames(tester);

    expect(find.byType(FirstLaunchHomePane), findsOneWidget);
    expect(find.text(testL10n.firstLaunchHomeTitle), findsOneWidget);
    expect(find.text(testL10n.firstLaunchCreateVaultTitle), findsOneWidget);
    expect(find.text(testL10n.firstLaunchTransferTitle), findsOneWidget);
    expect(find.byType(HomeTabStack), findsNothing);
    expect(find.byType(HomeCircleActionButton), findsNothing);
    expect(find.text(testL10n.homeNavHome), findsNothing);
    expect(find.byType(HomeHeader), findsOneWidget);
    expect(find.text(testL10n.onboardingIntroPage1Title), findsNothing);
  });

  testWidgets('尚無日記庫且尚未看過介紹時會自動顯示介紹 Dialog', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._emptyVaultOverrides(intro: _PendingOnboardingIntroController.new),
        ],
        child: widgetTestApp(
          center: false,
          wrapScaffold: false,
          child: const HomePage(),
        ),
      ),
    );
    await pumpIntroFrames(tester);

    expect(find.byType(FirstLaunchHomePane), findsNothing);
    expect(find.text(testL10n.firstLaunchCreateVaultTitle), findsNothing);
    expect(find.byType(AppDialogShell), findsOneWidget);
    expect(find.text(testL10n.onboardingIntroPage1Title), findsOneWidget);
    expect(
      tester
          .widget<HomeHeaderIconButton>(find.byType(HomeHeaderIconButton))
          .onPressed,
      isNull,
    );

    for (int i = 0; i < 4; i++) {
      await tester.tap(find.text(testL10n.onboardingIntroNext));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }
    await tester.tap(find.text(testL10n.onboardingIntroGetStarted));
    await tester.pump();
    await pumpIntroFrames(tester);

    expect(find.byType(AppDialogShell), findsNothing);
    expect(find.byType(FirstLaunchHomePane), findsOneWidget);
    expect(
      tester
          .widget<HomeHeaderIconButton>(find.byType(HomeHeaderIconButton))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('首次啟動流程失敗後可在後續重建重試', (WidgetTester tester) async {
    _seedAttempts = 0;
    final ProviderContainer container = ProviderContainer(
      overrides: [
        hasSeenOnboardingIntroProvider.overrideWith(
          _CompletedOnboardingIntroController.new,
        ),
        personalizationPreferencesProvider.overrideWith(
          _FailsOncePersonalizationController.new,
        ),
        effectiveAppSessionProvider.overrideWith(
          (Ref ref) async =>
              const AppSessionState(status: AppLockStatus.unlocked),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: widgetTestApp(
          center: false,
          wrapScaffold: false,
          child: const HomePage(),
        ),
      ),
    );
    await pumpIntroFrames(tester);

    expect(_seedAttempts, 1);
    expect(find.byType(FirstLaunchHomePane), findsNothing);

    container.invalidate(effectiveAppSessionProvider);
    await pumpIntroFrames(tester);

    expect(_seedAttempts, 2);
    expect(find.byType(FirstLaunchHomePane), findsOneWidget);
  });

  testWidgets('首次建庫直接在首頁顯示金鑰，選擇設定解鎖才前往設定', (WidgetTester tester) async {
    final _CreatingVaultRepository repository = _CreatingVaultRepository();
    Object? settingsAction;
    final GoRouter router = GoRouter(
      initialLocation: AppRoutes.homeRoute,
      routes: <RouteBase>[
        GoRoute(
          path: AppRoutes.homeRoute,
          builder: (_, _) => const Scaffold(body: FirstLaunchHomePane()),
        ),
        GoRoute(
          path: AppRoutes.settingsRoute,
          builder: (_, GoRouterState state) {
            settingsAction = state.extra;
            return const Scaffold(body: SizedBox());
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      settingsTestScope(
        repository: repository,
        wrapMaterialApp: false,
        child: MaterialApp.router(
          theme: appTestTheme(),
          locale: appZhLocale,
          supportedLocales: appSupportedLocales,
          localizationsDelegates: appLocalizationsDelegates,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text(testL10n.firstLaunchCreateVaultTitle));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final Finder dialog = find.byType(RecoveryKeySaveDialog);
    expect(dialog, findsOneWidget);
    expect(router.state.uri.path, AppRoutes.homeRoute);
    expect(settingsAction, isNull);

    final Finder surface = find.descendant(
      of: dialog,
      matching: find.byWidgetPredicate(
        (widget) => widget is Material && widget.type == MaterialType.card,
      ),
    );
    final Finder unlockSetup = find.widgetWithText(
      FilledButton,
      testL10n.settingsUnlockMethodConfigureButton,
    );
    final Rect loadingRect = tester.getRect(surface);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.widget<FilledButton>(unlockSetup).onPressed, isNull);
    repository.completeCreation();
    await tester.pumpAndSettle();
    expect(tester.getRect(surface), loadingRect);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tapAt(const Offset(8, 8));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(dialog, findsOneWidget);
    expect(repository.creations, 1);

    await tester.tap(unlockSetup);
    await tester.pumpAndSettle();
    expect(dialog, findsNothing);
    expect(settingsAction, SettingsEntryAction.focusUnlockMethod);

    router.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text(testL10n.firstLaunchTransferTitle));
    await tester.pumpAndSettle();
    expect(settingsAction, SettingsEntryAction.focusExternalRestore);
  });
}
