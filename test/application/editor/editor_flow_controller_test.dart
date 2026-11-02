import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/application/editor/editor_actions.dart';
import 'package:quill_diary/application/editor/editor_draft_snapshot.dart';
import 'package:quill_diary/application/editor/editor_flow_controller.dart';
import 'package:quill_diary/application/settings/settings_providers.dart';
import 'package:quill_diary/application/vault/vault_providers.dart';
import 'package:quill_diary/domain/attachment/asset_attachment.dart';
import 'package:quill_diary/domain/diary/diary_entry.dart';
import 'package:quill_diary/domain/diary/editor_draft.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/domain/vault_maintenance_models.dart';

import '../../helpers/presentation/editor/fake_editor_actions.dart';

void main() {
  test('儲存日記前會正規化任務清單 markdown', () async {
    final FakeEditorActions actions = FakeEditorActions();
    final ProviderContainer container = ProviderContainer(
      overrides: [
        editorActionsProvider.overrideWithValue(actions),
        vaultRepositoryProvider.overrideWithValue(actions.repository),
      ],
    );
    addTearDown(container.dispose);

    final EditorFlowController controller = container.read(
      editorFlowControllerProvider,
    );
    final UnlockedVaultSession session = UnlockedVaultSession(
      vaultId: 'vault-1',
      trustedDevice: true,
    );

    await controller.saveEntry(
      EditorSaveRequest(
        draftKey: 'draft-1',
        session: session,
        existingEntry: null,
        titleRaw: '標題',
        dateValue: '2026-06-18',
        entryTime: (hour: 8, minute: 0),
        tagsRaw: '標籤',
        markdownBodyRaw: '前言\n- [ ] 任務三',
        attachmentIds: const <AssetId>[],
        pendingAttachments: const <PendingAttachment>[],
        provisionalEntryId: 'entry-new',
        switchToPreview: true,
      ),
    );

    expect(actions.saveEntryCallCount, 1);
    expect(actions.savedEntryDraft?.markdownBody, '前言\n- [ ] 任務三\n');
  });

  test('salvage 儲存後會刷新維護摘要 provider', () async {
    final FakeEditorActions actions = FakeEditorActions();
    var repairReads = 0;
    var inspectReads = 0;
    final ProviderContainer container = ProviderContainer(
      overrides: [
        editorActionsProvider.overrideWithValue(actions),
        vaultRepositoryProvider.overrideWithValue(actions.repository),
        vaultRepairSummaryProvider.overrideWith((Ref ref) async {
          repairReads++;
          return null;
        }),
        vaultInspectSummaryProvider.overrideWith((Ref ref) async {
          inspectReads++;
          return null;
        }),
      ],
    );
    addTearDown(container.dispose);
    container.listen(vaultRepairSummaryProvider, (_, _) {});
    container.listen(vaultInspectSummaryProvider, (_, _) {});
    await container.read(vaultRepairSummaryProvider.future);
    await container.read(vaultInspectSummaryProvider.future);

    final UnlockedVaultSession session = UnlockedVaultSession(
      vaultId: 'vault-1',
      trustedDevice: true,
    );
    await container
        .read(editorFlowControllerProvider)
        .saveEntry(
          EditorSaveRequest(
            draftKey: 'draft-salvage',
            session: session,
            existingEntry: null,
            titleRaw: '搶救日記',
            dateValue: '2026-06-18',
            entryTime: (hour: 8, minute: 0),
            tagsRaw: '',
            markdownBodyRaw: '正文',
            attachmentIds: const <AssetId>[],
            pendingAttachments: const <PendingAttachment>[],
            provisionalEntryId: 'entry-salvage',
            switchToPreview: true,
            retireFindingsAfterSave: const <VaultFinding>[
              VaultFinding(
                kind: VaultRepairIssueKind.unreadableEntry,
                plannedAction: VaultPlannedAction.quarantine,
                manualAction: VaultManualAction.restoreFromBackup,
                canOpenEntry: false,
                internalReference: 'entries/broken.md.enc',
              ),
            ],
          ),
        );
    await container.pump();
    await container.read(vaultRepairSummaryProvider.future);
    await container.read(vaultInspectSummaryProvider.future);

    expect(repairReads, 2);
    expect(inspectReads, 2);
  });

  test('連續修改時依序保存第一份與最後一份快照', () async {
    final actions = _GatedDraftActions();
    final container = ProviderContainer(
      overrides: [
        editorActionsProvider.overrideWithValue(actions),
        vaultRepositoryProvider.overrideWithValue(actions.repository),
      ],
    );
    addTearDown(container.dispose);
    final persisted = <String>[];
    final session = container
        .read(editorFlowControllerProvider)
        .startSession(
          onDraftPersisted: (result) =>
              persisted.add(result.snapshot.markdownBody),
        );
    final first = session.persistDraft(_draftRequest('第一版'));
    final second = session.persistDraft(_draftRequest('中間版'));
    final last = session.persistDraft(_draftRequest('最後版'));
    expect(actions.writtenBodies, ['第一版']);
    actions.firstWrite.complete();
    await Future.wait([first, second, last]);
    expect(actions.writtenBodies, ['第一版', '最後版']);
    expect(persisted, ['第一版', '最後版']);
  });

  test('離開編輯器仍保存已擷取的最後快照且不再回呼畫面', () async {
    final actions = _GatedDraftActions();
    final container = ProviderContainer(
      overrides: [
        editorActionsProvider.overrideWithValue(actions),
        vaultRepositoryProvider.overrideWithValue(actions.repository),
      ],
    );
    addTearDown(container.dispose);
    var callbacks = 0;
    final session = container
        .read(editorFlowControllerProvider)
        .startSession(onDraftPersisted: (_) => callbacks++);
    final first = session.persistDraft(_draftRequest('離開前'));
    final last = session.persistDraft(_draftRequest('最後修改'));
    session.close();
    actions.firstWrite.complete();
    await Future.wait([first, last]);
    expect(actions.writtenBodies, ['離開前', '最後修改']);
    expect(callbacks, 0);
  });

  test('重設編輯器會捨棄等待中的快照並忽略先前操作的結果', () async {
    final actions = _GatedDraftActions();
    final container = ProviderContainer(
      overrides: [
        editorActionsProvider.overrideWithValue(actions),
        vaultRepositoryProvider.overrideWithValue(actions.repository),
      ],
    );
    addTearDown(container.dispose);
    var callbacks = 0;
    final session = container
        .read(editorFlowControllerProvider)
        .startSession(onDraftPersisted: (_) => callbacks++);
    final first = session.persistDraft(_draftRequest('已開始保存'));
    final queued = session.persistDraft(_draftRequest('等待保存'));
    session.reset();
    actions.firstWrite.complete();
    await Future.wait([first, queued]);
    expect(actions.writtenBodies, ['已開始保存']);
    expect(callbacks, 0);
  });

  test('草稿寫入失敗後會保留最後快照供下一次變更重試', () async {
    final actions = _FailOnceDraftActions();
    final container = ProviderContainer(
      overrides: [
        editorActionsProvider.overrideWithValue(actions),
        vaultRepositoryProvider.overrideWithValue(actions.repository),
      ],
    );
    addTearDown(container.dispose);
    final EditorFlowSession session = container
        .read(editorFlowControllerProvider)
        .startSession(onDraftPersisted: (_) {});

    await expectLater(
      session.persistDraft(_draftRequest('寫入失敗')),
      throwsStateError,
    );
    await session.persistDraft(_draftRequest('重試成功'));

    expect(actions.writtenBodies, <String>['寫入失敗', '重試成功']);
    expect(actions.writtenDraft?.markdownBody, '重試成功');
  });

  test('預覽連續勾選會依序提交，最後狀態不會被舊寫入覆蓋', () async {
    final actions = _GatedPreviewActions();
    final container = ProviderContainer(
      overrides: [
        editorActionsProvider.overrideWithValue(actions),
        vaultRepositoryProvider.overrideWithValue(actions.repository),
      ],
    );
    addTearDown(container.dispose);
    final EditorFlowSession session = container
        .read(editorFlowControllerProvider)
        .startSession(onDraftPersisted: (_) {});

    final Future<EditorSaveResult?> first = session.savePreview(
      _previewRequest('第一個勾選'),
    );
    expect(actions.savedBodies, <String>['第一個勾選']);
    final Future<EditorSaveResult?> last = session.savePreview(
      _previewRequest('最後一個勾選'),
    );
    actions.firstSave.complete();

    await Future.wait(<Future<EditorSaveResult?>>[first, last]);
    expect(actions.savedBodies, <String>['第一個勾選', '最後一個勾選']);
    expect(actions.savedEntryDraft?.markdownBody, '最後一個勾選');
  });
}

