import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/infrastructure/storage/restore_precheck.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/presentation/app_feedback.dart';
import 'package:quill_diary/shared/presentation/app_scrollbar.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_section.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_shell.dart';
import 'package:quill_diary/shared/presentation/widgets/recovery_key_text_field.dart';

Future<String?> showRestoreRecoveryKeyDialog(
  BuildContext context, {
  required RestorePrecheck precheck,
  String? validationError,
}) async {
  return showAppDialog<String>(
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
    final String hint = widget.precheck.backupRecoveryHint;
    final bool olderKey = widget.precheck.recoveryKeyRotatedSinceBackup;

    return AppDialogShell(
      icon: Icon(
        olderKey ? Icons.history_rounded : Icons.key_outlined,
        color: theme.colorScheme.primary,
      ),
      title: olderKey
          ? l10n.settingsRestoreDialogOlderKeyTitle
          : l10n.settingsRestoreDialogRecoveryKeyTitle,
      showClose: false,
      content: AppScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          spacing: 14,
          children: <Widget>[
            if (widget.validationError case final String error)
              AppFeedbackBanner(
                message: error,
                tone: AppFeedbackTone.error,
                outlined: true,
              ),
            AppDialogSummary(
              icon: Icons.key_outlined,
              title: olderKey
                  ? l10n.settingsRestoreDialogSubtitleRotatedBackup
                  : l10n.settingsRestoreDialogKeyInstructions,
              details: [
                if (hint.isNotEmpty) l10n.settingsRestoreKeyEnding(hint),
              ],
            ),
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
