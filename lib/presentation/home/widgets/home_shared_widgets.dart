import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:quill_diary/app/router.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/infrastructure/database/index_database.dart';
import 'entry_widgets.dart';
import 'package:quill_diary/shared/presentation/page_style.dart';
import 'package:quill_diary/shared/presentation/widgets/app_state_card.dart';
import 'package:quill_diary/shared/presentation/widgets/app_surface.dart';
import 'package:quill_diary/presentation/session/widgets/session_locked_pane.dart';
import 'package:quill_diary/application/session/providers/session_providers.dart';
import 'package:quill_diary/application/session/state/app_session_state.dart';
import 'home_scroll_affordance.dart';
import 'home_selection_toolbar.dart';

class HomeBlockedEntriesPane extends StatelessWidget {
  const HomeBlockedEntriesPane({required this.sessionState, super.key});

  final AppSessionState sessionState;

  @override
  Widget build(BuildContext context) {
    final SessionBlockedPresentation presentation =
        SessionBlockedPresentation.resolve(
          sessionState: sessionState,
          l10n: context.l10n,
        );
    VoidCallback? onAction;
    if (presentation.actionKind == SessionBlockedActionKind.retryUnlock) {
      onAction = () => unawaited(
        ProviderScope.containerOf(
          context,
        ).read(appSessionProvider.notifier).unlock(),
      );
    } else if (presentation.actionKind ==
        SessionBlockedActionKind.openSettings) {
      onAction = () => unawaited(context.push(AppRouter.settingsRoute));
    }

    return HomeScrollbarGutter(
      child: AppStateCard(
        icon: presentation.icon,
        title: presentation.title,
        message: presentation.message,
        actionLabel: presentation.actionLabel,
        actionIcon: presentation.actionIcon,
        onAction: onAction,
      ),
    );
  }
}

class HomePaneEmptyHint extends StatelessWidget {
  const HomePaneEmptyHint({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class HomeSectionCard extends StatelessWidget {
  const HomeSectionCard({
    required this.title,
    required this.child,
    this.stripeColor,
    this.expandChild = false,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 14),
    super.key,
  });

  final String title;
  final Widget child;
  final Color? stripeColor;
  final bool expandChild;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: title,
      stripeColor: stripeColor,
      expandChild: expandChild,
      padding: padding,
      headerGap: 14,
      style: AppSurfaceStyle.elevated,
      child: child,
    );
  }
}

class HomeDiarySliverSection extends StatelessWidget {
  const HomeDiarySliverSection({
    required this.title,
    required this.entries,
    this.stripeColor,
    super.key,
  });

  final String title;
  final List<EntryIndexRecord> entries;
  final Color? stripeColor;

  @override
  Widget build(BuildContext context) {
    return AppSliverSectionCard(
      title: title,
      stripeColor: stripeColor,
      slivers: <Widget>[
        HomeCompactEntrySliverList(entries: entries),
      ],
    );
  }
}

class HomeHeaderTabButton extends StatelessWidget {
  const HomeHeaderTabButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
    this.showLabel = false,
    super.key,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color foreground = active ? cs.onPrimary : cs.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: Tooltip(
        message: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(PageStyle.radiusPanel),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            height: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: showLabel ? 12 : 3,
              vertical: 3,
            ),
            decoration: BoxDecoration(
              color: active ? cs.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Center(
              child: ExcludeSemantics(
                child: showLabel
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(icon, size: 18, color: foreground),
                          const SizedBox(width: 6),
                          Text(
                            label,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: foreground,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      )
                    : Icon(icon, size: 20, color: foreground),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomeHeaderIconButton extends StatelessWidget {
  const HomeHeaderIconButton({
    required this.tooltip,
    required this.icon,
    this.onPressed,
    super.key,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color foregroundColor = cs.onSurfaceVariant;

    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(PageStyle.radiusPanel),
          child: SizedBox(
            width: kHomeSearchRowControlHeight,
            height: kHomeSearchRowControlHeight,
            child: Center(child: Icon(icon, size: 20, color: foregroundColor)),
          ),
        ),
      ),
    );
  }
}
