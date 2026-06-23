import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/presentation/app_feedback.dart';
import '../../../shared/presentation/app_typography.dart';

/// 建立或更新復原金鑰後，顯示金鑰並提供複製操作。
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
    final TextStyle keyStyle = AppTypography.mono(
      theme.textTheme.titleMedium ?? const TextStyle(),
    ).copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.8, height: 1.5);

    return AlertDialog(
      title: Text(title),
      content: SelectableText(recoveryKey, style: keyStyle),
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
