import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/presentation/editor/presentation/editor_hybrid_body.dart';
import 'package:quill_diary/infrastructure/preferences/editor_typography_preferences.dart';
import 'package:quill_diary/l10n/l10n.dart';

import '../../app_test_theme.dart';

Widget editorTestApp({
  required Widget child,
  Size viewport = const Size(400, 600),
}) {
  return MaterialApp(
    theme: appTestTheme(),
    locale: appZhLocale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SizedBox(
        width: viewport.width,
        height: viewport.height,
        child: child,
      ),
    ),
  );
}

Future<
  ({
    TextEditingController bodyController,
    GlobalKey<EditorHybridBodyState> bodyKey,
  })
>
pumpEditorHybridBody(WidgetTester tester, {String? bodyText}) async {
  final TextEditingController bodyController = TextEditingController(
    text: bodyText,
  );
  final GlobalKey<EditorHybridBodyState> bodyKey =
      GlobalKey<EditorHybridBodyState>();

  await tester.pumpWidget(
    editorTestApp(
      child: EditorHybridBody(
        key: bodyKey,
        bodyController: bodyController,
        typography: EditorTypographyPreferences.defaults,
        onBodyChanged: () {},
      ),
    ),
  );
  await tester.pumpAndSettle();

  return (bodyController: bodyController, bodyKey: bodyKey);
}
