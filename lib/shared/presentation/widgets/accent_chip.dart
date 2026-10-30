import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/shared/presentation/accent_visual.dart';
import 'package:quill_diary/shared/presentation/app_colors.dart';

class AccentChip extends StatelessWidget {
  const AccentChip({
    required this.label,
    required this.background,
    required this.foreground,
    this.compact = false,
    this.bordered,
    super.key,
  });

  AccentChip.pair({
    required this.label,
    required (Color, Color) pair,
    this.compact = false,
    this.bordered,
    super.key,
  }) : background = pair.$1,
       foreground = pair.$2;

  final String label;
  final Color background;
  final Color foreground;
  final bool compact;
  final bool? bordered;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AppColors colors = context.appColors;
    final BorderSide? borderSide = bordered == false
        ? null
        : accentChipBorderSide(
            colors,
            scheme,
            background,
            foreground,
            width: 0.9,
          );
    final TextStyle? textStyle =
        (compact ? theme.textTheme.labelSmall : theme.textTheme.labelMedium)
            ?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
              height: compact ? null : 1.15,
            );

    final Widget labelWidget = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: textStyle,
    );

    final Widget child = compact
        ? ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: (MediaQuery.sizeOf(context).width * 0.38).clamp(
                120,
                260,
              ),
            ),
            child: labelWidget,
          )
        : labelWidget;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: background,
        border: borderSide == null ? null : Border.fromBorderSide(borderSide),
      ),
      child: child,
    );
  }
}
