import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/session/providers/session_providers.dart';
import '../features/session/session_lifecycle_binding.dart';
import '../features/session/session_route_preservation.dart';
import '../features/session/state/app_session_state.dart';
import '../features/session/state/unlock_result.dart';
import '../features/settings/providers/billing_providers.dart';
import '../features/settings/providers/personalization_providers.dart';
import '../infrastructure/preferences/personalization_preferences.dart';
import '../l10n/l10n.dart';
import 'router.dart';
import 'theme.dart';

class QuillDiaryApp extends ConsumerStatefulWidget {
  const QuillDiaryApp({super.key});

  @override
  ConsumerState<QuillDiaryApp> createState() => _QuillDiaryAppState();
}

class _QuillDiaryAppState extends ConsumerState<QuillDiaryApp> {
  late final GoRouter _router = AppRouter.createRouter();
  late final SessionLifecycleBinding _sessionLifecycle =
      SessionLifecycleBinding(ref);

  @override
  void initState() {
    super.initState();
    _sessionLifecycle.attach();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref.read(sessionRoutePreservationProvider.notifier).bindLocationResolver(
        () => _router.state.uri.toString(),
      );
    });
  }

  @override
  void dispose() {
    _sessionLifecycle.detach();
    _router.dispose();
    super.dispose();
  }

  String get _currentRoute => _router.state.uri.toString();

  void _handleSessionRouteTransition(
    AppSessionState? previous,
    AppSessionState next,
  ) {
    final CompletedUnlockSnapshot? snapshot = ref
        .read(appSessionProvider.notifier)
        .consumeCompletedUnlockSnapshot();
    if (snapshot == null ||
        snapshot.source != UnlockRequestSource.lifecycleResume) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final SessionRoutePreservationState preservation = ref.read(
        sessionRoutePreservationProvider,
      );
      final SessionRouteNavigationAction action =
          resolveLifecycleResumeRouteAction(
        outcome: snapshot.outcome,
        recoverable: snapshot.recoverable,
        savedForInactivityLock: preservation.savedForInactivityLock,
        pendingRestoreLocation: preservation.pendingRestoreLocation,
        nextState: next,
      );

      final String? restoreTarget = action == SessionRouteNavigationAction.restore
          ? restoreTargetLocation(preservation)
          : null;

      if (action != SessionRouteNavigationAction.none ||
          snapshot.outcome == UnlockOutcome.failed) {
        ref.read(sessionRoutePreservationProvider.notifier).clear();
      }

      switch (action) {
        case SessionRouteNavigationAction.restore:
          if (restoreTarget != null && _currentRoute != restoreTarget) {
            _router.go(restoreTarget);
          }
        case SessionRouteNavigationAction.goHome:
          if (_currentRoute != AppRouter.homeRoute) {
            _router.go(AppRouter.homeRoute);
          }
        case SessionRouteNavigationAction.none:
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AppSessionState>(appSessionProvider, _handleSessionRouteTransition);

    ref.watch(sponsorBillingLifecycleProvider);
    final Locale locale = ref
        .watch(personalizationPreferencesProvider)
        .maybeWhen(
          data: (PersonalizationPreferences value) => value.materialLocale,
          orElse: () => appZhLocale,
        );
    final ThemeMode themeMode = ref
        .watch(personalizationPreferencesProvider)
        .maybeWhen(
          data: (value) => value.materialThemeMode,
          orElse: () => ThemeMode.system,
        );

    return _sessionLifecycle.wrap(
      DynamicColorBuilder(
        builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
          return MaterialApp.router(
            onGenerateTitle: (BuildContext context) => context.l10n.appTitle,
            scrollBehavior: const MaterialScrollBehavior().copyWith(
              scrollbars: false,
            ),
            theme: buildAppTheme(dynamicScheme: lightDynamic),
            darkTheme: buildAppTheme(
              dynamicScheme: darkDynamic,
              brightness: Brightness.dark,
            ),
            themeMode: themeMode,
            locale: locale,
            supportedLocales: appSupportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            routerConfig: _router,
          );
        },
      ),
    );
  }
}
