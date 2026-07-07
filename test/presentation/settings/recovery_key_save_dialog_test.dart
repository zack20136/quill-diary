import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/presentation/settings/widgets/recovery_key_save_dialog.dart';
import 'package:quill_diary/l10n/l10n.dart';

import '../../helpers/app_test_theme.dart';
import '../../helpers/shared/test_l10n.dart';

void main() {
  const String recoveryKey = 'ABCD-EFGH-IJKL-MNOP';

  Future<void> pumpDialog(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTestTheme(),
        darkTheme: appTestTheme(brightness: Brightness.dark),
        locale: appZhLocale,
        supportedLocales: appSupportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (BuildContext context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () {
                    unawaited(
                      showRecoveryKeySaveDialog(
                        context,
                        title: testL10n.settingsRecoveryKeySaveDialogTitle,
                        recoveryKey: recoveryKey,
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('保存對話框顯示完整復原金鑰與提示文案', (WidgetTester tester) async {
    await pumpDialog(tester);

    expect(find.text(recoveryKey), findsOneWidget);
    expect(
      find.text(testL10n.settingsRecoveryKeySaveDialogHint),
      findsOneWidget,
    );
  });

  testWidgets('保存對話框提供複製與關閉按鈕', (WidgetTester tester) async {
    await pumpDialog(tester);

    expect(find.text(testL10n.settingsRecoveryKeyCopyButton), findsOneWidget);
    expect(find.text(testL10n.commonActionClose), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
  });
}
