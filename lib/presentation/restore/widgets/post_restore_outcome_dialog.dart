import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/settings/settings_flow_controller.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/presentation/app_scrollbar.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_shell.dart';

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
        showClose: false,
        icon: Icon(
          outcome.isError
              ? Icons.error_outline_rounded
              : Icons.check_circle_outline_rounded,
          color: theme.colorScheme.onSurface,
        ),
        title: outcome.title,
        content: AppScrollView(
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
            child: Text(dialogContext.l10n.commonActionClose),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(outcome.primaryActionLabel),
          ),
        ],
      );
    },
  );
  return primaryPressed ?? false;
}
