import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/onboarding/onboarding_providers.dart';
import 'package:quill_diary/application/session/session_providers.dart';
import 'package:quill_diary/application/session/session_state.dart';
import 'package:quill_diary/application/settings/personalization_providers.dart';
import 'package:quill_diary/domain/preferences/personalization_preferences.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/home/pages/home_page.dart';
import 'package:quill_diary/presentation/home/widgets/home_circle_action_button.dart';
import 'package:quill_diary/presentation/home/widgets/home_shared_widgets.dart';
import 'package:quill_diary/presentation/home/widgets/home_tab_stack.dart';
import 'package:quill_diary/presentation/onboarding/first_launch_home_pane.dart';
import 'package:quill_diary/shared/data_versions.dart';
import 'package:quill_diary/shared/navigation/app_routes.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_shell.dart';

import '../../helpers/app_test_theme.dart';
import '../../helpers/shared/test_l10n.dart';
import '../../helpers/shared/widget_test_app.dart';

class _CompletedOnboardingIntroController extends OnboardingIntroController {
  @override
  Future<int> build() async => DataVersions.onboardingIntro;
}

class _PendingOnboardingIntroController extends OnboardingIntroController {
  @override
  Future<int> build() async => 0;

  @override
  Future<void> markCompleted() async {
    state = const AsyncData<int>(DataVersions.onboardingIntro);
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
    onboardingIntroVersionProvider.overrideWith(intro),
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
        onboardingIntroVersionProvider.overrideWith(
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

  testWidgets('點操作卡會前往對應設定區塊', (WidgetTester tester) async {
    final GoRouter router = GoRouter(
      initialLocation: AppRoutes.homeRoute,
      routes: <RouteBase>[
        GoRoute(
          path: AppRoutes.homeRoute,
          builder: (_, _) => const Scaffold(body: FirstLaunchHomePane()),
        ),
        GoRoute(
          path: AppRoutes.settingsRoute,
          builder: (_, _) => const Scaffold(body: SizedBox()),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        theme: appTestTheme(),
        locale: appZhLocale,
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationsDelegates,
        routerConfig: router,
      ),
    );
    await tester.pump();

    await tester.tap(find.text(testL10n.firstLaunchCreateVaultTitle));
    await tester.pump();
    expect(
      router.state.uri.toString(),
      AppRoutes.settingsLocation(focus: SettingsFocusTarget.recoveryKey),
    );

    router.go(AppRoutes.homeRoute);
    await tester.pump();
    await tester.tap(find.text(testL10n.firstLaunchTransferTitle));
    await tester.pump();
    expect(
      router.state.uri.toString(),
      AppRoutes.settingsLocation(focus: SettingsFocusTarget.externalRestore),
    );
  });
}
