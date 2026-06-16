import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/session/providers/session_providers.dart';
import '../../features/session/state/app_session_state.dart';
import '../../infrastructure/storage/tag_styles_store.dart';
import 'core_providers.dart';

/// 目前保險庫的標籤目錄（含未使用標籤與預設標籤）。
final tagCatalogProvider = FutureProvider<List<TagCatalogItem>>((
  Ref ref,
) async {
  final AppSessionState state = await ref.watch(
    effectiveAppSessionProvider.future,
  );
  if (!state.isUnlocked || state.session == null) {
    return const <TagCatalogItem>[];
  }
  return ref.watch(vaultRepositoryProvider).listTagCatalog();
});

/// 標籤目錄中已設定 accent 的對照表（normalized label → ARGB）。
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
