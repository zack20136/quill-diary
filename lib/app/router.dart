import 'package:flutter/material.dart';

import '../presentation/pages/editor_page.dart';
import '../presentation/pages/home_page.dart';
import '../presentation/pages/recovery_page.dart';

class AppRouter {
  static const String homeRoute = '/';
  static const String editorRoute = '/editor';
  static const String recoveryRoute = '/recovery';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case editorRoute:
        return MaterialPageRoute<void>(
          builder: (_) => const EditorPage(),
          settings: settings,
        );
      case recoveryRoute:
        return MaterialPageRoute<void>(
          builder: (_) => const RecoveryPage(),
          settings: settings,
        );
      case homeRoute:
      default:
        return MaterialPageRoute<void>(
          builder: (_) => const HomePage(),
          settings: settings,
        );
    }
  }
}
