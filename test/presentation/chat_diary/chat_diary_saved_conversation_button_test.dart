import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/chat_diary/chat_diary_providers.dart';
import 'package:quill_diary/domain/chat_diary/chat_diary_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/chat_diary/chat_diary_saved_conversation_button.dart';
import 'package:quill_diary/presentation/editor/widgets/editor_top_bar.dart';

import '../../helpers/ai/ai_test_helpers.dart';
import '../../helpers/app_test_theme.dart';

Widget _app({
  required ChatDiarySession? chat,
  required GoRouter router,
  Future<ChatDiarySession?> Function()? loadChat,
  double textScale = 1,
}) {
  return ProviderScope(
    overrides: [
      chatDiaryForEntryProvider.overrideWith(
        (ref, id) => loadChat != null ? loadChat() : Future.value(chat),
      ),
    ],
    child: MaterialApp.router(
      theme: appTestTheme(),
      locale: appZhLocale,
      supportedLocales: appSupportedLocales,
      localizationsDelegates: appLocalizationsDelegates,
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
    ),
  );
}

GoRouter _router(String entryId) => GoRouter(
  initialLocation: '/editor/$entryId',
  routes: [
    GoRoute(
      path: '/editor/:entryId',
      builder: (_, state) => Scaffold(
        body: EditorTopBar(
          previewMode: true,
          saving: false,
          canSaveEntry: true,
          canDelete: true,
          timestampLabel: '2026/01/02 14:30 · 星期五',
          onClose: () {},
          onSave: null,
          onInvalidSave: null,
          onDelete: () {},
          onEnterEditMode: () {},
          conversationButton: ChatDiarySavedConversationButton(
            entryId: state.pathParameters['entryId']!,
          ),
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
  testWidgets('沒有聊天紀錄仍顯示 AI 按鈕，點擊顯示提示並留在日記', (tester) async {
    final entryId = generateEntryId();
    final router = _router(entryId);
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(chat: null, router: router));
    await tester.pumpAndSettle();
    expect(find.text('查看保留的對話'), findsNothing);
    expect(find.text('AI'), findsOneWidget);
    await tester.tap(find.byTooltip('查看保留的對話'));
    await tester.pumpAndSettle();
    expect(find.text('這篇日記沒有保留的對話。'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, '/editor/$entryId');
  });

  testWidgets('日記旁邊有聊天時，檢視頁可以開啟聊天室', (tester) async {
    final entryId = generateEntryId();
    final chat = testChatDiarySession()
      ..finished = true
      ..generatedEntryId = entryId;
    final router = _router(entryId);
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(chat: chat, router: router));
    await tester.pumpAndSettle();
    expect(find.text('AI'), findsOneWidget);
    await tester.tap(find.byTooltip('查看保留的對話'));
    await tester.pumpAndSettle();
    expect(find.text('聊天室'), findsOneWidget);
  });

  testWidgets('載入時保留 AI 按鈕位置並停用，讀取失敗可提示並重試', (tester) async {
    final entryId = generateEntryId();
    final router = _router(entryId);
    addTearDown(router.dispose);
    final reading = Completer<ChatDiarySession?>();
    var reads = 0;
    await tester.pumpWidget(
      _app(
        chat: null,
        router: router,
        loadChat: () => reads++ == 0 ? reading.future : Future.value(null),
      ),
    );
    final button = find.byTooltip('查看保留的對話');
    expect(find.text('AI'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.ancestor(of: button, matching: find.byType(IconButton)),
          )
          .onPressed,
      isNull,
    );
    reading.completeError(StateError('合成讀取失敗'));
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('無法保存進度，請確認儲存空間後重試。'), findsOneWidget);
    expect(reads, 2);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('這篇日記沒有保留的對話。'), findsOneWidget);
  });

  testWidgets('窄螢幕放大文字時 AI 位於編輯左側，日期與按鈕不溢位', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = _router(generateEntryId());
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(chat: null, router: router, textScale: 2));
    await tester.pumpAndSettle();
    final button = find.byTooltip('查看保留的對話');
    final edit = find.byKey(const Key('editor-top-bar-edit'));
    expect(tester.getTopLeft(button).dx, lessThan(tester.getTopLeft(edit).dx));
    expect(tester.getSize(button), const Size(44, 44));
    expect(find.text('2026/01/02 14:30 · 星期五'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
