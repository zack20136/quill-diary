import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/ai/ai_connection_providers.dart';
import 'package:quill_diary/application/chat_diary/chat_diary_providers.dart';
import 'package:quill_diary/application/home/home_browse_state.dart';
import 'package:quill_diary/application/home/home_entry_query_providers.dart';
import 'package:quill_diary/application/session/providers/session_providers.dart';
import 'package:quill_diary/application/session/state/app_session_state.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/infrastructure/database/index_database.dart';
import 'package:quill_diary/infrastructure/storage/storage_providers.dart';
import 'package:quill_diary/presentation/diary/widgets/diary_entry_date_time.dart';
import 'package:quill_diary/presentation/home/widgets/home_chat_diary_draft_card.dart';
import 'package:quill_diary/presentation/home/widgets/home_timeline_pane.dart';

import '../../helpers/ai/ai_test_helpers.dart';
import '../../helpers/shared/entry_index_fixtures.dart';
import '../../helpers/shared/widget_test_app.dart';
import '../../helpers/vault/fake_entry_index_vault_repository.dart';

void main() {
  testWidgets('窄螢幕大字級的聊天草稿可長按全選並取消刪除，不另列完成聊天', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    const state = AppSessionState(
      status: AppLockStatus.unlocked,
      session: UnlockedVaultSession(vaultId: 'vault', trustedDevice: true),
    );
    const firstTitle = '第一份聊天草稿的標題很長，應保持單行並省略超出範圍的內容';
    final first = testChatDiarySession()..composerText = firstTitle;
    final second = testChatDiarySession()..composerText = '第二份聊天草稿';
    final archived = testChatDiarySession()
      ..finished = true
      ..composerText = '保留的完成聊天';
    await tester.pumpWidget(
      widgetTestApp(
        center: false,
        overrides: [
          effectiveAppSessionProvider.overrideWith((_) async => state),
          chatDiarySessionsProvider.overrideWith(
            (_) async => [first, second, archived],
          ),
          homeEntriesProvider.overrideWith(
            (_) => const AsyncData<List<EntryIndexRecord>>([]),
          ),
          homeEntryIndexListProvider.overrideWith(
            (_) async => const HomeEntryQueryResult(query: '', entries: []),
          ),
          homePinnedEntryIdsProvider.overrideWith((_) async => {}),
        ],
        child: const HomeTimelinePane(sessionState: state),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(HomeChatDiaryDraftCard), findsNWidgets(2));
    expect(find.text(firstTitle), findsOneWidget);
    final title = tester.widget<Text>(find.text(firstTitle));
    expect(title.maxLines, 1);
    expect(title.overflow, TextOverflow.ellipsis);
    expect(find.text('第二份聊天草稿'), findsOneWidget);
    expect(find.text('草稿'), findsNWidgets(2));
    expect(find.text('聊天日記草稿'), findsNothing);
    final firstCard = find.byType(HomeChatDiaryDraftCard).first;
    final chatIcon = find.descendant(
      of: firstCard,
      matching: find.byIcon(Icons.chat_bubble_outline),
    );
    expect(
      tester.getCenter(chatIcon).dy,
      closeTo(tester.getCenter(find.text(firstTitle)).dy, 0.1),
    );
    expect(find.byIcon(Icons.chat_bubble_outline), findsNWidgets(2));
    expect(find.text('保留的完成聊天'), findsNothing);
    expect(find.byType(DiaryEntryDateTime), findsNWidgets(2));
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    await tester.longPress(find.text(firstTitle));
    await tester.pumpAndSettle();
    expect(find.text('已選 1 項'), findsOneWidget);
    expect(find.byType(HomeChatDiaryDraftCard), findsNWidgets(2));
    await tester.tap(find.byTooltip('全選'));
    await tester.pumpAndSettle();
    expect(find.text('已選 2 項'), findsOneWidget);
    await tester.tap(find.byTooltip('刪除'));
    await tester.pumpAndSettle();
    expect(find.textContaining('選取的 2 個項目'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeChatDiaryDraftCard), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
  for (final failSecondChat in [false, true]) {
    testWidgets('混合多選日記與聊天草稿${failSecondChat ? '部分刪除失敗後可重試' : '只刪除選取項目'}', (
      tester,
    ) async {
      const session = UnlockedVaultSession(
        vaultId: 'vault',
        trustedDevice: true,
      );
      const state = AppSessionState(
        status: AppLockStatus.unlocked,
        session: session,
      );
      final first = testChatDiarySession()..composerText = '聊天甲';
      final second = testChatDiarySession()..composerText = '聊天乙';
      final store = MemoryChatDiaryStore()
        ..storedChats[first.id] = jsonEncode(first.toJson())
        ..storedChats[second.id] = jsonEncode(second.toJson())
        ..failingDeleteId = failSecondChat ? second.id : null;
      final repository = FakeEntryIndexVaultRepository(
        allEntries: [
          buildEntryIndexRecord(id: 'entry-a', title: '正式日記甲', tags: []),
          buildEntryIndexRecord(id: 'entry-b', title: '正式日記乙', tags: []),
        ],
      );
      await tester.pumpWidget(
        widgetTestApp(
          center: false,
          overrides: [
            effectiveAppSessionProvider.overrideWith((_) async => state),
            chatDiaryStoreProvider.overrideWithValue(store),
            chatDiarySessionsProvider.overrideWith((_) => store.list(session)),
            aiConnectionSettingsStoreProvider.overrideWithValue(
              MemoryAiConnectionSettingsStore(),
            ),
            vaultRepositoryProvider.overrideWithValue(repository),
            homeEntryIndexListProvider.overrideWith(
              (_) async => HomeEntryQueryResult(
                query: '',
                entries: List.of(repository.allEntries),
              ),
            ),
            homePinnedEntryIdsProvider.overrideWith((_) async => {}),
          ],
          child: const HomeTimelinePane(sessionState: state),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomeTimelinePane)),
      );
      await tester.longPress(find.text('聊天甲'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('聊天乙'));
      await tester.tap(find.text('正式日記甲'));
      await tester.pumpAndSettle();
      expect(find.text('已選 3 項'), findsOneWidget);
      expect(find.byIcon(Icons.html), findsNothing);
      expect(find.byTooltip('釘選'), findsNothing);
      await tester.tap(find.byTooltip('刪除'));
      await tester.pumpAndSettle();
      expect(find.textContaining('選取的 3 個項目'), findsOneWidget);
      await tester.tap(find.text('刪除'));
      await tester.pumpAndSettle();
      expect(repository.allEntries.map((entry) => entry.id), ['entry-b']);
      if (failSecondChat) {
        expect(store.storedChats.keys, [second.id]);
        final remaining = container.read(homeEntrySelectionProvider);
        expect(remaining.selectedIds, isEmpty);
        expect(remaining.selectedChatIds, {second.id});
        expect(find.text('操作失敗，請稍後再試。'), findsOneWidget);
        store.failingDeleteId = null;
        await tester.tap(find.byTooltip('刪除'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('刪除'));
        await tester.pumpAndSettle();
      }
      expect(store.storedChats, isEmpty);
      expect(container.read(homeEntrySelectionProvider).isActive, isFalse);
      expect(find.text('正式日記乙'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
