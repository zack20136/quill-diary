import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/application/session/session_messages.dart';
import 'package:quill_diary/application/session/state/app_session_state.dart';
import 'package:quill_diary/application/settings/settings_health_level.dart';
import 'package:quill_diary/application/settings/settings_text.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/storage/vault_maintenance_models.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';

import '../../helpers/shared/test_l10n.dart';

VaultRepairSummary _repairSummary({
  int entryIssueCount = 0,
  DateTime? finishedAt,
}) {
  return VaultRepairSummary.fromReport(
    VaultRepairReport(
      entryCount: 3,
      duration: const Duration(seconds: 1),
      finishedAt: finishedAt ?? DateTime.parse('2026-05-19T12:00:00Z'),
      relocatedEntries: 0,
      removedDuplicateEntries: 0,
      tagsAdded: 0,
      relocatedAssets: 0,
      removedOrphanAssets: 0,
      unresolvedFindings: <VaultFinding>[
        for (var index = 0; index < entryIssueCount; index++)
          VaultFinding(
            kind: VaultRepairIssueKind.unreadableEntry,
            plannedAction: VaultPlannedAction.quarantine,
            manualAction: VaultManualAction.restoreFromBackup,
            canOpenEntry: false,
            entryId: 'entry-$index',
            entryTitle: '日記 $index',
            entryDate: const DateOnly('2026-05-01'),
            internalReference: 'entries/entry-$index.md.enc',
          ),
      ],
    ),
  );
}

