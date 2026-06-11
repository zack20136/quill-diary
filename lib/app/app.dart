import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_identifiers.dart';
import '../features/session/application/session_unlock_coordinator.dart';
import '../features/session/providers/session_providers.dart';
import '../features/settings/providers/billing_providers.dart';
import 'router.dart';
import 'theme.dart';

class QuillDiaryApp extends ConsumerStatefulWidget {
  const QuillDiaryApp({super.key});

  @override
  ConsumerState<QuillDiaryApp> createState() => _QuillDiaryAppState();
}

class _QuillDiaryAppState extends ConsumerState<QuillDiaryApp>
    with WidgetsBindingObserver {
  late final GoRouter _router = AppRouter.createRouter();
  bool _unlockCoordinatorAttached = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(ref.read(appSessionProvider.notifier).handleLifecycleChange(state));
  }

  @override
  Widget build(BuildContext context) {
    if (!_unlockCoordinatorAttached) {
      _unlockCoordinatorAttached = true;
      SessionUnlockCoordinator(ref).listen();
    }

    ref.watch(sponsorBillingLifecycleProvider);

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return MaterialApp.router(
          title: AppIdentifiers.displayName,
          theme: buildAppTheme(dynamicScheme: lightDynamic),
          darkTheme: buildAppTheme(
            dynamicScheme: darkDynamic,
            brightness: Brightness.dark,
          ),
          themeMode: ThemeMode.system,
          supportedLocales: const <Locale>[
            Locale('zh', 'TW'),
          ],
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: _router,
        );
      },
    );
  }
}
