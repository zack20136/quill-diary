import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/chat_diary/chat_diary_providers.dart';

import '../../app/app_colors.dart';
import '../../app/router.dart';
import '../../application/ai/ai_connection_providers.dart';
import '../../application/chat_diary/chat_diary_controller.dart';
import '../../application/session/providers/session_providers.dart';
import '../../application/session/state/app_session_state.dart';
import '../../domain/chat_diary/chat_diary_session.dart';
import '../../domain/security/unlocked_vault_session.dart';
import '../../infrastructure/ai/ai_client.dart';
import '../../infrastructure/storage/shared/gallery_image_picker.dart';
import '../../infrastructure/storage/storage_providers.dart';
import '../../l10n/l10n.dart';
import '../../shared/presentation/app_feedback.dart';
import '../../shared/presentation/widgets/app_dialog_shell.dart';
import '../../shared/presentation/widgets/app_image_gallery_dialog.dart';
import 'chat_diary_request_preview_dialog.dart';
import '../ai/ai_connection_settings_dialog.dart';
import '../ai/ai_error_text.dart';
import '../session/widgets/session_locked_pane.dart';
import 'chat_diary_actions.dart';
import 'chat_diary_input_panel.dart';
import 'chat_diary_message_bubble.dart';
import 'chat_diary_private_text_controller.dart';

class ChatDiaryPage extends ConsumerStatefulWidget {
  const ChatDiaryPage({
    super.key,
    this.chatId,
    this.entryId,
    this.isNewChat = false,
  }) : assert(chatId != null || entryId != null);
  final String? chatId;
  final String? entryId;
  final bool isNewChat;
  String get _scopeId => chatId ?? entryId!;
  @override
  ConsumerState<ChatDiaryPage> createState() => _ChatDiaryPageState();
}

