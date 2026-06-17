import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/attachment/asset_attachment.dart';
import '../../../domain/diary/diary_entry.dart';
import '../../../domain/shared/value_objects.dart';
import '../application/editor_actions.dart';
import '../../session/providers/session_providers.dart';
import '../../session/state/app_session_state.dart';

class EntryIndexRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() {
    state = state + 1;
  }
}

final entryIndexRevisionProvider = NotifierProvider<EntryIndexRevision, int>(
  EntryIndexRevision.new,
);

final entryCoverPreviewBytesProvider = FutureProvider.autoDispose
    .family<Uint8List?, String>((Ref ref, String encPath) async {
      ref.watch(entryIndexRevisionProvider);
      final String path = encPath.trim();
      if (path.isEmpty) {
        return null;
      }
      final AppSessionState state = await ref.watch(
        effectiveAppSessionProvider.future,
      );
      if (!state.isUnlocked || state.session == null) {
        return null;
      }
      final Uint8List? bytes = await ref
          .read(editorActionsProvider)
          .readDecryptedAssetBytes(state.session!, path);
      if (bytes != null && bytes.isNotEmpty) {
        ref.keepAlive();
      }
      return bytes;
    });

final entryProvider = FutureProvider.family<DiaryEntry?, EntryId>((
  Ref ref,
  EntryId entryId,
) async {
  final session = await ref.watch(activeVaultSessionProvider.future);
  if (session == null) {
    return null;
  }
  return ref.read(editorActionsProvider).loadEntry(session, entryId);
});

final entryAttachmentsProvider =
    FutureProvider.family<List<AssetAttachment>, EntryId>((
      Ref ref,
      EntryId entryId,
    ) async {
      await ref.watch(activeVaultSessionProvider.future);
      ref.watch(entryIndexRevisionProvider);
      return ref.read(editorActionsProvider).loadAttachments(entryId);
    });
