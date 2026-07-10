import 'package:quill_diary/infrastructure/storage/vault_transfer_service.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/presentation/app_feedback.dart';
import 'package:quill_diary/shared/presentation/display_format.dart';
import 'package:quill_diary/application/settings/settings_flow_controller.dart';

void showSettingsFlowFeedback(
  BuildContext context,
  SettingsFlowFeedback? feedback,
) {
  if (!context.mounted || feedback == null) {
    return;
  }
  showAppFeedbackSnackBar(
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

SettingsFlowFeedback? backupPersistFeedback(
  BuildContext context,
  BackupPersistResult result, {
  required String Function(String savedPath) onSuccess,
  String Function(String message)? inspectFailedMessage,
}) {
  switch (result.status) {
    case BackupPersistStatus.success:
      final String? savedPath = result.savedPath;
      if (savedPath == null) {
        return null;
      }
      return SettingsFlowFeedback(
        onSuccess(DisplayFormat.formatSavedFileNameForDisplay(savedPath)),
        tone: SettingsFlowFeedbackTone.success,
      );
    case BackupPersistStatus.inspectFailed:
      final String Function(String message) formatInspectFailed =
          inspectFailedMessage ??
          (String message) =>
              context.l10n.settingsLocalBackupBackupInspectFailed(message);
      return SettingsFlowFeedback(
        formatInspectFailed(result.message),
        tone: SettingsFlowFeedbackTone.error,
      );
    case BackupPersistStatus.cancelled:
      return null;
  }
}
