import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/ai/ai_connection_providers.dart';
import 'package:quill_diary/application/chat_diary/chat_diary_providers.dart';
import 'package:quill_diary/application/home/home_entry_query_providers.dart';
import 'package:quill_diary/application/session/app_session_controller.dart';
import 'package:quill_diary/application/session/providers/session_providers.dart';
import 'package:quill_diary/application/session/state/app_session_state.dart';
import 'package:quill_diary/domain/ai/ai_connection_settings.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/infrastructure/ai/ai_client.dart';
import 'package:quill_diary/infrastructure/database/index_database.dart';
import 'package:quill_diary/l10n/l10n.dart';

import '../../ai/ai_test_helpers.dart';
import '../../app_test_theme.dart';

class ChatDiaryNavigationSession extends AppSessionController {
  ChatDiaryNavigationSession({
    this.session = const UnlockedVaultSession(
      vaultId: 'vault',
      trustedDevice: true,
    ),
  });
  final UnlockedVaultSession session;
  @override
  AppSessionState build() =>
      AppSessionState(status: AppLockStatus.unlocked, session: session);
}

Widget chatDiaryNavigationApp({
  required GoRouter router,
  required MemoryChatDiaryStore store,
  required MemoryAiConnectionSettingsStore connections,
  AiClient Function(AiConnectionConfig, String)? clientFactory,
}) => ProviderScope(
  overrides: [
    effectiveAppSessionProvider.overrideWith(
      (_) async => const AppSessionState(
        status: AppLockStatus.unlocked,
        session: UnlockedVaultSession(vaultId: 'vault', trustedDevice: true),
      ),
    ),
    appSessionProvider.overrideWith(ChatDiaryNavigationSession.new),
    aiClientFactoryProvider.overrideWithValue(
      clientFactory ?? (connectionConfig, _) => FakeAiClient(connectionConfig),
    ),
    chatDiaryStoreProvider.overrideWithValue(store),
    aiConnectionSettingsStoreProvider.overrideWithValue(connections),
    chatDiarySettingsStoreProvider.overrideWithValue(
      MemoryChatDiarySettingsStore(),
    ),
    homeEntriesProvider.overrideWith(
      (_) => const AsyncData<List<EntryIndexRecord>>([]),
    ),
    homeEntryIndexListProvider.overrideWith(
      (_) async => const HomeEntryQueryResult(query: '', entries: []),
    ),
    homePinnedEntryIdsProvider.overrideWith((_) async => {}),
  ],
  child: MaterialApp.router(
    routerConfig: router,
    theme: appTestTheme(brightness: Brightness.light),
    locale: appZhLocale,
    supportedLocales: appSupportedLocales,
    localizationsDelegates: appLocalizationsDelegates,
  ),
);
