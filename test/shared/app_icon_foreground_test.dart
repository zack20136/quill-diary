import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/shared/presentation/widgets/app_action_button.dart';

import '../helpers/shared/widget_test_app.dart';

void main() {
  Color? paintedColor(WidgetTester tester, Finder finder) {
    final element = tester.element(finder);
    final widget = element.widget;
    if (widget is Icon) {
      final theme = IconTheme.of(element);
      final color = widget.color ?? theme.color;
      return color?.withValues(alpha: color.a * (theme.opacity ?? 1));
    }
    return (widget as Text).style?.color ??
        DefaultTextStyle.of(element).style.color;
  }

  for (final brightness in Brightness.values) {
    for (final enabled in [true, false]) {
      testWidgets('$brightness ${enabled ? '可用' : '停用'}按鈕的圖示與文字採用相同前景色', (
        tester,
      ) async {
        await tester.pumpWidget(
          widgetTestApp(
            brightness: brightness,
            child: Builder(
              builder: (context) {
                final foreground = Theme.of(context).colorScheme.error;
                final VoidCallback? action = enabled ? () {} : null;
                return Wrap(
                  children: [
                    TextButton.icon(
                      key: const ValueKey<Object>('text'),
                      onPressed: action,
                      style: TextButton.styleFrom(foregroundColor: foreground),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('刪除'),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey<Object>('outlined'),
                      onPressed: action,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: foreground,
                      ),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('刪除'),
                    ),
                    FilledButton.icon(
                      key: const ValueKey<Object>('filled'),
                      onPressed: action,
                      style: FilledButton.styleFrom(
                        foregroundColor: foreground,
                      ),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('刪除'),
                    ),
                    ElevatedButton.icon(
                      key: const ValueKey<Object>('elevated'),
                      onPressed: action,
                      style: ElevatedButton.styleFrom(
                        foregroundColor: foreground,
                      ),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('刪除'),
                    ),
                    for (final appearance in AppActionButtonAppearance.values)
                      AppActionButton(
                        key: ValueKey<Object>(appearance),
                        label: '操作',
                        icon: Icons.delete_outline,
                        onPressed: action,
                        appearance: appearance,
                      ),
                  ],
                );
              },
            ),
          ),
        );
        for (final key in <Object>[
          'text',
          'outlined',
          'filled',
          'elevated',
          ...AppActionButtonAppearance.values,
        ]) {
          final button = find.byKey(ValueKey<Object>(key));
          final icon = find.descendant(of: button, matching: find.byType(Icon));
          final text = find.descendant(of: button, matching: find.byType(Text));
          expect(
            paintedColor(tester, icon),
            paintedColor(tester, text),
            reason: '$key',
          );
        }
      });
    }
    testWidgets('$brightness 清單列與收合標題的圖示跟隨標題文字', (tester) async {
      await tester.pumpWidget(
        widgetTestApp(
          brightness: brightness,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final selected in [true, false])
                ListTile(
                  key: ValueKey<Object>(selected),
                  selected: selected,
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('設定'),
                ),
              const ExpansionTile(
                key: ValueKey<Object>('expand'),
                leading: Icon(Icons.settings_outlined),
                title: Text('設定'),
                children: [Text('內容')],
              ),
            ],
          ),
        ),
      );
      for (final key in <Object>[true, false, 'expand']) {
        final row = find.byKey(ValueKey<Object>(key));
        expect(
          paintedColor(
            tester,
            find.descendant(
              of: row,
              matching: find.byIcon(Icons.settings_outlined),
            ),
          ),
          paintedColor(
            tester,
            find.descendant(of: row, matching: find.text('設定')),
          ),
        );
      }
      await tester.tap(find.byKey(const ValueKey<Object>('expand')));
      await tester.pumpAndSettle();
      final row = find.byKey(const ValueKey<Object>('expand'));
      expect(
        paintedColor(
          tester,
          find.descendant(
            of: row,
            matching: find.byIcon(Icons.settings_outlined),
          ),
        ),
        paintedColor(
          tester,
          find.descendant(of: row, matching: find.text('設定')),
        ),
      );
    });
  }
}
