import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/session/providers/session_providers.dart';
import 'router.dart';
import 'theme.dart';

class QuillLockDiaryApp extends ConsumerStatefulWidget {
  const QuillLockDiaryApp({super.key});

  @override
  ConsumerState<QuillLockDiaryApp> createState() => _QuillLockDiaryAppState();
}

class _QuillLockDiaryAppState extends ConsumerState<QuillLockDiaryApp>
    with WidgetsBindingObserver {
  late final GoRouter _router = AppRouter.createRouter();

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
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return MaterialApp.router(
          title: 'QuillLockDiary',
          theme: buildAppTheme(dynamicScheme: lightDynamic),
          darkTheme: buildAppTheme(
            dynamicScheme: darkDynamic,
            brightness: Brightness.dark,
          ),
          themeMode: ThemeMode.system,
          routerConfig: _router,
        );
      },
    );
  }
}
