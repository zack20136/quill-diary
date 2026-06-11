import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/core_providers.dart';
import '../../session/providers/session_providers.dart';

/// 目前有本機草稿的條目 key，供首頁與檢視頁顯示「未儲存」標籤。
final editorDraftKeysProvider = FutureProvider<Set<String>>((Ref ref) async {
  final session = await ref.watch(activeVaultSessionProvider.future);
  if (session == null) {
    return <String>{};
  }
  return ref.read(editorDraftStoreProvider).listDraftKeys();
});
