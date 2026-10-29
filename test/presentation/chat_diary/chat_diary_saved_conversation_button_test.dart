import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/chat_diary/chat_diary_providers.dart';
import 'package:quill_diary/domain/chat_diary/chat_diary_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/chat_diary/chat_diary_saved_conversation_button.dart';

import '../../helpers/ai/ai_test_helpers.dart';
import '../../helpers/app_test_theme.dart';

Widget _app({
  required String entryId,
  required ChatDiarySession? chat,
  required GoRouter router,
}) {
  return ProviderScope(
    overrides: [
      chatDiaryForEntryProvider.overrideWith((ref, id) async => chat),
    ],
    child: MaterialApp.router(
      theme: appTestTheme(),
      locale: appZhLocale,
      supportedLocales: appSupportedLocales,
      localizationsDelegates: appLocalizationsDelegates,
      routerConfig: router,
    ),
  );
}

GoRouter _router(String entryId) => GoRouter(
  initialLocation: '/editor/$entryId',
  routes: [
    GoRoute(
      path: '/editor/:entryId',
      builder: (_, state) => Scaffold(
        body: ChatDiarySavedConversationButton(
          entryId: state.pathParameters['entryId']!,
        ),
      ),
    ),
    GoRoute(
      path: '/chat-diary/entry/:entryId',
      builder: (_, _) => const Scaffold(body: Text('聊天室')),
    ),
  ],
);

void main() {
  testWidgets('沒有聊天紀錄時不顯示開啟按鈕', (tester) async {
    final entryId = generateEntryId();
    final router = _router(entryId);
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(entryId: entryId, chat: null, router: router));
    await tester.pumpAndSettle();
    expect(find.text('查看保留的對話'), findsNothing);
  });

  testWidgets('日記旁邊有聊天時，檢視頁可以開啟聊天室', (tester) async {
    final entryId = generateEntryId();
    final chat = testChatDiarySession()
      ..finished = true
      ..generatedEntryId = entryId;
    final router = _router(entryId);
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(entryId: entryId, chat: chat, router: router));
    await tester.pumpAndSettle();
    expect(find.text('查看保留的對話'), findsOneWidget);
    await tester.tap(find.text('查看保留的對話'));
    await tester.pumpAndSettle();
    expect(find.text('聊天室'), findsOneWidget);
  });
}
