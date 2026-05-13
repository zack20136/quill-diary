import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dynamic_color/dynamic_color.dart';

import 'router.dart';
import 'theme.dart';

class QuillLockDiaryApp extends ConsumerWidget {
  const QuillLockDiaryApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = AppRouter.createRouter();
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
          routerConfig: router,
        );
      },
    );
  }
}
