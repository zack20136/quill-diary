import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:go_router/go_router.dart';

import 'router.dart';
import 'theme.dart';

class QuillLockDiaryApp extends StatefulWidget {
  const QuillLockDiaryApp({super.key});

  @override
  State<QuillLockDiaryApp> createState() => _QuillLockDiaryAppState();
}

class _QuillLockDiaryAppState extends State<QuillLockDiaryApp> {
  late final GoRouter _router = AppRouter.createRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
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
