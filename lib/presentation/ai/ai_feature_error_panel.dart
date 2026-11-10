import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/errors/ai_error_text.dart';
import 'package:quill_diary/domain/ai/ai_failure.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/presentation/app_feedback.dart';

class AiFeatureErrorPanel extends StatelessWidget {
  const AiFeatureErrorPanel({
    super.key,
    required this.message,
    this.onRetry,
    this.retryLabel,
    this.onOpenSettings,
    this.openSettingsLabel,
    this.onDelete,
    this.deleteLabel,
  });

  final String message;
  final VoidCallback? onRetry;
  final String? retryLabel;
  final VoidCallback? onOpenSettings;
  final String? openSettingsLabel;
  final VoidCallback? onDelete;
  final String? deleteLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message),
        if (onRetry != null)
          TextButton(onPressed: onRetry, child: Text(retryLabel!)),
        if (onOpenSettings != null)
          TextButton(
            onPressed: onOpenSettings,
            child: Text(openSettingsLabel!),
          ),
        if (onDelete != null)
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: onDelete,
            child: Text(deleteLabel!),
          ),
      ],
    );
  }
}

void reportAiError(BuildContext context, Object error) {
  showAppFeedbackToast(
    context,
    aiErrorText(
      context.l10n,
      error is AiFailure ? error.code : AiErrorCode.storage,
    ),
    tone: AppFeedbackTone.error,
  );
}