void main() {
  test('未解鎖時索引健康為需注意', () {
    expect(
      settingsIndexHealthLevel(
        l10n: testL10n,
        sessionState: null,
        hasUnlockedSession: false,
      ),
      SettingsHealthLevel.warning,
    );
    expect(
      settingsIndexStatusMessage(
        testL10n,
        sessionState: null,
        hasUnlockedSession: false,
      ),
      testL10n.settingsRepairVaultLockedMessage,
    );
  });

  test('已解鎖且無修復報告時索引健康為正常', () {
    expect(
      settingsIndexHealthLevel(
        l10n: testL10n,
        sessionState: const AppSessionState(status: AppLockStatus.unlocked),
        hasUnlockedSession: true,
      ),
      SettingsHealthLevel.ok,
    );
    expect(
      settingsIndexStatusMessage(
        testL10n,
        sessionState: const AppSessionState(status: AppLockStatus.unlocked),
        hasUnlockedSession: true,
      ),
      testL10n.settingsRepairVaultReadyMessage,
    );
  });

  test('修復報告有殘留問題時索引健康為需注意', () {
    final VaultRepairSummary summary = _repairSummary(entryIssueCount: 2);
    expect(
      settingsIndexHealthLevel(
        l10n: testL10n,
        sessionState: const AppSessionState(status: AppLockStatus.unlocked),
        hasUnlockedSession: true,
        repairSummary: summary,
      ),
      SettingsHealthLevel.warning,
    );
    expect(
      settingsIndexStatusMessage(
        testL10n,
        sessionState: const AppSessionState(status: AppLockStatus.unlocked),
        hasUnlockedSession: true,
        repairSummary: summary,
      ),
      contains('2 篇日記需要處理'),
    );
  });

  test('同時有檢查與修復摘要時只顯示時間較近的一次', () {
    final VaultRepairSummary repair = VaultRepairSummary.fromReport(
      VaultRepairReport(
        entryCount: 2,
        duration: Duration.zero,
        finishedAt: DateTime.parse('2026-08-19T06:43:00Z'),
        relocatedEntries: 0,
        removedDuplicateEntries: 0,
        tagsAdded: 0,
        relocatedAssets: 0,
        removedOrphanAssets: 0,
      ),
    );
    final VaultInspectSummary inspect = VaultInspectSummary(
      entryCount: 2,
      finishedAt: DateTime.parse('2026-08-20T01:24:00Z'),
      findings: const <VaultFinding>[],
    );

    final String message = settingsIndexStatusMessage(
      testL10n,
      sessionState: const AppSessionState(status: AppLockStatus.unlocked),
      hasUnlockedSession: true,
      repairSummary: repair,
      inspectSummary: inspect,
    );

    expect(message, startsWith('最近一次檢查'));
    expect(message.contains('最近一次修復'), isFalse);
  });

  test('較新檢查無異常時不沿用舊修復的未解決項', () {
    final VaultRepairSummary repair = _repairSummary(
      entryIssueCount: 2,
      finishedAt: DateTime.parse('2026-08-19T06:43:00Z'),
    );
    final VaultInspectSummary inspect = VaultInspectSummary(
      entryCount: 4,
      finishedAt: DateTime.parse('2026-08-20T01:24:00Z'),
      findings: const <VaultFinding>[],
    );

    expect(
      settingsUnresolvedFindings(
        inspectSummary: inspect,
        repairSummary: repair,
      ),
      isEmpty,
    );
    expect(
      settingsIndexHealthLevel(
        l10n: testL10n,
        sessionState: const AppSessionState(status: AppLockStatus.unlocked),
        hasUnlockedSession: true,
        repairSummary: repair,
        inspectSummary: inspect,
      ),
      SettingsHealthLevel.ok,
    );
  });

  test('檢查與修復時間相同時優先顯示修復文案', () {
    final DateTime sameTime = DateTime.parse('2026-08-20T01:24:00Z');
    final VaultRepairSummary repair = VaultRepairSummary.fromReport(
      VaultRepairReport(
        entryCount: 2,
        duration: Duration.zero,
        finishedAt: sameTime,
        relocatedEntries: 0,
        removedDuplicateEntries: 0,
        tagsAdded: 0,
        relocatedAssets: 0,
        removedOrphanAssets: 0,
      ),
    );
    final VaultInspectSummary inspect = VaultInspectSummary(
      entryCount: 2,
      finishedAt: sameTime,
      findings: const <VaultFinding>[],
    );

    final String message = settingsIndexStatusMessage(
      testL10n,
      sessionState: const AppSessionState(status: AppLockStatus.unlocked),
      hasUnlockedSession: true,
      repairSummary: repair,
      inspectSummary: inspect,
    );

    expect(message, startsWith('最近一次修復'));
    expect(message.contains('最近一次檢查'), isFalse);
  });

  test('索引不可讀訊息時索引健康為錯誤', () {
    final String indexMessage = sessionIndexDatabaseUnreadableMessage(testL10n);
    expect(
      settingsIndexHealthLevel(
        l10n: testL10n,
        sessionState: AppSessionState(
          status: AppLockStatus.recoveryRequired,
          message: indexMessage,
        ),
        hasUnlockedSession: false,
      ),
      SettingsHealthLevel.error,
    );
    expect(
      settingsIndexStatusMessage(
        testL10n,
        sessionState: AppSessionState(
          status: AppLockStatus.fatalError,
          message: indexMessage,
        ),
        hasUnlockedSession: false,
      ),
      indexMessage,
    );
  });

  test('非索引 fatal 不會誤標為索引錯誤', () {
    final String unsupportedMessage = sessionUnsupportedRuntimeMessage(
      testL10n,
    );
    expect(
      settingsIndexHealthLevel(
        l10n: testL10n,
        sessionState: AppSessionState(
          status: AppLockStatus.fatalError,
          message: unsupportedMessage,
        ),
        hasUnlockedSession: false,
      ),
      SettingsHealthLevel.warning,
    );
    expect(
      settingsIndexStatusMessage(
        testL10n,
        sessionState: AppSessionState(
          status: AppLockStatus.fatalError,
          message: unsupportedMessage,
        ),
        hasUnlockedSession: false,
      ),
      testL10n.settingsRepairVaultLockedMessage,
    );
  });
}
