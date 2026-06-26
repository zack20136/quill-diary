import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../app/app_colors.dart';

/// 標籤強調色 Composer / 色輪對話框共用的 gradient 外殼與標題列。
class TagAccentDialogShell extends StatelessWidget {
  const TagAccentDialogShell({
    required this.icon,
    required this.title,
    this.footer,
    this.onClose,
    this.closeEnabled = true,
    required this.child,
    super.key,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final Widget? footer;
  final VoidCallback? onClose;
  final bool closeEnabled;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final AppColors appColors = context.appColors;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 384),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                appColors.accentDialogGradientStart,
                appColors.accentDialogGradientEnd,
              ],
            ),
            border: Border.all(color: appColors.accentDialogBorder),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: theme.shadowColor.withValues(alpha: 0.12),
                blurRadius: 28,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(icon, color: cs.primary, size: 26),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: context.l10n.commonCloseTooltip,
                      visualDensity: VisualDensity.compact,
                      onPressed: closeEnabled ? onClose : null,
                      icon: Icon(
                        Icons.close_rounded,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                child,
                ?footer,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
