import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_diary/application/diary/diary_entry_providers.dart';
import 'package:quill_diary/application/editor/editor_draft_providers.dart';
import 'package:quill_diary/application/editor/editor_flow_controller.dart';
import 'package:quill_diary/application/people/people_providers.dart';
import 'package:quill_diary/application/session/session_providers.dart';
import 'package:quill_diary/application/session/session_route_snapshot.dart';
import 'package:quill_diary/application/settings/settings_providers.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';

Future<void> finishRestoreSession(
  Ref ref,
  UnlockedVaultSession restored,
) async {
  final controller = ref.read(appSessionProvider.notifier);
  try {
    controller.beginPostRestoreStartup();
    ref.invalidate(editorDraftKeysProvider);
    ref.invalidate(editorFlowControllerProvider);
    ref.invalidate(recoveryMetadataProvider);
    ref.invalidate(settingsDriveConnectionProvider);
    ref.invalidate(unlockModeProvider);

    await controller.activateRestoredSession(restored);
    ref.read(diaryRevisionProvider.notifier).bump();
    ref.invalidate(peopleCatalogProvider);
  } finally {
    ref.read(sessionRouteSnapshotProvider.notifier).clear();
    controller.endTrustedUnlockBootstrap();
  }
}
