import 'package:quill_diary/application/settings/settings_flow_controller.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/presentation/app_feedback.dart';

void showSettingsFlowFeedback(
  BuildContext context,
  SettingsFlowFeedback? feedback,
) {
  if (!context.mounted || feedback == null) {
    return;
  }
  showAppFeedbackToast(
    context,
    feedback.message,
    tone: switch (feedback.tone) {
      SettingsFlowFeedbackTone.info => AppFeedbackTone.info,
      SettingsFlowFeedbackTone.success => AppFeedbackTone.success,
      SettingsFlowFeedbackTone.warning => AppFeedbackTone.warning,
      SettingsFlowFeedbackTone.error => AppFeedbackTone.error,
    },
  );
}
