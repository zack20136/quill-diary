import 'package:flutter/material.dart';

import 'package:quill_diary/application/settings/settings_flow_controller.dart';
import 'package:quill_diary/presentation/session/widgets/session_locked_pane.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_shell.dart';
import 'package:quill_diary/shared/presentation/widgets/app_action_button.dart';

Future<bool> showPostRestoreOutcomeDialog(
  BuildContext context, {
  required SettingsRestorePrompt outcome,
}) async {
  final bool? primaryPressed = await showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      final ThemeData theme = Theme.of(dialogContext);
      return AppDialogShell(
        icon: Icon(
          outcome.isError
              ? Icons.error_outline_rounded
              : Icons.check_circle_outline_rounded,
          color: outcome.isError
              ? theme.colorScheme.error
              : theme.colorScheme.primary,
        ),
        title: outcome.title,
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(outcome.body, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 12),
              Text(outcome.nextStepHint, style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Text(
                outcome.secondaryHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(MaterialLocalizations.of(dialogContext).okButtonLabel),
          ),
          AppActionButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon:
                outcome.primaryAction ==
                    SettingsRestorePrimaryAction.retryVerification
                ? kSessionRetryVerificationIcon
                : Icons.key_outlined,
            label: outcome.primaryActionLabel,
            appearance: AppActionButtonAppearance.primary,
          ),
        ],
      );
    },
  );
  return primaryPressed ?? false;
}
