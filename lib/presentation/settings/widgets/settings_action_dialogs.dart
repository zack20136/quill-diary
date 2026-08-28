import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:quill_diary/app/router.dart';
import 'package:quill_diary/application/settings/settings_text.dart';
import 'package:quill_diary/application/settings/vault_finding_presentation.dart';
import 'package:quill_diary/infrastructure/storage/restore_precheck.dart';
import 'package:quill_diary/infrastructure/storage/vault_maintenance_models.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/settings/restore_precheck_presenter.dart';
import 'package:quill_diary/shared/presentation/app_feedback.dart';
import 'package:quill_diary/shared/presentation/display_format.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_shell.dart';
import 'package:quill_diary/shared/presentation/widgets/app_surface.dart';
import '../backup/backup_pick_dialog.dart';
import '../backup/backup_pick_list_item.dart';

Future<bool> showInspectVaultConfirmDialog(
  BuildContext context, {
  VaultRepairSummary? repairSummary,
  VaultRepairSummary? lastRepairSummary,
}) async {
  final AppLocalizations l10n = context.l10n;
  repairSummary ??= lastRepairSummary;
  return await showAppDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => AppDialogShell(
          title: l10n.settingsInspectVaultConfirmTitle,
          content: SizedBox(
            width: double.maxFinite,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.7,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(l10n.settingsInspectVaultConfirmBody),
                    const SizedBox(height: 12),
                    if (repairSummary != null)
                      _PreflightLastRepairCard(summary: repairSummary)
                    else
                      Text(l10n.settingsInspectVaultPreflightNoRepair),
                    if (repairSummary != null &&
                        hasRepairDetailContent(repairSummary)) ...<Widget>[
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => unawaited(
                            showRepairDetailDialog(
                              dialogContext,
                              repairSummary,
                              size: AppDialogSize.compact,
                            ),
                          ),
                          child: Text(l10n.settingsRepairDetailButton),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.commonActionCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.settingsInspectVaultConfirmButton),
            ),
          ],
        ),
      ) ??
      false;
}

Future<void> showRepairDetailDialog(
  BuildContext context,
  VaultRepairSummary? summary, {
  AppDialogSize size = AppDialogSize.standard,
}) {
  final AppLocalizations l10n = context.l10n;
  return showAppDialog<void>(
    size: size,
    context: context,
    builder: (BuildContext dialogContext) => AppDialogShell(
      title: l10n.settingsRepairDetailTitle,
      content: SizedBox(
        width: double.maxFinite,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.7,
          ),
          child: SingleChildScrollView(
            child: _RepairDetailContent(summary: summary),
          ),
        ),
      ),
      actions: <Widget>[
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(l10n.commonActionClose),
        ),
      ],
    ),
  );
}

class _PreflightLastRepairCard extends StatelessWidget {
  const _PreflightLastRepairCard({required this.summary});
  final VaultRepairSummary summary;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String? backup = summary.backupFileName?.trim();
    final int unresolved = countAffectedVaultEntries(summary.findings);
    return _DialogSection(
      title: l10n.settingsInspectVaultPreflightLastRepair,
      children: <Widget>[
        Text(
          l10n.settingsLastRepairLogFinishedAt(
            DisplayFormat.formatDateTimeWithoutWeekday(
              l10n,
              summary.finishedAt,
            ),
          ),
        ),
        Text(l10n.settingsLastRepairLogCheckedEntries(summary.entryCount)),
        if (backup != null && backup.isNotEmpty)
          Text(l10n.settingsLastRepairLogBackupFile(backup)),
        if (unresolved > 0)
          Text(l10n.settingsLastRepairLogUnresolved(unresolved)),
      ],
    );
  }
}

class _DialogSection extends StatelessWidget {
  const _DialogSection({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AppInsetPanel(
      backgroundColor: theme.colorScheme.surfaceContainerLow,
      radius: 12,
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            ...children,
          ],
      ),
    );
  }
}

