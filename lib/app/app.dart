import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/session/app_lifecycle_session_bridge.dart';
import '../features/session/session_navigation_coordinator.dart';
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
  late final AppLifecycleSessionBridge _sessionLifecycle =
      AppLifecycleSessionBridge(ref);

  @override
  void initState() {
    super.initState();
    _sessionLifecycle.attach();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref
          .read(sessionNavigationCoordinatorProvider)
          .bindLocationResolver(() => _router.state.uri.toString());
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
    SessionNavigationRequest? previous,
    SessionNavigationRequest? next,
  ) {
    if (next == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final String target = sessionNavigationLocation(next);
      if (_currentRoute != target) {
        _router.go(target);
      }
      ref.read(sessionNavigationRequestProvider.notifier).clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<SessionNavigationRequest?>(
      sessionNavigationRequestProvider,
      _handleSessionRouteTransition,
    );

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
      MaterialApp.router(
        onGenerateTitle: (BuildContext context) => context.l10n.appTitle,
        scrollBehavior: const MaterialScrollBehavior().copyWith(
          scrollbars: false,
        ),
        theme: buildAppTheme(brightness: Brightness.light),
        darkTheme: buildAppTheme(brightness: Brightness.dark),
        themeMode: themeMode,
        locale: locale,
        supportedLocales: appSupportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        routerConfig: _router,
      ),
    );
  }
}
