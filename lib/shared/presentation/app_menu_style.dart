import 'package:material_ui/material_ui.dart';

MenuStyle appMenuStyle(BuildContext context, {required double width}) {
  final theme = Theme.of(context);
  final colors = theme.colorScheme;
  return MenuStyle(
    backgroundColor: WidgetStatePropertyAll(
      theme.brightness == Brightness.dark
          ? colors.surfaceContainer
          : colors.surfaceContainerLow,
    ),
    surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
    shadowColor: const WidgetStatePropertyAll(Colors.transparent),
    elevation: const WidgetStatePropertyAll(0),
    minimumSize: WidgetStatePropertyAll(Size(width, 0)),
    maximumSize: WidgetStatePropertyAll(Size(width, 320)),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant),
      ),
    ),
    padding: const WidgetStatePropertyAll(EdgeInsets.all(6)),
  );
}

ButtonStyle appMenuItemStyle(BuildContext context, {bool selected = false}) =>
    ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? Theme.of(context).disabledColor
            : Theme.of(context).colorScheme.onSurface,
      ),
      backgroundColor: WidgetStatePropertyAll(
        selected
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : Colors.transparent,
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