class _RepairDetailContent extends StatelessWidget {
  const _RepairDetailContent({required this.summary});
  final VaultRepairSummary? summary;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    if (summary == null) return Text(l10n.settingsRepairDetailEmpty);
    final VaultRepairSummary value = summary!;
    final List<Widget> sections = <Widget>[];
    final List<Widget> completed = <Widget>[
      for (final VaultRepairEntryActionLog log in value.entryActionLogs)
        if (log.hasActions) _EntryActionCard(log: log),
    ];
    if (completed.isEmpty && value.hasCompletedActions) {
      completed.add(Text(l10n.settingsRepairDetailAggregateFallback));
      completed.addAll(_aggregateActionLines(l10n, value));
    }
    if (completed.isNotEmpty) {
      sections.add(
        _DialogSection(
          title: l10n.settingsRepairDetailCompleted,
          children: completed,
        ),
      );
    }
    final List<Widget> global = <Widget>[
      if (value.removedOrphanAssets > 0)
        Text(l10n.settingsRepairDetailGlobalOrphans(value.removedOrphanAssets)),
      if (value.purgedBadAssets > 0)
        Text(l10n.settingsRepairDetailGlobalPurgedBad(value.purgedBadAssets)),
      if (value.purgedOldQuarantine > 0)
        Text(
          l10n.settingsRepairDetailPurgedOldQuarantine(
            value.purgedOldQuarantine,
          ),
        ),
    ];
    if (global.isNotEmpty) {
      sections.add(
        _DialogSection(
          title: l10n.settingsRepairDetailGlobal,
          children: global,
        ),
      );
    }
    final Map<String, List<VaultFinding>> groups = groupVaultFindings(
      value.findings,
    );
    if (groups.isNotEmpty) {
      sections.add(
        _DialogSection(
          title: l10n.settingsRepairDetailUnresolved,
          children: <Widget>[
            for (final List<VaultFinding> findings in groups.values)
              VaultFindingSummaryCard(
                presentation: VaultFindingGroupPresentation.fromFindings(
                  l10n,
                  findings,
                ),
                showPlannedActions: false,
              ),
          ],
        ),
      );
    }
    if (sections.isEmpty) return Text(l10n.settingsRepairDetailEmpty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int index = 0; index < sections.length; index++) ...<Widget>[
          if (index > 0) const SizedBox(height: 12),
          sections[index],
        ],
      ],
    );
  }

  List<Widget> _aggregateActionLines(
    AppLocalizations l10n,
    VaultRepairSummary value,
  ) => <Widget>[
    if (value.recoveredAttachments > 0)
      Text(
        l10n.settingsRepairDetailRecoveredAttachments(
          value.recoveredAttachments,
        ),
      ),
    if (value.removedBrokenReferences > 0)
      Text(
        l10n.settingsRepairDetailRemovedMissingAttachments(
          value.removedBrokenReferences,
        ),
      ),
    if (value.purgedBadAssets > 0)
      Text(l10n.settingsRepairDetailGlobalPurgedBad(value.purgedBadAssets)),
    if (value.purgedOldQuarantine > 0)
      Text(
        l10n.settingsRepairDetailPurgedOldQuarantine(value.purgedOldQuarantine),
      ),
    if (value.splitAttachments > 0)
      Text(l10n.settingsRepairDetailSplitAttachments(value.splitAttachments)),
    if (value.relocatedEntries > 0)
      Text(l10n.settingsRepairDetailRelocatedEntries(value.relocatedEntries)),
    if (value.quarantinedCount > 0)
      Text(l10n.settingsRepairDetailQuarantinedItems(value.quarantinedCount)),
  ];
}

