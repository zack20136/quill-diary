import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/attachment/asset_attachment.dart';
import '../../../domain/diary/diary_entry.dart';
import '../../../domain/shared/value_objects.dart';
import '../../../shared/providers/core_providers.dart';
import '../../session/providers/session_providers.dart';
import '../../session/state/app_session_state.dart';

final tagAccentArgbMapProvider = FutureProvider<Map<String, int>>((Ref ref) async {
  final AppSessionState state = await ref.watch(effectiveAppSessionProvider.future);
  if (!state.isUnlocked || state.session == null) {
    return const <String, int>{};
  }
  return ref.watch(vaultRepositoryProvider).fetchTagAccentArgbMap();
});

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

final entryCoverPreviewBytesProvider =
    FutureProvider.autoDispose.family<Uint8List?, String>((Ref ref, String encPath) async {
  ref.watch(entryIndexRevisionProvider);
  final String path = encPath.trim();
  if (path.isEmpty) {
    return null;
  }
  final AppSessionState state = await ref.watch(effectiveAppSessionProvider.future);
  if (!state.isUnlocked || state.session == null) {
    return null;
  }
  return ref.read(vaultRepositoryProvider).readDecryptedAssetBytes(state.session!, path);
});

final entryProvider = FutureProvider.family<DiaryEntry?, EntryId>((Ref ref, EntryId entryId) async {
  final session = await ref.watch(activeVaultSessionProvider.future);
  if (session == null) {
    return null;
  }
  return ref.read(vaultRepositoryProvider).loadEntry(session, entryId);
});

final entryAttachmentsProvider =
    FutureProvider.family<List<AssetAttachment>, EntryId>((Ref ref, EntryId entryId) async {
  await ref.watch(activeVaultSessionProvider.future);
  ref.watch(entryIndexRevisionProvider);
  return ref.read(vaultRepositoryProvider).loadAttachments(entryId);
});