EditorPersistDraftRequest _draftRequest(String body) =>
    EditorPersistDraftRequest(
      draftKey: 'queued-draft',
      snapshot: EditorDraftSnapshot(
        title: null,
        dateValue: '2026-06-18',
        entryHour: 8,
        entryMinute: 0,
        tags: const [],
        markdownBody: body,
        attachmentIds: const [],
      ),
      tagsRaw: '',
      attachmentIds: const [],
      pendingAttachments: const [],
      session: const UnlockedVaultSession(
        vaultId: 'vault-1',
        trustedDevice: true,
      ),
      createdAt: DateTime(2026, 6, 18),
      provisionalEntryId: 'entry-queued',
      existingEntryId: null,
    );

EditorSaveRequest _previewRequest(String body) => EditorSaveRequest(
  draftKey: 'preview-draft',
  session: const UnlockedVaultSession(vaultId: 'vault-1', trustedDevice: true),
  existingEntry: null,
  titleRaw: '標題',
  dateValue: '2026-06-18',
  entryTime: (hour: 8, minute: 0),
  tagsRaw: '',
  markdownBodyRaw: body,
  attachmentIds: const <AssetId>[],
  pendingAttachments: const <PendingAttachment>[],
  provisionalEntryId: 'preview-entry',
  switchToPreview: true,
);

