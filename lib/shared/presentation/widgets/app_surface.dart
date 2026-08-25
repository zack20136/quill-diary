import 'package:flutter/material.dart';

import '../../../app/app_colors.dart';
import '../page_style.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.elevated = false,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Material(
      color: context.appColors.sectionCard,
      elevation: elevated ? 1 : 0,
      shadowColor: theme.shadowColor.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(PageStyle.radiusCard),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: elevated
            ? const BoxDecoration()
            : BoxDecoration(
                border: Border.fromBorderSide(
                  context.appColors.outlineBorder(),
                ),
                borderRadius: BorderRadius.circular(PageStyle.radiusCard),
              ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class AppInsetPanel extends StatelessWidget {
  const AppInsetPanel({
    required this.child,
    this.padding = const EdgeInsets.all(12),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.appColors.sectionInset,
      borderRadius: BorderRadius.circular(PageStyle.radiusPanel),
    ),
    child: Padding(padding: padding, child: child),
  );
}
