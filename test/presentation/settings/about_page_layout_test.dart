import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/settings/pages/about_page.dart';

import '../../helpers/app_test_theme.dart';

void main() {
  for (final ({Locale locale, Brightness brightness, String name}) scenario
      in <({Locale locale, Brightness brightness, String name})>[
        (
          locale: appZhLocale,
          brightness: Brightness.light,
          name: '繁中淺色',
        ),
        (locale: appEnLocale, brightness: Brightness.dark, name: '英文深色'),
      ]) {
    testWidgets('${scenario.name}窄螢幕可顯示交換指南且沒有版面例外', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: scenario.locale,
            supportedLocales: appSupportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            theme: appTestTheme(brightness: scenario.brightness),
            home: const SettingsAboutPage(),
          ),
        ),
      );
      await tester.pump();

      final BuildContext tabViewContext = tester.element(
        find.byType(TabBarView),
      );
      final AppLocalizations l10n = AppLocalizations.of(tabViewContext);
      expect(l10n.localeName, scenario.locale.languageCode);
      DefaultTabController.of(tabViewContext).animateTo(3);
      await tester.pumpAndSettle();

      final Finder exchangeSection = find.text(
        l10n.aboutTabBackupRestoreSection4Title,
      );
      final ScrollableState scrollable = tester.state<ScrollableState>(
        find
            .byWidgetPredicate(
              (Widget widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            )
            .hitTestable(),
      );
      for (
        int attempt = 0;
        attempt < 50 && exchangeSection.evaluate().isEmpty;
        attempt++
      ) {
        final double currentOffset = scrollable.position.pixels;
        final double nextOffset = (currentOffset + 400).clamp(
          0,
          scrollable.position.maxScrollExtent,
        );
        if (nextOffset == currentOffset) {
          break;
        }
        scrollable.position.jumpTo(nextOffset);
        await tester.pump();
      }
      expect(
        exchangeSection,
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
