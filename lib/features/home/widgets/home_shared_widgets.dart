import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_colors.dart';
import '../../../app/router.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/presentation/page_style.dart';
import '../../session/presentation/session_locked_pane.dart';
import '../../session/providers/session_providers.dart';
import '../../session/session_messages.dart';
import '../../session/state/app_session_state.dart';
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
    if (sessionState.status == AppLockStatus.unlocking) {
      return HomeStateCard(
        icon: Icons.sync_rounded,
        title: context.l10n.homeUnlockingTitle,
        message:
            sessionState.message ??
            sessionTrustedUnlockInProgressMessage(context.l10n),
      );
    }

    if (sessionState.status == AppLockStatus.locked) {
      final AppLocalizations l10n = context.l10n;
      return HomeStateCard(
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
    return HomeStateCard(
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

class HomeSectionShell extends StatelessWidget {
  const HomeSectionShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Material(
      color: context.appColors.sectionCard,
      elevation: 1,
      shadowColor: cs.shadow.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(PageStyle.radiusCard),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: const EdgeInsets.all(14), child: child),
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
    super.key,
  });

  final String title;
  final Widget child;
  final Color? stripeColor;
  final Widget? titleTrail;
  final bool expandChild;

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
    this.actionIcon,
    this.actionOutlined = false,
    this.onAction,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final IconData? actionIcon;
  final bool actionOutlined;
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
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.55,
                  ),
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
                actionOutlined
                    ? OutlinedButton.icon(
                        onPressed: onAction,
                        icon: Icon(actionIcon ?? kSessionRetryVerificationIcon),
                        label: Text(actionLabel!),
                      )
                    : FilledButton.icon(
                        onPressed: onAction,
                        icon: Icon(actionIcon ?? Icons.settings_outlined),
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
          child: Center(child: Icon(icon, size: 20, color: foreground)),
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
