import 'package:flutter/material.dart';

import '../../../infrastructure/storage/restore_precheck.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/presentation/display_format.dart';
import '../backup/backup_pick_dialog.dart';
import '../backup/backup_pick_list_item.dart';
import '../settings_messages.dart';

Future<bool> showSettingsDeleteBackupDialog({
  required BuildContext context,
  required String title,
  required String body,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(context.l10n.commonActionCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(context.l10n.commonActionDelete),
            ),
          ],
        ),
      ) ??
      false;
}

Future<bool> showDisconnectDriveDialog(BuildContext context) async {
  final AppLocalizations l10n = context.l10n;
  return await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: Text(l10n.settingsDriveBackupDisconnectConfirmTitle),
          content: Text(l10n.settingsDriveBackupDisconnectConfirmBody),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.commonActionCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.settingsDriveBackupDisconnectButton),
            ),
          ],
        ),
      ) ??
      false;
}

Future<bool> showRotateRecoveryKeyDialog(BuildContext context) async {
  final AppLocalizations l10n = context.l10n;
  return await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: Text(l10n.settingsRecoveryKeyRotateDialogTitle),
          content: Text(l10n.settingsRecoveryKeyRotateDialogBody),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.commonActionCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.settingsActionUpdate),
            ),
          ],
        ),
      ) ??
      false;
}

Future<bool> showRestoreConfirmDialog(
  BuildContext context,
  RestorePrecheck precheck, {
  String? driveBackupName,
}) async {
  final AppLocalizations l10n = context.l10n;
  final List<String> bullets = buildRestoreConfirmBulletPoints(l10n, precheck);
  return await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: Text(
              driveBackupName == null
                  ? l10n.settingsRestoreDialogConfirmLocalTitle
                  : l10n.settingsRestoreDialogConfirmDriveTitle,
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (driveBackupName != null) ...<Widget>[
                    Text(l10n.settingsRestoreDialogDriveFileLine(driveBackupName)),
                    const SizedBox(height: 12),
                  ],
                  for (final String bullet in bullets)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text('• '),
                          Expanded(child: Text(bullet)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.commonActionCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n.settingsActionConfirm),
              ),
            ],
          );
        },
      ) ??
      false;
}

Future<BackupPickListItem?> showSettingsBackupPickerDialog({
  required BuildContext context,
  required String title,
  required String emptyMessage,
  required String deleteTooltip,
  required bool actionsDisabled,
  required Future<bool> Function(String fileName) confirmDelete,
  required List<BackupPickListItem> items,
}) {
  return showBackupPickDialog(
    context: context,
    title: title,
    emptyMessage: emptyMessage,
    deleteTooltip: deleteTooltip,
    actionsDisabled: actionsDisabled,
    confirmDelete: confirmDelete,
    items: items,
  );
}

String formatDriveBackupTime(AppLocalizations l10n, DateTime? value) {
  if (value == null) {
    return l10n.settingsDriveBackupUnknownCreatedTime;
  }
  return DisplayFormat.formatDateTime(l10n, value);
}
