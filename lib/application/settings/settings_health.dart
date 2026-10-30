import 'package:quill_diary/application/session/session_state.dart';
import 'package:quill_diary/infrastructure/storage/vault_maintenance_models.dart';

enum SettingsHealthLevel { ok, warning, error }

/// 無法對應到日記的 finding 共用分組鍵。
const String kUnrecognizedVaultFindingGroupKey = 'unrecognized';

/// 以日記為單位分組；無法對應者合併為一組。
String vaultFindingGroupKey(VaultFinding finding) {
  final String? entryId = finding.entryId?.trim();
  if (entryId != null && entryId.isNotEmpty) {
    return 'entry:$entryId';
  }
  return kUnrecognizedVaultFindingGroupKey;
}

Map<String, List<VaultFinding>> groupVaultFindings(
  Iterable<VaultFinding> findings,
) {
  final Map<String, List<VaultFinding>> grouped =
      <String, List<VaultFinding>>{};
  for (final VaultFinding finding in findings) {
    if (finding.resolved) continue;
    grouped
        .putIfAbsent(vaultFindingGroupKey(finding), () => <VaultFinding>[])
        .add(finding);
  }
  return grouped;
}

int countAffectedVaultEntries(Iterable<VaultFinding> findings) =>
    groupVaultFindings(findings).length;

/// 設定頁「日記庫」卡片共用的最近一次維護摘要。
///
/// 以 [finishedAt] 選出唯一有效來源；時間相同時優先修復結果。
class VaultMaintenanceSnapshot {
  const VaultMaintenanceSnapshot._({
    required this.source,
    required this.entryCount,
    required this.finishedAt,
    required this.unresolvedFindings,
    required this.affectedEntryCount,
    this.backupFileName,
  });

  final VaultMaintenanceSnapshotSource source;
  final int entryCount;
  final DateTime finishedAt;
  final List<VaultFinding> unresolvedFindings;
  final int affectedEntryCount;
  final String? backupFileName;

  bool get hasIssues => affectedEntryCount > 0;
}

enum VaultMaintenanceSnapshotSource { inspect, repair }

VaultMaintenanceSnapshot? resolveVaultMaintenanceSnapshot({
  VaultInspectSummary? inspectSummary,
  VaultRepairSummary? repairSummary,
}) {
  if (inspectSummary == null && repairSummary == null) {
    return null;
  }
  final DateTime? inspectAt = inspectSummary?.finishedAt;
  final DateTime? repairAt = repairSummary?.finishedAt;
  // 同時間優先 repair：inspect 較新才選 inspect。
  final bool preferRepair =
      repairSummary != null &&
      (inspectSummary == null ||
          inspectAt == null ||
          !inspectAt.isAfter(repairAt!));

  if (preferRepair) {
    final VaultRepairSummary selectedRepair = repairSummary;
    final List<VaultFinding> unresolved = <VaultFinding>[
      for (final VaultFinding finding in selectedRepair.findings)
        if (!finding.resolved) finding,
    ];
    return VaultMaintenanceSnapshot._(
      source: VaultMaintenanceSnapshotSource.repair,
      entryCount: selectedRepair.entryCount,
      finishedAt: selectedRepair.finishedAt,
      unresolvedFindings: unresolved,
      affectedEntryCount: countAffectedVaultEntries(unresolved),
      backupFileName: selectedRepair.backupFileName,
    );
  }

  final List<VaultFinding> unresolved = <VaultFinding>[
    for (final VaultFinding finding in inspectSummary!.findings)
      if (!finding.resolved) finding,
  ];
  return VaultMaintenanceSnapshot._(
    source: VaultMaintenanceSnapshotSource.inspect,
    entryCount: inspectSummary.entryCount,
    finishedAt: inspectSummary.finishedAt,
    unresolvedFindings: unresolved,
    affectedEntryCount: countAffectedVaultEntries(unresolved),
  );
}

SettingsHealthLevel settingsIndexHealthLevel({
  required AppSessionState? sessionState,
  required bool hasUnlockedSession,
  VaultRepairSummary? repairSummary,
  VaultInspectSummary? inspectSummary,
}) {
  if (sessionState?.failure == SessionFailure.unreadableIndex) {
    return SettingsHealthLevel.error;
  }
  if (!hasUnlockedSession) {
    return SettingsHealthLevel.warning;
  }
  final VaultMaintenanceSnapshot? snapshot = resolveVaultMaintenanceSnapshot(
    inspectSummary: inspectSummary,
    repairSummary: repairSummary,
  );
  if (snapshot?.hasIssues ?? false) {
    return SettingsHealthLevel.warning;
  }
  return SettingsHealthLevel.ok;
}
