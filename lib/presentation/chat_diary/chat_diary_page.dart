import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import 'package:quill_diary/application/ai/ai_connection_providers.dart';
import 'package:quill_diary/application/chat_diary/chat_diary_controller.dart';
import 'package:quill_diary/application/chat_diary/chat_diary_generations.dart';
import 'package:quill_diary/application/chat_diary/chat_diary_providers.dart';
import 'package:quill_diary/application/errors/ai_error_text.dart';
import 'package:quill_diary/application/session/session_providers.dart';
import 'package:quill_diary/application/session/session_state.dart';
import 'package:quill_diary/application/settings/personalization_providers.dart';
import 'package:quill_diary/domain/ai/ai_catalog.dart';
import 'package:quill_diary/domain/ai/ai_connection_settings.dart';
import 'package:quill_diary/domain/ai/ai_failure.dart';
import 'package:quill_diary/domain/chat_diary/chat_diary_generation.dart';
import 'package:quill_diary/domain/chat_diary/chat_diary_session.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/infrastructure/storage/shared/gallery_image_picker.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/ai/ai_connection_labels.dart';
import 'package:quill_diary/presentation/ai/ai_connection_settings_dialog.dart';
import 'package:quill_diary/presentation/chat_diary/chat_diary_actions.dart';
import 'package:quill_diary/presentation/chat_diary/chat_diary_composer_actions.dart';
import 'package:quill_diary/presentation/chat_diary/chat_diary_generation_card.dart';
import 'package:quill_diary/presentation/chat_diary/chat_diary_generation_label.dart';
import 'package:quill_diary/presentation/chat_diary/chat_diary_input_panel.dart';
import 'package:quill_diary/presentation/chat_diary/chat_diary_message_bubble.dart';
import 'package:quill_diary/presentation/chat_diary/chat_diary_private_text_controller.dart';
import 'package:quill_diary/presentation/chat_diary/chat_diary_request_preview_dialog.dart';
import 'package:quill_diary/presentation/session/widgets/session_locked_pane.dart';
import 'package:quill_diary/shared/navigation/app_routes.dart';
import 'package:quill_diary/shared/presentation/app_colors.dart';
import 'package:quill_diary/shared/presentation/app_feedback.dart';
import 'package:quill_diary/shared/presentation/app_menu_style.dart';
import 'package:quill_diary/shared/presentation/editor_typography_visual.dart';
import 'package:quill_diary/shared/presentation/page_style.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_shell.dart';
import 'package:quill_diary/shared/presentation/widgets/app_image_gallery_dialog.dart';

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
  bool _canAutoOpenGeneration = false;
  bool _openingEditor = false;
  bool _isSelectingImages = false;
  Completer<void>? _imagePickerForeground;
  final _contentDialogContexts = <Object, BuildContext>{};
  final _imageFutures = <String, Future<Uint8List?>>{};
  AiErrorCode? _lastReportedError;
  bool _lastReportedUnexpected = false;
  bool _lastReportedGenerationError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _composerController.addListener(_composerChanged);
    _scrollController.addListener(_scrollChanged);
    ref.listenManual(effectiveAppSessionProvider, (_, next) {
      if (next.value?.isUnlocked != true) {
        _dismissContentDialogs();
        _closeModelMenu();
        _imageFutures.clear();
        _loadedVaultSession = null;
        _releaseImagePickerWait();
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
    if (_chatController?.busy == true || chatSession?.finished != false) {
      _closeModelMenu();
    }
    final unexpected =
        _chatController?.unexpectedError == true &&
        _chatController?.errorMessageId == null;
    final error = _chatController?.errorMessageId == null
        ? _chatController?.error
        : null;
    final generationError = _chatController?.errorFromGeneration == true;
    if (unexpected != _lastReportedUnexpected ||
        error != _lastReportedError ||
        generationError != _lastReportedGenerationError) {
      _lastReportedUnexpected = unexpected;
      _lastReportedError = error;
      _lastReportedGenerationError = generationError;
      if ((unexpected || error != null) &&
          chatSession != null &&
          _chatController?.errorFromGeneration != true) {
        final vaultSession = _loadedVaultSession;
        final reportedError = error;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              !_isBackgrounded &&
              _loadedVaultSession == vaultSession &&
              _chatController?.chat == chatSession &&
              _chatController?.error == reportedError &&
              _chatController?.unexpectedError == unexpected &&
              _chatController?.errorFromGeneration != true &&
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
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _canAutoOpenGeneration = false;
    }
    // 系統圖庫取得焦點時仍可能看見聊天；真正進入背景才遮蔽。
    if (_isSelectingImages && state == AppLifecycleState.inactive) return;
    if (state != AppLifecycleState.resumed) {
      _imageFutures.clear();
      _dismissContentDialogs();
      _closeModelMenu();
    }
    if (mounted) {
      setState(() => _isBackgrounded = state != AppLifecycleState.resumed);
    }
    if (state == AppLifecycleState.resumed) _releaseImagePickerWait();
  }

  void _releaseImagePickerWait() {
    final waiting = _imagePickerForeground;
    _imagePickerForeground = null;
    waiting?.complete();
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
    if (chatController == null ||
        chatSession == null ||
        vaultSession == null ||
        _isSelectingImages ||
        _isBackgrounded) {
      return;
    }
    bool stillCurrent() =>
        mounted &&
        !_isBackgrounded &&
        _loadedVaultSession == vaultSession &&
        chatController.chat == chatSession;
    try {
      final List<XFile> files;
      _isSelectingImages = true;
      try {
        files = await pickGalleryImages();
        // Android 可先回傳選圖結果，再通知 App 已返回前景。
        final lifecycle = WidgetsBinding.instance.lifecycleState;
        if (files.isNotEmpty &&
            mounted &&
            _loadedVaultSession == vaultSession &&
            chatController.chat == chatSession &&
            lifecycle != null &&
            lifecycle != AppLifecycleState.resumed) {
          final foreground = _imagePickerForeground = Completer<void>();
          await foreground.future;
        }
      } finally {
        _isSelectingImages = false;
      }
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

  Future<void> _openEditor({bool generate = false}) async {
    if (_openingEditor || _isBackgrounded) return;
    _openingEditor = true;
    if (generate) _canAutoOpenGeneration = true;
    try {
      await _showFailure(() => _openEditorImpl(generate: generate));
    } finally {
      _openingEditor = false;
    }
  }

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
    bool canOpen() =>
        mounted &&
        !_isBackgrounded &&
        _loadedVaultSession == vaultSession &&
        chatController.chat == chatSession &&
        ModalRoute.of(context)?.isCurrent != false;
    if (generate) {
      final edited = await chatController.hasEditedDiaryDraft();
      if (!mounted || !canOpen() || !chatController.canGenerate) return;
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
      if (!mounted || !canOpen() || !chatController.canGenerate) return;
      _composerFocusNode.unfocus();
      final result = await chatController.generate(context.l10n);
      if (!mounted ||
          _isBackgrounded ||
          _loadedVaultSession != vaultSession ||
          chatController.chat != chatSession) {
        return;
      }
      if (result != ChatDiaryGenerationResult.generated) return;
      if (!_canAutoOpenGeneration ||
          ModalRoute.of(context)?.isCurrent == false) {
        return;
      }
    }
    if (!await chatController.handOffToEditor(canOpen: canOpen) || !mounted) {
      return;
    }
    final savedId = await context.push<String>(
      '${AppRoutes.editorRoute}?chat=${Uri.encodeComponent(chatSession.id)}',
    );
    if (!mounted || _loadedVaultSession != vaultSession) return;
    if (savedId != null) {
      context.pushReplacement('${AppRoutes.editorRoute}/$savedId');
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
        context.go(AppRoutes.homeRoute);
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
    final result = await showAiConnectionSettingsDialog(
      context,
      initialConnection: chatSession?.connectionConfig,
      initialHidePersonNames: chatSession?.hidePersonNames,
    );
    if (result == null ||
        !mounted ||
        chatController == null ||
        chatController.chat != chatSession) {
      return;
    }
    final settingsStore = ref.read(aiSettingsStoreProvider);
    final session = ref.read(appSessionProvider).session;
    if (session == null) return;
    final stored = await settingsStore.read(session);
    if (!mounted || chatController.chat != chatSession) return;
    await chatController.applySettings(
      result.chatConnection ?? chatSession!.connectionConfig,
      stored.chatDiary.hidePersonNames,
    );
  });

  Future<void> _deleteChat() async {
    final vaultSession = _loadedVaultSession;
    final chatSession = _chatController?.chat;
    if (vaultSession == null || chatSession == null) return;
    final deleted = await deleteChatDiary(
      context,
      ref,
      chatSession,
      vaultSession,
    );
    if (deleted && mounted) context.pop();
  }

  List<ChatModelOption> _modelChoices = const [];
  bool _currentModelIsExtra = false;
  final MenuController _modelMenuController = MenuController();
  final FocusNode _modelTagFocusNode = FocusNode();
  final FocusNode _modelMenuFocusNode = FocusNode();
  int _modelMenuRequest = 0;

  void _closeModelMenu() {
    _modelMenuRequest++;
    _modelMenuController.close();
  }

  Future<void> _openModelMenu() async {
    if (_modelMenuController.isOpen) {
      _closeModelMenu();
      return;
    }
    final chatController = _chatController;
    final chatSession = chatController?.chat;
    final vaultSession = _loadedVaultSession;
    if (chatController == null ||
        chatSession == null ||
        vaultSession == null ||
        chatSession.finished ||
        chatController.busy ||
        _isBackgrounded) {
      return;
    }
    final request = ++_modelMenuRequest;
    bool canOpen() =>
        mounted &&
        request == _modelMenuRequest &&
        !_isBackgrounded &&
        _loadedVaultSession == vaultSession &&
        _chatController?.chat == chatSession &&
        !chatController.busy &&
        !chatSession.finished;
    final stored = await ref.read(aiSettingsStoreProvider).read(vaultSession);
    if (!canOpen()) return;
    final Map<String, bool> apiKeys = {};
    for (final config in stored.connection.orderedConnections) {
      final String apiKey = await ref
          .read(aiSettingsStoreProvider)
          .readApiKey(config);
      if (!canOpen()) return;
      apiKeys[config.connectionId] = apiKey.trim().isNotEmpty;
    }
    final menuModels = chatModelMenu(
      settings: stored.connection,
      chatConfig: chatSession.connectionConfig,
      hasApiKey: (config) => apiKeys[config.connectionId] ?? false,
    );
    if (menuModels.models.isEmpty) return;
    setState(() {
      _modelChoices = menuModels.models;
      _currentModelIsExtra = menuModels.currentIsExtra;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (canOpen()) _modelMenuController.open();
    });
  }

  Widget _modelTag(BuildContext context, AiConnectionConfig current) {
    final colors = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final chatController = _chatController;
    final canSwitch =
        chatController != null &&
        !chatController.busy &&
        chatController.chat?.finished != true;
    final labelCounts = <String, int>{};
    for (final choice in _modelChoices) {
      final label = aiChatModelLabel(l10n, choice.connectionConfig);
      labelCounts.update(label, (count) => count + 1, ifAbsent: () => 1);
    }
    final menuItems = <Widget>[
      for (final choice in _modelChoices)
        Builder(
          builder: (context) {
            final selected = sameAiTarget(choice.connectionConfig, current);
            final label = aiChatModelLabel(l10n, choice.connectionConfig);
            final description =
                '${aiConnectionLabel(l10n, choice.connectionConfig)}\n${choice.connectionConfig.effectiveBaseUrl}/${choice.modelId}';
            return MenuItemButton(
              overflowAxis: Axis.vertical,
              key: ValueKey(
                'chat-model-option-${choice.connectionId}-${choice.modelId}${choice.isCurrentSnapshot ? '-current' : ''}',
              ),
              focusNode: selected ? _modelMenuFocusNode : null,
              onPressed: () {
                _closeModelMenu();
                unawaited(chatController!.selectChatModel(choice));
              },
              style: appMenuItemStyle(context, selected: selected),
              trailingIcon: selected ? const Icon(Icons.check, size: 18) : null,
              child: Tooltip(
                message: description,
                excludeFromSemantics: true,
                child: Semantics(
                  label: description,
                  selected: selected,
                  excludeSemantics: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        selected && _currentModelIsExtra
                            ? '$label · ${l10n.aiModelCurrent}'
                            : label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      if (choice.connectionConfig.provider ==
                              AiProvider.custom &&
                          labelCounts[label]! > 1)
                        Text(
                          aiConnectionLabel(l10n, choice.connectionConfig),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
    ];
    return RawMenuAnchor(
      controller: _modelMenuController,
      childFocusNode: _modelTagFocusNode,
      onOpen: _modelMenuFocusNode.requestFocus,
      consumeOutsideTaps: true,
      overlayBuilder: (context, info) {
        const gap = 6.0;
        final menuWidth = (info.overlaySize.width - 48).clamp(0.0, 320.0);
        final maxHeight =
            (info.anchorRect.top - MediaQuery.paddingOf(context).top - gap - 8)
                .clamp(0.0, 320.0);
        final maxLeft = (info.overlaySize.width - menuWidth - 12).clamp(
          0.0,
          double.infinity,
        );
        final menuStyle = appMenuStyle(context, width: menuWidth);
        return Positioned(
          left: info.anchorRect.left.clamp(0.0, maxLeft),
          bottom: info.overlaySize.height - info.anchorRect.top + gap,
          child: TapRegion(
            groupId: info.tapRegionGroupId,
            consumeOutsideTaps: true,
            onTapOutside: (_) => _closeModelMenu(),
            child: FocusTraversalGroup(
              policy: WidgetOrderTraversalPolicy(),
              child: FocusScope(
                child: Shortcuts(
                  shortcuts: const {
                    SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
                    SingleActivator(LogicalKeyboardKey.arrowDown):
                        NextFocusIntent(),
                    SingleActivator(LogicalKeyboardKey.arrowUp):
                        PreviousFocusIntent(),
                  },
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: menuWidth.clamp(0.0, 200.0),
                      maxWidth: menuWidth,
                      maxHeight: maxHeight,
                    ),
                    child: IntrinsicWidth(
                      child: Material(
                        key: const ValueKey('chat-model-menu'),
                        color: menuStyle.backgroundColor!.resolve({}),
                        shape: menuStyle.shape!.resolve({}),
                        clipBehavior: Clip.antiAlias,
                        child: Semantics(
                          container: true,
                          explicitChildNodes: true,
                          child: Padding(
                            padding: menuStyle.padding!.resolve({})!,
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: menuItems,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      builder: (context, controller, child) => ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width - 32,
        ),
        child: Material(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
          clipBehavior: Clip.antiAlias,
          child: Tooltip(
            message: l10n.aiSwitchModel,
            child: InkWell(
              key: const ValueKey('chat-model-tag'),
              focusNode: _modelTagFocusNode,
              onTap: canSwitch ? () => unawaited(_openModelMenu()) : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        aiChatModelLabel(l10n, current),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(color: colors.onSurfaceVariant),
                      ),
                    ),
                    Icon(
                      Icons.arrow_drop_down,
                      size: 18,
                      color: colors.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _terminalGenerationStatus(
    AppLocalizations l10n,
    ChatDiaryGeneration generation,
  ) {
    if (generation.phase == ChatDiaryGenerationPhase.completed) return null;
    final label = chatDiaryGenerationPhaseLabel(l10n, generation.phase);
    final failure = chatDiaryGenerationFailureDetail(l10n, generation);
    return failure == null ? label : '$label\n$failure';
  }

  Widget? _generationNotice(
    AppLocalizations l10n,
    ChatDiarySession chatSession,
    ChatDiaryController chatController,
    ChatDiaryGeneration? generation,
  ) {
    if (chatSession.finished || generation?.phase.isActive == true) return null;
    final retry = generation == null
        ? null
        : _terminalGenerationStatus(l10n, generation);
    if (retry != null) {
      return _generationNoticeBanner(
        message: retry,
        tone: generation!.phase == ChatDiaryGenerationPhase.failed
            ? AppFeedbackTone.error
            : AppFeedbackTone.info,
        actionLabel: l10n.chatDiaryRetryGeneration,
        onPressed: chatController.canGenerate
            ? () => _openEditor(generate: true)
            : null,
      );
    }
    if (chatSession.generatedEntryId == null) return null;
    final outdated = chatSession.isDraftOutdated;
    return _generationNoticeBanner(
      message: outdated
          ? l10n.chatDiaryDraftOutdated
          : l10n.chatDiaryDraftReady,
      tone: outdated ? AppFeedbackTone.warning : AppFeedbackTone.success,
      actionLabel: l10n.chatDiaryViewDraft,
      onPressed: chatController.busy || chatSession.editingMessageId != null
          ? null
          : () => _openEditor(),
    );
  }

  Widget _generationNoticeBanner({
    required String message,
    required AppFeedbackTone tone,
    required String actionLabel,
    required VoidCallback? onPressed,
  }) {
    final theme = Theme.of(context);
    final colors = resolveAppFeedbackColors(context, tone);
    final split = message.split('\n');
    final detail = split.length > 1 ? split.sublist(1).join('\n') : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Semantics(
        liveRegion: true,
        child: DecoratedBox(
          key: const ValueKey('chat-diary-generation-notice'),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(PageStyle.radiusCard),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  split.first,
                  style: detail == null
                      ? theme.textTheme.bodyMedium
                      : theme.textTheme.titleSmall,
                ),
                if (detail != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    detail,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: onPressed,
                    style: TextButton.styleFrom(
                      foregroundColor: colors.foreground,
                      backgroundColor: colors.background,
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(actionLabel),
                  ),
                ),
              ],
            ),
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
        onOpenSettings: () => context.push(AppRoutes.settingsRoute),
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
    final generation = ref.watch(
      chatDiaryGenerationsProvider.select(
        (jobs) => jobs[(chatSession.vaultId, chatSession.id)],
      ),
    );
    final generating = generation?.phase.isActive == true;
    final notice = _generationNotice(
      l10n,
      chatSession,
      chatController,
      generation,
    );
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
            style: watchPersonalizationPreferences(ref).typography
                .bodyTextStyle(Theme.of(context).textTheme),
          ),
        ),
    ];
    final messageIndices = {
      for (var index = 0; index < messages.length; index++)
        ValueKey(messages[index].id): headers.length + index,
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        final inputStyle = Theme.of(context).textTheme.bodyLarge!;
        final lineHeight =
            MediaQuery.textScalerOf(context).scale(inputStyle.fontSize!) *
            (inputStyle.height ?? 1);
        final textHeight =
            constraints.maxHeight / 3 -
            22 -
            (chatSession.pendingImageIds.isEmpty ? 0 : 96) -
            (chatSession.editingMessageId == null ? 0 : 48);
        final composerMaxLines = (textHeight / lineHeight).floor().clamp(1, 5);
        var composerMaxHeight = constraints.maxHeight * 0.7;
        if (notice != null) {
          final available = constraints.maxHeight - 260;
          if (available < composerMaxHeight) {
            composerMaxHeight = available > 0 ? available : 0;
          }
        }
        return Column(
          children: [
            Expanded(
              child: Column(
                children: [
                  if (notice != null) notice,
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
                                  notification.direction !=
                                  ScrollDirection.idle;
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
                              findChildIndexCallback: (key) =>
                                  messageIndices[key],
                              itemBuilder: (context, index) {
                                if (index < headers.length)
                                  return headers[index];
                                final message =
                                    messages[index - headers.length];
                                return ChatDiaryMessageBubble(
                                  key: ValueKey(message.id),
                                  chatSession: chatSession,
                                  message: message,
                                  versions:
                                      versions[(
                                        message.parentId,
                                        message.isUser,
                                      )]!,
                                  isBusy: chatController.busy,
                                  imageBuilder: (id) => _image(
                                    chatSession,
                                    id,
                                    galleryImageIds: message.imageIds,
                                    size: 128,
                                  ),
                                  onSelectVersion: chatController.selectVersion,
                                  onEditMessage: _editMessage,
                                  onRegenerateReply:
                                      chatController.regenerateReply,
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
                                onPressed: chatController.busy
                                    ? null
                                    : _jumpToLatest,
                                tooltip: l10n.chatDiaryJumpLatest,
                                icon: const Icon(Icons.arrow_downward),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (!chatSession.finished)
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: composerMaxHeight),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (generating)
                        ChatDiaryGenerationCard(
                          generation: generation!,
                          onStop: chatController.stop,
                        )
                      else ...[
                        ChatDiaryComposerActions(
                          model:
                              chatSession.connectionConfig.model.trim().isEmpty
                              ? null
                              : _modelTag(
                                  context,
                                  chatSession.connectionConfig,
                                ),
                          onGenerate: chatController.canGenerate
                              ? () => _openEditor(generate: true)
                              : null,
                        ),
                        ChatDiaryInputPanel(
                          maxLines: composerMaxLines,
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
                  ),
                ),
              ),
          ],
        );
      },
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
    if (!mounted || _loadedVaultSession != vaultSession) return;
    if (result == ChatDiaryLoadResult.loaded) {
      _changed();
    }
    if (result == ChatDiaryLoadResult.missing) {
      ref.invalidate(chatDiarySessionsProvider);
      context.go(AppRoutes.homeRoute);
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
        final actions = <Widget>[
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
        final requiredWidth =
            56 + 32 + painter.width + 2 * kMinInteractiveDimension;
        painter.dispose();
        final separateActions =
            MediaQuery.sizeOf(context).width < requiredWidth;
        return PopScope(
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) {
              _canAutoOpenGeneration = false;
              unawaited(chatController.persist());
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
    _releaseImagePickerWait();
    _chatController?.removeListener(_changed);
    _composerController.dispose();
    _composerFocusNode.dispose();
    _scrollController.dispose();
    _closeModelMenu();
    _modelTagFocusNode.dispose();
    _modelMenuFocusNode.dispose();
    super.dispose();
  }
}
