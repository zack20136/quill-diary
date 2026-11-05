import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/ai/ai_connection_providers.dart';
import 'package:quill_diary/application/diary_organization/diary_organization_controller.dart';
import 'package:quill_diary/application/errors/ai_error_text.dart';
import 'package:quill_diary/application/session/session_providers.dart';
import 'package:quill_diary/domain/ai/ai_connection_settings.dart';
import 'package:quill_diary/domain/ai/ai_failure.dart';
import 'package:quill_diary/domain/diary_organization/diary_organization.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/ai/ai_chat_input_panel.dart';
import 'package:quill_diary/presentation/ai/ai_chat_model_picker.dart';
import 'package:quill_diary/presentation/ai/ai_chat_scaffold.dart';
import 'package:quill_diary/presentation/ai/ai_composer_actions.dart';
import 'package:quill_diary/presentation/ai/ai_connection_settings_dialog.dart';
import 'package:quill_diary/presentation/ai/ai_generation_card.dart';
import 'package:quill_diary/presentation/ai/ai_message_bubble.dart';
import 'package:quill_diary/presentation/ai/ai_request_preview_dialog.dart';
import 'package:quill_diary/presentation/diary_organization/organization_draft_editor.dart';
import 'package:quill_diary/presentation/diary_organization/organization_quick_actions.dart';
import 'package:quill_diary/presentation/diary_organization/organization_review.dart';
import 'package:quill_diary/presentation/session/widgets/session_locked_pane.dart';
import 'package:quill_diary/shared/presentation/app_feedback.dart';
import 'package:quill_diary/shared/presentation/private_text_controller.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_shell.dart';

class DiaryOrganizationPage extends ConsumerStatefulWidget {
  const DiaryOrganizationPage({super.key, required this.entryId});
  final String entryId;
  @override
  ConsumerState<DiaryOrganizationPage> createState() =>
      _DiaryOrganizationPageState();
}

