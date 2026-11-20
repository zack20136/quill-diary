import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/presentation/ai/ai_generation_card.dart';
import 'package:quill_diary/shared/presentation/widgets/app_progress.dart';

import '../../helpers/shared/test_l10n.dart';
import '../../helpers/shared/widget_test_app.dart';

void main() {
  testWidgets('批次進度與計時同列，計時靠右並持續更新', (tester) async {
    var elapsed = const Duration(minutes: 3, seconds: 11);
    final progress = testL10n.personaBatchProgress(1, 1, 3);
    await tester.pumpWidget(
      widgetTestApp(
        viewport: const Size(355, 350),
        child: AiGenerationCard(
          title: testL10n.personaExtractingActive,
          status: progress,
          hint: testL10n.personaRetryHint,
          progress: 1 / 3,
          elapsed: () => elapsed,
          onStop: () {},
        ),
      ),
    );

    final timer = find.text(testL10n.aiGenerationElapsed('3:11'));
    final timerRect = tester.getRect(timer);
    final statusRect = tester.getRect(find.text(progress));
    expect(timerRect.top, lessThan(statusRect.bottom));
    expect(timerRect.left, greaterThanOrEqualTo(statusRect.right));
    expect(
      timerRect.right,
      closeTo(
        tester.getRect(find.byType(AppLinearProgressIndicator)).right,
        0.5,
      ),
    );
    expect(tester.widget<Text>(timer).textAlign, TextAlign.end);

    elapsed += const Duration(seconds: 1);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text(testL10n.aiGenerationElapsed('3:12')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
