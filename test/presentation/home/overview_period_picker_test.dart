import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/home/home_browse_state.dart';
import 'package:quill_diary/application/home/home_entry_query_providers.dart';
import 'package:quill_diary/presentation/home/widgets/overview_pane.dart';

import '../../helpers/shared/widget_test_app.dart';

Widget _testApp(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: widgetTestApp(
      center: false,
      child: const OverviewFocusedPeriodBar(),
    ),
  );
}

void main() {
  testWidgets('總覽月份標題可直接選擇年月且保留逐月箭頭', (WidgetTester tester) async {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        overviewAvailableYearsProvider.overrideWith(
          (Ref ref) async => const <int>[2024, 2026],
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(overviewScopeProvider.notifier).set(OverviewScope.month);
    container
        .read(overviewFocusedMonthProvider.notifier)
        .set(DateTime(2026, 1));

    await tester.pumpWidget(_testApp(container));
    await tester.pumpAndSettle();
    final Finder periodButton = find.byKey(
      const Key('overview-focused-period-button'),
    );
    expect(tester.getSize(periodButton).height, greaterThanOrEqualTo(44));
    await tester.tap(periodButton);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('app-date-picker-month-2')));
    await tester.tap(find.byKey(const Key('app-date-picker-apply')));
    await tester.pumpAndSettle();

    expect(container.read(overviewFocusedMonthProvider), DateTime(2026, 2));
    await tester.tap(find.byKey(const Key('overview-period-previous')));
    await tester.pump();
    expect(container.read(overviewFocusedMonthProvider), DateTime(2026, 1));
  });

  testWidgets('總覽年份標題有資料時可直接選擇年份', (WidgetTester tester) async {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        overviewAvailableYearsProvider.overrideWith(
          (Ref ref) async => const <int>[2020, 2026],
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(overviewScopeProvider.notifier).set(OverviewScope.year);
    container.read(overviewFocusedYearProvider.notifier).set(2025);

    await tester.pumpWidget(_testApp(container));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('overview-focused-period-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('app-date-picker-year-2024')));
    await tester.tap(find.byKey(const Key('app-date-picker-apply')));
    await tester.pumpAndSettle();

    expect(container.read(overviewFocusedYearProvider), 2024);
  });

  testWidgets('總覽年份沒有資料時中央期間不可選取', (WidgetTester tester) async {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        overviewAvailableYearsProvider.overrideWith(
          (Ref ref) async => const <int>[],
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(overviewScopeProvider.notifier).set(OverviewScope.year);

    await tester.pumpWidget(_testApp(container));
    await tester.pumpAndSettle();

    final TextButton button = tester.widget<TextButton>(
      find.byKey(const Key('overview-focused-period-button')),
    );
    expect(button.onPressed, isNull);
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('overview-period-previous')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('overview-period-next')))
          .onPressed,
      isNull,
    );
  });
}
