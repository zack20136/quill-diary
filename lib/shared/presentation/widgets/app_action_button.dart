import 'package:flutter/material.dart';

/// 共用操作按鈕的視覺層級。
enum AppActionButtonAppearance { primary, tonal, outlined, destructive }

/// 以一致的外觀與 loading 狀態呈現可點擊操作。
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
    final bool isDark = colorScheme.brightness == Brightness.dark;
    final ({Color background, Color foreground}) primaryColors = isDark
        ? (
            background: colorScheme.primaryContainer,
            foreground: colorScheme.onPrimaryContainer,
          )
        : (background: colorScheme.primary, foreground: colorScheme.onPrimary);
    final ({Color background, Color foreground}) tonalColors = isDark
        ? (
            background: colorScheme.surfaceContainerHighest,
            foreground: colorScheme.onSurface,
          )
        : (
            background: colorScheme.secondaryContainer,
            foreground: colorScheme.onSecondaryContainer,
          );
    final VoidCallback? callback = loading ? null : onPressed;
    final Color loadingColor = switch (appearance) {
      AppActionButtonAppearance.primary => primaryColors.foreground,
      AppActionButtonAppearance.tonal => tonalColors.foreground,
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
        style: FilledButton.styleFrom(
          backgroundColor: primaryColors.background,
          foregroundColor: primaryColors.foreground,
          disabledBackgroundColor: loading ? primaryColors.background : null,
          disabledForegroundColor: loading ? primaryColors.foreground : null,
        ),
        icon: iconWidget,
        label: Text(label),
      ),
      AppActionButtonAppearance.tonal => FilledButton.icon(
        onPressed: callback,
        style: FilledButton.styleFrom(
          backgroundColor: tonalColors.background,
          foregroundColor: tonalColors.foreground,
          disabledBackgroundColor: loading ? tonalColors.background : null,
          disabledForegroundColor: loading ? tonalColors.foreground : null,
          side: isDark
              ? BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.72),
                )
              : null,
        ),
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