class _EntryActionCard extends StatelessWidget {
  const _EntryActionCard({required this.log});
  final VaultRepairEntryActionLog log;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String title = log.title.trim().isEmpty
        ? l10n.settingsInspectVaultUnrecognizedEntry
        : log.title.trim();
    final String date = log.date == null
        ? l10n.settingsInspectVaultEntryDateUnknown
        : DisplayFormat.formatDateOnly(l10n, log.date!);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _DialogSection(
        title: '$title · $date',
        children: <Widget>[
          if (log.recoveredAttachments > 0)
            Text(
              l10n.settingsRepairDetailRecoveredAttachments(
                log.recoveredAttachments,
              ),
            ),
          if (log.removedMissingAttachments > 0)
            Text(
              l10n.settingsRepairDetailRemovedMissingAttachments(
                log.removedMissingAttachments,
              ),
            ),
          if (log.purgedBadAttachments > 0)
            Text(
              l10n.settingsRepairDetailPurgedBadAttachments(
                log.purgedBadAttachments,
              ),
            ),
          if (log.splitAttachments > 0)
            Text(
              l10n.settingsRepairDetailSplitAttachments(log.splitAttachments),
            ),
          if (log.relocatedEntries > 0)
            Text(
              l10n.settingsRepairDetailRelocatedEntries(log.relocatedEntries),
            ),
          if (log.quarantinedItems > 0)
            Text(
              l10n.settingsRepairDetailQuarantinedItems(log.quarantinedItems),
            ),
        ],
      ),
    );
  }
}

Future<bool?> showInspectVaultResultDialog(
  BuildContext context,
  VaultInspectReport report,
) {
  final AppLocalizations l10n = context.l10n;
  final Map<String, List<VaultFinding>> groups = groupVaultFindings(
    report.findings,
  );
  return showAppDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => AppDialogShell(
      icon: Icon(
        groups.isEmpty
            ? Icons.check_circle_outline_rounded
            : Icons.warning_amber_rounded,
        color: groups.isEmpty
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.tertiary,
      ),
      title: l10n.settingsInspectVaultResultTitle,
      content: SizedBox(
        width: double.maxFinite,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.7,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  l10n.settingsInspectVaultResultCheckedEntries(
                    report.entryCount,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  groups.isEmpty
                      ? l10n.settingsInspectVaultResultClean
                      : l10n.settingsInspectVaultResultWarning(groups.length),
                ),
                if (groups.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  for (final MapEntry<String, List<VaultFinding>> entry
                      in groups.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: VaultFindingSummaryCard(
                        presentation:
                            VaultFindingGroupPresentation.fromFindings(
                              l10n,
                              entry.value,
                            ),
                        showPlannedActions: false,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        if (groups.isEmpty)
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonActionClose),
          )
        else ...<Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.settingsInspectVaultHandleLaterButton),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.settingsInspectVaultRepairAfterBackupButton),
          ),
        ],
      ],
    ),
  );
}

Future<void> showRepairVaultResultDialog({
  required BuildContext context,
  required VaultRepairReport report,
  required Future<bool> Function(List<VaultFinding> findings) canSalvage,
  required Future<String?> Function(List<VaultFinding> findings) onSalvage,
  required Future<bool> Function(List<VaultFinding> findings) onDelete,
}) {
  return showAppDialog<void>(
    context: context,
    builder: (_) => _RepairVaultResultDialog(
      report: report,
      hostContext: context,
      canSalvage: canSalvage,
      onSalvage: onSalvage,
      onDelete: onDelete,
    ),
  );
}

class _RepairVaultResultDialog extends StatefulWidget {
  const _RepairVaultResultDialog({
    required this.report,
    required this.hostContext,
    required this.canSalvage,
    required this.onSalvage,
    required this.onDelete,
  });
  final VaultRepairReport report;
  final BuildContext hostContext;
  final Future<bool> Function(List<VaultFinding>) canSalvage;
  final Future<String?> Function(List<VaultFinding>) onSalvage;
  final Future<bool> Function(List<VaultFinding>) onDelete;
  @override
  State<_RepairVaultResultDialog> createState() =>
      _RepairVaultResultDialogState();
}

