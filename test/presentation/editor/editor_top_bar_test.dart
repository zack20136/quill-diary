import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/presentation/editor/widgets/editor_top_bar.dart';

import '../../helpers/presentation/editor/editor_test_scope.dart';

void main() {
  testWidgets('窄版工具列維持單列圖示順序且不顯示文字標籤', (tester) async {
    await tester.pumpWidget(
      editorTestApp(viewport: const Size(400, 600), child: _toolbar()),
    );

    expect(
      find.byKey(const Key('editor-action-toolbar-compact')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('editor-action-toolbar-wide')), findsNothing);
    expect(find.text('設定日期'), findsNothing);
    _expectToolbarOrder(tester);
  });

  testWidgets('寬版工具列維持單列順序並顯示圖示與文字', (tester) async {
    await tester.pumpWidget(
      editorTestApp(viewport: const Size(800, 600), child: _toolbar()),
    );

    expect(find.byKey(const Key('editor-action-toolbar-wide')), findsOneWidget);
    expect(
      find.byKey(const Key('editor-action-toolbar-compact')),
      findsNothing,
    );
    expect(find.text('設定日期'), findsOneWidget);
    expect(find.text('新增附件'), findsOneWidget);
    _expectToolbarOrder(tester);
  });

  testWidgets('無內容的儲存按鈕可觸發驗證且使用中性色', (tester) async {
    var invalidSaveCount = 0;
    await tester.pumpWidget(
      editorTestApp(
        child: EditorTopBar(
          previewMode: false,
          saving: false,
          canSaveEntry: false,
          canDelete: false,
          timestampLabel: '2026/08/18 10:00',
          onClose: () {},
          onSave: () {},
          onInvalidSave: () => invalidSaveCount++,
          onDelete: null,
          onEnterEditMode: null,
        ),
      ),
    );

    final Finder save = find.byKey(const Key('editor-top-bar-save'));
    await tester.tap(save);
    expect(invalidSaveCount, 1);
    expect(tester.getSize(save), const Size(44, 44));

    final IconButton button = tester.widget<IconButton>(
      find.descendant(of: save, matching: find.byType(IconButton)),
    );
    final Color? color = button.style?.foregroundColor?.resolve(
      const <WidgetState>{},
    );
    expect(color, Theme.of(tester.element(save)).colorScheme.onSurfaceVariant);
  });

  testWidgets('有效內容使用主色儲存且儲存中顯示進度並防止重複點擊', (tester) async {
    var saveCount = 0;
    Widget buildTopBar({required bool saving}) {
      return editorTestApp(
        child: EditorTopBar(
          previewMode: false,
          saving: saving,
          canSaveEntry: true,
          canDelete: true,
          timestampLabel: '2026/08/18 10:00',
          onClose: () {},
          onSave: () => saveCount++,
          onInvalidSave: () {},
          onDelete: () {},
          onEnterEditMode: null,
        ),
      );
    }

    await tester.pumpWidget(buildTopBar(saving: false));
    final Finder save = find.byKey(const Key('editor-top-bar-save'));
    final IconButton button = tester.widget<IconButton>(
      find.descendant(of: save, matching: find.byType(IconButton)),
    );
    final Color? color = button.style?.foregroundColor?.resolve(
      const <WidgetState>{},
    );
    expect(color, Theme.of(tester.element(save)).colorScheme.primary);
    await tester.tap(save);
    expect(saveCount, 1);

    await tester.pumpWidget(buildTopBar(saving: true));
    expect(find.byKey(const Key('editor-top-bar-saving')), findsOneWidget);
    await tester.tap(save);
    expect(saveCount, 1);
  });
}

EditorActionToolbar _toolbar() {
  return EditorActionToolbar(
    saving: false,
    onPickDate: () {},
    onPickTime: () {},
    onEditTags: () {},
    onPickImage: () {},
    onPickFile: () {},
    onInsertCheckbox: () {},
  );
}

void _expectToolbarOrder(WidgetTester tester) {
  const List<String> actionKeys = <String>[
    'date',
    'time',
    'tags',
    'task',
    'images',
    'attachment',
  ];
  final List<double> positions = actionKeys
      .map(
        (String key) =>
            tester.getTopLeft(find.byKey(Key('editor-toolbar-$key'))).dx,
      )
      .toList();
  expect(positions, orderedEquals(<double>[...positions]..sort()));
}
