import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_diary/application/diary/diary_entry_providers.dart';
import 'package:quill_diary/application/editor/editor_actions.dart';
import 'package:quill_diary/application/session/session_providers.dart';

final editorDraftKeysProvider = FutureProvider<Set<String>>((Ref ref) async {
  ref.watch(diaryRevisionProvider);
  final session = await ref.watch(activeVaultSessionProvider.future);
  if (session == null) {
    return <String>{};
  }
  return ref.read(editorActionsProvider).listDraftKeys();
});
