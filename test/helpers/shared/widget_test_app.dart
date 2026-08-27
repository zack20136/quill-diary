import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_diary/l10n/l10n.dart';

import '../app_test_theme.dart';

/// 共用 widget 測試殼：MaterialApp + theme + l10n，可選 ProviderScope。
Widget widgetTestApp({
  required Widget child,
  Brightness brightness = Brightness.light,
  bool includeDarkTheme = false,
  Size? viewport,
  List? overrides,
  bool center = true,
  bool wrapScaffold = true,
}) {
  Widget body = child;
  if (viewport != null) {
    body = SizedBox(
      width: viewport.width,
      height: viewport.height,
      child: body,
    );
  }
  if (center) {
    body = Center(child: body);
  }

  final Widget home = wrapScaffold ? Scaffold(body: body) : body;

  final Widget app = MaterialApp(
    theme: appTestTheme(brightness: brightness),
    darkTheme: includeDarkTheme
        ? appTestTheme(brightness: Brightness.dark)
        : null,
    locale: appZhLocale,
    supportedLocales: appSupportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: home,
  );

  if (overrides == null) {
    return app;
  }
  // 以 spread 推斷 ProviderScope 的 Override 型別（Riverpod 3 不直接匯出 Override）。
  return ProviderScope(overrides: [...overrides], child: app);
}
