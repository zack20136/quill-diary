import 'package:flutter/material.dart';

import '../../../infrastructure/storage/vault_transfer_service.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/presentation/display_format.dart';
import '../application/settings_flow_controller.dart';

void showSettingsFlowFeedback(
  BuildContext context,
  SettingsFlowFeedback? feedback,
) {
  if (!context.mounted || feedback == null) {
    return;
  }
  final ColorScheme colorScheme = Theme.of(context).colorScheme;
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        feedback.message,
        style: switch (feedback.tone) {
          SettingsFlowFeedbackTone.error => TextStyle(
            color: colorScheme.onError,
          ),
          SettingsFlowFeedbackTone.success => TextStyle(
            color: colorScheme.onPrimaryContainer,
          ),
          SettingsFlowFeedbackTone.info => null,
        },
      ),
      backgroundColor: switch (feedback.tone) {
        SettingsFlowFeedbackTone.error => colorScheme.error,
        SettingsFlowFeedbackTone.success => colorScheme.primaryContainer,
        SettingsFlowFeedbackTone.info => null,
      },
      behavior: SnackBarBehavior.floating,
    ),
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
