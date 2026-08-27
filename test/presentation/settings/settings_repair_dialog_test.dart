import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/storage/vault_maintenance_models.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';
import 'package:quill_diary/presentation/settings/widgets/settings_action_dialogs.dart';

import '../../helpers/app_test_theme.dart';
import '../../helpers/shared/test_l10n.dart';
import '../../helpers/shared/widget_test_app.dart';

void main() {
  Future<void> pumpLauncher(
    WidgetTester tester,
    Future<void> Function(BuildContext context) launch,
  ) async {
    await tester.pumpWidget(
      widgetTestApp(
        center: false,
        child: Builder(
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

  testWidgets('檢查前確認顯示目前狀態與上次修復摘要', (WidgetTester tester) async {
    bool? emptyResult;
    await pumpLauncher(tester, (BuildContext context) async {
      emptyResult = await showInspectVaultConfirmDialog(context);
    });
    expect(
      find.text(testL10n.settingsInspectVaultConfirmTitle),
      findsOneWidget,
    );
    expect(find.text(testL10n.settingsInspectVaultConfirmBody), findsOneWidget);
    expect(
      find.text(testL10n.settingsInspectVaultPreflightNoRepair),
      findsOneWidget,
    );
    await tester.tap(find.text(testL10n.settingsInspectVaultConfirmButton));
    await tester.pumpAndSettle();
    expect(emptyResult, isTrue);

    bool? cancelled;
    await pumpLauncher(tester, (BuildContext context) async {
      cancelled = await showInspectVaultConfirmDialog(
        context,
        lastRepairSummary: VaultRepairSummary(
          entryCount: 4,
          finishedAt: DateTime(2026, 8, 18, 10),
          issueCounts: const <VaultRepairIssueKind, int>{},
          relocatedEntries: 1,
          removedBrokenReferences: 2,
          backupFileName: 'backup_before_repair_demo.zip',
        ),
      );
    });
    expect(
      find.textContaining('backup_before_repair_demo.zip'),
      findsOneWidget,
    );
    expect(
      find.text(testL10n.settingsInspectVaultPreflightLastRepair),
      findsOneWidget,
    );
    await tester.tap(find.text(testL10n.commonActionCancel));
    await tester.pumpAndSettle();
    expect(cancelled, isFalse);
  });

  testWidgets('只有檢查摘要且無修復紀錄時可開始檢查', (WidgetTester tester) async {
    bool? result;
    await pumpLauncher(tester, (BuildContext context) async {
      result = await showInspectVaultConfirmDialog(context);
    });

    expect(
      find.text(testL10n.settingsInspectVaultPreflightCurrent),
      findsNothing,
    );
    expect(
      find.text(testL10n.settingsInspectVaultPreflightLastRepair),
      findsNothing,
    );
    expect(
      find.text(testL10n.settingsInspectVaultPreflightNoRepair),
      findsOneWidget,
    );
    expect(
      find.text(testL10n.settingsInspectVaultConfirmButton),
      findsOneWidget,
    );
    await tester.tap(find.text(testL10n.settingsInspectVaultConfirmButton));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('檢查前確認只顯示上次修復不顯示目前狀態', (WidgetTester tester) async {
    await pumpLauncher(tester, (BuildContext context) async {
      await showInspectVaultConfirmDialog(
        context,
        repairSummary: VaultRepairSummary(
          entryCount: 1,
          finishedAt: DateTime(2026, 8, 20, 10),
          issueCounts: const <VaultRepairIssueKind, int>{},
          backupFileName: 'older-repair.zip',
        ),
      );
    });

    expect(
      find.text(testL10n.settingsInspectVaultPreflightCurrent),
      findsNothing,
    );
    expect(
      find.text(testL10n.settingsInspectVaultPreflightSourceInspect),
      findsNothing,
    );
    expect(
      find.text(testL10n.settingsInspectVaultPreflightLastRepair),
      findsOneWidget,
    );
    expect(find.textContaining('older-repair.zip'), findsOneWidget);
  });

  testWidgets('較新的乾淨檢查不會隱藏較舊修復的問題與明細', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final VaultFinding finding = const VaultFinding(
      kind: VaultRepairIssueKind.unreadableEntry,
      plannedAction: VaultPlannedAction.quarantine,
      manualAction: VaultManualAction.restoreFromBackup,
      canOpenEntry: false,
      entryTitle: '仍需處理的日記',
      internalReference: 'entries/problem.md.enc',
    );
    await pumpLauncher(tester, (BuildContext context) async {
      await showInspectVaultConfirmDialog(
        context,
        repairSummary: VaultRepairSummary(
          entryCount: 1,
          finishedAt: DateTime(2026, 8, 20, 10),
          issueCounts: const <VaultRepairIssueKind, int>{
            VaultRepairIssueKind.unreadableEntry: 1,
          },
          findings: <VaultFinding>[finding],
        ),
      );
    });

    expect(
      find.text(testL10n.settingsInspectVaultPreflightCurrent),
      findsNothing,
    );
    expect(
      find.text(testL10n.settingsLastRepairLogUnresolved(1)),
      findsOneWidget,
    );
    expect(find.text(testL10n.settingsRepairDetailButton), findsOneWidget);
    final Finder dialogSurfaces = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byWidgetPredicate(
        (Widget widget) =>
            widget is Material && widget.type == MaterialType.card,
      ),
    );
    expect(tester.getSize(dialogSurfaces).width, 720);
    await tester.tap(find.text(testL10n.settingsRepairDetailButton));
    await tester.pumpAndSettle();
    expect(tester.getSize(dialogSurfaces.last).width, 640);
    expect(find.text(testL10n.settingsRepairDetailUnresolved), findsOneWidget);
    expect(find.text('仍需處理的日記'), findsOneWidget);
  });

  testWidgets('自動處理失敗只出現在仍需處理不出現在已完成', (WidgetTester tester) async {
    await pumpLauncher(tester, (BuildContext context) async {
      await showRepairDetailDialog(
        context,
        VaultRepairSummary(
          entryCount: 1,
          finishedAt: DateTime(2026, 8, 20, 10),
          issueCounts: const <VaultRepairIssueKind, int>{
            VaultRepairIssueKind.cleanupFailure: 1,
          },
          entryActionLogs: const <VaultRepairEntryActionLog>[
            VaultRepairEntryActionLog(
              title: '失敗日記',
              date: DateOnly('2026-08-01'),
              cleanupFailures: 1,
            ),
          ],
          findings: const <VaultFinding>[
            VaultFinding(
              kind: VaultRepairIssueKind.cleanupFailure,
              plannedAction: VaultPlannedAction.quarantine,
              manualAction: VaultManualAction.none,
              canOpenEntry: false,
              entryTitle: '失敗日記',
              entryDate: DateOnly('2026-08-01'),
              internalReference: 'entries/fail.md.enc',
            ),
          ],
        ),
      );
    });

    expect(find.text(testL10n.settingsRepairDetailCompleted), findsNothing);
    expect(
      find.text(testL10n.settingsRepairDetailCleanupFailures(1)),
      findsNothing,
    );
    expect(find.text(testL10n.settingsRepairDetailUnresolved), findsOneWidget);
    expect(find.text('失敗日記'), findsOneWidget);
  });

  testWidgets('舊摘要沒有逐篇紀錄時會以彙總與未解決問題顯示明細', (WidgetTester tester) async {
    await pumpLauncher(tester, (BuildContext context) async {
      await showInspectVaultConfirmDialog(
        context,
        repairSummary: VaultRepairSummary(
          entryCount: 2,
          finishedAt: DateTime(2026, 8, 20, 10),
          issueCounts: <VaultRepairIssueKind, int>{
            VaultRepairIssueKind.unreadableEntry: 1,
          },
          relocatedEntries: 1,
          findings: <VaultFinding>[
            VaultFinding(
              kind: VaultRepairIssueKind.unreadableEntry,
              plannedAction: VaultPlannedAction.quarantine,
              manualAction: VaultManualAction.restoreFromBackup,
              canOpenEntry: false,
              entryTitle: '仍需處理',
              internalReference: 'entries/problem.md.enc',
            ),
          ],
        ),
      );
    });

    await tester.tap(find.text(testL10n.settingsRepairDetailButton));
    await tester.pumpAndSettle();
    expect(
      find.text(testL10n.settingsRepairDetailAggregateFallback),
      findsOneWidget,
    );
    expect(find.text('仍需處理'), findsNWidgets(2));
    expect(
      find.text(testL10n.settingsRepairDetailUnresolved),
      findsNWidgets(2),
    );
  });

  testWidgets('修復完成且無未解決項時詳細資料不顯示仍需處理', (WidgetTester tester) async {
    final VaultRepairReport report = VaultRepairReport(
      entryCount: 2,
      duration: const Duration(seconds: 1),
      finishedAt: DateTime(2026, 8, 20, 10),
      relocatedEntries: 0,
      removedDuplicateEntries: 0,
      tagsAdded: 0,
      relocatedAssets: 0,
      removedOrphanAssets: 0,
      purgedBadAssets: 2,
      findings: const <VaultFinding>[
        VaultFinding(
          kind: VaultRepairIssueKind.assetIdentityMismatch,
          plannedAction: VaultPlannedAction.removeReference,
          manualAction: VaultManualAction.none,
          canOpenEntry: true,
          entryTitle: 'P的謊言 感想',
          entryDate: DateOnly('2025-08-02'),
          internalReference: 'assets/bad1.png.enc',
        ),
      ],
      unresolvedFindings: const <VaultFinding>[],
      entryActionLogs: const <VaultRepairEntryActionLog>[
        VaultRepairEntryActionLog(
          title: 'P的謊言 感想',
          date: DateOnly('2025-08-02'),
          purgedBadAttachments: 1,
        ),
      ],
    );
    await pumpLauncher(tester, (BuildContext context) async {
      await showRepairVaultResultDialog(
        context: context,
        report: report,
        canSalvage: (_) async => false,
        onSalvage: (_) async => null,
        onDelete: (_) async => false,
      );
    });

    expect(find.text(testL10n.settingsRepairVaultResultClean), findsOneWidget);
    await tester.tap(find.text(testL10n.settingsRepairDetailButton));
    await tester.pumpAndSettle();
    expect(find.text(testL10n.settingsRepairDetailCompleted), findsOneWidget);
    expect(find.text(testL10n.settingsRepairDetailUnresolved), findsNothing);
    expect(
      find.text(testL10n.settingsRepairIssueAssetIdentityMismatch),
      findsNothing,
    );
  });

  testWidgets('完全空的修復摘要不顯示明細按鈕', (WidgetTester tester) async {
    await pumpLauncher(tester, (BuildContext context) async {
      await showInspectVaultConfirmDialog(
        context,
        repairSummary: VaultRepairSummary(
          entryCount: 0,
          finishedAt: DateTime(2026, 8, 20, 10),
          issueCounts: <VaultRepairIssueKind, int>{},
        ),
      );
    });

    expect(
      find.text(testL10n.settingsInspectVaultPreflightLastRepair),
      findsOneWidget,
    );
    expect(find.text(testL10n.settingsRepairDetailButton), findsNothing);
  });

  testWidgets('修復明細會顯示清除舊隔離檔數量', (WidgetTester tester) async {
    final VaultRepairReport report = VaultRepairReport(
      entryCount: 1,
      duration: const Duration(seconds: 1),
      finishedAt: DateTime(2026, 8, 20, 10),
      relocatedEntries: 0,
      removedDuplicateEntries: 0,
      tagsAdded: 0,
      relocatedAssets: 0,
      removedOrphanAssets: 0,
      purgedOldQuarantine: 2,
    );
    await pumpLauncher(tester, (BuildContext context) async {
      await showRepairVaultResultDialog(
        context: context,
        report: report,
        canSalvage: (_) async => false,
        onSalvage: (_) async => null,
        onDelete: (_) async => false,
      );
    });

    expect(find.text(testL10n.settingsRepairDetailButton), findsOneWidget);
    await tester.tap(find.text(testL10n.settingsRepairDetailButton));
    await tester.pumpAndSettle();
    expect(
      find.text(testL10n.settingsRepairDetailPurgedOldQuarantine(2)),
      findsNWidgets(2),
    );
  });

  testWidgets('檢查無異常時只顯示關閉且沒有修復按鈕', (WidgetTester tester) async {
    bool? result;
    await pumpLauncher(tester, (BuildContext context) async {
      result = await showInspectVaultResultDialog(
        context,
        VaultInspectReport(
          entryCount: 3,
          duration: const Duration(milliseconds: 10),
          finishedAt: DateTime(2026, 8, 18),
          findings: const <VaultFinding>[],
        ),
      );
    });

    expect(find.text(testL10n.settingsInspectVaultResultTitle), findsOneWidget);
    expect(find.text(testL10n.settingsInspectVaultResultClean), findsOneWidget);
    expect(
      find.text(testL10n.settingsInspectVaultRepairAfterBackupButton),
      findsNothing,
    );
    expect(
      find.text(testL10n.settingsInspectVaultPlannedRemoveReference),
      findsNothing,
    );
    await tester.tap(find.text(testL10n.commonActionClose));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  testWidgets('檢查有異常時列出全部日記且不顯示預計動作教學', (WidgetTester tester) async {
    bool? result;
    const String hiddenId = 'entry_HIDDEN_ID';
    const String hiddenPath = 'entries/2026/08/broken.md.enc';
    await pumpLauncher(tester, (BuildContext context) async {
      result = await showInspectVaultResultDialog(
        context,
        VaultInspectReport(
          entryCount: 5,
          duration: const Duration(milliseconds: 10),
          finishedAt: DateTime(2026, 8, 18),
          findings: <VaultFinding>[
            for (var index = 0; index < 4; index++)
              VaultFinding(
                kind: VaultRepairIssueKind.missingAsset,
                plannedAction: VaultPlannedAction.removeReference,
                manualAction: VaultManualAction.openAndReuploadAttachment,
                canOpenEntry: true,
                entryId: 'entry_$index',
                entryTitle: '日記 $index',
                entryDate: const DateOnly('2026-08-01'),
                internalReference: hiddenPath,
              ),
            const VaultFinding(
              kind: VaultRepairIssueKind.missingAsset,
              plannedAction: VaultPlannedAction.removeReference,
              manualAction: VaultManualAction.openAndReuploadAttachment,
              canOpenEntry: true,
              entryId: hiddenId,
              entryTitle: '週末散步',
              entryDate: DateOnly('2026-08-01'),
              internalReference: hiddenPath,
            ),
          ],
        ),
      );
    });

    expect(find.text('日記 0'), findsOneWidget);
    expect(find.text('日記 1'), findsOneWidget);
    expect(find.text('日記 2'), findsOneWidget);
    expect(find.text('日記 3'), findsOneWidget);
    expect(find.text('週末散步'), findsOneWidget);
    expect(find.textContaining(hiddenId), findsNothing);
    expect(find.textContaining(hiddenPath), findsNothing);
    expect(
      find.text(testL10n.settingsInspectVaultPlannedRemoveReference),
      findsNothing,
    );
    expect(
      find.text(testL10n.settingsInspectVaultRepairAfterBackupButton),
      findsOneWidget,
    );
    await tester.tap(
      find.text(testL10n.settingsInspectVaultRepairAfterBackupButton),
    );
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('檢查前確認與修復完成皆可開啟詳細資料', (WidgetTester tester) async {
    await pumpLauncher(tester, (BuildContext context) async {
      await showInspectVaultConfirmDialog(
        context,
        lastRepairSummary: VaultRepairSummary(
          entryCount: 2,
          finishedAt: DateTime(2026, 8, 18, 10),
          issueCounts: const <VaultRepairIssueKind, int>{},
          recoveredAttachments: 1,
          removedOrphanAssets: 1,
          entryActionLogs: const <VaultRepairEntryActionLog>[
            VaultRepairEntryActionLog(
              title: '週末散步',
              date: DateOnly('2026-08-01'),
              recoveredAttachments: 1,
              removedMissingAttachments: 2,
            ),
          ],
        ),
      );
    });
    expect(find.text(testL10n.settingsRepairDetailButton), findsOneWidget);
    await tester.tap(find.text(testL10n.settingsRepairDetailButton));
    await tester.pumpAndSettle();
    expect(find.text(testL10n.settingsRepairDetailTitle), findsOneWidget);
    expect(find.textContaining('週末散步'), findsWidgets);
    expect(
      find.text(testL10n.settingsRepairDetailRecoveredAttachments(1)),
      findsOneWidget,
    );
    expect(
      find.text(testL10n.settingsRepairDetailRemovedMissingAttachments(2)),
      findsOneWidget,
    );
    await tester.tap(find.text(testL10n.commonActionClose).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(testL10n.commonActionCancel));
    await tester.pumpAndSettle();

    final VaultRepairReport report = VaultRepairReport(
      entryCount: 1,
      duration: const Duration(seconds: 1),
      finishedAt: DateTime(2026, 8, 18),
      relocatedEntries: 0,
      removedDuplicateEntries: 0,
      tagsAdded: 0,
      relocatedAssets: 0,
      removedOrphanAssets: 1,
      purgedBadAssets: 1,
      entryActionLogs: const <VaultRepairEntryActionLog>[
        VaultRepairEntryActionLog(
          title: '修好的日記',
          date: DateOnly('2026-08-02'),
          purgedBadAttachments: 1,
        ),
      ],
      unresolvedFindings: const <VaultFinding>[],
    );
    await pumpLauncher(tester, (BuildContext context) async {
      await showRepairVaultResultDialog(
        context: context,
        report: report,
        canSalvage: (_) async => false,
        onSalvage: (_) async => null,
        onDelete: (_) async => false,
      );
    });
    expect(find.text(testL10n.settingsRepairDetailButton), findsOneWidget);
    await tester.tap(find.text(testL10n.settingsRepairDetailButton));
    await tester.pumpAndSettle();
    expect(
      find.text(testL10n.settingsRepairDetailPurgedBadAttachments(1)),
      findsOneWidget,
    );
    await tester.tap(find.text(testL10n.commonActionClose).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(testL10n.commonActionClose));
    await tester.pumpAndSettle();
  });

  testWidgets('修復結果就地提供手動修復與永久刪除，圖片問題不顯示手動按鈕', (WidgetTester tester) async {
    final VaultRepairReport report = VaultRepairReport(
      entryCount: 2,
      duration: const Duration(seconds: 1),
      finishedAt: DateTime(2026, 8, 18),
      relocatedEntries: 1,
      removedDuplicateEntries: 0,
      tagsAdded: 0,
      relocatedAssets: 1,
      removedOrphanAssets: 0,
      quarantinedCount: 1,
      backupFileName: 'backup_before_repair_2026-08-18_10-00-00.zip',
      unresolvedFindings: const <VaultFinding>[
        VaultFinding(
          kind: VaultRepairIssueKind.unreadableEntry,
          plannedAction: VaultPlannedAction.quarantine,
          manualAction: VaultManualAction.restoreFromBackup,
          canOpenEntry: false,
          entryTitle: '壞掉的日記',
          internalReference: 'entries/2026/06/broken.md.enc',
        ),
      ],
    );
    List<VaultFinding>? salvaged;
    List<VaultFinding>? deleted;
    await pumpLauncher(tester, (BuildContext context) async {
      await showRepairVaultResultDialog(
        context: context,
        report: report,
        canSalvage: (_) async => false,
        onSalvage: (List<VaultFinding> findings) async {
          salvaged = findings;
          return null;
        },
        onDelete: (List<VaultFinding> findings) async {
          deleted = findings;
          return true;
        },
      );
    });
    await tester.pumpAndSettle();

    expect(find.text(testL10n.settingsRepairVaultResultTitle), findsOneWidget);
    expect(
      find.text(testL10n.settingsRepairVaultResultWarning(1)),
      findsOneWidget,
    );
    expect(find.textContaining('entries/2026/06/broken.md.enc'), findsNothing);
    expect(
      find.text(testL10n.settingsRepairVaultResultMissingAttachment),
      findsNothing,
    );
    expect(
      find.text(testL10n.settingsRepairVaultResultSalvageButton),
      findsNothing,
    );
    expect(
      find.text(testL10n.settingsAbnormalEntriesDeleteButton),
      findsOneWidget,
    );

    // 改測 canSalvage=true 的日記本體問題才出現手動修復
    await tester.tap(find.text(testL10n.commonActionClose));
    await tester.pumpAndSettle();

    final VaultRepairReport salvageReport = VaultRepairReport(
      entryCount: 1,
      duration: const Duration(seconds: 1),
      finishedAt: DateTime(2026, 8, 18),
      relocatedEntries: 0,
      removedDuplicateEntries: 0,
      tagsAdded: 0,
      relocatedAssets: 0,
      removedOrphanAssets: 0,
      unresolvedFindings: const <VaultFinding>[
        VaultFinding(
          kind: VaultRepairIssueKind.unreadableEntry,
          plannedAction: VaultPlannedAction.quarantine,
          manualAction: VaultManualAction.restoreFromBackup,
          canOpenEntry: false,
          entryTitle: '可搶救的日記',
          entryDate: DateOnly('2026-08-01'),
          internalReference: 'entries/2026/06/salvage.md.enc',
        ),
      ],
    );
    await pumpLauncher(tester, (BuildContext context) async {
      await showRepairVaultResultDialog(
        context: context,
        report: salvageReport,
        canSalvage: (_) async => true,
        onSalvage: (List<VaultFinding> findings) async {
          salvaged = findings;
          return null;
        },
        onDelete: (List<VaultFinding> findings) async {
          deleted = findings;
          return true;
        },
      );
    });

    expect(
      find.text(testL10n.settingsRepairVaultResultSalvageButton),
      findsOneWidget,
    );
    await tester.tap(
      find.text(testL10n.settingsRepairVaultResultSalvageButton),
    );
    await tester.pumpAndSettle();
    expect(salvaged, isNotNull);
    expect(
      find.text(testL10n.settingsRepairVaultResultSalvageFailed),
      findsOneWidget,
    );

    await tester.tap(find.text(testL10n.settingsAbnormalEntriesDeleteButton));
    await tester.pumpAndSettle();
    expect(
      find.text(testL10n.settingsAbnormalEntriesDeleteConfirmTitle),
      findsOneWidget,
    );
    final FilledButton deleteConfirm = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, testL10n.commonActionDelete),
    );
    expect(
      deleteConfirm.style?.backgroundColor?.resolve(const <WidgetState>{}),
      appTestTheme().colorScheme.error,
    );
    await tester.tap(find.text(testL10n.commonActionDelete));
    await tester.pumpAndSettle();
    expect(deleted, isNotNull);
    expect(
      find.text(testL10n.settingsAbnormalEntriesDeleteSuccess),
      findsOneWidget,
    );
  });

  testWidgets('沒有問題時結果只顯示關閉', (WidgetTester tester) async {
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

    await pumpLauncher(tester, (BuildContext context) async {
      await showRepairVaultResultDialog(
        context: context,
        report: report,
        canSalvage: (_) async => false,
        onSalvage: (_) async => null,
        onDelete: (_) async => false,
      );
    });

    expect(find.text(testL10n.settingsRepairVaultResultClean), findsOneWidget);
    expect(
      find.text(testL10n.settingsRepairVaultResultCheckedEntries(1)),
      findsOneWidget,
    );
    expect(
      find.text(testL10n.settingsRepairVaultResultSalvageButton),
      findsNothing,
    );
    expect(
      find.text(testL10n.settingsAbnormalEntriesDeleteButton),
      findsNothing,
    );
  });
}
