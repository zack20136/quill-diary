import 'package:flutter/material.dart';

import '../../../infrastructure/storage/restore_precheck.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/presentation/widgets/recovery_key_text_field.dart';
import '../../settings/settings_messages.dart';

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
  State<_RestoreRecoveryKeyDialog> createState() =>
      _RestoreRecoveryKeyDialogState();
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
    final AppLocalizations l10n = context.l10n;
    final String key = _controller.text.trim();
    if (key.isEmpty) {
      setState(
        () => _errorText = l10n.settingsRestoreDialogRecoveryKeyEmptyError,
      );
      return;
    }
    Navigator.of(context).pop(key);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String? hint = widget.precheck.backupRecoveryHint;

    return AlertDialog(
      title: Text(l10n.settingsRestoreDialogRecoveryKeyTitle),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              restoreRecoveryKeyDialogSubtitle(l10n, widget.precheck),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.settingsRestoreDialogRecoveryKeyVerifyNote,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (hint != null && hint.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                settingsRecoveryKeyHintLine(l10n, hint),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 16),
            RecoveryKeyTextField(
              controller: _controller,
              autofocus: true,
              errorText: _errorText,
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonActionCancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(l10n.settingsActionVerifyAndRestore),
        ),
      ],
    );
  }
}
