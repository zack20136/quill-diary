import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:quill_diary/application/ai/ai_connection_providers.dart';
import 'package:quill_diary/application/chat_diary/chat_diary_providers.dart';
import 'package:quill_diary/application/diary_organization/diary_organization_controller.dart';
import 'package:quill_diary/application/session/session_providers.dart';
import 'package:quill_diary/application/settings/personalization_providers.dart';
import 'package:quill_diary/application/vault/vault_providers.dart';
import 'package:quill_diary/domain/ai/ai_connection_settings.dart';
import 'package:quill_diary/domain/diary/diary_entry.dart';
import 'package:quill_diary/domain/people/person.dart';
import 'package:quill_diary/infrastructure/preferences/user_preferences.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';

import '../ai/ai_test_helpers.dart';
import '../vault/vault_test_harness.dart';

class OrganizationTestScope {
  OrganizationTestScope._();
  late VaultTestHarness harness;
  late RecoverySetupResult setup;
  late ProviderContainer container;
  late DiaryEntry entry;
  late FakeAiClient client;
  late OverviewAiSettingsStore settings;
  late DiaryOrganizationController controller;
  late ProviderSubscription<DiaryOrganizationController> subscription;

  static Future<OrganizationTestScope> create({
    String body = '今天和王小明散步。王小明說天氣很好。',
    bool withPerson = false,
    bool widgetMode = false,
    List<Override> overrides = const [],
  }) async {
    final scope = OrganizationTestScope._();
    scope.harness = await VaultTestHarness.create();
    scope.setup = await scope.harness.repository.setupRecoveryKey();
    final id = await scope.harness.saveSimpleEntry(
      scope.setup,
      markdownBody: body,
    );
    scope.entry = (await scope.harness.repository.loadEntry(
      scope.setup.session,
      id,
    ))!;
    if (withPerson) {
      await scope.harness.repository.createPerson(
        scope.setup.session,
        PersonDraft(name: '王小明', aliases: ['小明']),
      );
    }
    final config = testChatDiarySession().connectionConfig;
    scope.client = FakeAiClient(config);
    scope.settings = OverviewAiSettingsStore()
      ..settings = AiConnectionSettings(
        activeConnectionId: config.connectionId,
        connections: {config.connectionId: config},
      );
    scope.container = ProviderContainer(
      overrides: [
        ...overrides,
        if (widgetMode)
          organizationDraftProvider.overrideWith((ref, id) async => null),
        if (widgetMode)
          chatDiaryForEntryProvider.overrideWith((ref, id) async => null),
        vaultPathStrategyProvider.overrideWithValue(scope.harness.pathStrategy),
        vaultRepositoryProvider.overrideWithValue(scope.harness.repository),
        aiSettingsStoreProvider.overrideWithValue(scope.settings),
        aiClientFactoryProvider.overrideWithValue((_, _) => scope.client),
        userPreferencesProvider.overrideWithValue(
          UserPreferences(
            storageFile: File('${scope.harness.tempDir.path}/preferences.json'),
          ),
        ),
      ],
    );
    scope.container
        .read(appSessionProvider.notifier)
        .activateSession(scope.setup.session);
    scope.subscription = scope.container.listen(
      diaryOrganizationControllerProvider(id),
      (_, _) {},
    );
    scope.controller = scope.container.read(
      diaryOrganizationControllerProvider(id),
    );
    await scope.controller.load(scope.setup.session);
    return scope;
  }

  Future<void> dispose() async {
    container.dispose();
    await harness.repository.runVaultMutation(() async {});
    await harness.dispose();
  }
}
