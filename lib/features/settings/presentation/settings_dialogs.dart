import 'package:flutter/material.dart';

import '../../../infrastructure/storage/restore_precheck.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/presentation/app_feedback.dart';
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
  return await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => _RestoreConfirmDialog(
          precheck: precheck,
          driveBackupName: driveBackupName,
        ),
      ) ??
      false;
}

class _RestoreConfirmDialog extends StatefulWidget {
  const _RestoreConfirmDialog({required this.precheck, this.driveBackupName});

  final RestorePrecheck precheck;
  final String? driveBackupName;

  @override
  State<_RestoreConfirmDialog> createState() => _RestoreConfirmDialogState();
}

class _RestoreConfirmDialogState extends State<_RestoreConfirmDialog> {
  bool _overwriteAcknowledged = false;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final RestorePrecheck precheck = widget.precheck;
    final bool requiresOverwriteAck = precheck.willOverwriteLocalVault;
    final bool canConfirm = !requiresOverwriteAck || _overwriteAcknowledged;
    final List<RestorePrecheckSummaryItem> summaryItems =
        buildRestorePrecheckSummaryItems(l10n, precheck);

    return AlertDialog(
      title: Text(
        widget.driveBackupName == null
            ? l10n.settingsRestoreDialogConfirmLocalTitle
            : l10n.settingsRestoreDialogConfirmDriveTitle,
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (widget.driveBackupName != null) ...<Widget>[
              Text(
                l10n.settingsRestoreDialogDriveFileLine(
                  widget.driveBackupName!,
                ),
              ),
              const SizedBox(height: 12),
            ],
            AppFeedbackBanner(
              icon: precheck.willOverwriteLocalVault
                  ? Icons.warning_amber_rounded
                  : Icons.info_outline_rounded,
              message: restoreConfirmHeadline(l10n, precheck),
              tone: precheck.willOverwriteLocalVault
                  ? AppFeedbackTone.warning
                  : AppFeedbackTone.info,
            ),
            const SizedBox(height: 12),
            for (final RestorePrecheckSummaryItem item
                in summaryItems) ...<Widget>[
              _RestorePrecheckSummaryTile(item: item),
              const SizedBox(height: 8),
            ],
            if (requiresOverwriteAck) ...<Widget>[
              const SizedBox(height: 4),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _overwriteAcknowledged,
                onChanged: (bool? value) {
                  setState(() => _overwriteAcknowledged = value ?? false);
                },
                title: Text(
                  l10n.settingsRestoreConfirmOverwriteAcknowledgeCheckbox,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.commonActionCancel),
        ),
        FilledButton(
          onPressed: canConfirm ? () => Navigator.of(context).pop(true) : null,
          child: Text(l10n.settingsActionConfirm),
        ),
      ],
    );
  }
}

class _RestorePrecheckSummaryTile extends StatelessWidget {
  const _RestorePrecheckSummaryTile({required this.item});

  final RestorePrecheckSummaryItem item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Color iconColor = item.isWarning
        ? colorScheme.error
        : colorScheme.primary;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(item.icon, size: 20, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.body,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
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
