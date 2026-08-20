import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/settings/widgets/settings_sections.dart';

import '../../helpers/app_test_theme.dart';
import '../../helpers/shared/test_l10n.dart';

void main() {
  Widget host({
    required String message,
    String? title,
    String? hint,
    double? progress,
  }) {
    return MaterialApp(
      theme: appTestTheme(),
      locale: appZhLocale,
      supportedLocales: appSupportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Stack(
        children: <Widget>[
          SettingsBlockingProgressOverlay(
            message: message,
            title: title,
            hint: hint,
            progress: progress,
          ),
        ],
      ),
    );
  }

  testWidgets('無比例時顯示 indeterminate 線性條且沒有圓形指示器', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      host(
        title: testL10n.settingsProgressWorkingTitle,
        message: testL10n.settingsBackupStartingAfterRestore,
        hint: testL10n.settingsProgressKeepAppOpenHint,
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsNothing);
    final LinearProgressIndicator bar = tester.widget(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, isNull);
    expect(find.text(testL10n.settingsProgressWorkingTitle), findsOneWidget);
    expect(
      find.text(testL10n.settingsBackupStartingAfterRestore),
      findsOneWidget,
    );
    expect(
      find.text(testL10n.settingsProgressKeepAppOpenHint),
      findsOneWidget,
    );
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('有比例時顯示百分比並 clamp 到有效範圍', (WidgetTester tester) async {
    await tester.pumpWidget(
      host(
        title: testL10n.settingsProgressWorkingTitle,
        message: testL10n.settingsInspectVaultProgressCheckingAttachments,
        progress: 0.5,
      ),
    );

    final LinearProgressIndicator bar = tester.widget(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, 0.5);
    expect(find.text(testL10n.settingsProgressPercent(50)), findsOneWidget);
    expect(
      find.text(testL10n.settingsInspectVaultProgressCheckingAttachments),
      findsOneWidget,
    );

    await tester.pumpWidget(
      host(
        title: testL10n.settingsProgressWorkingTitle,
        message: 'overflow',
        progress: 1.4,
      ),
    );
    final LinearProgressIndicator clamped = tester.widget(
      find.byType(LinearProgressIndicator),
    );
    expect(clamped.value, 1.0);
    expect(find.text(testL10n.settingsProgressPercent(100)), findsOneWidget);
  });

  testWidgets('語意標籤會帶入標題、階段與百分比', (WidgetTester tester) async {
    await tester.pumpWidget(
      host(
        title: '正在處理',
        message: '正在檢查附件',
        progress: 0.38,
      ),
    );
    expect(
      find.bySemanticsLabel(
        testL10n.settingsProgressSemanticDeterminate('正在處理', '正在檢查附件', 38),
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(
      host(title: '正在處理', message: '正在啟動還原後的日記庫…'),
    );
    expect(
      find.bySemanticsLabel(
        testL10n.settingsProgressSemanticIndeterminate(
          '正在處理',
          '正在啟動還原後的日記庫…',
        ),
      ),
      findsOneWidget,
    );
  });
}
