import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/people/widgets/person_composer_dialog.dart';
import 'package:quill_diary/shared/presentation/widgets/tag_accent_dialog_shell.dart';

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
    expect(find.byType(TagAccentDialogShell), findsOneWidget);
    expect(find.byType(CustomScrollView), findsOneWidget);
    expect(find.text('儲存'), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('關係'), findsWidgets);
    expect(find.byType(Slider), findsOneWidget);
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
      (list.childrenDelegate as SliverChildBuilderDelegate)
          .estimatedChildCount,
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
      tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, '合作夥伴'),
      ).selected,
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
    expect(find.byType(DropdownButtonFormField<int>), findsNWidgets(2));
    expect(find.text('月份'), findsOneWidget);
    expect(find.text('日期'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('寬螢幕表單維持有限寬度', (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 800);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byType(TagAccentDialogShell)).width,
      lessThanOrEqualTo(560),
    );
    expect(find.byType(Divider), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('人物顏色預設為自動配色，選色後仍可切回自動', (
    WidgetTester tester,
  ) async {
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
    final Finder automatic = find.byKey(
      const Key('person-color-automatic'),
    );
    expect(tester.widget<ChoiceChip>(automatic).selected, isTrue);

    await tester.tap(find.byKey(const Key('person-color-preset-0')));
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(automatic).selected, isFalse);

    await tester.tap(automatic);
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(automatic).selected, isTrue);
    expect(tester.takeException(), isNull);
  });
}
