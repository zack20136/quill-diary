import '../../domain/shared/value_objects.dart';

/// 日記庫維護問題種類。
enum VaultRepairIssueKind {
  invalidEntryMetadata,
  unreadableEntry,
  entryIdentityMismatch,
  conflictingEntry,
  missingAsset,
  unreadableAsset,
  assetIdentityMismatch,
  conflictingAsset,
  unverifiedOrphanAsset,
  cleanupFailure,
}

/// 底層修復階段（不含 application 層的備份階段）。
enum VaultRepairPhase {
  scanningEntries,
  checkingAttachments,
  rebuildingIndex,
  rebuildingPeopleAnalytics,
  cleaning,
}

/// Application 層檢查／修復流程進度。
enum VaultMaintenanceFlowPhase {
  inspectingEntries,
  inspectingAttachments,
  rebuildingIndex,
  rebuildingPeople,
  creatingBackup,
  repairingEntries,
  repairingAttachments,
  updatingSearch,
}

typedef VaultRepairProgressCallback = void Function(VaultRepairPhase phase);

typedef VaultMaintenanceFlowProgressCallback =
    void Function(VaultMaintenanceFlowPhase phase);

/// 預計自動處理方式。
enum VaultPlannedAction {
  none,
  reindex,
  relocateToCanonical,
  quarantine,
  removeReference,
  splitAttachment,
  deleteDuplicate,
}

/// 使用者可執行的手動處理指引類型。
enum VaultManualAction {
  none,
  openAndReuploadAttachment,
  openAndRemoveBrokenReference,
  restoreFromBackup,
}

/// 附件在 UI 上的分類。
enum VaultAttachmentCategory { photo, file, unknown }

/// 僅含 kind／reference 的舊式問題描述；內部掃描仍會產生，再轉成 [VaultFinding]。
class VaultRepairIssue {
  const VaultRepairIssue({required this.kind, required this.reference});

  final VaultRepairIssueKind kind;
  final String reference;
}

/// 結構化維護發現項；UI 只使用易懂欄位，不顯示 [internalReference]。
class VaultFinding {
  const VaultFinding({
    required this.kind,
    required this.plannedAction,
    required this.manualAction,
    required this.canOpenEntry,
    required this.internalReference,
    this.entryId,
    this.entryTitle,
    this.entryDate,
    this.attachmentCategory = VaultAttachmentCategory.unknown,
    this.resolved = false,
  });

  final VaultRepairIssueKind kind;
  final VaultPlannedAction plannedAction;
  final VaultManualAction manualAction;
  final bool canOpenEntry;
  final EntryId? entryId;
  final String? entryTitle;
  final DateOnly? entryDate;
  final VaultAttachmentCategory attachmentCategory;
  final String internalReference;
  final bool resolved;

  VaultFinding copyWith({
    VaultPlannedAction? plannedAction,
    VaultManualAction? manualAction,
    bool? canOpenEntry,
    bool? resolved,
  }) {
    return VaultFinding(
      kind: kind,
      plannedAction: plannedAction ?? this.plannedAction,
      manualAction: manualAction ?? this.manualAction,
      canOpenEntry: canOpenEntry ?? this.canOpenEntry,
      internalReference: internalReference,
      entryId: entryId,
      entryTitle: entryTitle,
      entryDate: entryDate,
      attachmentCategory: attachmentCategory,
      resolved: resolved ?? this.resolved,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'kind': kind.name,
    'planned_action': plannedAction.name,
    'manual_action': manualAction.name,
    'can_open_entry': canOpenEntry,
    'entry_id': entryId,
    'entry_title': entryTitle,
    'entry_date': entryDate?.value,
    'attachment_category': attachmentCategory.name,
    'internal_reference': internalReference,
    'resolved': resolved,
  };

  static VaultFinding? fromJson(Map<String, Object?> json) {
    final VaultRepairIssueKind? kind = VaultRepairIssueKind.values
        .where((VaultRepairIssueKind value) => value.name == '${json['kind']}')
        .firstOrNull;
    final VaultPlannedAction? plannedAction = VaultPlannedAction.values
        .where(
          (VaultPlannedAction value) =>
              value.name == '${json['planned_action']}',
        )
        .firstOrNull;
    final VaultManualAction? manualAction = VaultManualAction.values
        .where(
          (VaultManualAction value) => value.name == '${json['manual_action']}',
        )
        .firstOrNull;
    final VaultAttachmentCategory attachmentCategory =
        VaultAttachmentCategory.values
            .where(
              (VaultAttachmentCategory value) =>
                  value.name == '${json['attachment_category']}',
            )
            .firstOrNull ??
        VaultAttachmentCategory.unknown;
    if (kind == null || plannedAction == null || manualAction == null) {
      return null;
    }
    final String? rawDate = json['entry_date']?.toString();
    return VaultFinding(
      kind: kind,
      plannedAction: plannedAction,
      manualAction: manualAction,
      canOpenEntry: json['can_open_entry'] == true,
      entryId: json['entry_id']?.toString(),
      entryTitle: json['entry_title']?.toString(),
      entryDate: rawDate == null || rawDate.isEmpty
          ? null
          : DateOnly.tryParse(rawDate),
      attachmentCategory: attachmentCategory,
      internalReference: '${json['internal_reference'] ?? ''}',
      resolved: json['resolved'] == true,
    );
  }
}

/// 逐篇修復動作摘要；只保留可顯示標題／日期與計數，不含 UUID 或路徑。
class VaultRepairEntryActionLog {
  const VaultRepairEntryActionLog({
    required this.title,
    this.date,
    this.recoveredAttachments = 0,
    this.removedMissingAttachments = 0,
    this.purgedBadAttachments = 0,
    this.splitAttachments = 0,
    this.relocatedEntries = 0,
    this.quarantinedItems = 0,
    this.cleanupFailures = 0,
  });

