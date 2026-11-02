import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/ai/ai_connection_providers.dart';
import 'package:quill_diary/application/chat_diary/chat_diary_providers.dart';
import 'package:quill_diary/application/home/home_entry_commands.dart';
import 'package:quill_diary/application/settings/personalization_providers.dart';
import 'package:quill_diary/application/vault/vault_providers.dart';
import 'package:quill_diary/domain/chat_diary/chat_diary_session.dart';
import 'package:quill_diary/domain/preferences/personalization_preferences.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/preferences/user_preferences.dart';

import '../../helpers/ai/ai_test_helpers.dart';
import '../../helpers/session/fake_session_vault_repository.dart';
import '../../helpers/shared/test_l10n.dart';

void main() {
  for (final generating in [false, true]) {
    testWidgets('首頁刪除${generating ? '生成中' : '回覆中'}的聊天，晚到內容不會重建草稿', (
      tester,
    ) async {
      const session = UnlockedVaultSession(
        vaultId: 'vault',
        trustedDevice: true,
      );
      final chat = testChatDiarySession(hidePersonNames: false);
      if (generating) {
        chat.appendMessage(
          ChatDiaryMessage(
            id: 'user-message',
            isUser: true,
            text: '合成內容',
            outboundText: '合成內容',
          ),
        );
      }
      final store = OverviewChatDiaryStore(chat);
      final stream = StreamController<String>();
      final client = FakeAiClient(chat.connectionConfig)
        ..response = () => stream.stream;
      late WidgetRef ref;
      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            chatDiaryStoreProvider.overrideWithValue(store),
            aiSettingsStoreProvider.overrideWithValue(
              OverviewAiSettingsStore(),
            ),
            aiClientFactoryProvider.overrideWithValue((_, _) => client),
            userPreferencesProvider.overrideWithValue(_HomeChatPreferences()),
            vaultRepositoryProvider.overrideWithValue(
              _RecordingHomeRepository(),
            ),
          ],
          child: Consumer(
            builder: (context, currentRef, _) {
              ref = currentRef;
              container = ProviderScope.containerOf(context);
              return const SizedBox();
            },
          ),
        ),
      );
      final subscription = container.listen(
        chatDiaryControllerProvider(chat.id),
        (_, _) {},
      );
      final controller = container.read(chatDiaryControllerProvider(chat.id));
      await controller.load(chat.id, session);
      if (generating) {
        unawaited(controller.generate(testZhL10n));
      } else {
        controller.updateComposer('等待中的合成內容', []);
        unawaited(controller.send());
      }
      await tester.pump();
      expect(client.calls, hasLength(1));
      subscription.close();
      final deleted = await deleteHomeItems(
        ref,
        session,
        entryIds: {},
        chatIds: {chat.id},
        isSessionCurrent: () => true,
      );
      expect(deleted.chatIds, {chat.id});
      expect(deleted.completed, isTrue);
      expect(client.closed, isTrue);
      stream.add('# 晚到內容\n\n不應留下');
      await stream.close();
      await tester.pumpAndSettle();
      expect(store.storedChats, isEmpty);
      expect(controller.chat, isNull);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('setHomeEntriesPinned 只將指定日記交給 repository', (
    WidgetTester tester,
  ) async {
    final _RecordingHomeRepository repository = _RecordingHomeRepository();
    late WidgetRef ref;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [vaultRepositoryProvider.overrideWithValue(repository)],
        child: Consumer(
          builder: (BuildContext context, WidgetRef currentRef, Widget? _) {
            ref = currentRef;
            return const SizedBox();
          },
        ),
      ),
    );
    await setHomeEntriesPinned(ref, <EntryId>{
      'entry-a',
      'entry-b',
    }, pinned: true);

    expect(repository.pinnedIds, <EntryId>{'entry-a', 'entry-b'});
    expect(repository.pinned, isTrue);
  });
}

class _HomeChatPreferences extends UserPreferences {
  @override
  Future<AppLanguage> get appLocale async => AppLanguage.zh;
  @override
  Future<PersonalizationPreferences> loadPersonalizationPreferences() async =>
      PersonalizationPreferences.defaults;
}

class _RecordingHomeRepository extends FakeSessionVaultRepository {
  Set<EntryId>? pinnedIds;
  bool? pinned;

  @override
  Future<void> setEntriesPinned(
    Iterable<EntryId> entryIds, {
    required bool pinned,
  }) async {
    pinnedIds = entryIds.toSet();
    this.pinned = pinned;
  }
}