class _RepairVaultResultDialogState extends State<_RepairVaultResultDialog> {
  late List<MapEntry<String, List<VaultFinding>>> _groups;
  final Map<String, bool> _salvageable = <String, bool>{};
  String? _busyKey;
  String? _feedback;

  @override
  void initState() {
    super.initState();
    _groups = groupVaultFindings(
      widget.report.unresolvedFindings,
    ).entries.toList();
    for (final MapEntry<String, List<VaultFinding>> group in _groups) {
      unawaited(_loadSalvage(group));
    }
  }

  Future<void> _loadSalvage(MapEntry<String, List<VaultFinding>> group) async {
    final bool value = await widget.canSalvage(group.value);
    if (mounted) setState(() => _salvageable[group.key] = value);
  }

  Future<void> _salvage(MapEntry<String, List<VaultFinding>> group) async {
    setState(() => _busyKey = group.key);
    final String? token = await widget.onSalvage(group.value);
    if (!mounted) return;
    if (token != null) {
      Navigator.of(context).pop();
      if (widget.hostContext.mounted) {
        unawaited(
          widget.hostContext.push(AppRouter.editorSalvageLocation(token)),
        );
      }
    } else {
      setState(() {
        _busyKey = null;
        _feedback = context.l10n.settingsRepairVaultResultSalvageFailed;
      });
    }
  }

  Future<void> _delete(MapEntry<String, List<VaultFinding>> group) async {
    final AppLocalizations l10n = context.l10n;
    final bool confirmed = await showAppConfirmDialog(
      context: context,
      title: l10n.settingsAbnormalEntriesDeleteConfirmTitle,
      content: Text(l10n.settingsAbnormalEntriesDeleteConfirmBody),
      cancelLabel: l10n.commonActionCancel,
      confirmLabel: l10n.commonActionDelete,
      confirmStyle: AppConfirmStyle.destructive,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busyKey = group.key);
    final bool success = await widget.onDelete(group.value);
    if (!mounted) return;
    setState(() {
      _busyKey = null;
      if (success) {
        _groups.removeWhere(
          (MapEntry<String, List<VaultFinding>> item) => item.key == group.key,
        );
        _feedback = l10n.settingsAbnormalEntriesDeleteSuccess;
      } else {
        _feedback = l10n.settingsAbnormalEntriesDeleteFailed;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final VaultRepairSummary detailSummary = VaultRepairSummary.fromReport(
      widget.report,
    );
    return AppDialogShell(
      title: l10n.settingsRepairVaultResultTitle,
      content: SizedBox(
        width: double.maxFinite,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .7,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  _groups.isEmpty
                      ? l10n.settingsRepairVaultResultClean
                      : l10n.settingsRepairVaultResultWarning(_groups.length),
                ),
                Text(
                  l10n.settingsRepairVaultResultCheckedEntries(
                    widget.report.entryCount,
                  ),
                ),
                if (_feedback != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(_feedback!),
                ],
                const SizedBox(height: 8),
                if (hasRepairDetailContent(detailSummary))
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => unawaited(
                        showRepairDetailDialog(
                          context,
                          detailSummary,
                          size: AppDialogSize.compact,
                        ),
                      ),
                      child: Text(l10n.settingsRepairDetailButton),
                    ),
                  ),
                const SizedBox(height: 12),
                for (final MapEntry<String, List<VaultFinding>> group
                    in _groups) ...<Widget>[
                  VaultFindingSummaryCard(
                    presentation: VaultFindingGroupPresentation.fromFindings(
                      l10n,
                      group.value,
                      canSalvage: _salvageable[group.key] == true,
                    ),
                    showPlannedActions: false,
                    showActions: true,
                    actionsBusy: _busyKey == group.key,
                    onSalvage: _salvageable[group.key] == true
                        ? () => unawaited(_salvage(group))
                        : null,
                    onDelete: () => unawaited(_delete(group)),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonActionClose),
        ),
      ],
    );
  }
}

