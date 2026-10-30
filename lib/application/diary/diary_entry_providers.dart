import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_diary/application/session/session_providers.dart';
import 'package:quill_diary/application/session/session_state.dart';
import 'package:quill_diary/application/vault/vault_providers.dart';
import 'package:quill_diary/domain/attachment/asset_attachment.dart';
import 'package:quill_diary/domain/diary/diary_entry.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';

class DiaryRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() {
    state = state + 1;
  }
}

final diaryRevisionProvider = NotifierProvider<DiaryRevision, int>(
  DiaryRevision.new,
);

final entryCoverPreviewBytesProvider = FutureProvider.autoDispose
    .family<Uint8List?, String>((Ref ref, String encPath) async {
      ref.watch(diaryRevisionProvider);
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
          .read(vaultRepositoryProvider)
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
  ref.watch(diaryRevisionProvider);
  final session = await ref.watch(activeVaultSessionProvider.future);
  if (session == null) {
    return null;
  }
  return ref.read(vaultRepositoryProvider).loadEntry(session, entryId);
});

final entryAttachmentsProvider =
    FutureProvider.family<List<AssetAttachment>, EntryId>((
      Ref ref,
      EntryId entryId,
    ) async {
      final session = await ref.watch(activeVaultSessionProvider.future);
      if (session == null) return const <AssetAttachment>[];
      ref.watch(diaryRevisionProvider);
      return ref.read(vaultRepositoryProvider).loadAttachments(entryId);
    });
