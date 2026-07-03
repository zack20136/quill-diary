import 'package:flutter/material.dart';

import '../../session/presentation/session_locked_pane.dart';
import '../post_restore_outcome.dart';

Future<bool> showPostRestoreOutcomeDialog(
  BuildContext context, {
  required PostRestoreOutcome outcome,
}) async {
  final bool? primaryPressed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      final ThemeData theme = Theme.of(dialogContext);
      return AlertDialog(
        icon: Icon(
          outcome.isError
              ? Icons.error_outline_rounded
              : Icons.check_circle_outline_rounded,
          color: outcome.isError
              ? theme.colorScheme.error
              : theme.colorScheme.primary,
        ),
        title: Text(outcome.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(outcome.body, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 12),
              Text(
                outcome.nextStepHint,
                style: theme.textTheme.titleSmall,
              ),
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
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: Icon(
              outcome.primaryAction ==
                      PostRestorePrimaryAction.retryVerification
                  ? kSessionRetryVerificationIcon
                  : Icons.key_outlined,
            ),
            label: Text(outcome.primaryActionLabel),
          ),
        ],
      );
    },
  );
  return primaryPressed ?? false;
}
