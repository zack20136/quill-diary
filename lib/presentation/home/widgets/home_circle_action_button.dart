import 'package:material_ui/material_ui.dart';

import 'package:quill_diary/presentation/home/home_layout.dart';

class HomeCircleActionButton extends StatelessWidget {
  const HomeCircleActionButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.emphasized = false,
    super.key,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool usePrimary = emphasized && onPressed != null;
    final Color iconColor = onPressed == null
        ? cs.onSecondaryContainer.withValues(alpha: 0.38)
        : usePrimary
        ? cs.onPrimary
        : cs.onSecondaryContainer;

    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: usePrimary ? cs.primary : cs.secondaryContainer,
          surfaceTintColor: usePrimary ? Colors.transparent : null,
          elevation: 3,
          shadowColor: cs.shadow.withValues(alpha: 0.18),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: HomeLayout.circleActionSize,
              height: HomeLayout.circleActionSize,
              child: Icon(
                icon,
                color: iconColor,
                size: HomeLayout.circleActionIconSize,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
