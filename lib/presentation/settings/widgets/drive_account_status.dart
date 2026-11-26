import 'package:material_ui/material_ui.dart';

import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/presentation/app_colors.dart';
import 'package:quill_diary/shared/presentation/app_feedback.dart';
import 'package:quill_diary/shared/presentation/page_style.dart';

class DriveAccountStatus extends StatelessWidget {
  const DriveAccountStatus({
    required this.isConnected,
    this.accountLabel,
    this.disconnectedLabel,
    this.disconnectedIcon = Icons.cloud_off_outlined,
    super.key,
  });

  final bool isConnected;
  final String? accountLabel;
  final String? disconnectedLabel;
  final IconData disconnectedIcon;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    if (!isConnected) {
      final bool isErrorState = disconnectedLabel != null;
      final colors = resolveAppFeedbackColors(
        context,
        isErrorState ? AppFeedbackTone.error : AppFeedbackTone.warning,
      );
      return _DriveAccountStatusCard(
        icon: disconnectedIcon,
        iconColor: colors.foreground,
        iconBackground: colors.background,
        child: Text(
          disconnectedLabel ?? l10n.settingsDriveBackupDisconnectedLabel,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isErrorState
                ? colors.foreground
                : theme.colorScheme.onSurfaceVariant,
            height: 1.4,
            fontWeight: isErrorState ? FontWeight.w600 : null,
          ),
        ),
      );
    }

    final String label = accountLabel?.trim().isNotEmpty == true
        ? accountLabel!.trim()
        : l10n.settingsDriveBackupFallbackAccountLabel;

    final colors = resolveAppFeedbackColors(context, AppFeedbackTone.success);
    return _DriveAccountStatusCard(
      icon: Icons.cloud_done_outlined,
      iconColor: colors.foreground,
      iconBackground: colors.background,
      child: Text(
        label,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
          height: 1.3,
        ),
      ),
    );
  }
}

class _DriveAccountStatusCard extends StatelessWidget {
  const _DriveAccountStatusCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.child,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.appColors.sectionCard,
        borderRadius: BorderRadius.circular(PageStyle.radiusPanel),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(icon, color: iconColor, size: 20),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
