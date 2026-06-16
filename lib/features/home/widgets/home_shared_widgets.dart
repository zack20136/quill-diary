import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/presentation/page_style.dart';
import '../../session/presentation/session_status_copy.dart';
import '../../session/providers/session_providers.dart';
import '../../session/session_messages.dart';
import '../../session/state/app_session_state.dart';
import '../home_copy.dart';
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
  return sessionState.status == AppLockStatus.unlocked && sessionState.session == null;
}

class HomeBlockedEntriesPane extends StatelessWidget {
  const HomeBlockedEntriesPane({required this.sessionState, super.key});

  final AppSessionState sessionState;

  @override
  Widget build(BuildContext context) {
    if (sessionState.status == AppLockStatus.unlocking) {
      return HomeStateCard(
        icon: Icons.sync_rounded,
        title: HomeCopy.unlockingTitle(context),
        message: sessionState.message ?? kTrustedUnlockInProgressMessage,
      );
    }

    if (sessionState.status == AppLockStatus.locked) {
      return HomeStateCard(
        icon: Icons.lock_outline,
        title: blockedTitleForStatus(context.l10n, sessionState.status),
        message: blockedSubtitleForState(context.l10n, sessionState),
        actionLabel: HomeCopy.retryVerification(context),
        onAction: () => unawaited(
          ProviderScope.containerOf(context)
              .read(appSessionProvider.notifier)
              .unlock(),
        ),
      );
    }

    final bool offerSettings = blockedOffersSettingsNavigation(sessionState);
    return HomeStateCard(
      icon: blockedIconForStatus(sessionState.status),
      title: blockedTitleForStatus(context.l10n, sessionState.status),
      message: blockedSubtitleForState(context.l10n, sessionState),
      actionLabel: offerSettings ? HomeCopy.goToSettings(context) : null,
      onAction: offerSettings ? () => unawaited(context.push(AppRouter.settingsRoute)) : null,
    );
  }
}

class HomeSectionShell extends StatelessWidget {
  const HomeSectionShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(PageStyle.radiusCard),
        border: Border.fromBorderSide(PageStyle.outlineSide(cs)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: child,
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
    this.listSection = false,
    this.stripeColor,
    this.titleTrail,
    this.expandChild = false,
    super.key,
  });

  final String title;
  final Widget child;
  final bool listSection;
  final Color? stripeColor;
  final Widget? titleTrail;
  final bool expandChild;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final Color bg = listSection
        ? (theme.brightness == Brightness.light
            ? Colors.white
            : cs.surfaceContainerLowest)
        : cs.surface;
    final Color stripe = stripeColor ?? cs.primary;

    return Material(
      color: bg,
      elevation: 1,
      surfaceTintColor: Colors.transparent,
      shadowColor: cs.shadow.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(PageStyle.radiusCard),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
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

/// 日記列表區塊標題右側的取消篩選按鈕。
class HomeDiarySectionCloseButton extends StatelessWidget {
  const HomeDiarySectionCloseButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: HomeCopy.tooltipDeselectTag(context),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      iconSize: 16,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      onPressed: onPressed,
      icon: const Icon(Icons.close_rounded),
    );
  }
}

/// 總覽式日記列表區塊：外層卡片 + 標題列 + 內文。
class HomeDiaryListSectionCard extends StatelessWidget {
  const HomeDiaryListSectionCard({
    required this.title,
    required this.child,
    this.stripeColor,
    this.titleTrail,
    super.key,
  });

  final String title;
  final Widget child;
  final Color? stripeColor;
  final Widget? titleTrail;

  @override
  Widget build(BuildContext context) {
    return HomeSectionCard(
      listSection: true,
      title: title,
      stripeColor: stripeColor,
      titleTrail: titleTrail,
      child: child,
    );
  }
}

class HomeStateCard extends StatelessWidget {
  const HomeStateCard({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return HomeSectionShell(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.55),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Icon(icon, size: 32, color: theme.colorScheme.primary),
                ),
              ),
              const SizedBox(height: 12),
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              if (actionLabel != null && onAction != null) ...<Widget>[
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.settings_outlined),
                  label: Text(actionLabel!),
                ),
              ],
            ],
          ),
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
    return Tooltip(
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
            child: Icon(icon, size: 20, color: foreground),
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
          child: Center(
            child: Icon(icon, size: 20, color: foregroundColor),
          ),
        ),
      ),
    );
  }
}
