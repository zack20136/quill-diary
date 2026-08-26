import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:quill_diary/app/router.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/application/session/providers/session_providers.dart';
import 'package:quill_diary/application/session/session_messages.dart';
import 'package:quill_diary/application/session/state/app_session_state.dart';
import 'package:quill_diary/shared/presentation/widgets/app_action_button.dart';
import 'package:quill_diary/shared/presentation/widgets/app_state_card.dart';

const IconData kSessionRetryVerificationIcon = Icons.verified_user_outlined;

IconData sessionBlockedIconForStatus(AppLockStatus status) {
  return switch (status) {
    AppLockStatus.locked => Icons.lock_outline,
    AppLockStatus.recoveryRequired => Icons.key_outlined,
    AppLockStatus.fatalError => Icons.error_outline,
    AppLockStatus.unlocking => Icons.sync_rounded,
    _ => Icons.info_outline,
  };
}

bool sessionBlockedOffersSettingsNavigation(AppSessionState sessionState) {
  if (sessionState.status == AppLockStatus.recoveryRequired) {
    return true;
  }
  if (sessionState.status == AppLockStatus.locked) {
    return true;
  }
  return sessionState.status == AppLockStatus.unlocked &&
      sessionState.session == null;
}

/// Session 鎖定／阻擋狀態的共用內容（不含外層卡片）。
class SessionBlockedContent extends StatelessWidget {
  const SessionBlockedContent({
    required this.sessionState,
    this.onUnlock,
    this.onOpenSettings,
    super.key,
  });

  final AppSessionState sessionState;
  final VoidCallback? onUnlock;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SessionBlockedPresentation presentation =
        SessionBlockedPresentation.resolve(
          sessionState: sessionState,
          l10n: l10n,
        );

    VoidCallback? onAction;
    if (presentation.actionKind == SessionBlockedActionKind.retryUnlock) {
      onAction = onUnlock;
    } else if (presentation.actionKind ==
        SessionBlockedActionKind.openSettings) {
      onAction = onOpenSettings;
    }

    return AppStateView(
      icon: presentation.icon,
      title: presentation.title,
      message: presentation.message,
      actionLabel: presentation.actionLabel,
      actionIcon: presentation.actionIcon,
      onAction: onAction,
    );
  }
}

enum SessionBlockedActionKind { none, retryUnlock, openSettings }

class SessionBlockedPresentation {
  const SessionBlockedPresentation({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionKind,
    this.actionLabel,
    this.actionIcon,
  });

  final IconData icon;
  final String title;
  final String message;
  final SessionBlockedActionKind actionKind;
  final String? actionLabel;
  final IconData? actionIcon;

  static SessionBlockedPresentation resolve({
    required AppSessionState sessionState,
    required AppLocalizations l10n,
  }) {
    if (sessionState.status == AppLockStatus.unlocking) {
      return SessionBlockedPresentation(
        icon: sessionBlockedIconForStatus(sessionState.status),
        title: l10n.homeUnlockingTitle,
        message:
            sessionState.message ??
            sessionTrustedUnlockInProgressMessage(l10n),
        actionKind: SessionBlockedActionKind.none,
      );
    }

    if (sessionState.status == AppLockStatus.locked) {
      return SessionBlockedPresentation(
        icon: Icons.lock_outline,
        title: l10n.sessionBlockedLockedTitle,
        message: sessionState.message?.isNotEmpty == true
            ? sessionState.message!
            : l10n.sessionBlockedLockedSubtitle,
        actionKind: SessionBlockedActionKind.retryUnlock,
        actionLabel: l10n.homeRetryVerification,
        actionIcon: kSessionRetryVerificationIcon,
      );
    }

    final bool offerSettings = sessionBlockedOffersSettingsNavigation(
      sessionState,
    );
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
            _ => l10n.editorSessionLockedFallback,
          };

    return SessionBlockedPresentation(
      icon: sessionBlockedIconForStatus(sessionState.status),
      title: blockedTitle,
      message: blockedSubtitle,
      actionKind: offerSettings
          ? SessionBlockedActionKind.openSettings
          : SessionBlockedActionKind.none,
      actionLabel: offerSettings ? l10n.homeGoToSettings : null,
      actionIcon: Icons.settings_outlined,
    );
  }
}

class SessionRetryVerificationButton extends StatelessWidget {
  const SessionRetryVerificationButton({
    required this.onPressed,
    this.busy = false,
    super.key,
  });

  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) => AppActionButton(
    label: context.l10n.homeRetryVerification,
    icon: kSessionRetryVerificationIcon,
    onPressed: onPressed,
    appearance: AppActionButtonAppearance.primary,
    loading: busy,
  );
}

/// 編輯器等 inline 版面使用的 session 阻擋畫面。
class SessionBlockedPane extends ConsumerWidget {
  const SessionBlockedPane({required this.sessionState, super.key});

  final AppSessionState sessionState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SessionBlockedContent(
      sessionState: sessionState,
      onUnlock: () =>
          unawaited(ref.read(appSessionProvider.notifier).unlock()),
      onOpenSettings: () =>
          unawaited(context.push(AppRouter.settingsRoute)),
    );
  }
}
