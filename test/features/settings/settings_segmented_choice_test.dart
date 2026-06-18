import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/features/settings/widgets/personalization_sections.dart';
import 'package:quill_diary/features/settings/widgets/settings_sections.dart';
import 'package:quill_diary/infrastructure/preferences/personalization_preferences.dart';
import 'package:quill_diary/infrastructure/preferences/user_preferences.dart';
import 'package:quill_diary/infrastructure/security/app_unlock_mode.dart';
import 'package:quill_diary/l10n/l10n.dart';

Widget _testApp({
  required Locale locale,
  required Widget child,
  double width = 320,
}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: Scaffold(
      body: Center(
        child: SizedBox(width: width, child: child),
      ),
    ),
  );
}

void main() {
  group('settings segmented choice', () {
    testWidgets('unlock mode 在中英文小畫面下不 overflow', (WidgetTester tester) async {
      Future<void> onSelected(AppUnlockMode _) async {}

      for (final Locale locale in <Locale>[appZhLocale, appEnLocale]) {
        await tester.pumpWidget(
          _testApp(
            locale: locale,
            child: UnlockMethodSectionBody(
              enabled: true,
              changeAllowed: true,
              busy: false,
              unlockMode: AppUnlockMode.deviceLock,
              onModeSelected: onSelected,
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('unlock mode busy 時 segmented choice 會停用點擊', (WidgetTester tester) async {
      Future<void> onSelected(AppUnlockMode _) async {}

      await tester.pumpWidget(
        _testApp(
          locale: appZhLocale,
          child: UnlockMethodSectionBody(
            enabled: true,
            changeAllowed: true,
            busy: true,
            unlockMode: AppUnlockMode.none,
            onModeSelected: onSelected,
          ),
        ),
      );
      await tester.pump();

      final List<InkWell> inkWells = tester.widgetList<InkWell>(
        find.byType(InkWell),
      ).toList(growable: false);
      expect(inkWells, isNotEmpty);
      expect(inkWells.every((InkWell widget) => widget.onTap == null), isTrue);
    });

    testWidgets('personalization segmented choice 在中英文小畫面下不 overflow', (
      WidgetTester tester,
    ) async {
      Future<void> onSelected(AppThemeModePreference _) async {}

      for (final Locale locale in <Locale>[appZhLocale, appEnLocale]) {
        await tester.pumpWidget(
          _testApp(
            locale: locale,
            child: PersonalizationAppearanceSectionBody(
              selected: AppThemeModePreference.system,
              onSelected: onSelected,
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('timeout segmented choice 在小畫面下不 overflow', (WidgetTester tester) async {
      Future<void> onSelected(SessionBackgroundTimeoutMinutes _) async {}

      await tester.pumpWidget(
        _testApp(
          locale: appEnLocale,
          width: 360,
          child: PersonalizationSessionTimeoutSectionBody(
            selected: SessionBackgroundTimeoutMinutes.three,
            onSelected: onSelected,
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
