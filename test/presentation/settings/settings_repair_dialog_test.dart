import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/settings/widgets/settings_action_dialogs.dart';

import '../../helpers/app_test_theme.dart';
import '../../helpers/shared/test_l10n.dart';

void main() {
  Future<void> pumpLauncher(
    WidgetTester tester,
    Future<void> Function(BuildContext context) launch,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTestTheme(),
        locale: appZhLocale,
        supportedLocales: appSupportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (BuildContext context) => FilledButton(
            onPressed: () => unawaited(launch(context)),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('修復前會說明安全清理規則並可取消', (WidgetTester tester) async {
    bool? result;
    await pumpLauncher(tester, (BuildContext context) async {
      result = await showRepairVaultConfirmDialog(context);
    });

    expect(find.text(testL10n.settingsRepairVaultConfirmTitle), findsOneWidget);
    expect(find.text(testL10n.settingsRepairVaultConfirmBody), findsOneWidget);
    await tester.tap(find.text(testL10n.commonActionCancel));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  testWidgets('有未解決問題時結果會說明檔案已保留', (WidgetTester tester) async {
    final VaultRepairReport report = VaultRepairReport(
      entryCount: 2,
      duration: const Duration(seconds: 1),
      finishedAt: DateTime(2026, 8, 18),
      relocatedEntries: 1,
      removedDuplicateEntries: 0,
      tagsAdded: 0,
      relocatedAssets: 1,
      removedOrphanAssets: 0,
      issues: const <VaultRepairIssue>[
        VaultRepairIssue(
          kind: VaultRepairIssueKind.conflictingAsset,
          reference: 'asset-1',
        ),
        VaultRepairIssue(
          kind: VaultRepairIssueKind.cleanupFailure,
          reference: 'assets/old.enc',
        ),
      ],
    );
    await pumpLauncher(
      tester,
      (BuildContext context) => showRepairVaultResultDialog(context, report),
    );

    expect(find.text(testL10n.settingsRepairVaultResultTitle), findsOneWidget);
    expect(
      find.text(testL10n.settingsRepairVaultResultWarning(2)),
      findsOneWidget,
    );
    expect(find.textContaining('相關檔案都已保留'), findsOneWidget);
    expect(
      find.text(
        testL10n.settingsRepairVaultResultIssueCount(
          testL10n.settingsRepairIssueConflictingAsset,
          1,
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        testL10n.settingsRepairVaultResultIssueCount(
          testL10n.settingsRepairIssueCleanupFailure,
          1,
        ),
      ),
      findsOneWidget,
    );
    expect(find.text(testL10n.settingsRepairIssueMissingAsset), findsNothing);
  });

  testWidgets('沒有問題時結果不顯示 issue 清單', (WidgetTester tester) async {
    final VaultRepairReport report = VaultRepairReport(
      entryCount: 1,
      duration: const Duration(milliseconds: 20),
      finishedAt: DateTime(2026, 8, 18),
      relocatedEntries: 0,
      removedDuplicateEntries: 0,
      tagsAdded: 0,
      relocatedAssets: 0,
      removedOrphanAssets: 0,
    );

    await pumpLauncher(
      tester,
      (BuildContext context) => showRepairVaultResultDialog(context, report),
    );

    expect(find.text(testL10n.settingsRepairVaultResultClean), findsOneWidget);
    expect(
      find.text(testL10n.settingsRepairVaultResultCheckedEntries(1)),
      findsOneWidget,
    );
    expect(find.textContaining('0 個'), findsNothing);
    expect(find.textContaining('：1 個'), findsNothing);
  });
}
