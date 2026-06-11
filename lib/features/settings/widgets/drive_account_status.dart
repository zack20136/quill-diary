import 'package:flutter/material.dart';

import '../../../shared/presentation/page_style.dart';
import '../settings_copy.dart';

/// 精簡的 Google Drive 帳號連線狀態列。
class DriveAccountStatus extends StatelessWidget {
  const DriveAccountStatus({
    required this.isConnected,
    this.accountLabel,
    super.key,
  });

  final bool isConnected;
  final String? accountLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    if (!isConnected) {
      return _DriveAccountStatusCard(
        icon: Icons.cloud_off_outlined,
        iconColor: colorScheme.onSurfaceVariant,
        iconBackground: colorScheme.surfaceContainerHighest,
        child: Text(
          SettingsDriveBackupCopy.disconnectedLabel,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
      );
    }

    final String label = accountLabel?.trim().isNotEmpty == true
        ? accountLabel!.trim()
        : SettingsDriveBackupCopy.fallbackAccountLabel;

    return _DriveAccountStatusCard(
      icon: Icons.cloud_done_outlined,
      iconColor: colorScheme.primary,
      iconBackground: Color.alphaBlend(
        colorScheme.primary.withValues(alpha: 0.08),
        colorScheme.surfaceContainerLow,
      ),
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
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
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
