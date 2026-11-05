import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/shared/presentation/app_menu_style.dart';

/// 自訂錨點選單使用的可捲動面板；一般欄位選單沿用 MenuAnchor。
class AppMenuPanel extends StatelessWidget {
  const AppMenuPanel({
    super.key,
    required this.width,
    required this.maxHeight,
    required this.children,
  });

  final double width;
  final double maxHeight;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final style = appMenuStyle(context, width: width);
    return FocusTraversalGroup(
      policy: WidgetOrderTraversalPolicy(),
      child: FocusScope(
        child: Shortcuts(
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
            SingleActivator(LogicalKeyboardKey.arrowDown): NextFocusIntent(),
            SingleActivator(LogicalKeyboardKey.arrowUp): PreviousFocusIntent(),
          },
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: width.clamp(0.0, 200.0),
              maxWidth: width,
              maxHeight: maxHeight,
            ),
            child: IntrinsicWidth(
              child: Material(
                color: style.backgroundColor!.resolve({}),
                shape: style.shape!.resolve({}),
                clipBehavior: Clip.antiAlias,
                child: Semantics(
                  container: true,
                  explicitChildNodes: true,
                  child: Padding(
                    padding: style.padding!.resolve({})!,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: children,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
