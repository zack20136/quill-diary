import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/app/app_colors.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/people/widgets/person_composer_dialog.dart';
import 'package:quill_diary/shared/presentation/accent_visual.dart';
import 'package:quill_diary/shared/presentation/widgets/accent_dialog_shell.dart';

import '../../helpers/app_test_theme.dart';

Widget _testApp() {
  return ProviderScope(
    child: MaterialApp(
      theme: appTestTheme(),
      locale: appZhLocale,
      supportedLocales: appSupportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const Dialog(
        insetPadding: EdgeInsets.all(12),
        backgroundColor: Colors.transparent,
        child: PersonComposerDialog(),
      ),
    ),
  );
}

Widget _dialogLauncherApp() {
  return ProviderScope(
    child: MaterialApp(
      theme: appTestTheme(),
      locale: appZhLocale,
      supportedLocales: appSupportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Builder(
        builder: (BuildContext context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => showPersonComposerDialog(context),
              child: const Text('開啟人物表單'),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('小螢幕與鍵盤開啟時表單可捲動且不會 overflow', (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    tester.view.viewInsets = const FakeViewPadding(bottom: 220);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    expect(find.text('基本資料'), findsOneWidget);
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(AccentDialogShell), findsOneWidget);
    expect(find.byType(CustomScrollView), findsOneWidget);
    expect(find.text('儲存'), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('關係'), findsWidgets);
    expect(find.byType(Slider), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('鍵盤開啟時人物表單維持原位與固定高度', (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.viewPadding = const FakeViewPadding(bottom: 24);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_dialogLauncherApp());
    await tester.tap(find.text('開啟人物表單'));
    await tester.pumpAndSettle();

    final Finder dialog = find.byKey(const Key('person-composer-dialog'));
    final Rect beforeKeyboard = tester.getRect(dialog);

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();

    expect(tester.getRect(dialog), beforeKeyboard);
    expect(tester.takeException(), isNull);
  });

  testWidgets('別名可批次加入、橫向顯示並提示重複', (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    final Finder aliasField = find.widgetWithText(TextField, '新增別名');
    await tester.enterText(aliasField, '阿明，小華');
    await tester.pump();

    expect(find.widgetWithText(InputChip, '阿明'), findsOneWidget);
    expect(find.widgetWithText(InputChip, '小華'), findsOneWidget);
    expect(
      tester.widgetList<InputChip>(find.byType(InputChip)),
      everyElement(
        predicate<InputChip>(
          (InputChip chip) =>
              chip.materialTapTargetSize != MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );

    await tester.enterText(aliasField, '阿明');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(find.text('這個別名已經加入'), findsOneWidget);
    expect(tester.widget<TextField>(aliasField).controller!.text, '阿明');
    expect(tester.takeException(), isNull);
  });

  testWidgets('中文輸入法組字期間不會提交別名', (WidgetTester tester) async {
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextField, '新增別名'));

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '阿明，',
        selection: TextSelection.collapsed(offset: 3),
        composing: TextRange(start: 0, end: 3),
      ),
    );
    await tester.pump();

    expect(find.byType(InputChip), findsNothing);
  });

  testWidgets('七個關係選項固定單列並可選取合作夥伴', (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();
    final Finder relationshipList = find.byKey(
      const Key('person-relationships-list'),
    );
    expect(relationshipList, findsOneWidget);
    final ListView list = tester.widget<ListView>(relationshipList);
    expect(
      (list.childrenDelegate as SliverChildBuilderDelegate).estimatedChildCount,
      13,
    );
    expect(find.text('家人'), findsOneWidget);
    expect(find.text('認識的人'), findsNothing);
    await tester.drag(relationshipList, const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('合作夥伴'), findsOneWidget);
    expect(find.text('其他'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilterChip, '合作夥伴'));
    await tester.pump();
    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, '合作夥伴'))
          .selected,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('關係描述與備註初始一行並隨內容增高', (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    final Finder descriptionField = find.byWidgetPredicate(
      (Widget widget) =>
          widget is TextField && widget.decoration?.labelText == '關係描述',
    );
    final TextField description = tester.widget<TextField>(descriptionField);
    expect(description.minLines, 1);
    expect(description.maxLines, isNull);
    final double initialHeight = tester.getSize(descriptionField).height;

    await tester.enterText(descriptionField, '第一行\n第二行\n第三行');
    await tester.pump();
    expect(tester.getSize(descriptionField).height, greaterThan(initialHeight));

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
    await tester.pumpAndSettle();
    final Finder notesField = find.byWidgetPredicate(
      (Widget widget) =>
          widget is TextField && widget.decoration?.labelText == '備註',
    );
    final TextField notes = tester.widget<TextField>(notesField);
    expect(notes.minLines, 1);
    expect(notes.maxLines, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('熟悉程度預設認識且其他資訊順序正確', (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();
    expect(find.text('認識'), findsOneWidget);
    expect(
      tester.getCenter(find.text('認識')).dy,
      closeTo(tester.getCenter(find.text('熟悉程度')).dy, 1),
    );
    expect(find.text('未設定'), findsNothing);
    final Slider slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.value, 3);
    expect(slider.semanticFormatterCallback!(slider.value), '認識，3／5');
    expect(find.text('陌生'), findsOneWidget);
    expect(find.text('很熟'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
    await tester.pumpAndSettle();
    final Finder acquaintance = find.text('認識年份');
    final Finder birthday = find.text('生日');
    final Finder notes = find.text('備註');
    expect(
      tester.getTopLeft(acquaintance).dy,
      lessThan(tester.getTopLeft(birthday).dy),
    );
    expect(
      tester.getTopLeft(birthday).dy,
      lessThan(tester.getTopLeft(notes).dy),
    );
    expect(find.byType(SwitchListTile), findsNothing);
    expect(find.text('年份不詳'), findsNothing);

    final Finder birthdayField = find.ancestor(
      of: birthday,
      matching: find.byType(InkWell),
    );
    expect(birthdayField, findsOneWidget);
    await tester.ensureVisible(birthdayField);
    await tester.pumpAndSettle();
    await tester.tap(birthdayField);
    await tester.pumpAndSettle();
    expect(find.text('選擇生日'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<int>), findsNothing);
    expect(find.byKey(const Key('app-date-picker-day-view')), findsOneWidget);
    await tester.tap(find.byKey(const Key('app-date-picker-period-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('app-date-picker-month-view')), findsOneWidget);
    expect(find.byKey(const ValueKey('app-date-picker-month-12')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('寬螢幕表單不再使用固定最大寬度', (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 800);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byType(AccentDialogShell)).width,
      876,
    );
    expect(find.byType(Divider), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('生日與認識年份可套用並清除', (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
    await tester.pumpAndSettle();

    Finder fieldFor(String label) => find.ancestor(
      of: find.text(label),
      matching: find.byType(InkWell),
    );

    await tester.tap(fieldFor('生日'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('app-date-picker-period-button')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('app-date-picker-month-12')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('app-date-picker-day-31')),
    );
    await tester.tap(find.byKey(const Key('app-date-picker-apply')));
    await tester.pumpAndSettle();
    expect(find.text('12月31日'), findsOneWidget);

    await tester.tap(fieldFor('認識年份'));
    await tester.pumpAndSettle();
    final GridView yearGrid = tester.widget<GridView>(
      find.byKey(const Key('app-date-picker-year-grid')),
    );
    yearGrid.controller!.jumpTo(0);
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('app-date-picker-year-1900')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('app-date-picker-year-1899')),
      findsNothing,
    );
    yearGrid.controller!.jumpTo(yearGrid.controller!.position.maxScrollExtent);
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey<String>('app-date-picker-year-2024')),
    );
    await tester.tap(find.byKey(const Key('app-date-picker-apply')));
    await tester.pumpAndSettle();
    expect(find.text('2024年'), findsOneWidget);

    await tester.tap(find.byTooltip('清除生日'));
    await tester.tap(find.byTooltip('清除認識年份'));
    await tester.pumpAndSettle();
    expect(find.text('12月31日'), findsNothing);
    expect(find.text('2024年'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('人物顏色預設為自動配色，選色後仍可切回自動', (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
    await tester.pumpAndSettle();

    final Finder colorList = find.byKey(const Key('person-color-list'));
    expect(colorList, findsOneWidget);
    expect(
      (tester.widget<ListView>(colorList).childrenDelegate
              as SliverChildBuilderDelegate)
          .estimatedChildCount,
      39,
    );
    final Finder automatic = find.byKey(const Key('person-color-automatic'));
    expect(tester.widget<ChoiceChip>(automatic).selected, isTrue);

    await tester.tap(find.byKey(const Key('person-color-preset-0')));
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(automatic).selected, isFalse);

    final ThemeData theme = appTestTheme();
    final AppColors colors = theme.extension<AppColors>()!;
    final Color accent = kAccentColorPresets.first;
    final (Color expectedBackground, Color expectedForeground) =
        accentColorPair(accent, colors.sectionInset);
    final Finder selectedPreset = find.byKey(
      const Key('person-color-preset-0'),
    );
    final AnimatedContainer colorCircle = tester.widget<AnimatedContainer>(
      find.descendant(
        of: selectedPreset,
        matching: find.byType(AnimatedContainer),
      ),
    );
    final BoxDecoration decoration = colorCircle.decoration as BoxDecoration;
    final Icon checkIcon = tester.widget<Icon>(
      find.descendant(of: selectedPreset, matching: find.byIcon(Icons.check_rounded)),
    );
    expect(decoration.color, expectedBackground);
    expect(decoration.border?.top.color, theme.colorScheme.primary);
    expect(checkIcon.color, expectedForeground);

    await tester.tap(automatic);
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(automatic).selected, isTrue);
    expect(tester.takeException(), isNull);
  });
}
