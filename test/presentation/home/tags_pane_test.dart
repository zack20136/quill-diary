import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/errors/user_facing_error.dart';
import 'package:quill_diary/application/home/home_browse_state.dart';
import 'package:quill_diary/application/session/session_state.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/presentation/home/widgets/home_selection_toolbar.dart';
import 'package:quill_diary/presentation/tag/widgets/tag_accent_composer_dialog.dart';
import 'package:quill_diary/shared/presentation/widgets/accent_chip.dart';
import 'package:quill_diary/shared/presentation/widgets/accent_color_wheel_dialog.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_shell.dart';

import '../../helpers/presentation/home/tag_test_scope.dart';
import '../../helpers/shared/test_l10n.dart';

void main() {
  late TagTestRepository repository;
  late ProviderContainer container;

  Future<void> open(WidgetTester tester, {List<String>? labels}) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    repository = labels == null
        ? TagTestRepository()
        : TagTestRepository(labels: labels);
    container = tagTestContainer(repository);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    });
    await tester.pumpWidget(tagTestApp(container));
    await tester.pumpAndSettle();
  }

  Finder row(String label) =>
      find.byKey(ValueKey('tag-row-${label.toLowerCase()}'));
  Finder dialogAction(String label) => find.descendant(
    of: find.byType(AppConfirmDialog),
    matching: find.widgetWithText(TextButton, label),
  );
  HomeSelectionToolbar toolbar(WidgetTester tester) =>
      tester.widget<HomeSelectionToolbar>(find.byType(HomeSelectionToolbar));

  Future<void> requestDelete(WidgetTester tester) async {
    await tester.tap(find.byTooltip(testL10n.commonActionDelete));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> confirmDelete(WidgetTester tester) async {
    await tester.tap(
      find.descendant(
        of: find.byType(AppConfirmDialog),
        matching: find.widgetWithText(
          FilledButton,
          testL10n.commonActionDelete,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('查無標籤時可從空狀態清除搜尋並回到原清單', (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextField).first, '查無此標籤');
    await tester.pumpAndSettle();
    expect(find.text(testL10n.commonNoTagSearchResults), findsOneWidget);
    await tester.tap(find.text(testL10n.commonClearSearchTooltip));
    await tester.pumpAndSettle();
    expect(row('Alpha').hitTestable(), findsOneWidget);
  });

  testWidgets('鉛筆只開啟編輯，取消刪除保留未存名稱、選色與原本預覽', (tester) async {
    await open(tester);
    expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
    await tester.tap(row('Alpha'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: row('Beta'),
        matching: find.byTooltip(testL10n.homeTooltipEditTag),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TagAccentComposerDialog), findsOneWidget);
    final cancel = find.widgetWithText(TextButton, testL10n.commonActionCancel);
    final save = find.widgetWithText(FilledButton, testL10n.tagSaveButton);
    expect(cancel, findsOneWidget);
    expect(
      find.descendant(of: save, matching: find.byType(Icon)),
      findsNothing,
    );
    expect(
      tester.getTopLeft(find.byTooltip(testL10n.commonActionDelete)).dx,
      lessThan(tester.getTopLeft(cancel).dx),
    );
    await tester.enterText(find.byType(TextField).last, 'Changed');
    await tester.tap(find.byKey(const Key('tag-color-preset-1')));
    await tester.pumpAndSettle();
    final preview = find.descendant(
      of: find.byType(TagAccentComposerDialog),
      matching: find.byType(AccentChip),
    );
    final accent = tester.widget<AccentChip>(preview).colors.accent;
    await tester.tap(find.text(testL10n.tagCustomColorLabel));
    await tester.pumpAndSettle();
    final colorSave = find.descendant(
      of: find.byType(AccentColorWheelDialog),
      matching: find.widgetWithText(FilledButton, testL10n.tagSaveButton),
    );
    expect(
      find.descendant(of: colorSave, matching: find.byType(Icon)),
      findsNothing,
    );
    await tester.tap(colorSave);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(testL10n.commonActionDelete));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(testL10n.homeDeleteTagConfirm('Beta')), findsOneWidget);
    await tester.tap(dialogAction(testL10n.commonActionCancel));
    await tester.pumpAndSettle();
    expect(repository.deleteCalls, isEmpty);
    expect(find.byType(TagAccentComposerDialog), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).last).controller!.text,
      'Changed',
    );
    expect(tester.widget<AccentChip>(preview).colors.accent, accent);
    await tester.tap(cancel);
    await tester.pumpAndSettle();
    expect(find.text(testL10n.homeDiarySectionTag('Alpha')), findsOneWidget);
    await tester.tap(find.byTooltip(testL10n.homeTooltipAddTag));
    await tester.pumpAndSettle();
    expect(find.byTooltip(testL10n.commonActionDelete), findsNothing);
  });

  testWidgets('長按與勾選不改日記預覽，退出與返回鍵只結束標籤多選', (tester) async {
    await open(tester);
    await tester.tap(row('Alpha'));
    await tester.pumpAndSettle();
    await tester.longPress(row('Beta'));
    await tester.pumpAndSettle();
    expect(toolbar(tester).selectedCount, 1);
    expect(find.byTooltip(testL10n.homeTooltipEditTag), findsNothing);
    expect(find.text(testL10n.homeTagRowTapHint), findsNothing);
    await tester.tap(row('Gamma'));
    await tester.pumpAndSettle();
    expect(toolbar(tester).selectedCount, 2);
    expect(find.text(testL10n.homeDiarySectionTag('Alpha')), findsOneWidget);
    expect(container.read(homeEntrySelectionProvider).isActive, isFalse);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(HomeSelectionToolbar), findsNothing);
    expect(find.text(testL10n.homeDiarySectionTag('Alpha')), findsOneWidget);
    await tester.longPress(row('Beta'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(testL10n.homeTooltipDeselectTag));
    await tester.pumpAndSettle();
    expect(find.byType(HomeSelectionToolbar), findsNothing);
  });

  testWidgets('全選只涵蓋搜尋結果，零選取停用刪除並保留搜尋條件', (tester) async {
    await open(tester, labels: ['Alpha', 'Alpine', 'Beta']);
    await tester.enterText(find.byType(TextField), 'Al');
    await tester.pumpAndSettle();
    expect(row('Beta'), findsNothing);
    await tester.longPress(row('Alpha'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.byTooltip(testL10n.homeSelectionSelectAll));
    await tester.pumpAndSettle();
    expect(toolbar(tester).selectedCount, 2);
    await tester.tap(find.byTooltip(testL10n.homeSelectionDeselectAll));
    await tester.pumpAndSettle();
    expect(toolbar(tester).selectedCount, 0);
    final delete = tester.widget<IconButton>(
      find.byKey(Key('home-selection-action-${testL10n.commonActionDelete}')),
    );
    expect(delete.onPressed, isNull);
    await tester.tap(find.byTooltip(testL10n.homeTooltipDeselectTag));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Al',
    );
  });

  testWidgets('批次只確認一次，取消保留勾選，處理中停用操作且成功清除預覽', (tester) async {
    await open(tester);
    await tester.tap(row('Alpha'));
    await tester.pumpAndSettle();
    await tester.longPress(row('Alpha'));
    await tester.tap(row('Beta'));
    await tester.pumpAndSettle();
    await requestDelete(tester);
    expect(find.byType(AppConfirmDialog), findsOneWidget);
    expect(find.text('Alpha\nBeta'), findsOneWidget);
    expect(repository.deleteCalls, isEmpty);
    await tester.tap(dialogAction(testL10n.commonActionCancel));
    await tester.pumpAndSettle();
    expect(toolbar(tester).selectedCount, 2);
    repository.deleteGate = Completer<void>();
    await requestDelete(tester);
    await confirmDelete(tester);
    expect(repository.deleteCalls, ['Alpha']);
    expect(toolbar(tester).enabled, isFalse);
    expect(
      tester
          .widgetList<IconButton>(
            find.descendant(
              of: find.byType(HomeSelectionToolbar),
              matching: find.byType(IconButton),
            ),
          )
          .every((button) => button.onPressed == null),
      isTrue,
    );
    await tester.tap(row('Gamma'));
    await tester.pump();
    expect(toolbar(tester).selectedCount, 2);
    repository.deleteGate!.complete();
    await tester.pumpAndSettle();
    expect(repository.deleteCalls, ['Alpha', 'Beta']);
    expect(find.byType(HomeSelectionToolbar), findsNothing);
    expect(row('Alpha'), findsNothing);
    expect(row('Beta'), findsNothing);
    expect(row('Gamma'), findsOneWidget);
    expect(find.text(testL10n.homeTagPreviewTitle), findsWidgets);
    expect(repository.allEntries.single.tags, ['Gamma']);
  });

  testWidgets('部分失敗停止後續刪除，刷新後只重試未完成項目', (tester) async {
    await open(tester);
    repository.failOn = 'Beta';
    await tester.longPress(row('Alpha'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(testL10n.homeSelectionSelectAll));
    await tester.pumpAndSettle();
    await requestDelete(tester);
    await confirmDelete(tester);
    await tester.pumpAndSettle();
    expect(repository.deleteCalls, ['Alpha', 'Beta']);
    expect(row('Alpha'), findsNothing);
    expect(toolbar(tester).selectedCount, 2);
    expect(
      find.text(
        testL10n.homeTagsDeletePartial(
          1,
          2,
          userFacingErrorMessage(repository.failure, l10n: testL10n),
        ),
      ),
      findsOneWidget,
    );
    repository.failOn = null;
    await requestDelete(tester);
    await confirmDelete(tester);
    await tester.pumpAndSettle();
    expect(repository.deleteCalls, ['Alpha', 'Beta', 'Beta', 'Gamma']);
    expect(find.byType(HomeSelectionToolbar), findsNothing);
    expect(repository.allEntries, hasLength(1));
  });

  testWidgets('切換分頁清除勾選，已確認的刪除繼續且不恢復舊選取', (tester) async {
    await open(tester);
    repository.deleteGate = Completer<void>();
    await tester.longPress(row('Alpha'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(testL10n.homeSelectionSelectAll));
    await tester.pumpAndSettle();
    await requestDelete(tester);
    await confirmDelete(tester);
    container.read(homeTabProvider.notifier).set(HomeTab.people);
    await tester.pump();
    repository.deleteGate!.complete();
    await tester.pumpAndSettle();
    expect(repository.deleteCalls, ['Alpha', 'Beta', 'Gamma']);
    container.read(homeTabProvider.notifier).set(HomeTab.tags);
    await tester.pumpAndSettle();
    expect(find.byType(HomeSelectionToolbar), findsNothing);
    expect(find.text(testL10n.homeNoTagsTitle), findsOneWidget);
  });

  testWidgets('確認刪除期間換庫，晚到的確認不能刪除舊標籤或恢復多選', (tester) async {
    await open(tester);
    await tester.longPress(row('Alpha'));
    await tester.pumpAndSettle();
    await requestDelete(tester);
    container
        .read(tagTestSessionProvider.notifier)
        .set(
          const AppSessionState(
            status: AppLockStatus.unlocked,
            session: UnlockedVaultSession(
              vaultId: 'another-vault',
              trustedDevice: true,
            ),
          ),
        );
    await tester.pump();
    await confirmDelete(tester);
    await tester.pumpAndSettle();
    expect(repository.deleteCalls, isEmpty);
    expect(find.byType(HomeSelectionToolbar), findsNothing);
  });

  for (final replaceVault in [false, true]) {
    testWidgets('${replaceVault ? '更換日記庫' : '鎖定再解鎖'}停止後續刪除，晚到結果不影響新選取', (
      tester,
    ) async {
      await open(tester);
      repository.deleteGate = Completer<void>();
      await tester.longPress(row('Alpha'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(testL10n.homeSelectionSelectAll));
      await tester.pumpAndSettle();
      await requestDelete(tester);
      await confirmDelete(tester);
      final session = container.read(tagTestSessionProvider.notifier);
      session.set(
        replaceVault
            ? const AppSessionState(
                status: AppLockStatus.unlocked,
                session: UnlockedVaultSession(
                  vaultId: 'new-vault',
                  trustedDevice: true,
                ),
              )
            : const AppSessionState(status: AppLockStatus.locked),
      );
      await tester.pumpAndSettle();
      expect(find.byType(HomeSelectionToolbar), findsNothing);
      if (!replaceVault) {
        session.set(tagTestSession);
        await tester.pumpAndSettle();
      }
      await tester.longPress(row('Beta'));
      await tester.pumpAndSettle();
      repository.deleteGate!.complete();
      await tester.pumpAndSettle();
      expect(repository.deleteCalls, ['Alpha']);
      expect(toolbar(tester).selectedCount, 1);
      expect(tester.widget<ListTile>(row('Beta')).selected, isTrue);
    });
  }
}