  final String title;
  final DateOnly? date;
  final int recoveredAttachments;
  final int removedMissingAttachments;
  final int purgedBadAttachments;
  final int splitAttachments;
  final int relocatedEntries;
  final int quarantinedItems;
  final int cleanupFailures;

  /// 僅成功動作；cleanupFailures 應顯示於「仍需處理」，不算已完成。
  bool get hasActions =>
      recoveredAttachments > 0 ||
      removedMissingAttachments > 0 ||
      purgedBadAttachments > 0 ||
      splitAttachments > 0 ||
      relocatedEntries > 0 ||
      quarantinedItems > 0;

  Map<String, Object?> toJson() => <String, Object?>{
    'title': title,
    'date': date?.value,
    'recovered_attachments': recoveredAttachments,
    'removed_missing_attachments': removedMissingAttachments,
    'purged_bad_attachments': purgedBadAttachments,
    'split_attachments': splitAttachments,
    'relocated_entries': relocatedEntries,
    'quarantined_items': quarantinedItems,
    'cleanup_failures': cleanupFailures,
  };

  static VaultRepairEntryActionLog? fromJson(Map<String, Object?> json) {
    final String title = '${json['title'] ?? ''}'.trim();
    final String? rawDate = json['date']?.toString();
    return VaultRepairEntryActionLog(
      title: title,
      date: rawDate == null || rawDate.isEmpty
          ? null
          : DateOnly.tryParse(rawDate),
      recoveredAttachments:
          int.tryParse('${json['recovered_attachments'] ?? 0}') ?? 0,
      removedMissingAttachments:
          int.tryParse('${json['removed_missing_attachments'] ?? 0}') ?? 0,
      purgedBadAttachments:
          int.tryParse('${json['purged_bad_attachments'] ?? 0}') ?? 0,
      splitAttachments: int.tryParse('${json['split_attachments'] ?? 0}') ?? 0,
      relocatedEntries: int.tryParse('${json['relocated_entries'] ?? 0}') ?? 0,
      quarantinedItems: int.tryParse('${json['quarantined_items'] ?? 0}') ?? 0,
      cleanupFailures: int.tryParse('${json['cleanup_failures'] ?? 0}') ?? 0,
    );
  }
}

enum VaultRepairActionScope { entry, global }

enum VaultRepairActionType {
  recoverAttachment,
  removeMissingReference,
  purgeBadAttachment,
  splitAttachment,
  relocateEntry,
  quarantine,
  removeDuplicate,
  purgeOrphan,
  purgeOldQuarantine,
  cleanupFailure,
  salvaged,
  permanentlyDeleted,
}

enum VaultRepairActionOutcome { succeeded, failed }

/// 修復期間的記憶體事件；不會寫入摘要或其他持久化資料。
class VaultRepairActionEvent {
  const VaultRepairActionEvent({
    required this.scope,
    required this.type,
    required this.outcome,
    this.entryTitle,
    this.entryDate,
    this.internalIdentity,
  });

  final VaultRepairActionScope scope;
  final VaultRepairActionType type;
  final VaultRepairActionOutcome outcome;
  final String? entryTitle;
  final DateOnly? entryDate;
  final String? internalIdentity;
}

class VaultRepairActionAggregation {
  const VaultRepairActionAggregation({
    required this.entryActionLogs,
    required this.relocatedEntries,
    required this.removedDuplicateEntries,
    required this.relocatedAssets,
    required this.removedOrphanAssets,
    required this.quarantinedCount,
    required this.purgedBadAssets,
    required this.removedBrokenReferences,
    required this.splitAttachments,
    required this.recoveredAttachments,
    required this.cleanupFailures,
    required this.permanentlyDeleted,
    required this.salvaged,
    required this.purgedOldQuarantine,
  });

