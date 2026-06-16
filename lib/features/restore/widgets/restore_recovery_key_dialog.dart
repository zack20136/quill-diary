import 'package:flutter/material.dart';

import '../../settings/settings_copy.dart';
import '../../../infrastructure/storage/restore_precheck.dart';

/// 還原備份前收集建立該備份時保存的復原金鑰。
Future<String?> showRestoreRecoveryKeyDialog(
  BuildContext context, {
  required RestorePrecheck precheck,
  String? validationError,
}) async {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) => _RestoreRecoveryKeyDialog(
      precheck: precheck,
      validationError: validationError,
    ),
  );
}

class _RestoreRecoveryKeyDialog extends StatefulWidget {
  const _RestoreRecoveryKeyDialog({
    required this.precheck,
    this.validationError,
  });

  final RestorePrecheck precheck;
  final String? validationError;

  @override
  State<_RestoreRecoveryKeyDialog> createState() => _RestoreRecoveryKeyDialogState();
}

class _RestoreRecoveryKeyDialogState extends State<_RestoreRecoveryKeyDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _errorText = widget.validationError;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final String key = _controller.text.trim();
    if (key.isEmpty) {
      setState(() => _errorText = SettingsRestoreDialogCopy.recoveryKeyEmptyError);
      return;
    }
    Navigator.of(context).pop(key);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? hint = widget.precheck.backupRecoveryHint;

    return AlertDialog(
      title: const Text(SettingsRestoreDialogCopy.recoveryKeyDialogTitle),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              restoreRecoveryKeyDialogSubtitle(widget.precheck),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              SettingsRestoreDialogCopy.recoveryKeyVerifyNote,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (hint != null && hint.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                SettingsCopy.recoveryKeyHintLine(hint),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: SettingsCopy.recoveryKeyFieldLabel,
                hintText: SettingsCopy.recoveryKeyFieldHint,
                errorText: _errorText,
              ),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(SettingsCopy.actionCancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text(SettingsCopy.actionVerifyAndRestore),
        ),
      ],
    );
  }
}
