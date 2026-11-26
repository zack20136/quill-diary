import 'package:material_ui/material_ui.dart';

/// 共用操作按鈕的視覺層級。
enum AppActionButtonAppearance { primary, tonal, outlined, destructive }

class AppActionButton extends StatelessWidget {
  const AppActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.appearance = AppActionButtonAppearance.outlined,
    this.fullWidth = false,
    this.loading = false,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final AppActionButtonAppearance appearance;
  final bool fullWidth;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final VoidCallback? callback = loading ? null : onPressed;
    final Color loadingColor = switch (appearance) {
      AppActionButtonAppearance.primary => colorScheme.onPrimary,
      AppActionButtonAppearance.tonal => colorScheme.onSecondaryContainer,
      AppActionButtonAppearance.outlined => colorScheme.onSurface,
      AppActionButtonAppearance.destructive => colorScheme.error,
    };
    final Widget iconWidget = loading
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: loadingColor,
            ),
          )
        : Icon(icon);
    final Widget button = switch (appearance) {
      AppActionButtonAppearance.primary => FilledButton.icon(
        onPressed: callback,
        style: loading
            ? FilledButton.styleFrom(
                disabledBackgroundColor: colorScheme.primary,
                disabledForegroundColor: loadingColor,
              )
            : null,
        icon: iconWidget,
        label: Text(label),
      ),
      AppActionButtonAppearance.tonal => FilledButton.tonalIcon(
        onPressed: callback,
        style: loading
            ? FilledButton.styleFrom(
                disabledBackgroundColor: colorScheme.secondaryContainer,
                disabledForegroundColor: loadingColor,
              )
            : null,
        icon: iconWidget,
        label: Text(label),
      ),
      AppActionButtonAppearance.outlined => OutlinedButton.icon(
        onPressed: callback,
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          disabledForegroundColor: loading ? colorScheme.onSurface : null,
          side: BorderSide(color: colorScheme.outline),
        ),
        icon: iconWidget,
        label: Text(label),
      ),
      AppActionButtonAppearance.destructive => OutlinedButton.icon(
        onPressed: callback,
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.error,
          disabledForegroundColor: loading ? colorScheme.error : null,
        ),
        icon: iconWidget,
        label: Text(label),
      ),
    };
    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}