  final List<VaultRepairEntryActionLog> entryActionLogs;
  final int relocatedEntries;
  final int removedDuplicateEntries;
  final int relocatedAssets;
  final int removedOrphanAssets;
  final int quarantinedCount;
  final int purgedBadAssets;
  final int removedBrokenReferences;
  final int splitAttachments;
  final int recoveredAttachments;
  final int cleanupFailures;
  final int permanentlyDeleted;
  final int salvaged;
  final int purgedOldQuarantine;
}

VaultRepairActionAggregation aggregateVaultRepairActionEvents(
  Iterable<VaultRepairActionEvent> events,
) {
  final Map<String, Map<VaultRepairActionType, int>> counts =
      <String, Map<VaultRepairActionType, int>>{};
  final Map<String, ({String title, DateOnly? date})> labels =
      <String, ({String title, DateOnly? date})>{};
  final Set<String> seen = <String>{};
  var relocatedEntries = 0;
  var removedDuplicateEntries = 0;
  var relocatedAssets = 0;
  var removedOrphanAssets = 0;
  var quarantinedCount = 0;
  var purgedBadAssets = 0;
  var removedBrokenReferences = 0;
  var splitAttachments = 0;
  var recoveredAttachments = 0;
  var cleanupFailures = 0;
  var permanentlyDeleted = 0;
  var salvaged = 0;
  var purgedOldQuarantine = 0;

  for (final VaultRepairActionEvent event in events) {
    // 失敗只進 unresolved findings，不寫入「已完成」逐篇 log。
    if (event.outcome != VaultRepairActionOutcome.succeeded) {
      if (event.type == VaultRepairActionType.cleanupFailure) {
        cleanupFailures++;
      }
      continue;
    }
    final String identity = event.internalIdentity ?? '';
    final String key = event.scope == VaultRepairActionScope.entry
        ? '${event.entryTitle ?? ''}|${event.entryDate?.value ?? ''}|'
              '${event.type.name}|$identity'
        : '${event.type.name}|$identity';
    if (!seen.add(key)) continue;
    if (event.scope == VaultRepairActionScope.entry) {
      final String groupKey =
          '${event.entryTitle ?? ''}|${event.entryDate?.value ?? ''}';
      final Map<VaultRepairActionType, int> group = counts.putIfAbsent(
        groupKey,
        () => <VaultRepairActionType, int>{},
      );
      group.update(event.type, (int value) => value + 1, ifAbsent: () => 1);
      labels[groupKey] = (title: event.entryTitle ?? '', date: event.entryDate);
    }
    switch (event.type) {
      case VaultRepairActionType.relocateEntry:
        relocatedEntries++;
      case VaultRepairActionType.removeDuplicate:
        removedDuplicateEntries++;
      case VaultRepairActionType.recoverAttachment:
        recoveredAttachments++;
        relocatedAssets++;
      case VaultRepairActionType.removeMissingReference:
        removedBrokenReferences++;
      case VaultRepairActionType.purgeBadAttachment:
        purgedBadAssets++;
      case VaultRepairActionType.splitAttachment:
        splitAttachments++;
      case VaultRepairActionType.quarantine:
        quarantinedCount++;
      case VaultRepairActionType.purgeOrphan:
        removedOrphanAssets++;
      case VaultRepairActionType.purgeOldQuarantine:
        purgedOldQuarantine +=
            int.tryParse((event.internalIdentity ?? '').split(':').last) ?? 1;
      case VaultRepairActionType.cleanupFailure:
        cleanupFailures++;
      case VaultRepairActionType.salvaged:
        salvaged++;
      case VaultRepairActionType.permanentlyDeleted:
        permanentlyDeleted++;
    }
  }

  final List<VaultRepairEntryActionLog> logs = <VaultRepairEntryActionLog>[];
  for (final MapEntry<String, Map<VaultRepairActionType, int>> item
      in counts.entries) {
    final ({String title, DateOnly? date}) label = labels[item.key]!;
    final Map<VaultRepairActionType, int> value = item.value;
    final VaultRepairEntryActionLog log = VaultRepairEntryActionLog(
      title: label.title,
      date: label.date,
      recoveredAttachments: value[VaultRepairActionType.recoverAttachment] ?? 0,
      removedMissingAttachments:
          value[VaultRepairActionType.removeMissingReference] ?? 0,
      purgedBadAttachments:
          value[VaultRepairActionType.purgeBadAttachment] ?? 0,
      splitAttachments: value[VaultRepairActionType.splitAttachment] ?? 0,
      relocatedEntries: value[VaultRepairActionType.relocateEntry] ?? 0,
      quarantinedItems: value[VaultRepairActionType.quarantine] ?? 0,
    );
    if (log.hasActions) logs.add(log);
  }
  return VaultRepairActionAggregation(
    entryActionLogs: logs,
    relocatedEntries: relocatedEntries,
    removedDuplicateEntries: removedDuplicateEntries,
    relocatedAssets: relocatedAssets,
    removedOrphanAssets: removedOrphanAssets,
    quarantinedCount: quarantinedCount,
    purgedBadAssets: purgedBadAssets,
    removedBrokenReferences: removedBrokenReferences,
    splitAttachments: splitAttachments,
    recoveredAttachments: recoveredAttachments,
    cleanupFailures: cleanupFailures,
    permanentlyDeleted: permanentlyDeleted,
    salvaged: salvaged,
    purgedOldQuarantine: purgedOldQuarantine,
  );
}

bool hasRepairDetailContent(VaultRepairSummary summary) =>
    summary.entryActionLogs.isNotEmpty ||
    summary.hasCompletedActions ||
    summary.hasUnresolvedIssues;

/// 依 applied／失敗 finding 分組成可持久化的逐篇動作紀錄。
List<VaultRepairEntryActionLog> buildVaultRepairEntryActionLogs(
  Iterable<VaultFinding> findings,
) {
  final Map<String, List<VaultFinding>> groups = <String, List<VaultFinding>>{};
  for (final VaultFinding finding in findings) {
    final String key = finding.entryId?.trim().isNotEmpty == true
        ? 'id:${finding.entryId}'
        : 'title:${finding.entryTitle ?? ''}|${finding.entryDate ?? ''}';
    groups.putIfAbsent(key, () => <VaultFinding>[]).add(finding);
  }
  final List<VaultRepairEntryActionLog> logs = <VaultRepairEntryActionLog>[];
  for (final List<VaultFinding> group in groups.values) {
    var recoveredAttachments = 0;
    var removedMissingAttachments = 0;
    var purgedBadAttachments = 0;
    var splitAttachments = 0;
    var relocatedEntries = 0;
    var quarantinedItems = 0;
    String title = '';
    DateOnly? date;
    for (final VaultFinding finding in group) {
      if (finding.kind == VaultRepairIssueKind.cleanupFailure) {
        continue;
      }
      final String? candidate = finding.entryTitle?.trim();
      if (title.isEmpty && candidate != null && candidate.isNotEmpty) {
        title = candidate;
      }
      date ??= finding.entryDate;
      switch (finding.plannedAction) {
        case VaultPlannedAction.relocateToCanonical:
          if (isAutoResolvableAssetIssueKind(finding.kind)) {
            recoveredAttachments++;
          } else {
            relocatedEntries++;
          }
        case VaultPlannedAction.removeReference:
          if (finding.kind == VaultRepairIssueKind.missingAsset) {
            removedMissingAttachments++;
          } else {
            purgedBadAttachments++;
          }
        case VaultPlannedAction.splitAttachment:
          splitAttachments++;
        case VaultPlannedAction.quarantine:
          quarantinedItems++;
        case VaultPlannedAction.deleteDuplicate:
          relocatedEntries++;
        case VaultPlannedAction.reindex:
        case VaultPlannedAction.none:
          break;
      }
    }
    final VaultRepairEntryActionLog log = VaultRepairEntryActionLog(
      title: title,
      date: date,
      recoveredAttachments: recoveredAttachments,
      removedMissingAttachments: removedMissingAttachments,
      purgedBadAttachments: purgedBadAttachments,
      splitAttachments: splitAttachments,
      relocatedEntries: relocatedEntries,
      quarantinedItems: quarantinedItems,
    );
    if (log.hasActions) logs.add(log);
  }
  return logs;
}

class VaultRepairReport {
  const VaultRepairReport({
    required this.entryCount,
    required this.duration,
    required this.finishedAt,
    required this.relocatedEntries,
    required this.removedDuplicateEntries,
    required this.tagsAdded,
    required this.relocatedAssets,
    required this.removedOrphanAssets,
    this.issues = const <VaultRepairIssue>[],
    this.findings = const <VaultFinding>[],
    this.appliedActions = const <VaultFinding>[],
    this.unresolvedFindings = const <VaultFinding>[],
    this.entryActionLogs = const <VaultRepairEntryActionLog>[],
    this.quarantinedCount = 0,
    this.purgedBadAssets = 0,
    this.removedBrokenReferences = 0,
    this.splitAttachments = 0,
    this.recoveredAttachments = 0,
    this.purgedOldQuarantine = 0,
    this.backupFileName,
    this.repairId,
  });

