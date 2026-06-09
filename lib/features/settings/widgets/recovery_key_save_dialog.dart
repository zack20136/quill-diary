import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../settings_copy.dart';

/// 建立或更新復原金鑰後，顯示金鑰並提供複製操作。
Future<void> showRecoveryKeySaveDialog(
  BuildContext context, {
  required String title,
  required String recoveryKey,
}) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) => RecoveryKeySaveDialog(
      title: title,
      recoveryKey: recoveryKey,
    ),
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
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(SettingsRecoveryKeyCopy.copiedMessage)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle? keyStyle = theme.textTheme.titleMedium?.copyWith(
      fontFamily: 'monospace',
      fontWeight: FontWeight.w600,
      letterSpacing: 0.8,
      height: 1.5,
    );

    return AlertDialog(
      title: Text(title),
      content: SelectableText(
        recoveryKey,
        style: keyStyle,
      ),
      actions: <Widget>[
        TextButton.icon(
          onPressed: () => _copy(context),
          icon: const Icon(Icons.content_copy_rounded, size: 18),
          label: const Text(SettingsRecoveryKeyCopy.copyButton),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(SettingsCopy.actionClose),
        ),
      ],
    );
  }
}
