import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/editor_actions.dart';
import '../../session/providers/session_providers.dart';

/// 列出目前 vault 中可還原的編輯草稿 key。
final editorDraftKeysProvider = FutureProvider<Set<String>>((Ref ref) async {
  final session = await ref.watch(activeVaultSessionProvider.future);
  if (session == null) {
    return <String>{};
  }
  return ref.read(editorActionsProvider).listDraftKeys();
});