  final int entryCount;
  final Duration duration;
  final DateTime finishedAt;
  final int relocatedEntries;
  final int removedDuplicateEntries;
  final int tagsAdded;
  final int relocatedAssets;
  final int removedOrphanAssets;
  final List<VaultRepairIssue> issues;
  final List<VaultFinding> findings;
  final List<VaultFinding> appliedActions;
  final List<VaultFinding> unresolvedFindings;
  final List<VaultRepairEntryActionLog> entryActionLogs;
  final int quarantinedCount;
  final int purgedBadAssets;
  final int removedBrokenReferences;
  final int splitAttachments;
  final int recoveredAttachments;
  final int purgedOldQuarantine;
  final String? backupFileName;
  final String? repairId;

  bool get hasUnresolvedIssues =>
      unresolvedFindings.isNotEmpty || issues.isNotEmpty;

  int issueCount(VaultRepairIssueKind kind) {
    if (unresolvedFindings.isNotEmpty) {
      return unresolvedFindings
          .where((VaultFinding finding) => finding.kind == kind)
          .length;
    }
    return issues.where((VaultRepairIssue issue) => issue.kind == kind).length;
  }

  VaultRepairReport copyWith({
    List<VaultRepairIssue>? issues,
    List<VaultFinding>? findings,
    List<VaultFinding>? appliedActions,
    List<VaultFinding>? unresolvedFindings,
    List<VaultRepairEntryActionLog>? entryActionLogs,
    int? quarantinedCount,
    int? purgedBadAssets,
    int? removedBrokenReferences,
    int? splitAttachments,
    int? recoveredAttachments,
    int? purgedOldQuarantine,
    String? backupFileName,
    String? repairId,
  }) {
    return VaultRepairReport(
      entryCount: entryCount,
      duration: duration,
      finishedAt: finishedAt,
      relocatedEntries: relocatedEntries,
      removedDuplicateEntries: removedDuplicateEntries,
      tagsAdded: tagsAdded,
      relocatedAssets: relocatedAssets,
      removedOrphanAssets: removedOrphanAssets,
      issues: issues ?? this.issues,
      findings: findings ?? this.findings,
      appliedActions: appliedActions ?? this.appliedActions,
      unresolvedFindings: unresolvedFindings ?? this.unresolvedFindings,
      entryActionLogs: entryActionLogs ?? this.entryActionLogs,
      quarantinedCount: quarantinedCount ?? this.quarantinedCount,
      purgedBadAssets: purgedBadAssets ?? this.purgedBadAssets,
      removedBrokenReferences:
          removedBrokenReferences ?? this.removedBrokenReferences,
      splitAttachments: splitAttachments ?? this.splitAttachments,
      recoveredAttachments: recoveredAttachments ?? this.recoveredAttachments,
      purgedOldQuarantine: purgedOldQuarantine ?? this.purgedOldQuarantine,
      backupFileName: backupFileName ?? this.backupFileName,
      repairId: repairId ?? this.repairId,
    );
  }
}

class VaultInspectReport {
  const VaultInspectReport({
    required this.entryCount,
    required this.duration,
    required this.finishedAt,
    required this.findings,
  });

