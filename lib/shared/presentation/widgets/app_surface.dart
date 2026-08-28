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
    final Widget titleRow = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Icon(icon, color: accent, size: 22),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Text(title, style: theme.textTheme.titleMedium),
        ),
      ],
    );

    return IntrinsicHeight(
      child: Row(
        // trailing 放在外層，避免把標題與藍條一起撐高後垂直錯位。
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            width: 4,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Align(
              // 無說明時與 trailing 垂直置中；有說明時維持頂對齊。
              alignment: description == null
                  ? Alignment.centerLeft
                  : Alignment.topLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  titleRow,
                  if (description != null) ...<Widget>[
                    const SizedBox(height: 4),
                    // 說明從 icon 左緣開始，避免 icon 下方留白。
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
          ),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: 4),
            // 動作與標題垂直置中，避免 TextButton 等比標題矮時貼頂。
            Align(alignment: Alignment.center, child: trailing!),
          ],
        ],
      ),
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
    this.headerGap = 16,
    this.expandChild = false,
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
  final double headerGap;
  final bool expandChild;

  @override
  Widget build(BuildContext context) => AppCard(
    style: style,
    padding: padding,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: expandChild ? MainAxisSize.max : MainAxisSize.min,
      children: <Widget>[
        AppSectionHeader(
          title: title,
          description: description,
          icon: icon,
          stripeColor: stripeColor,
          trailing: trailing,
        ),
        SizedBox(height: headerGap),
        if (expandChild) Expanded(child: child) else child,
      ],
    ),
  );
}

/// Sliver 版區段卡片：與 [AppSectionCard] 共用 stripe header 與 elevation 外觀。
class AppSliverSectionCard extends StatelessWidget {
  const AppSliverSectionCard({
    required this.title,
    required this.slivers,
    this.stripeColor,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 14),
    this.headerGap = 14,
    super.key,
  });

  final String title;
  final List<Widget> slivers;
  final Color? stripeColor;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final double headerGap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return DecoratedSliver(
      decoration: BoxDecoration(
        color: context.appColors.sectionCard,
        borderRadius: BorderRadius.circular(PageStyle.radiusCard),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.08),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      sliver: SliverPadding(
        padding: padding,
        sliver: SliverMainAxisGroup(
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: AppSectionHeader(
                title: title,
                stripeColor: stripeColor,
                trailing: trailing,
              ),
            ),
            SliverToBoxAdapter(child: SizedBox(height: headerGap)),
            ...slivers,
          ],
        ),
      ),
    );
  }
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