class _ChatDiaryPageState extends ConsumerState<ChatDiaryPage>
    with WidgetsBindingObserver {
  final _composerController = ChatDiaryPrivateTextController();
  final _scrollController = ScrollController();
  ChatDiaryController? _chatController;
  UnlockedVaultSession? _loadedVaultSession;
  bool _syncingComposer = false;
  bool _followTail = true;
  bool _userControllingScroll = false;
  bool _jumpingToLatest = false;
  bool _tailUpdateScheduled = false;
  final _composerFocusNode = FocusNode();
  bool _isBackgrounded = false;
  final _contentDialogContexts = <Object, BuildContext>{};
  final _imageFutures = <String, Future<Uint8List?>>{};
  AiErrorCode? _lastReportedError;
  bool _lastReportedUnexpected = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _composerController.addListener(_composerChanged);
    _scrollController.addListener(_scrollChanged);
    ref.listenManual(effectiveAppSessionProvider, (_, next) {
      if (next.value?.isUnlocked != true) {
        _dismissContentDialogs();
        _imageFutures.clear();
        _chatController?.lock();
        _loadedVaultSession = null;
        _syncingComposer = true;
        _composerController.setDocument('', []);
        _syncingComposer = false;
      }
    });
  }

  void _composerChanged() {
    if (!_syncingComposer) {
      _chatController?.updateComposer(
        _composerController.text,
        _composerController.privateRanges,
      );
    }
  }

  void _changed() {
    final chatSession = _chatController?.chat;
    final unexpected =
        _chatController?.unexpectedError == true &&
        _chatController?.errorMessageId == null;
    final error = _chatController?.errorMessageId == null
        ? _chatController?.error
        : null;
    if (unexpected != _lastReportedUnexpected || error != _lastReportedError) {
      _lastReportedUnexpected = unexpected;
      _lastReportedError = error;
      if ((unexpected || error != null) && chatSession != null) {
        final vaultSession = _loadedVaultSession;
        final reportedError = error;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              !_isBackgrounded &&
              _loadedVaultSession == vaultSession &&
              _chatController?.chat == chatSession &&
              _chatController?.error == reportedError &&
              _chatController?.unexpectedError == unexpected &&
              _chatController?.errorMessageId == null) {
            showAppFeedbackToast(
              context,
              unexpected
                  ? context.l10n.aiErrorUnexpected
                  : aiErrorText(context.l10n, reportedError!),
              tone: AppFeedbackTone.error,
            );
          }
        });
      }
    }
    if (chatSession != null &&
        (_composerController.text != chatSession.composerText ||
            _composerController.privateRanges
                    .map((r) => '${r.start}:${r.end}')
                    .join(',') !=
                chatSession.composerRanges
                    .map((r) => '${r.start}:${r.end}')
                    .join(','))) {
      _syncingComposer = true;
      _composerController.setDocument(
        chatSession.composerText,
        chatSession.composerRanges,
      );
      _syncingComposer = false;
    }
    _scheduleFollowTail();
  }

  void _scheduleFollowTail() {
    if (!_followTail || _userControllingScroll || _tailUpdateScheduled) return;
    _tailUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tailUpdateScheduled = false;
      if (mounted &&
          _scrollController.hasClients &&
          _followTail &&
          !_userControllingScroll &&
          _scrollController.position.extentAfter > 0) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  void _scrollChanged() {
    if (_jumpingToLatest) return;
    final follow =
        _scrollController.hasClients &&
        _scrollController.position.extentAfter < 80;
    if (follow != _followTail && mounted) setState(() => _followTail = follow);
  }

  Future<void> _jumpToLatest() async {
    setState(() => _followTail = true);
    _jumpingToLatest = true;
    if (_scrollController.hasClients) {
      await _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
    _jumpingToLatest = false;
    if (mounted) _scrollChanged();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _chatController?.stop();
      _imageFutures.clear();
      _dismissContentDialogs();
    }
    if (mounted) {
      setState(() => _isBackgrounded = state != AppLifecycleState.resumed);
    }
  }

  Future<void> _send() async {
    _followTail = true;
    await _chatController?.send();
  }

  void _editMessage(ChatDiaryMessage message) {
    _chatController?.beginEditing(message.id);
    _composerFocusNode.requestFocus();
  }

  Future<void> _pickImages() async {
    final chatController = _chatController;
    final chatSession = chatController?.chat;
    final vaultSession = _loadedVaultSession;
    if (chatController == null || chatSession == null || vaultSession == null) {
      return;
    }
    bool stillCurrent() =>
        mounted &&
        !_isBackgrounded &&
        _loadedVaultSession == vaultSession &&
        chatController.chat == chatSession;
    try {
      final files = await pickGalleryImages();
      if (!stillCurrent()) return;
      for (final file in files) {
        final bytes = await file.readAsBytes();
        if (!stillCurrent()) return;
        await chatController.addImage(bytes);
        if (!stillCurrent()) return;
      }
    } on Object {
      if (mounted && stillCurrent()) {
        showAppFeedbackToast(
          context,
          context.l10n.aiErrorImage,
          tone: AppFeedbackTone.error,
        );
      }
    }
  }

  Future<void> _openEditor({bool generate = false}) =>
      _showFailure(() => _openEditorImpl(generate: generate));

  Future<void> _showFailure(Future<void> Function() action) async {
    final chatSession = _chatController?.chat;
    final vaultSession = _loadedVaultSession;
    bool stillCurrent() =>
        !_isBackgrounded &&
        _loadedVaultSession == vaultSession &&
        _chatController?.chat == chatSession;
    try {
      await action();
    } on AiFailure catch (error) {
      if (mounted && stillCurrent()) {
        showAppFeedbackToast(
          context,
          aiErrorText(context.l10n, error.code),
          tone: AppFeedbackTone.error,
        );
      }
    } on Object {
      if (mounted && stillCurrent()) {
        showAppFeedbackToast(
          context,
          context.l10n.aiErrorStorage,
          tone: AppFeedbackTone.error,
        );
      }
    }
  }

  Future<void> _openEditorImpl({bool generate = false}) async {
    final chatController = _chatController;
    final chatSession = chatController?.chat;
    final vaultSession = _loadedVaultSession;
    if (chatController == null || chatSession == null || vaultSession == null) {
      return;
    }
    if (generate) {
      final edited = await chatController.hasEditedDiaryDraft();
      if (!mounted || _loadedVaultSession != vaultSession) return;
      if (edited &&
          !await showAppConfirmDialog(
            context: context,
            title: context.l10n.chatDiaryGenerateDiary,
            content: Text(context.l10n.chatDiaryReplaceDraft),
            cancelLabel: context.l10n.commonActionCancel,
            confirmLabel: context.l10n.commonActionConfirm,
          )) {
        return;
      }
      if (!mounted ||
          _loadedVaultSession != vaultSession ||
          !await chatController.generate(context.l10n)) {
        return;
      }
    } else {
      await chatController.suspendForEditor();
    }
    if (!mounted || _loadedVaultSession != vaultSession) return;
    final savedId = await context.push<String>(
      '${AppRouter.editorRoute}?chat=${Uri.encodeComponent(chatSession.id)}',
    );
    if (!mounted || _loadedVaultSession != vaultSession) return;
    if (savedId != null) {
      context.pushReplacement('${AppRouter.editorRoute}/$savedId');
      return;
    }
    try {
      final result = await chatController.resumeAfterEditor(
        chatSession.id,
        vaultSession,
      );
      if (mounted &&
          _loadedVaultSession == vaultSession &&
          result == ChatDiaryLoadResult.missing) {
        context.go(AppRouter.homeRoute);
      }
    } on Object {
      if (mounted) context.pop();
    }
  }

  Future<void> _preview() => _showFailure(_previewImpl);

  Future<void> _previewImpl() async {
    final chatController = _chatController;
    final chatSession = chatController?.chat;
    final vaultSession = _loadedVaultSession;
    if (chatController == null ||
        chatSession == null ||
        chatController.busy ||
        _isBackgrounded) {
      return;
    }
    final preview = await chatController.previewConversation();
    if (!mounted ||
        preview == null ||
        vaultSession == null ||
        _loadedVaultSession != vaultSession ||
        _isBackgrounded) {
      return;
    }
    await _showContentDialog(
      (_) => ChatDiaryRequestPreviewDialog(
        preview: preview,
        imageBuilder: (id, galleryImageIds) =>
            _image(chatSession, id, galleryImageIds: galleryImageIds),
      ),
    );
  }

  void _dismissContentDialogs() {
    for (final dialogContext
        in _contentDialogContexts.values.toList().reversed) {
      if (dialogContext.mounted) Navigator.of(dialogContext).pop();
    }
    _contentDialogContexts.clear();
  }

  Future<void> _showContentDialog(
    WidgetBuilder builder, {
    bool isGallery = false,
  }) async {
    final dialogId = Object();
    Widget buildDialog(BuildContext dialogContext) {
      _contentDialogContexts[dialogId] = dialogContext;
      return builder(dialogContext);
    }

    try {
      if (isGallery) {
        await showDialog<void>(
          context: context,
          barrierColor: context.appColors.scrim,
          builder: buildDialog,
        );
      } else {
        await showAppDialog<void>(context: context, builder: buildDialog);
      }
    } finally {
      _contentDialogContexts.remove(dialogId);
    }
  }

  Future<Uint8List?> _loadImage(ChatDiarySession chatSession, String imageId) =>
      _imageFutures.putIfAbsent(
        '${chatSession.id}:${chatSession.finished}:$imageId',
        () => ref
            .read(chatDiaryStoreProvider)
            .readImage(chatSession, imageId, _loadedVaultSession!),
      );

  Future<void> _showImageGallery(
    ChatDiarySession chatSession,
    String imageId,
    List<String> imageIds,
  ) {
    final imageStore = ref.read(chatDiaryStoreProvider);
    final vaultSession = _loadedVaultSession!;
    final imageFutures = Map<String, Future<Uint8List?>>.of(_imageFutures);
    return _showContentDialog(
      (_) => AppImageGalleryDialog(
        itemCount: imageIds.length,
        initialIndex: imageIds.indexOf(imageId),
        imageBuilder: (context, index) {
          final foreground = context.appColors.galleryForeground;
          return FutureBuilder<Uint8List?>(
            future: imageFutures.putIfAbsent(
              '${chatSession.id}:${chatSession.finished}:${imageIds[index]}',
              () => imageStore.readImage(
                chatSession,
                imageIds[index],
                vaultSession,
              ),
            ),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Icon(
                  Icons.broken_image_outlined,
                  color: foreground,
                  size: 56,
                );
              }
              if (snapshot.connectionState != ConnectionState.done) {
                return Center(
                  child: CircularProgressIndicator(color: foreground),
                );
              }
              final bytes = snapshot.data;
              if (bytes == null) {
                return Center(
                  child: Text(
                    context.l10n.chatDiaryImageDeleted,
                    style: TextStyle(color: foreground),
                  ),
                );
              }
              return Image.memory(
                bytes,
                fit: BoxFit.contain,
                gaplessPlayback: true,
                cacheWidth:
                    (MediaQuery.sizeOf(context).width *
                            MediaQuery.devicePixelRatioOf(context))
                        .round(),
                errorBuilder: (_, _, _) => Icon(
                  Icons.broken_image_outlined,
                  color: foreground,
                  size: 56,
                ),
              );
            },
          );
        },
      ),
      isGallery: true,
    );
  }

  Widget _image(
    ChatDiarySession chatSession,
    String id, {
    bool removable = false,
    double size = 84,
    List<String>? galleryImageIds,
  }) => FutureBuilder<Uint8List?>(
    future: _loadImage(chatSession, id),
    builder: (context, snapshot) => SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (snapshot.hasData)
            InkWell(
              onTap: _chatController!.busy
                  ? null
                  : () => _showImageGallery(
                      chatSession,
                      id,
                      List.of(galleryImageIds ?? [id]),
                    ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  snapshot.data!,
                  fit: BoxFit.cover,
                  cacheWidth: (size * 2).round(),
                  errorBuilder: (_, _, _) =>
                      const Center(child: Icon(Icons.broken_image_outlined)),
                ),
              ),
            )
          else if (snapshot.connectionState == ConnectionState.done &&
              !snapshot.hasError)
            Center(
              child: Text(
                context.l10n.chatDiaryImageDeleted,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            )
          else
            Center(
              child: Icon(
                snapshot.hasError
                    ? Icons.broken_image_outlined
                    : Icons.image_outlined,
              ),
            ),
          if (removable)
            Align(
              alignment: Alignment.topRight,
              child: IconButton.filledTonal(
                onPressed: () => _chatController!.removePendingImage(id),
                tooltip: context.l10n.chatDiaryRemoveImage,
                icon: const Icon(Icons.close, size: 16),
              ),
            ),
        ],
      ),
    ),
  );

  Future<void> _openSettings() => _showFailure(() async {
    final chatController = _chatController;
    final chatSession = chatController?.chat;
    if (!await showAiConnectionSettingsDialog(
          context,
          initialConnection: chatSession?.connectionConfig,
          initialHidePersonNames: chatSession?.hidePersonNames,
        ) ||
        !mounted ||
        chatController == null ||
        chatController.chat != chatSession) {
      return;
    }
    final connectionsStore = ref.read(aiConnectionSettingsStoreProvider);
    final diaryStore = ref.read(chatDiarySettingsStoreProvider);
    final connection = await connectionsStore.read();
    if (!mounted || chatController.chat != chatSession) return;
    final diary = await diaryStore.read();
    if (!mounted || chatController.chat != chatSession) return;
    await chatController.applySettings(
      connection.activeConfig,
      diary.hidePersonNames,
    );
  });

  Future<void> _openSavedDiary() async {
    final chatSession = _chatController?.chat;
    final vaultSession = _loadedVaultSession;
    final entryId = chatSession?.generatedEntryId;
    if (entryId == null || vaultSession == null) return;
    await context.push('${AppRouter.editorRoute}/$entryId');
    if (!mounted || _loadedVaultSession != vaultSession) return;
    final entry = await ref
        .read(vaultRepositoryProvider)
        .loadEntry(vaultSession, entryId);
    if (!mounted || _loadedVaultSession != vaultSession) return;
    if (entry == null) {
      context.go(AppRouter.homeRoute);
      return;
    }
    setState(_imageFutures.clear);
    await _chatController!.loadForEntry(entryId, vaultSession);
  }

  Future<void> _deleteChat() async {
    final vaultSession = _loadedVaultSession;
    final chatSession = _chatController?.chat;
    if (vaultSession == null || chatSession == null) return;
    final deleted = await deleteChatDiary(
      context,
      ref,
      chatSession,
      vaultSession,
      deleteLocalChat: _chatController!.delete,
    );
    if (deleted && mounted) context.pop();
  }

  Widget _modelTag(BuildContext context, String model) {
    final colors = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width - 32,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Text(
            model,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
        ),
      ),
    );
  }

  Widget _buildConversationContent(
    ChatDiaryController chatController,
    UnlockedVaultSession? vaultSession,
    AppSessionState? sessionState,
  ) {
    final l10n = context.l10n;
    if (vaultSession == null) {
      return SessionBlockedContent(
        sessionState:
            sessionState ??
            const AppSessionState(status: AppLockStatus.uninitialized),
        onOpenSettings: () => context.push(AppRouter.settingsRoute),
        onUnlock: () => ref.read(appSessionProvider.notifier).unlock(),
      );
    }
    if (_isBackgrounded) {
      return Center(
        child: Semantics(
          label: l10n.chatDiaryContentHidden,
          child: const Icon(Icons.lock_outline),
        ),
      );
    }
    final chatSession = chatController.chat;
    if (chatSession == null) {
      return Center(
        child: chatController.error == null
            ? const CircularProgressIndicator()
            : Text(aiErrorText(l10n, chatController.error!)),
      );
    }
    final messages = chatSession.activeMessages;
    final versions = chatSession.messageVersions;
    final headers = <Widget>[
      if (chatSession.finished)
        Center(
          child: Text(
            l10n.chatDiaryArchivedNotice,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ),
      if (chatSession.openingMessage.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 28, bottom: 16),
          child: Text(
            chatSession.openingMessage,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
    ];
    final messageIndices = {
      for (var index = 0; index < messages.length; index++)
        ValueKey(messages[index].id): headers.length + index,
    };
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              NotificationListener<ScrollMetricsNotification>(
                onNotification: (_) {
                  if (!_userControllingScroll) {
                    _scheduleFollowTail();
                  }
                  return false;
                },
                child: NotificationListener<UserScrollNotification>(
                  onNotification: (notification) {
                    final holding =
                        notification.direction != ScrollDirection.idle;
                    if (holding != _userControllingScroll) {
                      _userControllingScroll = holding;
                      if (!holding) _scrollChanged();
                    }
                    return false;
                  },
                  child: ListView.builder(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    itemCount: headers.length + messages.length,
                    findChildIndexCallback: (key) => messageIndices[key],
                    itemBuilder: (context, index) {
                      if (index < headers.length) return headers[index];
                      final message = messages[index - headers.length];
                      return ChatDiaryMessageBubble(
                        key: ValueKey(message.id),
                        chatSession: chatSession,
                        message: message,
                        versions: versions[(message.parentId, message.isUser)]!,
                        isBusy: chatController.busy,
                        imageBuilder: (id) => _image(
                          chatSession,
                          id,
                          galleryImageIds: message.imageIds,
                          size: 128,
                        ),
                        onSelectVersion: chatController.selectVersion,
                        onEditMessage: _editMessage,
                        onRegenerateReply: chatController.regenerateReply,
                      );
                    },
                  ),
                ),
              ),
              if (!_followTail)
                Positioned(
                  bottom: 8,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: IconButton.filledTonal(
                      onPressed: chatController.busy ? null : _jumpToLatest,
                      tooltip: l10n.chatDiaryJumpLatest,
                      icon: const Icon(Icons.arrow_downward),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (chatSession.finished)
          Padding(
            padding: const EdgeInsets.all(12),
            child: FilledButton(
              onPressed: chatSession.generatedEntryId == null
                  ? null
                  : () => _showFailure(_openSavedDiary),
              child: Text(l10n.chatDiaryOpenDiary),
            ),
          )
        else ...[
          if (chatSession.generatedEntryId != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      chatSession.isDraftOutdated
                          ? l10n.chatDiaryDraftOutdated
                          : l10n.chatDiaryDraftReady,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  TextButton(
                    onPressed:
                        chatController.busy ||
                            chatSession.editingMessageId != null
                        ? null
                        : () => _openEditor(),
                    child: Text(l10n.chatDiaryContinueDraft),
                  ),
                ],
              ),
            ),
          if (chatSession.connectionConfig.model.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _modelTag(
                  context,
                  chatSession.connectionConfig.model.trim(),
                ),
              ),
            ),
          ChatDiaryInputPanel(
            chatSession: chatSession,
            isBusy: chatController.busy,
            canSend: chatController.canSend,
            composerController: _composerController,
            composerFocusNode: _composerFocusNode,
            imageBuilder: (id) => _image(
              chatSession,
              id,
              removable: !chatController.busy,
              galleryImageIds: chatSession.pendingImageIds,
            ),
            onCancelEditing: chatController.cancelEditing,
            onPickImages: _pickImages,
            onOpenSettings: _openSettings,
            onSend: _send,
          ),
        ],
      ],
    );
  }

  Future<void> _loadChat(
    ChatDiaryController chatController,
    UnlockedVaultSession vaultSession,
  ) async {
    final ChatDiaryLoadResult result;
    if (widget.entryId != null) {
      result = await chatController.loadForEntry(widget.entryId!, vaultSession);
    } else if (widget.isNewChat) {
      result = await chatController.start(
        widget.chatId!,
        vaultSession,
        openingMessage: context.l10n.chatDiaryWelcomeMessage,
      );
    } else {
      result = await chatController.load(
        widget.chatId!,
        vaultSession,
        openingMessage: context.l10n.chatDiaryWelcomeMessage,
      );
    }
    if (mounted &&
        _loadedVaultSession == vaultSession &&
        result == ChatDiaryLoadResult.missing) {
      ref.invalidate(chatDiarySessionsProvider);
      context.go(AppRouter.homeRoute);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final chatController = ref.watch(
      chatDiaryControllerProvider(widget._scopeId),
    );
    if (_chatController != chatController) {
      _chatController?.removeListener(_changed);
      _chatController = chatController;
      chatController.addListener(_changed);
    }
    final state = ref.watch(effectiveAppSessionProvider).value;
    final vaultSession = state?.isUnlocked == true ? state?.session : null;
    if (vaultSession != null && _loadedVaultSession != vaultSession) {
      _imageFutures.clear();
      _loadedVaultSession = vaultSession;
      unawaited(_loadChat(chatController, vaultSession));
    }
    return ListenableBuilder(
      listenable: chatController,
      builder: (context, _) {
        final chatSession = chatController.chat;
        final canUseActions =
            chatSession != null &&
            vaultSession != null &&
            !_isBackgrounded &&
            !chatController.busy;
        final showGenerate = chatSession != null && !chatSession.finished;
        final actions = <Widget>[
          if (showGenerate)
            TextButton(
              onPressed: canUseActions && chatController.canGenerate
                  ? () => _openEditor(generate: true)
                  : null,
              child: Text(l10n.chatDiaryGenerateDiary),
            ),
          IconButton(
            tooltip: l10n.chatDiaryPreviewRequest,
            onPressed: canUseActions ? _preview : null,
            icon: const Icon(Icons.visibility_outlined),
          ),
          IconButton(
            tooltip: l10n.chatDiaryDeleteChat,
            onPressed: canUseActions ? _deleteChat : null,
            style: IconButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            icon: const Icon(Icons.delete_outline),
          ),
        ];
        final textTheme = Theme.of(context).textTheme;
        final painter = TextPainter(
          text: TextSpan(
            text: l10n.chatDiaryTitle,
            style: textTheme.titleLarge,
          ),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        var requiredWidth =
            56 + 32 + painter.width + 2 * kMinInteractiveDimension;
        if (showGenerate) {
          painter.text = TextSpan(
            text: l10n.chatDiaryGenerateDiary,
            style: textTheme.labelLarge,
          );
          painter.layout();
          requiredWidth += (painter.width + 24).clamp(64, double.infinity);
        }
        painter.dispose();
        final separateActions =
            MediaQuery.sizeOf(context).width < requiredWidth;
        return PopScope(
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) {
              chatController.stop();
            }
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(
                l10n.chatDiaryTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              actions: separateActions ? null : actions,
            ),
            body: SafeArea(
              child: Column(
                children: [
                  if (separateActions)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Wrap(
                          alignment: WrapAlignment.end,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: actions,
                        ),
                      ),
                    ),
                  Expanded(
                    child: _buildConversationContent(
                      chatController,
                      vaultSession,
                      state,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _chatController?.removeListener(_changed);
    _composerController.dispose();
    _composerFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
