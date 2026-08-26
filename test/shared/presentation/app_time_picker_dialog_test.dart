import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/presentation/time_picker/app_time_picker_dialog.dart';

import '../../helpers/app_test_theme.dart';

Widget _pickerApp({
  required TimeOfDay initialTime,
  required ValueChanged<TimeOfDay?> onResult,
  Brightness brightness = Brightness.light,
}) => MaterialApp(
  theme: appTestTheme(brightness: brightness),
  locale: appZhLocale,
  supportedLocales: appSupportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: Builder(
    builder: (BuildContext context) => Scaffold(
      body: Center(
        child: FilledButton(
          key: const Key('open-picker'),
          onPressed: () => unawaited(
            showAppTimePickerDialog(
              context: context,
              initialTime: initialTime,
            ).then(onResult),
          ),
          child: const Text('開啟'),
        ),
      ),
    ),
  ),
);

Finder _valueText(String controlKey, String value) => find.descendant(
  of: find.byKey(Key(controlKey)),
  matching: find.text(value),
);

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('open-picker')));
  await tester.pumpAndSettle();
}

void main() {
  for (final (TimeOfDay time, String hour, String minute, String period)
      in <(TimeOfDay, String, String, String)>[
        (const TimeOfDay(hour: 0, minute: 0), '12', '00', 'AM'),
        (const TimeOfDay(hour: 7, minute: 30), '07', '30', 'AM'),
        (const TimeOfDay(hour: 12, minute: 0), '12', '00', 'PM'),
        (const TimeOfDay(hour: 23, minute: 59), '11', '59', 'PM'),
      ]) {
    testWidgets(
      '24 小時初始值 ${time.hour}:${time.minute} 轉成 $period $hour:$minute',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _pickerApp(initialTime: time, onResult: (_) {}),
        );
        await _open(tester);
        expect(_valueText('app-time-picker-hour', hour), findsOneWidget);
        expect(_valueText('app-time-picker-minute', minute), findsOneWidget);
        final Material periodMaterial = tester.widget<Material>(
          find
              .ancestor(
                of: find.byKey(Key('app-time-picker-${period.toLowerCase()}')),
                matching: find.byType(Material),
              )
              .first,
        );
        expect(periodMaterial, isNotNull);
      },
    );
  }

  testWidgets('AM PM 切換後以 24 小時制回傳', (WidgetTester tester) async {
    TimeOfDay? result;
    await tester.pumpWidget(
      _pickerApp(
        initialTime: const TimeOfDay(hour: 1, minute: 15),
        onResult: (TimeOfDay? value) => result = value,
      ),
    );
    await _open(tester);
    await tester.tap(find.byKey(const Key('app-time-picker-pm')));
    await tester.tap(find.byKey(const Key('app-time-picker-confirm')));
    await tester.pumpAndSettle();
    expect(result, const TimeOfDay(hour: 13, minute: 15));
  });

  testWidgets('AM PM 選項使用可見的 Material 漣漪回饋', (WidgetTester tester) async {
    await tester.pumpWidget(
      _pickerApp(
        initialTime: const TimeOfDay(hour: 8, minute: 15),
        onResult: (_) {},
      ),
    );
    await _open(tester);
    final BuildContext context = tester.element(
      find.byKey(const Key('app-time-picker-pm')),
    );
    final InkWell option = tester.widget<InkWell>(
      find.byKey(const Key('app-time-picker-pm')),
    );
    expect(
      option.splashColor,
      Theme.of(context).colorScheme.primary.withValues(alpha: 0.18),
    );
    expect(option.highlightColor, isNot(Colors.transparent));
  });

  testWidgets('底部只有確定，沒有取消與鐘面提示', (WidgetTester tester) async {
    await tester.pumpWidget(
      _pickerApp(
        initialTime: const TimeOfDay(hour: 8, minute: 15),
        onResult: (_) {},
      ),
    );
    await _open(tester);
    await tester.tap(find.byKey(const Key('app-time-picker-minute')));
    await tester.pump();
    expect(find.byKey(const Key('app-time-picker-cancel')), findsNothing);
    expect(find.text('取消'), findsNothing);
    expect(find.text('確定'), findsOneWidget);
    expect(find.text('點選以 5 分鐘調整，拖曳可精確到 1 分鐘'), findsNothing);
  });

  testWidgets('鐘面與時間欄、操作列之間有足夠留白', (WidgetTester tester) async {
    await tester.pumpWidget(
      _pickerApp(
        initialTime: const TimeOfDay(hour: 8, minute: 15),
        onResult: (_) {},
      ),
    );
    await _open(tester);
    final Rect dial = tester.getRect(find.byKey(const Key('app-time-picker-dial')));
    final Rect hour = tester.getRect(find.byKey(const Key('app-time-picker-hour')));
    final double actionsTop = math.min(
      tester.getTopLeft(find.byKey(const Key('app-time-picker-entry-mode'))).dy,
      tester.getTopLeft(find.byKey(const Key('app-time-picker-confirm'))).dy,
    );
    expect(dial.top - hour.bottom, greaterThanOrEqualTo(24));
    expect(actionsTop - dial.bottom, greaterThanOrEqualTo(24));
  });

  testWidgets('點擊背景會關閉並回傳 null', (WidgetTester tester) async {
    TimeOfDay? result = const TimeOfDay(hour: 9, minute: 30);
    await tester.pumpWidget(
      _pickerApp(
        initialTime: const TimeOfDay(hour: 8, minute: 15),
        onResult: (TimeOfDay? value) => result = value,
      ),
    );
    await _open(tester);
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });

  testWidgets('分鐘點擊以五分鐘調整且拖曳維持每分鐘精度', (WidgetTester tester) async {
    TimeOfDay? result;
    await tester.pumpWidget(
      _pickerApp(
        initialTime: const TimeOfDay(hour: 1, minute: 0),
        onResult: (TimeOfDay? value) => result = value,
      ),
    );
    await _open(tester);
    final Finder dial = find.byKey(const Key('app-time-picker-dial'));
    Offset center = tester.getCenter(dial);
    final double radius = tester.getSize(dial).width * .38;
    await tester.tapAt(center + Offset(radius, 0));
    await tester.pump();
    expect(_valueText('app-time-picker-hour', '03'), findsOneWidget);

    center = tester.getCenter(dial);
    final double angle = 57 / 60 * math.pi * 2 - math.pi / 2;
    await tester.tapAt(
      center + Offset(math.cos(angle), math.sin(angle)) * radius,
    );
    await tester.pump();
    expect(_valueText('app-time-picker-minute', '55'), findsOneWidget);

    final Offset minutePosition =
        center + Offset(math.cos(angle), math.sin(angle)) * radius;
    final TestGesture minuteGesture = await tester.startGesture(center);
    await minuteGesture.moveTo(center + (minutePosition - center) * .3);
    await minuteGesture.moveTo(minutePosition);
    await minuteGesture.up();
    await tester.pump();
    expect(_valueText('app-time-picker-minute', '57'), findsOneWidget);
    await tester.tap(find.byKey(const Key('app-time-picker-confirm')));
    await tester.pumpAndSettle();
    expect(result, const TimeOfDay(hour: 3, minute: 57));
  });

  testWidgets('拖曳選擇小時後會切換至分鐘鐘面', (WidgetTester tester) async {
    await tester.pumpWidget(
      _pickerApp(
        initialTime: const TimeOfDay(hour: 1, minute: 17),
        onResult: (_) {},
      ),
    );
    await _open(tester);
    final Finder dial = find.byKey(const Key('app-time-picker-dial'));
    final Offset center = tester.getCenter(dial);
    final double radius = tester.getSize(dial).width * .38;
    final TestGesture gesture = await tester.startGesture(center);
    await gesture.moveTo(center - const Offset(24, 0));
    await gesture.moveTo(center - Offset(radius, 0));
    await gesture.up();
    await tester.pump();
    expect(_valueText('app-time-picker-hour', '09'), findsOneWidget);

    await tester.tapAt(center - Offset(0, radius));
    await tester.pump();
    expect(_valueText('app-time-picker-minute', '00'), findsOneWidget);
  });

  testWidgets('鍵盤模式驗證範圍並正確回傳 PM 時間', (WidgetTester tester) async {
    TimeOfDay? result;
    await tester.pumpWidget(
      _pickerApp(
        initialTime: const TimeOfDay(hour: 8, minute: 0),
        onResult: (TimeOfDay? value) => result = value,
      ),
    );
    await _open(tester);
    await tester.tap(find.byKey(const Key('app-time-picker-entry-mode')));
    await tester.pump();
    final Finder fields = find.byType(TextField);
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.first, '13');
    await tester.pump();
    expect(find.byKey(const Key('app-time-picker-error')), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('app-time-picker-confirm')))
          .onPressed,
      isNull,
    );
    await tester.enterText(fields.first, '11');
    await tester.enterText(fields.last, '59');
    await tester.tap(find.byKey(const Key('app-time-picker-pm')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('app-time-picker-confirm')));
    await tester.pumpAndSettle();
    expect(result, const TimeOfDay(hour: 23, minute: 59));
  });

  for (final Brightness brightness in Brightness.values) {
    testWidgets('窄螢幕大字體在 ${brightness.name} 主題不會重疊或 overflow', (
      WidgetTester tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 568);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        _pickerApp(
          initialTime: const TimeOfDay(hour: 7, minute: 57),
          onResult: (_) {},
          brightness: brightness,
        ),
      );
      await _open(tester);
      final Finder surface = find.byWidgetPredicate(
        (Widget widget) =>
            widget is Material && widget.type == MaterialType.card,
      );
      expect(tester.getSize(surface).width, 288);
      expect(find.byKey(const Key('app-time-picker-dial')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('中等文字縮放不會 overflow', (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      _pickerApp(
        initialTime: const TimeOfDay(hour: 19, minute: 45),
        onResult: (_) {},
      ),
    );
    await _open(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('寬螢幕維持九成 dialog 寬度且鐘面不過度放大', (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 600);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _pickerApp(
        initialTime: const TimeOfDay(hour: 19, minute: 45),
        onResult: (_) {},
      ),
    );
    await _open(tester);
    final Finder surface = find.byWidgetPredicate(
      (Widget widget) => widget is Material && widget.type == MaterialType.card,
    );
    expect(tester.getSize(surface).width, 720);
    expect(
      tester.getSize(find.byKey(const Key('app-time-picker-dial'))).width,
      252,
    );
    expect(tester.takeException(), isNull);
  });
}
