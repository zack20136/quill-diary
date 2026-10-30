import 'package:go_router/go_router.dart';

import 'package:quill_diary/domain/chat_diary/chat_diary_session.dart';
import 'package:quill_diary/presentation/chat_diary/chat_diary_page.dart';
import 'package:quill_diary/presentation/editor/pages/editor_page.dart';
import 'package:quill_diary/presentation/home/pages/home_page.dart';
import 'package:quill_diary/presentation/people/pages/person_detail_page.dart';
import 'package:quill_diary/presentation/settings/pages/about_page.dart';
import 'package:quill_diary/presentation/settings/pages/personalization_page.dart';
import 'package:quill_diary/presentation/settings/pages/settings_page.dart';
import 'package:quill_diary/presentation/settings/pages/support_page.dart';

import 'package:quill_diary/shared/navigation/app_routes.dart';

abstract final class AppRouter {
  static GoRouter createRouter() {
    return GoRouter(
      initialLocation: AppRoutes.homeRoute,
      routes: <RouteBase>[
        GoRoute(path: AppRoutes.homeRoute, builder: (_, _) => const HomePage()),
        GoRoute(
          path: '${AppRoutes.chatDiaryRoutePrefix}/entry/:entryId',
          builder: (_, state) {
            final entryId = state.pathParameters['entryId'] ?? '';
            return RegExp(r'^jrn_[0-9A-HJKMNP-TV-Z]{26}$').hasMatch(entryId)
                ? ChatDiaryPage(entryId: entryId)
                : const HomePage();
          },
        ),
        GoRoute(
          path: '${AppRoutes.chatDiaryRoutePrefix}/new/:id',
          builder: (_, state) =>
              ChatDiarySession.isValidId(state.pathParameters['id'] ?? '')
              ? ChatDiaryPage(
                  chatId: state.pathParameters['id']!,
                  isNewChat: true,
                )
              : const HomePage(),
        ),
        GoRoute(
          path: '${AppRoutes.chatDiaryRoutePrefix}/:id',
          builder: (_, state) =>
              ChatDiarySession.isValidId(state.pathParameters['id'] ?? '')
              ? ChatDiaryPage(chatId: state.pathParameters['id']!)
              : const HomePage(),
        ),
        GoRoute(
          path: AppRoutes.editorRoute,
          builder: (_, GoRouterState state) => EditorPage(
            salvageToken: state.uri.queryParameters['salvage'],
            chatId:
                ChatDiarySession.isValidId(
                  state.uri.queryParameters['chat'] ?? '',
                )
                ? state.uri.queryParameters['chat']
                : null,
            startInEditMode:
                state.uri.queryParameters['salvage'] != null ||
                state.uri.queryParameters['chat'] != null,
          ),
        ),
        GoRoute(
          path: AppRoutes.editorDetailRoute,
          builder: (_, GoRouterState state) => EditorPage(
            entryId: state.pathParameters['entryId'],
            startInEditMode: state.uri.queryParameters['edit'] == '1',
          ),
        ),
        GoRoute(
          path: AppRoutes.personDetailRoute,
          builder: (_, GoRouterState state) =>
              PersonDetailPage(personId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: AppRoutes.settingsRoute,
          builder: (_, GoRouterState state) => SettingsPage(
            initialFocus: SettingsFocusTarget.tryParse(
              state.uri.queryParameters[SettingsFocusTarget.queryKey],
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.aboutRoute,
          builder: (_, _) => const SettingsAboutPage(),
        ),
        GoRoute(
          path: AppRoutes.personalizationRoute,
          builder: (_, _) => const PersonalizationPage(),
        ),
        GoRoute(
          path: AppRoutes.supportRoute,
          builder: (_, _) => const SupportPage(),
        ),
      ],
    );
  }
}
