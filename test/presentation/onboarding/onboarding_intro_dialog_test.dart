import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/onboarding/onboarding_providers.dart';
import 'package:quill_diary/application/settings/personalization_providers.dart';
import 'package:quill_diary/domain/preferences/personalization_preferences.dart';
import 'package:quill_diary/infrastructure/preferences/user_preferences.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/onboarding/onboarding_intro_dialog.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_shell.dart';

import '../../helpers/shared/test_l10n.dart';
import '../../helpers/shared/widget_test_app.dart';

class _InstantOnboardingIntroController extends OnboardingIntroController {
  @override
  Future<bool> build() async => false;

  @override
  Future<void> markCompleted() async {
    state = const AsyncData<bool>(true);
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

  Future<void> openDialog(
    WidgetTester tester, {
    Locale locale = appZhLocale,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userPreferencesProvider.overrideWithValue(preferences),
          hasSeenOnboardingIntroProvider.overrideWith(
            _InstantOnboardingIntroController.new,
          ),
        ],
        child: widgetTestApp(
          locale: locale,
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

  testWidgets('窄螢幕上的中英文導覽翻到最後一頁時外框位置固定', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(352, 600);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final Finder surface = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byWidgetPredicate(
        (widget) => widget is Material && widget.type == MaterialType.card,
      ),
    );
    Rect? firstPage;
    for (final (locale, l10n) in [
      (appZhLocale, testL10n),
      (appEnLocale, testEnL10n),
    ]) {
      await openDialog(tester, locale: locale);
      firstPage ??= tester.getRect(surface);
      expect(tester.getRect(surface), firstPage);
      for (int page = 1; page < 5; page++) {
        await tester.tap(find.text(l10n.onboardingIntroNext));
        await tester.pumpAndSettle();
        expect(tester.getRect(surface), firstPage);
      }
      await tester.tap(find.text(l10n.onboardingIntroGetStarted));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('切換英文後會寫入語系偏好', (WidgetTester tester) async {
    await openDialog(tester);

    expect(find.text(testL10n.onboardingIntroLanguageEnShort), findsOneWidget);

    await tester.tap(find.text(testL10n.onboardingIntroLanguageEnShort));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(OnboardingIntroDialog)),
    );
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (container.read(personalizationPreferencesProvider).value?.locale !=
            AppLanguage.en &&
        DateTime.now().isBefore(deadline)) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    expect(
      container.read(personalizationPreferencesProvider).value?.locale,
      AppLanguage.en,
    );
    expect(
      await tester.runAsync(() => preferences.storedAppLocaleOrNull),
      AppLanguage.en,
    );
  });
}
