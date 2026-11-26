import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:quill_diary/app/router.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/settings/pages/about_page.dart';
import 'package:quill_diary/shared/navigation/app_routes.dart';

import '../../helpers/app_test_theme.dart';
import '../../helpers/shared/test_l10n.dart';

void main() {
  late GoRouter router;

  setUp(() {
    router = AppRouter.createRouter();
    addTearDown(router.dispose);
  });

  Future<void> pumpAbout(
    WidgetTester tester,
    String location, {
    Locale locale = appZhLocale,
    Brightness brightness = Brightness.light,
  }) async {
    router.go(location);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: router,
          theme: appTestTheme(brightness: brightness),
          locale: locale,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder topicLink(AboutTopic topic) => find.byKey(ValueKey(topic));

  AboutTopic activeTopic(WidgetTester tester) => tester
      .widget<SettingsAboutTopicPage>(find.byType(SettingsAboutTopicPage))
      .topic;

  testWidgets('直接開啟人物，再從人物前往 AI 時，系統返回逐頁回到目錄', (tester) async {
    await pumpAbout(tester, AppRoutes.aboutTopicLocation(AboutTopic.people));
    expect(activeTopic(tester), AboutTopic.people);

    final aiCard = topicLink(AboutTopic.ai).hitTestable();
    await tester.scrollUntilVisible(aiCard, 200);
    await tester.pumpAndSettle();
    await tester.tap(aiCard);
    await tester.pumpAndSettle();
    expect(activeTopic(tester), AboutTopic.ai);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(activeTopic(tester), AboutTopic.people);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(SettingsAboutPage), findsOneWidget);
  });

  testWidgets('未知主題回到目錄並可開啟有效主題', (tester) async {
    await pumpAbout(tester, '${AppRoutes.aboutRoute}/unknown');
    expect(
      router.routeInformationProvider.value.uri.path,
      AppRoutes.aboutRoute,
    );

    await tester.tap(topicLink(AboutTopic.writing));
    await tester.pumpAndSettle();
    expect(activeTopic(tester), AboutTopic.writing);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsAboutPage), findsOneWidget);
  });

  testWidgets('窄螢幕放大字級時可捲到還原警示與換機步驟', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpAbout(
      tester,
      AppRoutes.aboutRoute,
      locale: appEnLocale,
      brightness: Brightness.dark,
    );

    final backupLink = topicLink(AboutTopic.backup).hitTestable();
    await tester.scrollUntilVisible(backupLink, 180);
    await tester.pumpAndSettle();
    await tester.tap(backupLink);
    await tester.pumpAndSettle();

    final warning = find.text(
      testEnL10n.settingsRestoreConfirmOverwriteHeadline,
    );
    final lastStep = find.text(testEnL10n.aboutBackupMoveCheck);
    for (final target in [warning, lastStep]) {
      await tester.scrollUntilVisible(target.hitTestable(), 180);
      await tester.pumpAndSettle();
      expect(target.hitTestable(), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });
}
