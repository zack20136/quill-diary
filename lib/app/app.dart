import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/session/session_lifecycle_binding.dart';
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
  }

  @override
  void dispose() {
    _sessionLifecycle.detach();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
