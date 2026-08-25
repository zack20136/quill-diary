import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:quill_diary/app/app_colors.dart';
import 'package:quill_diary/app/router.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/infrastructure/database/index_database.dart';
import 'entry_widgets.dart';
import 'package:quill_diary/shared/presentation/page_style.dart';
import 'package:quill_diary/shared/presentation/widgets/app_state_card.dart';
import 'package:quill_diary/presentation/session/widgets/session_locked_pane.dart';
import 'package:quill_diary/application/session/providers/session_providers.dart';
import 'package:quill_diary/application/session/session_messages.dart';
import 'package:quill_diary/application/session/state/app_session_state.dart';
import 'home_scroll_affordance.dart';
import 'home_selection_toolbar.dart';

IconData blockedIconForStatus(AppLockStatus status) {
  return switch (status) {
    AppLockStatus.locked => Icons.lock_outline,
    AppLockStatus.recoveryRequired => Icons.key_outlined,
    AppLockStatus.fatalError => Icons.error_outline,
    _ => Icons.info_outline,
  };
}

bool blockedOffersSettingsNavigation(AppSessionState sessionState) {
  if (sessionState.status == AppLockStatus.recoveryRequired) {
    return true;
  }
  if (sessionState.status == AppLockStatus.locked) {
    return true;
  }
  return sessionState.status == AppLockStatus.unlocked &&
      sessionState.session == null;
}

class HomeBlockedEntriesPane extends StatelessWidget {
  const HomeBlockedEntriesPane({required this.sessionState, super.key});

  final AppSessionState sessionState;

  @override
  Widget build(BuildContext context) {
    return HomeScrollbarGutter(child: _buildBody(context));
  }

  Widget _buildBody(BuildContext context) {
    if (sessionState.status == AppLockStatus.unlocking) {
      return AppStateCard(
        icon: Icons.sync_rounded,
        title: context.l10n.homeUnlockingTitle,
        message:
            sessionState.message ??
            sessionTrustedUnlockInProgressMessage(context.l10n),
      );
    }

    if (sessionState.status == AppLockStatus.locked) {
      final AppLocalizations l10n = context.l10n;
      return AppStateCard(
        icon: Icons.lock_outline,
        title: l10n.sessionBlockedLockedTitle,
        message: sessionState.message?.isNotEmpty == true
            ? sessionState.message!
            : l10n.sessionBlockedLockedSubtitle,
        actionLabel: context.l10n.homeRetryVerification,
        actionIcon: kSessionRetryVerificationIcon,
        onAction: () => unawaited(
          ProviderScope.containerOf(
            context,
          ).read(appSessionProvider.notifier).unlock(),
        ),
      );
    }

    final bool offerSettings = blockedOffersSettingsNavigation(sessionState);
    final AppLocalizations l10n = context.l10n;
    final String blockedTitle = switch (sessionState.status) {
      AppLockStatus.locked => l10n.sessionBlockedLockedTitle,
      AppLockStatus.recoveryRequired =>
        l10n.sessionBlockedRecoveryRequiredTitle,
      AppLockStatus.fatalError => l10n.sessionBlockedFatalErrorTitle,
      _ => l10n.sessionBlockedDefaultTitle,
    };
    final String blockedSubtitle = sessionState.message?.isNotEmpty == true
        ? sessionState.message!
        : switch (sessionState.status) {
            AppLockStatus.locked => l10n.sessionBlockedLockedSubtitle,
            AppLockStatus.recoveryRequired =>
              l10n.sessionBlockedRecoveryRequiredSubtitle,
            AppLockStatus.fatalError => l10n.sessionBlockedFatalErrorSubtitle,
            _ => '',
          };
    return AppStateCard(
      icon: blockedIconForStatus(sessionState.status),
      title: blockedTitle,
      message: blockedSubtitle,
      actionLabel: offerSettings ? context.l10n.homeGoToSettings : null,
      actionIcon: Icons.settings_outlined,
      onAction: offerSettings
          ? () => unawaited(context.push(AppRouter.settingsRoute))
          : null,
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
    this.titleTrail,
    this.expandChild = false,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 14),
    super.key,
  });

  final String title;
  final Widget child;
  final Color? stripeColor;
  final Widget? titleTrail;
  final bool expandChild;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final Color stripe = stripeColor ?? cs.primary;

    return Material(
      color: context.appColors.sectionCard,
      elevation: 1,
      shadowColor: cs.shadow.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(PageStyle.radiusCard),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: expandChild ? MainAxisSize.max : MainAxisSize.min,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 4,
                  height: 22,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    color: stripe,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ?titleTrail,
              ],
            ),
            const SizedBox(height: 14),
            if (expandChild) Expanded(child: child) else child,
          ],
        ),
      ),
    );
  }
}

class HomeDiarySectionCloseButton extends StatelessWidget {
  const HomeDiarySectionCloseButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: context.l10n.homeTooltipDeselectTag,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      iconSize: 16,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      onPressed: onPressed,
      icon: const Icon(Icons.close_rounded),
    );
  }
}

class HomeDiarySliverSection extends StatelessWidget {
  const HomeDiarySliverSection({
    required this.title,
    required this.entries,
    this.stripeColor,
    this.titleTrail,
    super.key,
  });

  final String title;
  final List<EntryIndexRecord> entries;
  final Color? stripeColor;
  final Widget? titleTrail;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final Color stripe = stripeColor ?? cs.primary;
    return DecoratedSliver(
      decoration: BoxDecoration(
        color: context.appColors.sectionCard,
        borderRadius: BorderRadius.circular(PageStyle.radiusCard),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.08),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      sliver: SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        sliver: SliverMainAxisGroup(
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 4,
                    height: 22,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      color: stripe,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  ?titleTrail,
                ],
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 14)),
            HomeCompactEntrySliverList(entries: entries),
          ],
        ),
      ),
    );
  }
}

class HomeHeaderTabButton extends StatelessWidget {
  const HomeHeaderTabButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
    super.key,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

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
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
            decoration: BoxDecoration(
              color: active ? cs.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Center(
              child: ExcludeSemantics(
                child: Icon(icon, size: 20, color: foreground),
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

    return Tooltip(
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
    );
  }
}