class _DiaryOrganizationPageState extends ConsumerState<DiaryOrganizationPage>
    with WidgetsBindingObserver {
  final _privacy = PrivateTextController();
  final _composer = PrivateTextController();
  final _composerFocus = FocusNode();
  final _scroll = ScrollController();
  bool _followTail = true;
  UnlockedVaultSession? _loaded;
  bool _syncing = false;
  final _dialogs = <Route<dynamic>>[];
  DiaryOrganizationController get _controller =>
      ref.read(diaryOrganizationControllerProvider(widget.entryId));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(() {
      _followTail = _scroll.position.maxScrollExtent - _scroll.offset < 80;
    });
    _privacy.addListener(() {
      if (!_syncing) {
        _controller.updatePrivacy(_privacy.privateRanges);
        setState(() {});
      }
    });
    _composer.addListener(() {
      if (!_syncing) {
        _controller.updateComposer(_composer.text, _composer.privateRanges);
        setState(() {});
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _dismissDialogs();
    }
    if (mounted) setState(() {});
  }

  void _dismissDialogs() {
    for (final route in List.of(_dialogs)) {
      if (route.isActive) route.navigator?.removeRoute(route);
    }
  }

  Future<T?> _dialog<T>(Widget child) async {
    final route = DialogRoute<T>(
      context: context,
      builder: (_) => AppDialogWidth(child: child),
    );
    _dialogs.add(route);
    try {
      return await Navigator.of(context).push(route);
    } finally {
      _dialogs.remove(route);
    }
  }

  Future<void> _settings() async {
    final controller = _controller;
    final current = controller.draft;
    final result = await _dialog<AiConnectionSettingsResult>(
      AiConnectionSettingsDialog(initialConnection: current?.connection),
    );
    if (!mounted ||
        result == null ||
        current != controller.draft ||
        controller.vault == null) {
      return;
    }
    final stored = await ref
        .read(aiSettingsStoreProvider)
        .read(controller.vault!);
    if (!mounted || current != controller.draft) return;
    await controller.changeConnection(
      result.chatConnection ?? stored.connection.activeConfig,
    );
    if (!mounted || current != controller.draft) return;
    await controller.refreshPrivacyPreset();
  }

  Future<void> _load(UnlockedVaultSession vault) => _run(() async {
    final controller = _controller;
    await controller.load(vault);
    final current = controller.draft;
    if (!mounted || _loaded != vault || current == null) return;
    final connection = current.connection;
    final needsSettings =
        !connection.isConfigured ||
        connection.provider.requiresApiKey &&
            (await ref.read(aiSettingsStoreProvider).readApiKey(connection))
                .isEmpty;
    if (!mounted ||
        _loaded != vault ||
        controller.draft != current ||
        (WidgetsBinding.instance.lifecycleState != null &&
            WidgetsBinding.instance.lifecycleState !=
                AppLifecycleState.resumed)) {
      return;
    }
    if (needsSettings) await _settings();
  });

  Future<void> _send({String? message, int? turn}) async {
    _followTail = true;
    await _controller.sendMessage(message: message, retryTurn: turn);
    if (mounted && _controller.error == AiErrorCode.configuration) {
      await _run(_settings);
    }
  }

  Future<void> _generate() async {
    await _controller.generateDraft();
    if (mounted && _controller.error == AiErrorCode.configuration) {
      await _run(_settings);
    }
  }

  Future<void> _preview() async {
    final session = _controller.vault;
    final preview = await _controller.previewRequest();
    if (!mounted || preview == null || _controller.vault != session) return;
    final generationPreview = await _controller.previewRequest(generate: true);
    if (!mounted || generationPreview == null || _controller.vault != session) {
      return;
    }
    await _dialog<void>(
      AiRequestPreviewDialog(
        preview: preview,
        generationPreview: generationPreview,
        generationLabel: context.l10n.organizationGenerate,
      ),
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    final session = _controller.vault;
    try {
      await action();
    } on Object catch (error) {
      if (mounted && _controller.vault == session) {
        showAppFeedbackToast(
          context,
          aiErrorText(
            context.l10n,
            error is AiFailure ? error.code : AiErrorCode.storage,
          ),
          tone: AppFeedbackTone.error,
        );
      }
    }
  }

  Future<void> _discard(bool restart) async {
    final l10n = context.l10n;
    final confirmed = await _dialog<bool>(
      AlertDialog(
        title: Text(
          restart ? l10n.organizationRestart : l10n.organizationDelete,
        ),
        content: Text(l10n.organizationDiscardBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonActionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              restart ? l10n.commonActionConfirm : l10n.commonActionDelete,
            ),
          ),
        ],
      ),
    );
    if (confirmed != true ||
        !mounted ||
        _controller.busy &&
            _controller.draft?.stage == OrganizationStage.applying) {
      return;
    }
    await _controller.discard(restart: restart);
    if (mounted && !restart) context.pop();
  }

  Future<void> _edit() async {
    final draft = _controller.draft!;
    final edited = await _dialog<String>(
      OrganizationDraftEditor(
        body: draft.currentBody,
        originals: draft.originals,
        surfaces: draft.tokenSurfaces,
      ),
    );
    if (edited != null && mounted && draft == _controller.draft) {
      await _controller.editBody(edited);
    }
  }

  Widget _hideButton(PrivateTextController controller, {bool enabled = true}) =>
      IconButton(
        tooltip: controller.selectionIsPrivate
            ? context.l10n.aiUnhideSelection
            : context.l10n.aiHideSelection,
        onPressed:
            !enabled ||
                !controller.selection.isValid ||
                controller.selection.isCollapsed
            ? null
            : () {
                if (controller.selectionIsPrivate) {
                  controller.unhideSelection();
                } else {
                  controller.hideSelection();
                }
              },
        icon: Icon(
          controller.selectionIsPrivate
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
        ),
      );

  Widget _notices(DiaryOrganizationController controller) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (controller.error != null)
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(aiErrorText(context.l10n, controller.error!)),
        ),
      if (controller.editorDraftExists)
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(context.l10n.organizationEditorDraft),
        ),
      if (controller.conflict)
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(context.l10n.organizationConflict),
              TextButton(
                onPressed: controller.busy
                    ? null
                    : () => _run(() => _discard(true)),
                child: Text(context.l10n.organizationRestart),
              ),
            ],
          ),
        ),
    ],
  );

  Widget _privacyPage(DiaryOrganizationController controller) {
    final l10n = context.l10n;
    final content = Scaffold(
      appBar: AppBar(
        title: Text(l10n.organizationPrivacyTitle),
        leading: CloseButton(onPressed: _close),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.organizationPrivacyHint),
            ),
            _notices(controller),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  key: const ValueKey('organization-privacy-text'),
                  controller: _privacy,
                  readOnly: true,
                  expands: true,
                  minLines: null,
                  maxLines: null,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ),
            if (!controller.canStart &&
                !controller.busy &&
                !controller.conflict &&
                !controller.editorDraftExists)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(l10n.organizationNeedsText),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _hideButton(_privacy, enabled: !controller.busy),
                  const Spacer(),
                  FilledButton(
                    key: const ValueKey('organization-start'),
                    onPressed: controller.canStart
                        ? () => _run(controller.startChat)
                        : null,
                    child: Text(l10n.organizationStart),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (MediaQuery.sizeOf(context).width < 600) {
      return Dialog.fullscreen(child: content);
    }
    return Scaffold(
      body: Center(
        child: Dialog(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 840,
              maxHeight: MediaQuery.sizeOf(context).height * 0.9,
            ),
            child: content,
          ),
        ),
      ),
    );
  }

  Widget _versions(int index) {
    final controller = _controller;
    final draft = controller.draft!;
    final versions = draft.versionsOf(index);
    if (versions.length < 2) return const SizedBox.shrink();
    final selected = versions.indexOf(index);
    final enabled = !controller.busy && draft.editingTurn == null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: context.l10n.chatDiaryPreviousVersion,
          icon: const Icon(Icons.chevron_left, size: 18),
          onPressed: enabled && selected > 0
              ? () => controller.selectTurn(versions[selected - 1])
              : null,
        ),
        Text(
          '${selected + 1} / ${versions.length}',
          style: Theme.of(context).textTheme.labelSmall,
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: context.l10n.chatDiaryNextVersion,
          icon: const Icon(Icons.chevron_right, size: 18),
          onPressed: enabled && selected < versions.length - 1
              ? () => controller.selectTurn(versions[selected + 1])
              : null,
        ),
      ],
    );
  }

  Widget _message(String text, {required bool user, required int turn}) {
    final controller = _controller;
    final draft = controller.draft!;
    final current = draft.turns[turn];
    final visible = organizationVisibleText(
      text,
      draft.originals,
      surfaces: user ? current.surfaces : const {},
    );
    final pending =
        !user &&
        controller.busy &&
        !controller.generating &&
        current.interrupted &&
        turn == draft.activeTurnIndices.lastOrNull;
    final failed = !user && current.interrupted && !pending;
    final canAct = !controller.busy && draft.editingTurn == null;
    return AiMessageBubble(
      id: 'organization-${user ? 'user' : 'assistant'}-$turn',
      text: visible.text,
      isUser: user,
      privateRanges: visible.ranges,
      pending: pending,
      canAct: canAct,
      failureText: failed ? context.l10n.chatDiaryInterrupted : null,
      leadingActions: _versions(turn),
      onEdit: user
          ? () async {
              await controller.beginEditing(turn);
              if (mounted) _composerFocus.requestFocus();
            }
          : null,
      onRetry: !user ? () => _send(turn: turn) : null,
      retryFailed: failed,
    );
  }

  Widget _chat(DiaryOrganizationController controller) {
    final draft = controller.draft!;
    final l10n = context.l10n;
    final canInteract =
        !controller.busy &&
        !controller.conflict &&
        !controller.editorDraftExists;
    final hasMessages = draft.activeTurnIndices.any(
      (i) => draft.turns[i].user.isNotEmpty,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final style = Theme.of(context).textTheme.bodyLarge!;
        final lineHeight =
            MediaQuery.textScalerOf(context).scale(style.fontSize!) *
            (style.height ?? 1);
        final maxLines = ((constraints.maxHeight / 3 - 80) / lineHeight)
            .floor()
            .clamp(1, 5);
        return Column(
          children: [
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                children: [
                  _notices(controller),
                  if (!hasMessages)
                    OrganizationQuickActions(
                      enabled: canInteract && draft.editingTurn == null,
                      onSelected: (message) => _send(message: message),
                    ),
                  if (draft.generationInterrupted && !controller.generating)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(l10n.organizationInterrupted),
                    ),
                  for (final index in draft.activeTurnIndices) ...[
                    if (draft.turns[index].user.isNotEmpty)
                      _message(
                        draft.turns[index].user,
                        user: true,
                        turn: index,
                      ),
                    _message(
                      draft.turns[index].reply,
                      user: false,
                      turn: index,
                    ),
                  ],
                ],
              ),
            ),
            if (controller.generating)
              AiGenerationCard(
                cardKey: const ValueKey('organization-generation-card'),
                title: l10n.organizationGenerating,
                status: switch (controller.generationPhase) {
                  OrganizationGenerationPhase.preparing =>
                    l10n.chatDiaryGenerationPreparing,
                  OrganizationGenerationPhase.receiving =>
                    l10n.organizationGenerationReceiving,
                  OrganizationGenerationPhase.validating =>
                    l10n.organizationGenerationValidating,
                  OrganizationGenerationPhase.saving =>
                    l10n.chatDiaryGenerationSaving,
                  OrganizationGenerationPhase.idle => '',
                },
                hint: l10n.chatDiaryGenerationHint,
                onStop: controller.stop,
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: constraints.maxHeight * 0.75,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasMessages)
                        OrganizationQuickActions(
                          compact: true,
                          enabled: canInteract && draft.editingTurn == null,
                          onSelected: (message) => _send(message: message),
                        ),
                      AiComposerActions(
                        actionLabel: l10n.organizationGenerate,
                        actionTooltip: controller.canGenerate
                            ? l10n.organizationGenerate
                            : draft.composer.trim().isNotEmpty
                            ? l10n.organizationGenerateNeedsSend
                            : l10n.organizationGenerateNeedsReply,
                        actionKey: const ValueKey('organization-generate'),
                        model: AiChatModelPicker(
                          current: draft.connection,
                          enabled: canInteract,
                          onSelected: controller.selectModel,
                        ),
                        onAction: controller.canGenerate ? _generate : null,
                      ),
                      AiChatInputPanel(
                        key: ObjectKey(draft),
                        editing: draft.editingTurn != null,
                        onCancelEditing: controller.cancelEditing,
                        isBusy: controller.busy,
                        canSend:
                            canInteract && _composer.text.trim().isNotEmpty,
                        composerController: _composer,
                        composerFocusNode: _composerFocus,
                        composerKey: const ValueKey('organization-composer'),
                        hintText: l10n.organizationMessageHint,
                        onOpenSettings: () => _run(_settings),
                        onSend: () => _send(),
                        onStop: controller.stop,
                        maxLines: maxLines,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _review(DiaryOrganizationController controller) => OrganizationReview(
    controller: controller,
    notices: _notices(controller),
    onBack: () {
      _followTail = true;
      unawaited(_run(controller.returnToChat));
    },
    onEdit: () => _run(_edit),
    onApply: () async {
      final saved = await controller.apply();
      if (mounted && saved != null) context.pop(saved);
    },
  );

  Future<void> _close() => _run(() async {
    if (_controller.busy &&
        _controller.draft?.stage == OrganizationStage.applying) {
      return;
    }
    await _controller.persist(rethrowError: true);
    if (mounted) context.pop();
  });

  @override
  Widget build(BuildContext context) {
    ref.listen(effectiveAppSessionProvider, (_, next) {
      if (next.hasError ||
          next.value?.isUnlocked != true ||
          next.value?.session != _loaded) {
        _dismissDialogs();
        _loaded = null;
      }
    });
    final session = ref.watch(effectiveAppSessionProvider).value;
    final controller = ref.watch(
      diaryOrganizationControllerProvider(widget.entryId),
    );
    if (session == null || !session.isUnlocked || session.session == null) {
      return Scaffold(
        body: session == null
            ? const Center(child: CircularProgressIndicator())
            : SessionBlockedPane(sessionState: session),
      );
    }
    if (_loaded != session.session) {
      final vault = session.session!;
      _loaded = vault;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _loaded == vault) unawaited(_load(vault));
      });
    }
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final draft = controller.draft;
        if (WidgetsBinding.instance.lifecycleState != null &&
            WidgetsBinding.instance.lifecycleState !=
                AppLifecycleState.resumed) {
          return const Scaffold();
        }
        if (draft == null) {
          return Scaffold(
            appBar: AppBar(title: Text(context.l10n.organizationTitle)),
            body: Center(
              child: controller.loading || controller.error == null
                  ? const CircularProgressIndicator()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(aiErrorText(context.l10n, controller.error!)),
                        TextButton(
                          onPressed: () => controller.load(session.session!),
                          child: Text(context.l10n.chatDiaryRetry),
                        ),
                      ],
                    ),
            ),
          );
        }
        _syncing = true;
        if (_privacy.text != draft.source.markdownBody ||
            jsonEncode(
                  _privacy.privateRanges.map((r) => r.toJson()).toList(),
                ) !=
                jsonEncode(
                  draft.hiddenRanges.map((r) => r.toJson()).toList(),
                )) {
          _privacy.setDocument(draft.source.markdownBody, draft.hiddenRanges);
        }
        if (_composer.text != draft.composer ||
            jsonEncode(
                  _composer.privateRanges.map((r) => r.toJson()).toList(),
                ) !=
                jsonEncode(
                  draft.composerRanges.map((r) => r.toJson()).toList(),
                )) {
          _composer.setDocument(draft.composer, draft.composerRanges);
        }
        _syncing = false;
        if (draft.stage == OrganizationStage.chat &&
            draft.activeTurnIndices.isNotEmpty &&
            _followTail) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _scroll.hasClients && _followTail) {
              _scroll.jumpTo(_scroll.position.maxScrollExtent);
            }
          });
        }
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) unawaited(_close());
          },
          child: draft.stage == OrganizationStage.privacy
              ? _privacyPage(controller)
              : draft.stage == OrganizationStage.review ||
                    draft.stage == OrganizationStage.applying
              ? Scaffold(
                  appBar: AppBar(
                    title: Text(context.l10n.organizationReview),
                    leading: CloseButton(onPressed: _close),
                  ),
                  body: _review(controller),
                )
              : AiChatScaffold(
                  title: context.l10n.organizationTitle,
                  leading: CloseButton(onPressed: _close),
                  onPreview: controller.busy ? null : () => _run(_preview),
                  onDelete: controller.busy
                      ? null
                      : () => _run(() => _discard(false)),
                  deleteTooltip: context.l10n.organizationDelete,
                  body: _chat(controller),
                ),
        );
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _privacy.dispose();
    _composer.dispose();
    _composerFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }
}
