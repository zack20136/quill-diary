part of 'settings_page.dart';

class _SettingsTopNavSection extends StatelessWidget {
  const _SettingsTopNavSection();

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          cs.surfaceContainerLowest.withValues(alpha: 0.9),
          cs.surface,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.fromBorderSide(PageStyle.outlineSide(cs)),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: _SettingsAppBarNavActions(),
      ),
    );
  }
}

class _SettingsAppBarNavActions extends StatelessWidget {
  const _SettingsAppBarNavActions();

  static const double _gap = 8;
  static const double _horizontalPadding = 16;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Align(
        alignment: Alignment.centerLeft,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              _SettingsAppBarNavButton(
                label: context.l10n.personalizationNavButtonLabel,
                icon: Icons.tune_rounded,
                onPressed: () =>
                    unawaited(context.push(AppRouter.personalizationRoute)),
              ),
              const SizedBox(width: _gap),
              _SettingsAppBarNavButton(
                label: context.l10n.aboutPageTitle,
                icon: Icons.info_outline_rounded,
                onPressed: () => unawaited(context.push(AppRouter.aboutRoute)),
              ),
              const SizedBox(width: _gap),
              _SettingsAppBarNavButton(
                label: context.l10n.settingsSupportNavButtonLabel,
                icon: Icons.favorite_border_rounded,
                onPressed: () =>
                    unawaited(context.push(AppRouter.supportRoute)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsAppBarNavButton extends StatelessWidget {
  const _SettingsAppBarNavButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Material(
      color: Color.alphaBlend(
        cs.surfaceContainerHigh.withValues(alpha: 0.9),
        cs.surface,
      ),
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.9)),
        ),
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: 16, color: cs.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsLegalRow extends StatelessWidget {
  const _SettingsLegalRow({
    required this.title,
    required this.onTap,
    required this.colorScheme,
  });

  final String title;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _sessionSummary(AppLocalizations l10n, AppSessionState sessionState) {
  final String? message = sessionState.message;
  return switch (sessionState.status) {
    AppLockStatus.uninitialized =>
      message ?? l10n.settingsSecurityLockStatusPreparing,
    AppLockStatus.unlocking =>
      message ?? sessionTrustedUnlockInProgressMessage(l10n),
    AppLockStatus.unlocked =>
      message ?? l10n.settingsSecurityLockStatusUnlocked,
    AppLockStatus.locked =>
      message ?? sessionLockedRetryVerificationMessage(l10n),
    AppLockStatus.recoveryRequired =>
      message ?? sessionRecoveryRequiredAfterRestoreMessage(l10n),
    AppLockStatus.fatalError =>
      message ?? l10n.settingsSecurityLockStatusFatalError,
  };
}

IconData _sessionIcon(AppLockStatus status) {
  return switch (status) {
    AppLockStatus.uninitialized => Icons.hourglass_top_rounded,
    AppLockStatus.unlocking => Icons.sync_rounded,
    AppLockStatus.unlocked => Icons.lock_open_rounded,
    AppLockStatus.locked => Icons.lock_outline_rounded,
    AppLockStatus.recoveryRequired => Icons.key_outlined,
    AppLockStatus.fatalError => Icons.error_outline_rounded,
  };
}

AppFeedbackTone _sessionTone(AppLockStatus status) {
  return switch (status) {
    AppLockStatus.uninitialized => AppFeedbackTone.info,
    AppLockStatus.unlocking => AppFeedbackTone.info,
    AppLockStatus.recoveryRequired => AppFeedbackTone.warning,
    AppLockStatus.fatalError => AppFeedbackTone.error,
    _ => AppFeedbackTone.info,
  };
}
