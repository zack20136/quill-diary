import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_identifiers.dart';
import '../features/session/session_lifecycle_binding.dart';
import '../features/settings/providers/billing_providers.dart';
import '../features/settings/providers/personalization_providers.dart';
import '../infrastructure/preferences/personalization_preferences.dart';
import 'router.dart';
import 'theme.dart';

class QuillDiaryApp extends ConsumerStatefulWidget {
  const QuillDiaryApp({super.key});

  @override
  ConsumerState<QuillDiaryApp> createState() => _QuillDiaryAppState();
}

class _QuillDiaryAppState extends ConsumerState<QuillDiaryApp> {
  late final GoRouter _router = AppRouter.createRouter();
  late final SessionLifecycleBinding _sessionLifecycle = SessionLifecycleBinding(ref);

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
    final PersonalizationPreferences prefs = watchPersonalizationPreferences(ref);

    return _sessionLifecycle.wrap(
      DynamicColorBuilder(
        builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
          return MaterialApp.router(
            title: AppIdentifiers.displayName,
            theme: buildAppTheme(dynamicScheme: lightDynamic),
            darkTheme: buildAppTheme(
              dynamicScheme: darkDynamic,
              brightness: Brightness.dark,
            ),
            themeMode: prefs.materialThemeMode,
            locale: prefs.materialLocale,
            supportedLocales: const <Locale>[
              Locale('zh', 'TW'),
              Locale('en'),
            ],
            localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            routerConfig: _router,
          );
        },
      ),
    );
  }
}
