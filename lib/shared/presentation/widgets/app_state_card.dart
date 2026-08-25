import 'package:flutter/material.dart';

import 'app_action_button.dart';
import 'app_surface.dart';

/// 呈現空白、錯誤或引導狀態，並可提供單一後續操作的卡片。
class AppStateCard extends StatelessWidget {
  const AppStateCard({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.actionIcon,
    this.actionAppearance = AppActionButtonAppearance.primary,
    this.onAction,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final IconData? actionIcon;
  final AppActionButtonAppearance actionAppearance;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AppCard(
      elevated: true,
      padding: const EdgeInsets.all(34),
      child: Center(
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
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
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
              AppActionButton(
                label: actionLabel!,
                icon: actionIcon ?? Icons.settings_outlined,
                onPressed: onAction,
                appearance: actionAppearance,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
