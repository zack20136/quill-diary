import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_diary/application/diary/diary_entry_providers.dart';
import 'package:quill_diary/application/session/session_providers.dart';
import 'package:quill_diary/application/session/session_state.dart';
import 'package:quill_diary/application/vault/vault_providers.dart';
import 'package:quill_diary/domain/tag/tag.dart';
import 'package:quill_diary/infrastructure/storage/tag_styles_store.dart';

final tagCatalogProvider = FutureProvider<List<TagCatalogItem>>((
  Ref ref,
) async {
  ref.watch(diaryRevisionProvider);
  final AppSessionState state = await ref.watch(
    effectiveAppSessionProvider.future,
  );
  if (!state.isUnlocked || state.session == null) {
    return const <TagCatalogItem>[];
  }
  return ref.watch(vaultRepositoryProvider).listTagCatalog();
});
final tagAccentArgbMapProvider = FutureProvider<Map<String, int>>((
  Ref ref,
) async {
  final AppSessionState state = await ref.watch(
    effectiveAppSessionProvider.future,
  );
  if (!state.isUnlocked || state.session == null) {
    return const <String, int>{};
  }
  final List<TagCatalogItem> catalog = await ref.watch(
    tagCatalogProvider.future,
  );
  return TagStylesStore.toAccentMap(catalog);
});
