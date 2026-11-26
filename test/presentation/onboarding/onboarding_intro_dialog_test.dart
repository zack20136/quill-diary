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
    expect(
      find.text(testL10n.onboardingIntroPage1Title).hitTestable(),
      findsOneWidget,
    );
    expect(
      find.text(testL10n.onboardingIntroGetStarted).hitTestable(),
      findsNothing,
    );
    expect(
      find.text(testL10n.onboardingIntroNext).hitTestable(),
      findsOneWidget,
    );
    expect(find.text(testL10n.onboardingIntroBack).hitTestable(), findsNothing);

    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(find.byType(AppDialogShell), findsOneWidget);

    await tester.tap(find.text(testL10n.onboardingIntroNext));
    await tester.pumpAndSettle();
    expect(
      find.text(testL10n.onboardingIntroPage2Title).hitTestable(),
      findsOneWidget,
    );
    expect(
      find.text(testL10n.onboardingIntroBack).hitTestable(),
      findsOneWidget,
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      find.text(testL10n.onboardingIntroPage1Title).hitTestable(),
      findsOneWidget,
    );

    for (int i = 0; i < 4; i++) {
      await tester.tap(find.text(testL10n.onboardingIntroNext));
      await tester.pumpAndSettle();
    }
    expect(
      find.text(testL10n.onboardingIntroPage5Title).hitTestable(),
      findsOneWidget,
    );
    expect(
      find.text(testL10n.onboardingIntroGetStarted).hitTestable(),
      findsOneWidget,
    );

    await tester.tap(find.text(testL10n.onboardingIntroGetStarted));
    await tester.pumpAndSettle();
    expect(find.byType(AppDialogShell), findsNothing);
  });

  testWidgets('左右滑動會換到下一頁或上一頁', (WidgetTester tester) async {
    await openDialog(tester);

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(
      find.text(testL10n.onboardingIntroPage2Title).hitTestable(),
      findsOneWidget,
    );

    await tester.fling(find.byType(PageView), const Offset(400, 0), 1000);
    await tester.pumpAndSettle();
    expect(
      find.text(testL10n.onboardingIntroPage1Title).hitTestable(),
      findsOneWidget,
    );
  });

  final dialogSurface = find
      .descendant(of: find.byType(Dialog), matching: find.byType(Material))
      .first;

  testWidgets('高度充足的窄版英文導覽五頁等高且每頁完整顯示', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(352, 1500);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await openDialog(tester, locale: appEnLocale);

    final height = tester.getSize(dialogSurface).height;
    final content = find.descendant(
      of: find.byType(PageView),
      matching: find.byType(SingleChildScrollView),
    );
    for (var page = 1; page <= 5; page++) {
      final scroll = tester.state<ScrollableState>(
        find.descendant(of: content, matching: find.byType(Scrollable)),
      );
      expect(tester.getSize(dialogSurface).height, closeTo(height, 0.1));
      expect(
        scroll.position.maxScrollExtent,
        0,
        reason: '第 $page 頁，對話框高度 $height，內容區 ${tester.getRect(content)}',
      );
      if (page < 5) {
        await tester.tap(find.text(testEnL10n.onboardingIntroNext));
        await tester.pumpAndSettle();
      }
    }
  });

  testWidgets('小螢幕放大字級時可滑到導覽內文底部並繼續下一頁', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(352, 600);
    tester.platformDispatcher.textScaleFactorTestValue = 1.65;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await openDialog(tester, locale: appEnLocale);

    final next = find.text(testEnL10n.onboardingIntroNext).hitTestable();
    await tester.tap(next);
    await tester.pumpAndSettle();

    final lastBullet = find.descendant(
      of: find.byType(PageView),
      matching: find.text(
        testEnL10n.onboardingIntroPage2Item2(
          testEnL10n.chatDiarySend,
          testEnL10n.chatDiaryGenerateDiary,
          testEnL10n.organizationGenerate,
        ),
      ),
    );
    final content = find.ancestor(
      of: lastBullet,
      matching: find.byType(SingleChildScrollView),
    );
    final scrollable = find.descendant(
      of: content,
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(scrollable).position;
    expect(position.extentAfter, greaterThan(0));
    final viewport = tester.getRect(content);
    for (var swipe = 0; swipe < 10 && position.extentAfter > 1; swipe++) {
      await tester.timedDrag(
        content,
        Offset(0, -2 * viewport.height),
        const Duration(milliseconds: 350),
      );
      await tester.pumpAndSettle();
    }
    expect(position.extentAfter, closeTo(0, 1));
    expect(
      tester.getRect(lastBullet).bottom,
      lessThanOrEqualTo(viewport.bottom),
    );
    expect(
      find.byKey(const ValueKey<String>('app-scrollbar-thumb')),
      findsNothing,
    );

    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(
      find.text(testEnL10n.onboardingIntroPage3Title).hitTestable(),
      findsOneWidget,
    );
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
