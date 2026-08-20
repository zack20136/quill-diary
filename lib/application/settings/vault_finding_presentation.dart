import 'package:quill_diary/application/settings/settings_text.dart';
import 'package:quill_diary/infrastructure/storage/vault_maintenance_models.dart';
import 'package:quill_diary/l10n/l10n.dart';

/// 將 [VaultFinding] 轉成 UI 可直接顯示的文案；不推測解決狀態。
class VaultFindingPresentation {
  const VaultFindingPresentation({
    required this.title,
    required this.dateLabel,
    required this.problemLabel,
    required this.plannedActionLabel,
    required this.manualGuide,
    required this.canOpenEntry,
    required this.canSalvage,
    required this.entryId,
    required this.attachmentLabel,
  });

  final String title;
  final String dateLabel;
  final String problemLabel;
  final String plannedActionLabel;
  final String manualGuide;
  final bool canOpenEntry;
  final bool canSalvage;
  final String? entryId;
  final String? attachmentLabel;

  factory VaultFindingPresentation.fromFinding(
    AppLocalizations l10n,
    VaultFinding finding, {
    String? backupFileName,
    bool canSalvage = false,
  }) {
    final String? attachmentLabel = switch (finding.attachmentCategory) {
      VaultAttachmentCategory.photo =>
        l10n.settingsAbnormalEntriesAttachmentPhoto,
      VaultAttachmentCategory.file =>
        l10n.settingsAbnormalEntriesAttachmentFile,
      VaultAttachmentCategory.unknown => null,
    };
    return VaultFindingPresentation(
      title: settingsFindingTitle(l10n, finding),
      dateLabel: settingsFindingDateLabel(l10n, finding),
      problemLabel: settingsRepairIssueLabel(l10n, finding.kind),
      plannedActionLabel: settingsPlannedActionLabel(
        l10n,
        finding.plannedAction,
      ),
      manualGuide: settingsManualGuide(
        l10n,
        finding.manualAction,
        backupFileName: backupFileName,
      ),
      canOpenEntry: finding.canOpenEntry,
      canSalvage: canSalvage,
      entryId: finding.entryId,
      attachmentLabel: attachmentLabel,
    );
  }
}

/// 同篇日記的多個 finding 合併呈現。
class VaultFindingGroupPresentation {
  const VaultFindingGroupPresentation({
    required this.title,
    required this.dateLabel,
    required this.problemLabels,
    required this.plannedActionLabels,
    required this.manualGuides,
    required this.canOpenEntry,
    required this.canSalvage,
    required this.entryId,
    required this.findings,
  });

  final String title;
  final String dateLabel;
  final List<String> problemLabels;
  final List<String> plannedActionLabels;
  final List<String> manualGuides;
  final bool canOpenEntry;
  final bool canSalvage;
  final String? entryId;
  final List<VaultFinding> findings;

  factory VaultFindingGroupPresentation.fromFindings(
    AppLocalizations l10n,
    List<VaultFinding> findings, {
    String? backupFileName,
    bool canSalvage = false,
  }) {
    assert(findings.isNotEmpty);
    final List<VaultFindingPresentation> items = <VaultFindingPresentation>[
      for (final VaultFinding finding in findings)
        VaultFindingPresentation.fromFinding(
          l10n,
          finding,
          backupFileName: backupFileName,
          canSalvage: canSalvage,
        ),
    ];
    final VaultFindingPresentation primary = items.first;
    final List<String> problems = <String>[];
    final List<String> actions = <String>[];
    final List<String> guides = <String>[];
    for (final VaultFindingPresentation item in items) {
      if (!problems.contains(item.problemLabel)) {
        problems.add(item.problemLabel);
      }
      if (!actions.contains(item.plannedActionLabel)) {
        actions.add(item.plannedActionLabel);
      }
      if (item.manualGuide.isNotEmpty && !guides.contains(item.manualGuide)) {
        guides.add(item.manualGuide);
      }
    }
    final String? entryId = findings
        .map((VaultFinding item) => item.entryId?.trim())
        .whereType<String>()
        .where((String id) => id.isNotEmpty)
        .firstOrNull;
    final bool canOpen = findings.any((VaultFinding item) => item.canOpenEntry);
    return VaultFindingGroupPresentation(
      title: primary.title,
      dateLabel: primary.dateLabel,
      problemLabels: problems,
      plannedActionLabels: actions,
      manualGuides: guides,
      canOpenEntry: canOpen,
      canSalvage: canSalvage,
      entryId: entryId,
      findings: findings,
    );
  }
}