  final int entryCount;
  final Duration duration;
  final DateTime finishedAt;
  final List<VaultFinding> findings;

  bool get hasFindings => findings.isNotEmpty;

  int get unresolvedCount =>
      findings.where((VaultFinding finding) => !finding.resolved).length;
}

class VaultRepairSummary {
  const VaultRepairSummary({
    required this.entryCount,
    required this.finishedAt,
    required this.issueCounts,
    this.lastUpdatedAt,
    this.salvagedCount = 0,
    this.permanentlyDeletedCount = 0,
    this.relocatedEntries = 0,
    this.removedDuplicateEntries = 0,
    this.tagsAdded = 0,
    this.relocatedAssets = 0,
    this.removedOrphanAssets = 0,
    this.quarantinedCount = 0,
    this.purgedBadAssets = 0,
    this.removedBrokenReferences = 0,
    this.splitAttachments = 0,
    this.recoveredAttachments = 0,
    this.purgedOldQuarantine = 0,
    this.backupFileName,
    this.repairId,
    this.findings = const <VaultFinding>[],
    this.entryActionLogs = const <VaultRepairEntryActionLog>[],
  });

  final int entryCount;
  final DateTime finishedAt;
  final Map<VaultRepairIssueKind, int> issueCounts;
  final DateTime? lastUpdatedAt;
  final int salvagedCount;
  final int permanentlyDeletedCount;
  final int relocatedEntries;
  final int removedDuplicateEntries;
  final int tagsAdded;
  final int relocatedAssets;
  final int removedOrphanAssets;
  final int quarantinedCount;
  final int purgedBadAssets;
  final int removedBrokenReferences;
  final int splitAttachments;
  final int recoveredAttachments;
  final int purgedOldQuarantine;
  final String? backupFileName;
  final String? repairId;
  final List<VaultFinding> findings;
  final List<VaultRepairEntryActionLog> entryActionLogs;

  bool get hasUnresolvedIssues =>
      findings.any((VaultFinding finding) => !finding.resolved) ||
      issueCounts.values.any((int count) => count > 0);

  int get unresolvedFindingCount => findings
      .where((VaultFinding finding) => !finding.resolved)
      .fold(0, (int total, _) => total + 1);

