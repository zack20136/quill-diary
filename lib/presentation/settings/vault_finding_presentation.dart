import 'package:quill_diary/application/settings/settings_text.dart';
import 'package:quill_diary/infrastructure/storage/vault_maintenance_models.dart';
import 'package:quill_diary/l10n/l10n.dart';

/// 同篇日記的多個 finding 合併呈現。
class VaultFindingGroupPresentation {
  const VaultFindingGroupPresentation({
    required this.title,
    required this.dateLabel,
    required this.problemLabels,
    required this.plannedActionLabels,
    required this.canOpenEntry,
    required this.canSalvage,
    required this.entryId,
    required this.findings,
  });

  final String title;
  final String dateLabel;
  final List<String> problemLabels;
  final List<String> plannedActionLabels;
  final bool canOpenEntry;
  final bool canSalvage;
  final String? entryId;
  final List<VaultFinding> findings;

  factory VaultFindingGroupPresentation.fromFindings(
    AppLocalizations l10n,
    List<VaultFinding> findings, {
    bool canSalvage = false,
  }) {
    assert(findings.isNotEmpty);
    final VaultFinding primary = findings.first;
    final List<String> problems = findings
        .map((finding) => settingsRepairIssueLabel(l10n, finding.kind))
        .toSet()
        .toList();
    final List<String> actions = findings
        .map(
          (finding) => settingsPlannedActionLabel(l10n, finding.plannedAction),
        )
        .toSet()
        .toList();
    final String? entryId = findings
        .map((VaultFinding item) => item.entryId?.trim())
        .whereType<String>()
        .where((String id) => id.isNotEmpty)
        .firstOrNull;
    final bool canOpen = findings.any((VaultFinding item) => item.canOpenEntry);
    return VaultFindingGroupPresentation(
      title: settingsFindingTitle(l10n, primary),
      dateLabel: settingsFindingDateLabel(l10n, primary),
      problemLabels: problems,
      plannedActionLabels: actions,
      canOpenEntry: canOpen,
      canSalvage: canSalvage,
      entryId: entryId,
      findings: findings,
    );
  }
}
