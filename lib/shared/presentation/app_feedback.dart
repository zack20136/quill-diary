import 'package:flutter/material.dart';

import '../../features/home/providers/home_bottom_chrome_provider.dart';
import '../../features/home/home_layout.dart';
import 'page_style.dart';

enum AppFeedbackTone { info, warning, error }

class AppFeedbackColors {
  const AppFeedbackColors({required this.background, required this.foreground});

  final Color background;
  final Color foreground;
}

AppFeedbackColors resolveAppFeedbackColors(
  ColorScheme colorScheme,
  AppFeedbackTone tone,
) {
  return switch (tone) {
    AppFeedbackTone.info => AppFeedbackColors(
      background: colorScheme.primaryContainer,
      foreground: colorScheme.onPrimaryContainer,
    ),
    AppFeedbackTone.warning => AppFeedbackColors(
      background: colorScheme.secondaryContainer,
      foreground: colorScheme.onSecondaryContainer,
    ),
    AppFeedbackTone.error => AppFeedbackColors(
      background: colorScheme.errorContainer,
      foreground: colorScheme.onErrorContainer,
    ),
  };
}

IconData defaultAppFeedbackIcon(AppFeedbackTone tone) {
  return switch (tone) {
    AppFeedbackTone.info => Icons.info_outline_rounded,
    AppFeedbackTone.warning => Icons.warning_amber_rounded,
    AppFeedbackTone.error => Icons.error_outline_rounded,
  };
}

/// 內嵌於頁面的持久提示橫幅。
class AppFeedbackBanner extends StatelessWidget {
  const AppFeedbackBanner({
    required this.message,
    this.icon,
    this.tone = AppFeedbackTone.info,
    super.key,
  });

  final String message;
  final IconData? icon;
  final AppFeedbackTone tone;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppFeedbackColors colors = resolveAppFeedbackColors(
      theme.colorScheme,
      tone,
    );
    final IconData resolvedIcon = icon ?? defaultAppFeedbackIcon(tone);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(PageStyle.radiusPanel),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(resolvedIcon, color: colors.foreground, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.foreground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void showAppFeedbackSnackBar(
  BuildContext context,
  String message, {
  AppFeedbackTone tone = AppFeedbackTone.info,
}) {
  if (!context.mounted) {
    return;
  }
  final ThemeData theme = Theme.of(context);
  final AppFeedbackColors colors = resolveAppFeedbackColors(
    theme.colorScheme,
    tone,
  );
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final HomeBottomChromeSnackBarLift? lift = beginHomeSnackBarLift(context);
  messenger.hideCurrentSnackBar();
  final ScaffoldFeatureController<SnackBar, SnackBarClosedReason> controller =
      messenger.showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(color: colors.foreground),
      ),
      backgroundColor: colors.background,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PageStyle.radiusPanel),
      ),
      margin: const EdgeInsets.fromLTRB(
        HomeLayout.bodyHorizontal,
        0,
        HomeLayout.bodyHorizontal,
        HomeLayout.snackBarBottomPadding,
      ),
    ),
  );
  lift?.bind(controller);
}
