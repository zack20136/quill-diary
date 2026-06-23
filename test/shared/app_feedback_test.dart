import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/features/home/home_layout.dart';
import 'package:quill_diary/shared/presentation/app_feedback.dart';

void main() {
  group('resolveAppFeedbackColors', () {
    test('maps each tone to the shared palette', () {
      final ColorScheme cs = ColorScheme.fromSeed(seedColor: const Color(0xFF4C7A67));

      expect(
        resolveAppFeedbackColors(cs, AppFeedbackTone.info).background,
        cs.primaryContainer,
      );
      expect(
        resolveAppFeedbackColors(cs, AppFeedbackTone.info).foreground,
        cs.onPrimaryContainer,
      );
      expect(
        resolveAppFeedbackColors(cs, AppFeedbackTone.warning).background,
        cs.secondaryContainer,
      );
      expect(
        resolveAppFeedbackColors(cs, AppFeedbackTone.error).background,
        cs.errorContainer,
      );
    });
  });

  group('AppFeedbackBanner', () {
    testWidgets('uses tone background color', (WidgetTester tester) async {
      final ColorScheme cs = ColorScheme.fromSeed(seedColor: const Color(0xFF4C7A67));

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(colorScheme: cs),
          home: const Scaffold(
            body: AppFeedbackBanner(
              message: 'warning message',
              tone: AppFeedbackTone.warning,
            ),
          ),
        ),
      );

      final DecoratedBox banner = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(AppFeedbackBanner),
          matching: find.byType(DecoratedBox),
        ),
      );
      final BoxDecoration decoration = banner.decoration! as BoxDecoration;

      expect(decoration.color, cs.secondaryContainer);
      expect(find.text('warning message'), findsOneWidget);
    });
  });

  group('showAppFeedbackSnackBar', () {
    testWidgets('shows floating snackbar with info colors', (
      WidgetTester tester,
    ) async {
      final ColorScheme cs = ColorScheme.fromSeed(seedColor: const Color(0xFF4C7A67));

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(colorScheme: cs, useMaterial3: false),
          home: Builder(
            builder: (BuildContext context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      showAppFeedbackSnackBar(context, 'saved');
                    },
                    child: const Text('notify'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('notify'));
      await tester.pump();

      final SnackBar snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snackBar.behavior, SnackBarBehavior.floating);
      expect(snackBar.backgroundColor, cs.primaryContainer);
      expect(
        snackBar.margin,
        const EdgeInsets.fromLTRB(
          HomeLayout.bodyHorizontal,
          0,
          HomeLayout.bodyHorizontal,
          HomeLayout.snackBarBottomPadding,
        ),
      );
      expect(find.text('saved'), findsOneWidget);
    });
  });
}
