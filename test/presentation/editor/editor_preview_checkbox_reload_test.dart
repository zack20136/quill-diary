import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/application/editor/editor_actions.dart';
import 'package:quill_diary/application/editor/editor_entry_providers.dart';
import 'package:quill_diary/application/session/providers/session_providers.dart';
import 'package:quill_diary/application/session/state/app_session_state.dart';
import 'package:quill_diary/application/settings/settings_providers.dart';
import 'package:quill_diary/domain/diary/diary_entry.dart';
import 'package:quill_diary/domain/recovery/kdf_descriptor.dart';
import 'package:quill_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/presentation/editor/pages/editor_page.dart';
import 'package:quill_diary/presentation/editor/widgets/editor_markdown_preview.dart';
import 'package:quill_diary/shared/presentation/widgets/app_loading_state.dart';

import '../../helpers/presentation/editor/editor_test_scope.dart';
import '../../helpers/presentation/editor/fake_editor_actions.dart';

void main() {
  const UnlockedVaultSession session = UnlockedVaultSession(
    vaultId: 'vault-1',
    trustedDevice: true,
  );

  final DiaryEntry entryWithTasks = DiaryEntry(
    id: 'entry-1',
    vaultId: 'vault-1',
    title: '任務清單',
    date: DateOnly.parse('2026-06-18'),
    createdAt: DateTime(2026, 6, 18, 8),
    updatedAt: DateTime(2026, 6, 18, 9),
    markdownBody: '- [ ] 任務甲\n- [ ] 很長的任務乙內容用來確認版面',
    tags: const <String>['筆記'],
    attachmentIds: const <AssetId>[],
  );

  testWidgets('entryProvider reload 時預覽畫面不換成整頁 loading', (
    WidgetTester tester,
  ) async {
    final Completer<DiaryEntry?> reloadHang = Completer<DiaryEntry?>();
    final _ReloadAwareEditorActions actions = _ReloadAwareEditorActions(
      existingEntry: entryWithTasks,
      hangAfterFirstLoad: reloadHang,
    );

    final ProviderContainer container = ProviderContainer(
      overrides: [
        editorActionsProvider.overrideWithValue(actions),
        effectiveAppSessionProvider.overrideWith(
          (Ref ref) async => const AppSessionState(
            status: AppLockStatus.unlocked,
            session: session,
          ),
        ),
        recoveryMetadataProvider.overrideWith(
          (Ref ref) async => _recoveryMetadata,
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: editorTestApp(
          child: const EditorPage(entryId: 'entry-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(EditorMarkdownPreview), findsOneWidget);
    expect(find.text('任務甲'), findsOneWidget);
    expect(find.byType(AppLoadingState), findsNothing);

    // 模擬預覽勾選存檔後 invalidate entryProvider 的 reload。
    container.invalidate(entryProvider('entry-1'));
    await tester.pump();

    expect(find.byType(AppLoadingState), findsNothing);
    expect(find.byType(EditorMarkdownPreview), findsOneWidget);
    expect(find.text('任務甲'), findsOneWidget);

    reloadHang.complete(entryWithTasks);
    await tester.pumpAndSettle();
    expect(find.text('任務甲'), findsOneWidget);
  });
}

class _ReloadAwareEditorActions extends FakeEditorActions {
  _ReloadAwareEditorActions({
    required DiaryEntry existingEntry,
    required this.hangAfterFirstLoad,
  }) : super(existingEntry: existingEntry, attachments: const []);

  final Completer<DiaryEntry?> hangAfterFirstLoad;

  @override
  Future<DiaryEntry?> loadEntry(
    UnlockedVaultSession session,
    EntryId entryId,
  ) async {
    loadEntryCallCount++;
    if (loadEntryCallCount == 1) {
      return existingEntry ?? FakeEditorActions.defaultEntry;
    }
    return hangAfterFirstLoad.future;
  }
}

final RecoveryMetadata _recoveryMetadata = RecoveryMetadata(
  vaultId: 'vault-1',
  recoveryEnabled: true,
  recoveryKeyVersion: 1,
  recoveryKeyHint: 'hint',
  createdAt: DateTime(2026, 6, 18),
  kdf: KdfDescriptor.argon2idRecovery(
    saltBytes: List<int>.generate(16, (int index) => index),
  ),
);