  bool get hasCompletedActions =>
      relocatedEntries > 0 ||
      removedDuplicateEntries > 0 ||
      relocatedAssets > 0 ||
      removedOrphanAssets > 0 ||
      quarantinedCount > 0 ||
      purgedBadAssets > 0 ||
      removedBrokenReferences > 0 ||
      splitAttachments > 0 ||
      recoveredAttachments > 0 ||
      purgedOldQuarantine > 0 ||
      tagsAdded > 0;

  factory VaultRepairSummary.fromReport(VaultRepairReport report) {
    final Map<VaultRepairIssueKind, int> counts = <VaultRepairIssueKind, int>{};
    // 必須以 unresolvedFindings 為準；空清單代表已全部處理，不可回退到
    // report.findings（其中仍可能含「已靠 appliedActions 對消」的舊 finding）。
    final List<VaultFinding> unresolved = report.unresolvedFindings;
    for (final VaultFinding finding in unresolved) {
      counts.update(finding.kind, (int value) => value + 1, ifAbsent: () => 1);
    }
    if (counts.isEmpty) {
      for (final VaultRepairIssue issue in report.issues) {
        counts.update(issue.kind, (int value) => value + 1, ifAbsent: () => 1);
      }
    }
    final List<VaultFinding> applied = report.appliedActions
        .where((VaultFinding item) => item.resolved)
        .toList();
    final List<VaultRepairEntryActionLog> entryActionLogs =
        report.entryActionLogs.isNotEmpty
        ? report.entryActionLogs
              .where((VaultRepairEntryActionLog log) => log.hasActions)
              .toList()
        : buildVaultRepairEntryActionLogs(applied);
    return VaultRepairSummary(
      entryCount: report.entryCount,
      finishedAt: report.finishedAt,
      issueCounts: counts,
      lastUpdatedAt: report.finishedAt,
      relocatedEntries: report.relocatedEntries,
      removedDuplicateEntries: report.removedDuplicateEntries,
      tagsAdded: report.tagsAdded,
      relocatedAssets: report.relocatedAssets,
      removedOrphanAssets: report.removedOrphanAssets,
      quarantinedCount: report.quarantinedCount,
      purgedBadAssets: report.purgedBadAssets,
      removedBrokenReferences: report.removedBrokenReferences,
      splitAttachments: report.splitAttachments,
      recoveredAttachments: report.recoveredAttachments,
      purgedOldQuarantine: report.purgedOldQuarantine,
      backupFileName: report.backupFileName,
      repairId: report.repairId,
      findings: unresolved,
      entryActionLogs: entryActionLogs,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'entry_count': entryCount,
    'finished_at': finishedAt.toIso8601String(),
    'last_updated_at': lastUpdatedAt?.toIso8601String(),
    'salvaged_count': salvagedCount,
    'permanently_deleted_count': permanentlyDeletedCount,
    'relocated_entries': relocatedEntries,
    'removed_duplicate_entries': removedDuplicateEntries,
    'tags_added': tagsAdded,
    'relocated_assets': relocatedAssets,
    'removed_orphan_assets': removedOrphanAssets,
    'quarantined_count': quarantinedCount,
    'purged_bad_assets': purgedBadAssets,
    'removed_broken_references': removedBrokenReferences,
    'split_attachments': splitAttachments,
    'recovered_attachments': recoveredAttachments,
    'purged_old_quarantine': purgedOldQuarantine,
    'backup_file_name': backupFileName,
    'repair_id': repairId,
    'issue_counts': <String, int>{
      for (final MapEntry<VaultRepairIssueKind, int> item
          in issueCounts.entries)
        item.key.name: item.value,
    },
    'findings': <Map<String, Object?>>[
      for (final VaultFinding finding in findings) finding.toJson(),
    ],
    'entry_action_logs': <Map<String, Object?>>[
      for (final VaultRepairEntryActionLog log in entryActionLogs) log.toJson(),
    ],
  };

  static VaultRepairSummary? fromJson(Map<String, Object?> json) {
    final DateTime? finishedAt = DateTime.tryParse(
      '${json['finished_at'] ?? ''}',
    );
    final DateTime? lastUpdatedAt = DateTime.tryParse(
      '${json['last_updated_at'] ?? ''}',
    );
    final Object? rawCounts = json['issue_counts'];
    if (finishedAt == null || rawCounts is! Map<Object?, Object?>) return null;
    final Map<VaultRepairIssueKind, int> counts = <VaultRepairIssueKind, int>{};
    for (final MapEntry<Object?, Object?> item in rawCounts.entries) {
      final VaultRepairIssueKind? kind = VaultRepairIssueKind.values
          .where((VaultRepairIssueKind value) => value.name == '${item.key}')
          .firstOrNull;
      final int? count = int.tryParse('${item.value}');
      if (kind != null && count != null && count >= 0) counts[kind] = count;
    }
    final List<VaultFinding> findings = <VaultFinding>[];
    final Object? rawFindings = json['findings'];
    if (rawFindings is List<Object?>) {
      for (final Object? item in rawFindings) {
        if (item is Map<String, Object?>) {
          final VaultFinding? finding = VaultFinding.fromJson(item);
          if (finding != null) findings.add(finding);
        } else if (item is Map) {
          final VaultFinding? finding = VaultFinding.fromJson(
            item.cast<String, Object?>(),
          );
          if (finding != null) findings.add(finding);
        }
      }
    }
    final List<VaultRepairEntryActionLog> entryActionLogs =
        <VaultRepairEntryActionLog>[];
    final Object? rawLogs = json['entry_action_logs'];
    if (rawLogs is List<Object?>) {
      for (final Object? item in rawLogs) {
        if (item is Map<String, Object?>) {
          final VaultRepairEntryActionLog? log =
              VaultRepairEntryActionLog.fromJson(item);
          if (log != null) entryActionLogs.add(log);
        } else if (item is Map) {
          final VaultRepairEntryActionLog? log =
              VaultRepairEntryActionLog.fromJson(item.cast<String, Object?>());
          if (log != null) entryActionLogs.add(log);
        }
      }
    }
    return VaultRepairSummary(
      entryCount: int.tryParse('${json['entry_count'] ?? 0}') ?? 0,
      finishedAt: finishedAt,
      issueCounts: counts,
      lastUpdatedAt: lastUpdatedAt ?? finishedAt,
      salvagedCount: int.tryParse('${json['salvaged_count'] ?? 0}') ?? 0,
      permanentlyDeletedCount:
          int.tryParse('${json['permanently_deleted_count'] ?? 0}') ?? 0,
      relocatedEntries: int.tryParse('${json['relocated_entries'] ?? 0}') ?? 0,
      removedDuplicateEntries:
          int.tryParse('${json['removed_duplicate_entries'] ?? 0}') ?? 0,
      tagsAdded: int.tryParse('${json['tags_added'] ?? 0}') ?? 0,
      relocatedAssets: int.tryParse('${json['relocated_assets'] ?? 0}') ?? 0,
      removedOrphanAssets:
          int.tryParse('${json['removed_orphan_assets'] ?? 0}') ?? 0,
      quarantinedCount: int.tryParse('${json['quarantined_count'] ?? 0}') ?? 0,
      purgedBadAssets: int.tryParse('${json['purged_bad_assets'] ?? 0}') ?? 0,
      removedBrokenReferences:
          int.tryParse('${json['removed_broken_references'] ?? 0}') ?? 0,
      splitAttachments: int.tryParse('${json['split_attachments'] ?? 0}') ?? 0,
      recoveredAttachments:
          int.tryParse('${json['recovered_attachments'] ?? 0}') ?? 0,
      purgedOldQuarantine:
          int.tryParse('${json['purged_old_quarantine'] ?? 0}') ?? 0,
      backupFileName: json['backup_file_name']?.toString(),
      repairId: json['repair_id']?.toString(),
      findings: findings,
      entryActionLogs: entryActionLogs,
    );
  }
}

/// 檢查／修復共用的階段式進度：開始偏低、結束前不提前到 100%。
double vaultInspectProgressFraction(VaultRepairPhase phase) => switch (phase) {
  VaultRepairPhase.scanningEntries => 0.12,
  VaultRepairPhase.checkingAttachments => 0.38,
  VaultRepairPhase.rebuildingIndex => 0.62,
  VaultRepairPhase.rebuildingPeopleAnalytics => 0.82,
  VaultRepairPhase.cleaning => 0.94,
};

double vaultMaintenanceProgressFraction(VaultMaintenanceFlowPhase phase) =>
    switch (phase) {
      VaultMaintenanceFlowPhase.creatingBackup => 0.10,
      VaultMaintenanceFlowPhase.inspectingEntries ||
      VaultMaintenanceFlowPhase.repairingEntries => 0.28,
      VaultMaintenanceFlowPhase.inspectingAttachments ||
      VaultMaintenanceFlowPhase.repairingAttachments => 0.52,
      VaultMaintenanceFlowPhase.rebuildingIndex => 0.74,
      VaultMaintenanceFlowPhase.rebuildingPeople ||
      VaultMaintenanceFlowPhase.updatingSearch => 0.92,
    };

class VaultInspectSummary {
  const VaultInspectSummary({
    required this.entryCount,
    required this.finishedAt,
    required this.findings,
  });

