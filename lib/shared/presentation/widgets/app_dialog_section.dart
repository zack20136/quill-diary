import 'package:material_ui/material_ui.dart';

class AppDialogSection extends StatelessWidget {
  const AppDialogSection({
    required this.child,
    this.padding = EdgeInsets.zero,
    this.outlined = false,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: outlined
            ? BorderSide(color: colors.outlineVariant.withValues(alpha: 0.4))
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    );
  }
}

class AppDialogSummary extends StatelessWidget {
  const AppDialogSummary({
    required this.title,
    this.details = const <String>[],
    this.icon,
    super.key,
  });

  final String title;
  final List<String> details;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppDialogSection(
      outlined: true,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: <Widget>[
          if (icon != null) Icon(icon, color: theme.colorScheme.primary),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: <Widget>[
                Text(title, style: theme.textTheme.titleSmall),
                for (final detail in details)
                  Text(detail, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