class VaultFindingSummaryCard extends StatelessWidget {
  const VaultFindingSummaryCard({
    required this.presentation,
    this.showPlannedActions = true,
    this.showActions = false,
    this.onSalvage,
    this.onDelete,
    this.actionsBusy = false,
    super.key,
  });

  final VaultFindingGroupPresentation presentation;
  final bool showPlannedActions;
  final bool showActions;
  final VoidCallback? onSalvage;
  final VoidCallback? onDelete;
  final bool actionsBusy;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                presentation.title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                presentation.dateLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              for (
                var index = 0;
                index < presentation.problemLabels.length;
                index++
              ) ...<Widget>[
                Text(presentation.problemLabels[index]),
                if (showPlannedActions &&
                    index <
                        presentation.plannedActionLabels.length) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    presentation.plannedActionLabels[index],
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
              ],
              if (showActions &&
                  presentation.findings.any(
                    (VaultFinding finding) =>
                        finding.kind == VaultRepairIssueKind.missingAsset,
                  ))
                Text(l10n.settingsRepairVaultResultMissingAttachment),
              if (showActions) ...<Widget>[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    if (onSalvage != null)
                      FilledButton.tonal(
                        onPressed: actionsBusy ? null : onSalvage,
                        child: Text(
                          l10n.settingsRepairVaultResultSalvageButton,
                        ),
                      ),
                    if (onDelete != null)
                      FilledButton.tonal(
                        onPressed: actionsBusy ? null : onDelete,
                        child: Text(l10n.settingsAbnormalEntriesDeleteButton),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Future<bool> showSettingsDeleteBackupDialog({
  required BuildContext context,
  required String title,
  required String body,
}) async {
  return showAppConfirmDialog(
    context: context,
    title: title,
    content: Text(body),
    cancelLabel: context.l10n.commonActionCancel,
    confirmLabel: context.l10n.commonActionDelete,
    confirmStyle: AppConfirmStyle.destructive,
  );
}

Future<bool> showDisconnectDriveDialog(BuildContext context) async {
  final AppLocalizations l10n = context.l10n;
  return showAppConfirmDialog(
    context: context,
    title: l10n.settingsDriveBackupDisconnectConfirmTitle,
    content: Text(l10n.settingsDriveBackupDisconnectConfirmBody),
    cancelLabel: l10n.commonActionCancel,
    confirmLabel: l10n.settingsDriveBackupDisconnectButton,
    confirmStyle: AppConfirmStyle.destructive,
  );
}

Future<bool> showAbandonCancelCleanupDialog(BuildContext context) async {
  final AppLocalizations l10n = context.l10n;
  return showAppConfirmDialog(
    context: context,
    title: l10n.driveUploadAbandonCancelCleanupConfirmTitle,
    content: Text(l10n.driveUploadAbandonCancelCleanupConfirmBody),
    cancelLabel: l10n.commonActionCancel,
    confirmLabel: l10n.driveUploadAbandonCancelCleanupButton,
    confirmStyle: AppConfirmStyle.destructive,
  );
}

Future<bool> showRotateRecoveryKeyDialog(BuildContext context) async {
  final AppLocalizations l10n = context.l10n;
  return showAppConfirmDialog(
    context: context,
    title: l10n.settingsRecoveryKeyRotateDialogTitle,
    content: Text(l10n.settingsRecoveryKeyRotateDialogBody),
    cancelLabel: l10n.commonActionCancel,
    confirmLabel: l10n.settingsActionUpdate,
  );
}

Future<bool> showRestoreConfirmDialog(
  BuildContext context,
  RestorePrecheck precheck, {
  String? driveBackupName,
}) async {
  return await showAppDialog<bool>(
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

    return AppDialogShell(
      title: widget.driveBackupName == null
          ? l10n.settingsRestoreDialogConfirmLocalTitle
          : l10n.settingsRestoreDialogConfirmDriveTitle,
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
  return DisplayFormat.formatDateTimeWithoutWeekday(l10n, value);
}
