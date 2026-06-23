import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../providers/session_providers.dart';
import '../session_messages.dart';
import '../state/app_session_state.dart';

/// 「重新驗證」動作共用的圖示。
const IconData kSessionRetryVerificationIcon = Icons.verified_user_outlined;

/// 觸發可信裝置重新驗證的標準按鈕。
class SessionRetryVerificationButton extends StatelessWidget {
  const SessionRetryVerificationButton({
    required this.onPressed,
    this.busy = false,
    super.key,
  });

  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: busy ? null : onPressed,
      icon: const Icon(kSessionRetryVerificationIcon),
      label: Text(context.l10n.homeRetryVerification),
    );
  }
}

/// 編輯頁等全螢幕場景在 session 不可用時顯示的鎖定狀態。
class SessionBlockedPane extends ConsumerWidget {
  const SessionBlockedPane({required this.sessionState, super.key});

  final AppSessionState sessionState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    if (sessionState.status == AppLockStatus.unlocking) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(
            sessionState.message ??
                sessionTrustedUnlockInProgressMessage(l10n),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ],
      );
    }

    if (sessionState.status == AppLockStatus.locked) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.lock_outline_rounded,
            size: 48,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.sessionBlockedLockedTitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            sessionState.message?.isNotEmpty == true
                ? sessionState.message!
                : l10n.sessionBlockedLockedSubtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          SessionRetryVerificationButton(
            onPressed: () => unawaited(
              ref.read(appSessionProvider.notifier).unlock(),
            ),
          ),
        ],
      );
    }

    final String message = switch (sessionState.status) {
      AppLockStatus.recoveryRequired =>
        sessionState.message ??
            sessionRecoveryRequiredAfterRestoreMessage(l10n),
      _ =>
        sessionState.message ?? l10n.editorSessionLockedFallback,
    };

    return Text(
      message,
      textAlign: TextAlign.center,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        height: 1.45,
      ),
    );
  }
}
