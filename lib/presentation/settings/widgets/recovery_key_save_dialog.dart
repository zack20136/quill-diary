import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:quill_diary/app/app_colors.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/presentation/app_feedback.dart';
import 'package:quill_diary/shared/presentation/app_typography.dart';
import 'package:quill_diary/shared/presentation/page_style.dart';

Future<void> showRecoveryKeySaveDialog(
  BuildContext context, {
  required String title,
  required String recoveryKey,
}) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) =>
        RecoveryKeySaveDialog(title: title, recoveryKey: recoveryKey),
  );
}

class RecoveryKeySaveDialog extends StatelessWidget {
  const RecoveryKeySaveDialog({
    required this.title,
    required this.recoveryKey,
    super.key,
  });

  final String title;
  final String recoveryKey;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: recoveryKey));
    if (!context.mounted) {
      return;
    }
    showAppFeedbackSnackBar(
      context,
      context.l10n.settingsRecoveryKeyCopiedMessage,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final AppColors colors = context.appColors;
    final TextStyle keyStyle = AppTypography.mono(
      theme.textTheme.titleMedium ?? const TextStyle(),
    ).copyWith(fontWeight: FontWeight.w600, letterSpacing: 1.1, height: 1.55);

    return AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              l10n.settingsRecoveryKeySaveDialogHint,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.sectionInset,
                borderRadius: BorderRadius.circular(PageStyle.radiusPanel),
                border: Border.fromBorderSide(colors.outlineBorder()),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
                ),
                child: SelectableText(recoveryKey, style: keyStyle),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton.icon(
          onPressed: () => _copy(context),
          icon: const Icon(Icons.content_copy_rounded, size: 18),
          label: Text(l10n.settingsRecoveryKeyCopyButton),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonActionClose),
        ),
      ],
    );
  }
}
