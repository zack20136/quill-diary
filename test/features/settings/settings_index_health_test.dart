import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/features/session/session_messages.dart';
import 'package:quill_diary/features/session/state/app_session_state.dart';
import 'package:quill_diary/features/settings/settings_messages.dart';
import 'package:quill_diary/features/settings/widgets/settings_sections.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';

import '../../helpers/shared/test_l10n.dart';

VaultRepairReport _repairReport({int skippedCorruptEntries = 0}) {
  return VaultRepairReport(
    entryCount: 3,
    duration: const Duration(seconds: 1),
    finishedAt: DateTime.parse('2026-05-19T12:00:00Z'),
    relocatedEntries: 0,
    removedDuplicateEntries: 0,
    skippedCorruptEntries: skippedCorruptEntries,
    tagsAdded: 0,
    relocatedAssets: 0,
    removedOrphanAssets: 0,
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
    final VaultRepairReport report = _repairReport(skippedCorruptEntries: 2);
    expect(
      settingsIndexHealthLevel(
        l10n: testL10n,
        sessionState: const AppSessionState(status: AppLockStatus.unlocked),
        hasUnlockedSession: true,
        repairReport: report,
      ),
      SettingsHealthLevel.warning,
    );
    expect(
      settingsIndexStatusMessage(
        testL10n,
        sessionState: const AppSessionState(status: AppLockStatus.unlocked),
        hasUnlockedSession: true,
        repairReport: report,
      ),
      isNot(testL10n.settingsRepairVaultReadyMessage),
    );
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
