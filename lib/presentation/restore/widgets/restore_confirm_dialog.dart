import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/infrastructure/storage/restore_precheck.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/presentation/app_feedback.dart';
import 'package:quill_diary/shared/presentation/app_scrollbar.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_section.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_shell.dart';

Future<bool> showRestoreConfirmDialog(
  BuildContext context,
  RestorePrecheck precheck, {
  required bool requiresRecoveryKey,
  String? driveBackupName,
}) async {
  return await showAppDialog<bool>(
        context: context,
        builder: (BuildContext context) => _RestoreConfirmDialog(
          precheck: precheck,
          requiresRecoveryKey: requiresRecoveryKey,
          driveBackupName: driveBackupName,
        ),
      ) ??
      false;
}

class _RestoreConfirmDialog extends StatefulWidget {
  const _RestoreConfirmDialog({
    required this.precheck,
    required this.requiresRecoveryKey,
    this.driveBackupName,
  });

  final RestorePrecheck precheck;
  final bool requiresRecoveryKey;
  final String? driveBackupName;

  @override
  State<_RestoreConfirmDialog> createState() => _RestoreConfirmDialogState();
}

class _RestoreConfirmDialogState extends State<_RestoreConfirmDialog> {
  bool _overwriteAcknowledged = false;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final RestorePrecheck precheck = widget.precheck;
    final bool overwrites = precheck.willOverwriteLocalVault;
    final bool needsKey = widget.requiresRecoveryKey;
    final bool olderKey = precheck.recoveryKeyRotatedSinceBackup;
    final String hint = precheck.backupRecoveryHint;
    final String? driveBackupName = widget.driveBackupName;

    return AppDialogShell(
      title: driveBackupName == null
          ? l10n.settingsRestoreDialogConfirmLocalTitle
          : l10n.settingsRestoreDialogConfirmDriveTitle,
      content: AppScrollView(
        child: Column(
          spacing: 12,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AppFeedbackBanner(
              message: overwrites
                  ? l10n.settingsRestoreConfirmOverwriteHeadline
                  : l10n.settingsRestoreConfirmFreshVaultHeadline,
              tone: overwrites ? AppFeedbackTone.warning : AppFeedbackTone.info,
            ),
            if (needsKey ||
                precheck.localMetadata != null ||
                driveBackupName != null)
              AppDialogSection(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (driveBackupName != null)
                      _RestoreDetail(
                        icon: Icons.cloud_outlined,
                        title: l10n.settingsRestoreSelectedDriveFile,
                        body: driveBackupName,
                      ),
                    if (needsKey)
                      _RestoreDetail(
                        icon: olderKey
                            ? Icons.history_rounded
                            : Icons.key_outlined,
                        title: olderKey
                            ? l10n.settingsRestorePrecheckRotatedTitle
                            : l10n.settingsRestorePrecheckRecoveryKeyTitle,
                        body: olderKey
                            ? l10n.settingsRestorePrecheckRotatedBody
                            : l10n.settingsRestorePrecheckRecoveryKeyBody,
                      ),
                    if (needsKey && hint.isNotEmpty)
                      _RestoreDetail(
                        icon: Icons.pin_outlined,
                        title: l10n.settingsRestorePrecheckHintTitle,
                        body: l10n.settingsRestoreKeyEnding(hint),
                      ),
                    if (precheck.localMetadata != null)
                      _RestoreDetail(
                        icon: precheck.sameVaultId
                            ? Icons.book_outlined
                            : Icons.devices_outlined,
                        title: precheck.sameVaultId
                            ? l10n.settingsRestorePrecheckSameVaultTitle
                            : l10n.settingsRestorePrecheckOtherVaultTitle,
                        body: precheck.sameVaultId
                            ? (needsKey
                                  ? null
                                  : l10n.settingsRestorePrecheckTrustedUnlockBody)
                            : l10n.settingsRestorePrecheckOtherVaultBody,
                      ),
                  ],
                ),
              ),
            if (precheck.preview.backupId == null)
              AppFeedbackBanner(
                icon: Icons.info_outline_rounded,
                message: l10n.settingsRestoreLegacyBackupNotice,
                tone: AppFeedbackTone.warning,
              ),
            AppDialogSummary(
              icon: Icons.fact_check_outlined,
              title: l10n.settingsRestorePrecheckRebuildIndexTitle,
              details: <String>[l10n.settingsRestorePrecheckRebuildIndexBody],
            ),
            if (overwrites)
              AppConfirmationCheckbox(
                label: l10n.settingsRestoreConfirmOverwriteAcknowledgeCheckbox,
                value: _overwriteAcknowledged,
                onChanged: (bool value) {
                  setState(() => _overwriteAcknowledged = value);
                },
              ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.commonActionCancel),
        ),
        FilledButton(
          onPressed: !overwrites || _overwriteAcknowledged
              ? () => Navigator.of(context).pop(true)
              : null,
          child: Text(
            needsKey
                ? l10n.settingsRestoreEnterKeyNext
                : l10n.settingsActionConfirm,
          ),
        ),
      ],
    );
  }
}

class _RestoreDetail extends StatelessWidget {
  const _RestoreDetail({required this.icon, required this.title, this.body});

  final IconData icon;
  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return ListTile(
      leading: Icon(icon, size: 20, color: colors.primary),
      title: Text(title, style: theme.textTheme.titleSmall),
      subtitle: body == null ? null : Text(body!),
      dense: true,
      minLeadingWidth: 20,
      horizontalTitleGap: 12,
    );
  }
}
