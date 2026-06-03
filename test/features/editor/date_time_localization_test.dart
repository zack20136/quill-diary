import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('app and editor date time pickers are configured for Taiwan Traditional Chinese', () {
    final Directory root = Directory.current;
    final String appSource = File(p.join(root.path, 'lib', 'app', 'app.dart')).readAsStringSync();
    final String editorSource = File(
      p.join(root.path, 'lib', 'features', 'editor', 'pages', 'editor_page.dart'),
    ).readAsStringSync();

    expect(appSource, contains("locale: const Locale('zh', 'TW')"));
    expect(appSource, contains('GlobalMaterialLocalizations.delegate'));
    expect(appSource, contains('GlobalCupertinoLocalizations.delegate'));
    expect(editorSource, contains("locale: const Locale('zh', 'TW')"));
    expect(editorSource, contains('alwaysUse24HourFormat: true'));
  });
}