class _GatedDraftActions extends FakeEditorActions {
  final firstWrite = Completer<void>();
  final writtenBodies = <String>[];

  @override
  Future<void> writeDraft(
    String draftKey,
    EditorDraftRecord record,
    UnlockedVaultSession session,
  ) async {
    writtenBodies.add(record.markdownBody);
    if (writtenBodies.length == 1) await firstWrite.future;
    await super.writeDraft(draftKey, record, session);
  }
}

class _GatedPreviewActions extends FakeEditorActions {
  final Completer<void> firstSave = Completer<void>();
  final List<String> savedBodies = <String>[];

  @override
  Future<DiaryEntry> saveEntry(
    UnlockedVaultSession session,
    DiaryEntry draft, {
    required List<PendingAttachment> pendingAttachments,
    List<VaultFinding> retireFindingsAfterSave = const <VaultFinding>[],
  }) async {
    savedBodies.add(draft.markdownBody);
    if (savedBodies.length == 1) await firstSave.future;
    return super.saveEntry(
      session,
      draft,
      pendingAttachments: pendingAttachments,
      retireFindingsAfterSave: retireFindingsAfterSave,
    );
  }
}

class _FailOnceDraftActions extends FakeEditorActions {
  bool _fail = true;
  final List<String> writtenBodies = <String>[];

  @override
  Future<void> writeDraft(
    String draftKey,
    EditorDraftRecord record,
    UnlockedVaultSession session,
  ) async {
    writtenBodies.add(record.markdownBody);
    if (_fail) {
      _fail = false;
      throw StateError('模擬草稿寫入失敗');
    }
    await super.writeDraft(draftKey, record, session);
  }
}
