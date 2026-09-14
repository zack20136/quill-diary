import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/application/onboarding/onboarding_intro.dart';
import 'package:quill_diary/application/onboarding/onboarding_providers.dart';
import 'package:quill_diary/infrastructure/preferences/personalization_preferences.dart';
import 'package:quill_diary/infrastructure/preferences/preferences_providers.dart';
import 'package:quill_diary/infrastructure/preferences/user_preferences.dart';
import 'package:quill_diary/presentation/onboarding/onboarding_intro_dialog.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_shell.dart';

import '../../helpers/shared/test_l10n.dart';
import '../../helpers/shared/widget_test_app.dart';

class _InstantOnboardingIntroController extends OnboardingIntroController {
  @override
  Future<int> build() async => 0;

  @override
  Future<void> markCompleted() async {
    state = const AsyncData<int>(onboardingIntroCurrentVersion);
  }
}

void main() {
  late Directory tempDir;
  late UserPreferences preferences;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('onboarding_dialog');
    preferences = UserPreferences(
      storageFile: File('${tempDir.path}/app_preferences.json'),
    );
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<void> openDialog(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userPreferencesProvider.overrideWithValue(preferences),
          onboardingIntroVersionProvider.overrideWith(
            _InstantOnboardingIntroController.new,
          ),
        ],
        child: widgetTestApp(
          child: Builder(
            builder: (BuildContext context) => FilledButton(
              onPressed: () => showOnboardingIntroDialog(context),
              child: const Text('開啟介紹'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('開啟介紹'));
    await tester.pumpAndSettle();
  }

  testWidgets('不可點背景關閉，第五頁才提供開始使用', (WidgetTester tester) async {
    await openDialog(tester);

    expect(find.byType(AppDialogShell), findsOneWidget);
    expect(find.text(testL10n.onboardingIntroPage1Title), findsOneWidget);
    expect(find.text(testL10n.onboardingIntroGetStarted), findsNothing);
    expect(find.text(testL10n.onboardingIntroNext), findsOneWidget);
    expect(find.text(testL10n.onboardingIntroBack), findsNothing);

    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(find.byType(AppDialogShell), findsOneWidget);

    await tester.tap(find.text(testL10n.onboardingIntroNext));
    await tester.pumpAndSettle();
    expect(find.text(testL10n.onboardingIntroPage2Title), findsOneWidget);
    expect(find.text(testL10n.onboardingIntroBack), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text(testL10n.onboardingIntroPage1Title), findsOneWidget);

    for (int i = 0; i < 4; i++) {
      await tester.tap(find.text(testL10n.onboardingIntroNext));
      await tester.pumpAndSettle();
    }
    expect(find.text(testL10n.onboardingIntroPage5Title), findsOneWidget);
    expect(find.text(testL10n.onboardingIntroGetStarted), findsOneWidget);

    await tester.tap(find.text(testL10n.onboardingIntroGetStarted));
    await tester.pumpAndSettle();
    expect(find.byType(AppDialogShell), findsNothing);
  });

  testWidgets('左右滑動會換到下一頁或上一頁', (WidgetTester tester) async {
    await openDialog(tester);

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text(testL10n.onboardingIntroPage2Title), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text(testL10n.onboardingIntroPage1Title), findsOneWidget);
  });

  testWidgets('Dialog 會依當頁內容調整高度', (WidgetTester tester) async {
    await openDialog(tester);

    final double firstPageHeight = tester.getSize(find.byType(PageView)).height;

    await tester.tap(find.text(testL10n.onboardingIntroNext));
    await tester.pumpAndSettle();
    await tester.tap(find.text(testL10n.onboardingIntroNext));
    await tester.pumpAndSettle();

    final double thirdPageHeight = tester.getSize(find.byType(PageView)).height;
    expect(thirdPageHeight, greaterThan(firstPageHeight));
  });

  testWidgets('切換英文後會寫入語系偏好', (WidgetTester tester) async {
    await openDialog(tester);

    expect(find.text(testL10n.onboardingIntroLanguageEnShort), findsOneWidget);

    await tester.tap(find.text(testL10n.onboardingIntroLanguageEnShort));
    await tester.pumpAndSettle();
    expect(await preferences.storedAppLocaleOrNull, AppLanguage.en);
  });
}
