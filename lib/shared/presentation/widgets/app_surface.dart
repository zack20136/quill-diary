import 'package:flutter/material.dart';

import '../../../app/app_colors.dart';
import '../page_style.dart';

enum AppSurfaceStyle { outlined, elevated, outlinedElevated }

class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.style = AppSurfaceStyle.outlined,
    this.backgroundColor,
    this.radius = PageStyle.radiusCard,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final AppSurfaceStyle style;
  final Color? backgroundColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Material(
      color: backgroundColor ?? context.appColors.sectionCard,
      elevation: switch (style) {
        AppSurfaceStyle.outlined => 0,
        AppSurfaceStyle.elevated || AppSurfaceStyle.outlinedElevated => 1,
      },
      shadowColor: theme.shadowColor.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: switch (style) {
          AppSurfaceStyle.elevated => const BoxDecoration(),
          AppSurfaceStyle.outlined || AppSurfaceStyle.outlinedElevated =>
            BoxDecoration(
                border: Border.fromBorderSide(
                  context.appColors.outlineBorder(),
                ),
                borderRadius: BorderRadius.circular(radius),
              ),
        },
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class AppInsetPanel extends StatelessWidget {
  const AppInsetPanel({
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.backgroundColor,
    this.radius = PageStyle.radiusPanel,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final double radius;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: backgroundColor ?? context.appColors.sectionInset,
      borderRadius: BorderRadius.circular(radius),
    ),
    child: Padding(padding: padding, child: child),
  );
}


class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    required this.title,
    this.description,
    this.icon,
    this.stripeColor,
    this.trailing,
    super.key,
  });

  final String title;
  final String? description;
  final IconData? icon;
  final Color? stripeColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color accent = stripeColor ?? theme.colorScheme.primary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 4,
          height: description == null ? 24 : 42,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 12),
        if (icon != null) ...<Widget>[
          Icon(icon, color: accent, size: 22),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: theme.textTheme.titleMedium),
              if (description != null) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  description!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...<Widget>[
          const SizedBox(width: 12),
          trailing!,
        ],
      ],
    );
  }
}

class AppSectionCard extends StatelessWidget {
  const AppSectionCard({
    required this.title,
    required this.child,
    this.description,
    this.icon,
    this.stripeColor,
    this.trailing,
    this.style = AppSurfaceStyle.outlined,
    this.padding = const EdgeInsets.all(18),
    super.key,
  });

  final String title;
  final Widget child;
  final String? description;
  final IconData? icon;
  final Color? stripeColor;
  final Widget? trailing;
  final AppSurfaceStyle style;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => AppCard(
    style: style,
    padding: padding,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppSectionHeader(
          title: title,
          description: description,
          icon: icon,
          stripeColor: stripeColor,
          trailing: trailing,
        ),
        const SizedBox(height: 16),
        child,
      ],
    ),
  );
}

class AppActionGroup extends StatelessWidget {
  const AppActionGroup({
    required this.actions,
    this.spacing = 10,
    this.inset = true,
    super.key,
  });

  final List<Widget> actions;
  final double spacing;
  final bool inset;

  @override
  Widget build(BuildContext context) {
    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int index = 0; index < actions.length; index++) ...<Widget>[
          if (index > 0) SizedBox(height: spacing),
          actions[index],
        ],
      ],
    );
    return inset ? AppInsetPanel(child: content) : content;
  }
}