  final int entryCount;
  final DateTime finishedAt;
  final List<VaultFinding> findings;

  bool get hasFindings => findings.isNotEmpty;

  int get unresolvedCount =>
      findings.where((VaultFinding finding) => !finding.resolved).length;

  factory VaultInspectSummary.fromReport(VaultInspectReport report) {
    return VaultInspectSummary(
      entryCount: report.entryCount,
      finishedAt: report.finishedAt,
      findings: report.findings,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'entry_count': entryCount,
    'finished_at': finishedAt.toIso8601String(),
    'findings': <Map<String, Object?>>[
      for (final VaultFinding finding in findings) finding.toJson(),
    ],
  };

  static VaultInspectSummary? fromJson(Map<String, Object?> json) {
    final DateTime? finishedAt = DateTime.tryParse(
      '${json['finished_at'] ?? ''}',
    );
    if (finishedAt == null) return null;
    final List<VaultFinding> findings = <VaultFinding>[];
    final Object? rawFindings = json['findings'];
    if (rawFindings is List<Object?>) {
      for (final Object? item in rawFindings) {
        if (item is Map<String, Object?>) {
          final VaultFinding? finding = VaultFinding.fromJson(item);
          if (finding != null) findings.add(finding);
        } else if (item is Map) {
          final VaultFinding? finding = VaultFinding.fromJson(
            item.cast<String, Object?>(),
          );
          if (finding != null) findings.add(finding);
        }
      }
    }
    return VaultInspectSummary(
      entryCount: int.tryParse('${json['entry_count'] ?? 0}') ?? 0,
      finishedAt: finishedAt,
      findings: findings,
    );
  }
}

VaultAttachmentCategory attachmentCategoryForMimeType(String? mimeType) {
  final String normalized = (mimeType ?? '').trim().toLowerCase();
  if (normalized.startsWith('image/')) {
    return VaultAttachmentCategory.photo;
  }
  if (normalized.isEmpty) {
    return VaultAttachmentCategory.unknown;
  }
  return VaultAttachmentCategory.file;
}

bool isAutoResolvableAssetIssueKind(VaultRepairIssueKind kind) {
  return kind == VaultRepairIssueKind.missingAsset ||
      kind == VaultRepairIssueKind.unreadableAsset ||
      kind == VaultRepairIssueKind.assetIdentityMismatch ||
      kind == VaultRepairIssueKind.conflictingAsset;
}

bool isAssetOnlyFindingGroup(Iterable<VaultFinding> findings) {
  final List<VaultFinding> items = findings.toList(growable: false);
  return items.isNotEmpty &&
      items.every(
        (VaultFinding finding) => isAutoResolvableAssetIssueKind(finding.kind),
      );
}

VaultPlannedAction plannedActionForIssue(
  VaultRepairIssueKind kind, {
  required bool forRepair,
}) {
  if (!forRepair) {
    return VaultPlannedAction.none;
  }
  return switch (kind) {
    VaultRepairIssueKind.invalidEntryMetadata ||
    VaultRepairIssueKind.unreadableEntry ||
    VaultRepairIssueKind.entryIdentityMismatch => VaultPlannedAction.quarantine,
    VaultRepairIssueKind.conflictingEntry => VaultPlannedAction.quarantine,
    VaultRepairIssueKind.missingAsset => VaultPlannedAction.removeReference,
    VaultRepairIssueKind.unreadableAsset ||
    VaultRepairIssueKind.assetIdentityMismatch =>
      VaultPlannedAction.removeReference,
    VaultRepairIssueKind.conflictingAsset => VaultPlannedAction.splitAttachment,
    VaultRepairIssueKind.unverifiedOrphanAsset => VaultPlannedAction.quarantine,
    VaultRepairIssueKind.cleanupFailure => VaultPlannedAction.none,
  };
}

VaultManualAction manualActionForIssue(VaultRepairIssueKind kind) {
  return switch (kind) {
    VaultRepairIssueKind.missingAsset =>
      VaultManualAction.openAndReuploadAttachment,
    VaultRepairIssueKind.unreadableAsset ||
    VaultRepairIssueKind.assetIdentityMismatch =>
      VaultManualAction.openAndRemoveBrokenReference,
    VaultRepairIssueKind.conflictingAsset =>
      VaultManualAction.openAndReuploadAttachment,
    VaultRepairIssueKind.invalidEntryMetadata ||
    VaultRepairIssueKind.unreadableEntry ||
    VaultRepairIssueKind.entryIdentityMismatch =>
      VaultManualAction.restoreFromBackup,
    VaultRepairIssueKind.conflictingEntry ||
    VaultRepairIssueKind.unverifiedOrphanAsset ||
    VaultRepairIssueKind.cleanupFailure => VaultManualAction.none,
  };
}

bool canOpenEntryForIssue(VaultRepairIssueKind kind) {
  return switch (kind) {
    VaultRepairIssueKind.missingAsset ||
    VaultRepairIssueKind.unreadableAsset ||
    VaultRepairIssueKind.assetIdentityMismatch ||
    VaultRepairIssueKind.conflictingAsset ||
    VaultRepairIssueKind.conflictingEntry => true,
    VaultRepairIssueKind.invalidEntryMetadata ||
    VaultRepairIssueKind.unreadableEntry ||
    VaultRepairIssueKind.entryIdentityMismatch ||
    VaultRepairIssueKind.unverifiedOrphanAsset ||
    VaultRepairIssueKind.cleanupFailure => false,
  };
}
