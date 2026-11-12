import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/diary/diary_entry_providers.dart';
import 'package:quill_diary/application/editor/editor_draft_providers.dart';
import 'package:quill_diary/application/home/home_browse_state.dart';
import 'package:quill_diary/application/home/home_entry_query_providers.dart';
import 'package:quill_diary/application/session/session_providers.dart';
import 'package:quill_diary/application/session/session_state.dart';
import 'package:quill_diary/application/settings/personalization_providers.dart';
import 'package:quill_diary/application/vault/vault_providers.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/domain/tag/tag.dart';
import 'package:quill_diary/presentation/home/widgets/tags_pane.dart';

import '../../preferences/in_memory_user_preferences.dart';
import '../../shared/entry_index_fixtures.dart';
import '../../shared/widget_test_app.dart';
import '../../vault/fake_entry_index_vault_repository.dart';

const tagTestSession = AppSessionState(
  status: AppLockStatus.unlocked,
  session: UnlockedVaultSession(vaultId: 'tag-vault', trustedDevice: true),
);

class TagTestSessionController extends Notifier<AppSessionState> {
  @override
  AppSessionState build() => tagTestSession;

  void set(AppSessionState value) => state = value;
}

final tagTestSessionProvider =
    NotifierProvider<TagTestSessionController, AppSessionState>(
      TagTestSessionController.new,
    );

class TagTestRepository extends FakeEntryIndexVaultRepository {
  TagTestRepository({List<String> labels = const ['Alpha', 'Beta', 'Gamma']})
    : super(
        tagCatalog: labels
            .map((label) => TagCatalogItem(label: label))
            .toList(),
        allEntries: [buildDiaryEntrySummary(tags: List.of(labels))],
      );

  final List<String> deleteCalls = [];
  Completer<void>? deleteGate;
  String? failOn;
  final failure = StateError('標籤寫入失敗');

  @override
  Future<int> removeTagFromAllEntries(
    UnlockedVaultSession session,
    String tag,
  ) async {
    deleteCalls.add(tag);
    await deleteGate?.future;
    if (tag == failOn) throw failure;
    final normalized = normalizeText(tag);
    var affected = 0;
    for (final entry in allEntries) {
      final previous = entry.tags.length;
      entry.tags.removeWhere((label) => normalizeText(label) == normalized);
      if (entry.tags.length != previous) affected++;
    }
    tagCatalog.removeWhere((item) => item.normalized == normalized);
    return affected;
  }
}

ProviderContainer tagTestContainer(TagTestRepository repository) {
  final container = ProviderContainer(
    overrides: [
      vaultRepositoryProvider.overrideWithValue(repository),
      effectiveAppSessionProvider.overrideWith(
        (ref) async => ref.watch(tagTestSessionProvider),
      ),
      allDiaryEntrySummariesProvider.overrideWith((ref) async {
        ref.watch(diaryRevisionProvider);
        return repository.listEntries();
      }),
      editorDraftKeysProvider.overrideWith((_) async => {}),
      userPreferencesProvider.overrideWithValue(InMemoryUserPreferences()),
    ],
  );
  container.read(homeTabProvider.notifier).set(HomeTab.tags);
  return container;
}

Widget tagTestApp(ProviderContainer container) => UncontrolledProviderScope(
  container: container,
  child: widgetTestApp(
    center: false,
    child: Consumer(
      builder: (context, ref, _) => IndexedStack(
        index: ref.watch(homeTabProvider) == HomeTab.tags ? 0 : 1,
        children: [
          TagsManagePane(sessionState: ref.watch(tagTestSessionProvider)),
          const SizedBox.shrink(),
        ],
      ),
    ),
  ),
);
