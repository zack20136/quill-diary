import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../domain/attachment/asset_attachment.dart';
import '../../../domain/diary/diary_entry.dart';
import '../../../domain/security/unlocked_vault_session.dart';
import '../../../domain/shared/value_objects.dart';
import '../../../infrastructure/database/index_database.dart';
import '../../../infrastructure/preferences/editor_typography_preferences.dart';
import '../../../infrastructure/storage/vault_repository.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/presentation/app_feedback.dart';
import '../../../shared/presentation/display_format.dart';
import '../../../app/app_colors.dart';
import '../../../shared/presentation/tag_visual.dart';
import '../../../shared/presentation/widgets/tag_accent_composer_dialog.dart';
import '../../../shared/providers/tag_providers.dart';
import '../../../shared/utils/diary_presence_tag_counts.dart';
import '../../../shared/utils/tag_catalog_merge.dart';
import '../../../shared/utils/user_facing_error.dart';
import '../../home/providers/home_providers.dart';
import '../../session/presentation/session_locked_pane.dart';
import '../../session/providers/session_providers.dart';
import '../../session/state/app_session_state.dart';
import '../../settings/providers/personalization_providers.dart';
import '../../settings/providers/settings_providers.dart';
import '../application/editor_draft_models.dart';
import '../application/editor_flow_controller.dart';
import '../gallery_image_download.dart';
import '../presentation/editor_attachment_strip.dart';
import '../presentation/editor_form_sections.dart';
import '../presentation/editor_keyboard_chrome.dart';
import '../presentation/editor_preview_gallery.dart';
import '../presentation/editor_top_bar.dart';
import '../providers/editor_draft_providers.dart';
import '../providers/editor_providers.dart';

part '../widgets/editor_dialogs.dart';

class EditorPage extends ConsumerStatefulWidget {
  const EditorPage({super.key, this.entryId, this.startInEditMode = false});

  final String? entryId;
  final bool startInEditMode;

  @override
  ConsumerState<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends ConsumerState<EditorPage>
    with WidgetsBindingObserver {
  static const double _editorSectionGap = 8;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _dateController = TextEditingController(
    text: DateOnly.fromDateTime(DateTime.now()).value,
  );
  final TextEditingController _tagsController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final List<PendingAttachment> _pendingAttachments = <PendingAttachment>[];
  final Map<String, Future<String>> _savedAssetPathFutures =
      <String, Future<String>>{};

  List<AssetId> _keptExistingAttachmentIds = <AssetId>[];
  late bool _previewMode;
  TimeOfDay _entryTime = TimeOfDay.now();
  bool _didLoadExisting = false;
  bool _saving = false;
  bool _showEntryRequiredHint = false;
  int? _draggingEditorImageIndex;
  bool _didOfferDraftRestore = false;
  bool _handlingDraftRestore = false;
  bool _preservesEditorOnLock = false;
  bool _draftPersistInFlight = false;
  bool _draftPersistQueued = false;
  bool _suppressTagDraftListener = false;
  bool _suppressDraftListener = false;
  late final ProviderSubscription<AsyncValue<AppSessionState>>
  _sessionSubscription;

  EditorDraftSnapshot? _lastSavedSnapshot;
  EditorDraftSnapshot? _lastPersistedDraftSnapshot;
  UnlockedVaultSession? _activeSession;
  DiaryEntry? _activeEntry;
  EntryId? _provisionalEntryId;
  DateTime? _draftCreatedAt;

  static const String _newDraftKey = '__new__';

  EditorFlowController get _editorFlow =>
      ref.read(editorFlowControllerProvider);

  bool get _isEditing => !_previewMode;
  String get _draftKey => widget.entryId ?? _newDraftKey;
  bool get _hasTitle => _titleController.text.trim().isNotEmpty;
  bool get _hasBody => _bodyController.text.trim().isNotEmpty;
  bool get _canSaveEntry => _hasTitle || _hasBody;

  Iterable<PendingAttachment> get _pendingImageAttachments =>
      _pendingAttachments.where(
        (PendingAttachment attachment) =>
            attachment.mimeType.startsWith('image/'),
      );

  Iterable<PendingAttachment> get _pendingNonImageAttachments =>
      _pendingAttachments.where(
        (PendingAttachment attachment) =>
            !attachment.mimeType.startsWith('image/'),
      );

  Map<String, int> _watchedTagAccentArgbMap() {
    return ref
        .watch(tagAccentArgbMapProvider)
        .maybeWhen(
          data: (Map<String, int> map) => map,
          orElse: () => const <String, int>{},
        );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _previewMode = widget.entryId != null && !widget.startInEditMode;
    _provisionalEntryId = widget.entryId ?? generateEntryId();
    _draftCreatedAt = DateTime.now();
    _dateController.addListener(_clearSavedAssetEncryptedPathFutures);
    _tagsController.addListener(_onDraftChanged);
    _titleController.addListener(_onDraftChanged);
    _bodyController.addListener(_onDraftChanged);
    _dateController.addListener(_onDraftChanged);
    _sessionSubscription = ref.listenManual<AsyncValue<AppSessionState>>(
      effectiveAppSessionProvider,
      (_, AsyncValue<AppSessionState> next) {
        next.whenData((AppSessionState sessionState) {
          if (sessionState.status != AppLockStatus.locked) {
            return;
          }
          _onSessionLocked();
        });
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionSubscription.close();
    _persistDraftBeforeDispose();
    _draftPersistQueued = false;
    _dateController.removeListener(_clearSavedAssetEncryptedPathFutures);
    _dateController.removeListener(_onDraftChanged);
    _tagsController.removeListener(_onDraftChanged);
    _titleController.removeListener(_onDraftChanged);
    _bodyController.removeListener(_onDraftChanged);
    _titleController.dispose();
    _dateController.dispose();
    _tagsController.dispose();
    _bodyController.dispose();
    _savedAssetPathFutures.clear();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      unawaited(_persistDraftNow());
    }
  }

  void _onDraftChanged() {
    if (_suppressTagDraftListener || _previewMode || !mounted) {
      return;
    }
    if (_suppressDraftListener) {
      return;
    }
    setState(() {
      if (_showEntryRequiredHint && _canSaveEntry) {
        _showEntryRequiredHint = false;
      }
    });
    _scheduleDraftPersist();
  }

  void _notifyEntryRequired() {
    if (!mounted) {
      return;
    }
    setState(() => _showEntryRequiredHint = true);
    showAppFeedbackSnackBar(context, context.l10n.editorSaveNeedsEntryMessage);
  }

  EditorDraftSnapshot _currentDraftSnapshot() {
    return buildEditorDraftSnapshot(
      titleRaw: _titleController.text,
      dateRaw: _dateController.text,
      entryHour: _entryTime.hour,
      entryMinute: _entryTime.minute,
      tagsRaw: _tagsController.text,
      bodyRaw: _bodyController.text,
      keptAttachmentIds: _keptExistingAttachmentIds,
      pendingAttachments: _pendingAttachments,
    );
  }

  bool _isDraftDirty() {
    return editorDraftIsDirty(
      current: _currentDraftSnapshot(),
      saved: _lastSavedSnapshot,
    );
  }

  bool _shouldSkipDraftPersist() {
    if (!_isEditing || _saving || _handlingDraftRestore) {
      return true;
    }
    final EditorDraftSnapshot current = _currentDraftSnapshot();
    if (_lastPersistedDraftSnapshot != null &&
        !editorDraftIsDirty(
          current: current,
          saved: _lastPersistedDraftSnapshot,
        )) {
      return true;
    }
    if (widget.entryId == null && editorDraftIsEmpty(current)) {
      return true;
    }
    return false;
  }

  void _scheduleDraftPersist() {
    if (_previewMode) {
      return;
    }
    if (_draftPersistInFlight) {
      _draftPersistQueued = true;
      return;
    }
    unawaited(_persistDraft());
  }

  Future<void> _persistDraft() async {
    if (_draftPersistInFlight || _shouldSkipDraftPersist()) {
      return;
    }
    _draftPersistInFlight = true;
    final UnlockedVaultSession? session = _activeSession;
    if (session == null) {
      _draftPersistInFlight = false;
      return;
    }

    try {
      final EditorPersistDraftResult result = await _editorFlow.persistDraft(
        EditorPersistDraftRequest(
          draftKey: _draftKey,
          snapshot: _currentDraftSnapshot(),
          tagsRaw: _tagsController.text,
          keptAttachmentIds: List<AssetId>.from(_keptExistingAttachmentIds),
          pendingAttachments: List<PendingAttachment>.from(_pendingAttachments),
          session: session,
          createdAt: _draftCreatedAt ?? DateTime.now(),
          provisionalEntryId: _provisionalEntryId ??=
              widget.entryId ?? generateEntryId(),
          existingEntryId: widget.entryId,
        ),
      );
      _draftCreatedAt = result.record.createdAt;
      _lastPersistedDraftSnapshot = result.snapshot;
    } finally {
      _draftPersistInFlight = false;
      if (_draftPersistQueued) {
        _draftPersistQueued = false;
        if (!_previewMode) {
          unawaited(_persistDraft());
        }
      }
    }
  }

  Future<void> _persistDraftNow() async {
    if (_draftPersistInFlight) {
      _draftPersistQueued = true;
    } else {
      await _persistDraft();
    }
    while (_draftPersistInFlight || _draftPersistQueued) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> _requestClose() async {
    if (_saving) {
      return;
    }
    if (!_isEditing) {
      if (mounted) {
        context.pop();
      }
      return;
    }
    await _persistDraftNow();
    if (!_isDraftDirty()) {
      await _discardLocalDraft();
      if (!mounted) {
        return;
      }
      if (widget.entryId == null) {
        context.pop();
      } else {
        setState(() => _previewMode = true);
      }
      return;
    }
    final bool? discard = await _showDiscardDraftDialog();
    if (discard != true) {
      return;
    }
    await _discardLocalDraft();
    if (!mounted) {
      return;
    }
    if (widget.entryId == null) {
      context.pop();
      return;
    }
    final DiaryEntry? entry = _activeEntry;
    if (entry != null) {
      _applyEntryToControllers(entry);
    }
    setState(() => _previewMode = true);
  }

  Future<void> _discardLocalDraft() async {
    _draftPersistQueued = false;
    await _editorFlow.discardDraft(_draftKey);
    _lastPersistedDraftSnapshot = null;
  }

  void _applyEntryToControllers(DiaryEntry entry) {
    _suppressDraftListener = true;
    _suppressTagDraftListener = true;
    _titleController.text = entry.title ?? '';
    _dateController.text = entry.date.value;
    _tagsController.text = entry.tags.join(', ');
    _bodyController.text = entry.markdownBody;
    _keptExistingAttachmentIds = List<AssetId>.from(entry.attachmentIds);
    _pendingAttachments.clear();
    _savedAssetPathFutures.clear();
    _entryTime = TimeOfDay(
      hour: entry.createdAt.hour,
      minute: entry.createdAt.minute,
    );
    _provisionalEntryId = entry.id;
    _draftCreatedAt = entry.createdAt;
    _lastSavedSnapshot = editorDraftSnapshotFromEntry(entry);
    _showEntryRequiredHint = false;
    _suppressTagDraftListener = false;
    _suppressDraftListener = false;
  }

  void _applyDraftRestore(EditorDraftRestoreDecision decision) {
    final EditorDraftRecord record = decision.record!;
    _suppressDraftListener = true;
    _suppressTagDraftListener = true;
    _titleController.text = record.title ?? '';
    _dateController.text = record.dateValue;
    _tagsController.text = record.tags.join(', ');
    _bodyController.text = record.markdownBody;
    _keptExistingAttachmentIds = List<AssetId>.from(record.keptAttachmentIds);
    _pendingAttachments
      ..clear()
      ..addAll(decision.pendingAttachments);
    _entryTime = TimeOfDay(hour: record.entryHour, minute: record.entryMinute);
    _provisionalEntryId = record.provisionalEntryId;
    _draftCreatedAt = record.createdAt;
    _lastPersistedDraftSnapshot = decision.snapshot;
    _showEntryRequiredHint = false;
    _suppressTagDraftListener = false;
    _suppressDraftListener = false;
    if (mounted) {
      setState(() => _previewMode = false);
    }
  }

  Future<void> _offerDraftRestoreIfNeeded(
    UnlockedVaultSession session,
    DiaryEntry? entry,
  ) async {
    if (!mounted) {
      return;
    }
    _handlingDraftRestore = true;
    final EditorDraftRestoreDecision decision = await _editorFlow
        .restoreDraftIfNeeded(
          draftKey: _draftKey,
          session: session,
          existingEntry: entry,
          decideRestore: (EditorDraftRecord record) =>
              _showRestoreDraftDialog(record, hasExistingEntry: entry != null),
        );
    _handlingDraftRestore = false;
    if (!mounted) {
      return;
    }
    if (decision.kind == EditorDraftRestoreKind.restored) {
      _applyDraftRestore(decision);
      return;
    }
    if (decision.kind == EditorDraftRestoreKind.discarded && entry != null) {
      _applyEntryToControllers(entry);
      setState(() {});
    }
  }

  void _onSessionLocked() {
    if (_isEditing && _activeSession != null) {
      _preservesEditorOnLock = true;
      _didOfferDraftRestore = true;
    }
    unawaited(_persistDraftAndMaybeClear());
  }

  Future<void> _persistDraftAndMaybeClear() async {
    if (_isEditing &&
        !_saving &&
        !_handlingDraftRestore &&
        _activeSession != null &&
        mounted) {
      await _persistDraftNow();
    }
    if (mounted && !_preservesEditorOnLock) {
      _clearSensitiveLocalState();
    }
  }

  void _clearSensitiveLocalState() {
    _titleController.clear();
    _dateController.text = DateOnly.fromDateTime(DateTime.now()).value;
    _tagsController.clear();
    _bodyController.clear();
    _pendingAttachments.clear();
    _keptExistingAttachmentIds = <AssetId>[];
    _savedAssetPathFutures.clear();
    _lastSavedSnapshot = null;
    _lastPersistedDraftSnapshot = null;
    _didLoadExisting = false;
    _didOfferDraftRestore = false;
    _handlingDraftRestore = false;
    _draftPersistInFlight = false;
    _draftPersistQueued = false;
    _previewMode = widget.entryId != null && !widget.startInEditMode;
    _entryTime = TimeOfDay.now();
    _provisionalEntryId = widget.entryId ?? generateEntryId();
    _draftCreatedAt = DateTime.now();
    if (mounted) {
      setState(() {});
    }
  }

  void _persistDraftBeforeDispose() {
    if (_isEditing &&
        !_saving &&
        !_handlingDraftRestore &&
        _activeSession != null &&
        _isDraftDirty()) {
      unawaited(_persistDraftNow());
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<AppSessionState> sessionAsync = ref.watch(
      effectiveAppSessionProvider,
    );
    final AsyncValue<DiaryEntry?> entryAsync = widget.entryId == null
        ? const AsyncValue<DiaryEntry?>.data(null)
        : ref.watch(entryProvider(widget.entryId!));
    final AsyncValue<Object?> metadataAsync = ref.watch(
      recoveryMetadataProvider,
    );

    return sessionAsync.when(
      data: (AppSessionState sessionState) {
        final UnlockedVaultSession? session = sessionState.session;
        if (!sessionState.isUnlocked || session == null) {
          return Scaffold(
            appBar: AppBar(title: Text(context.l10n.editorPageTitle)),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SessionBlockedPane(sessionState: sessionState),
              ),
            ),
          );
        }

        return entryAsync.when(
          data: (DiaryEntry? entry) {
            _loadExistingEntryIfNeeded(entry);
            _activeSession = session;
            _activeEntry = entry;
            if (_preservesEditorOnLock) {
              _preservesEditorOnLock = false;
            }
            if (!_didOfferDraftRestore) {
              _didOfferDraftRestore = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                unawaited(_offerDraftRestoreIfNeeded(session, entry));
              });
            }

            final AsyncValue<List<AssetAttachment>> attachmentsAsync =
                widget.entryId == null
                ? const AsyncValue<List<AssetAttachment>>.data(
                    <AssetAttachment>[],
                  )
                : ref.watch(entryAttachmentsProvider(widget.entryId!));
            final List<AssetAttachment> allSavedAttachments =
                attachmentsAsync.asData?.value ?? const <AssetAttachment>[];
            final List<AssetAttachment> savedImages = _orderedSavedImages(
              allSavedAttachments,
            );
            final List<AssetAttachment> savedNonImages =
                _savedNonImageAttachments(allSavedAttachments);
            final List<PendingAttachment> pendingImages =
                _pendingImageAttachments.toList();
            final List<PendingAttachment> pendingNonImages =
                _pendingNonImageAttachments.toList();
            final EditorTypographyPreferences typography =
                watchPersonalizationPreferences(ref).typography;
            final bool showUnsavedTag =
                widget.entryId != null &&
                ref
                    .watch(editorDraftKeysProvider)
                    .maybeWhen(
                      data: (Set<String> draftKeys) =>
                          draftKeys.contains(widget.entryId),
                      orElse: () => false,
                    );

            return PopScope(
              canPop: false,
              onPopInvokedWithResult: (bool didPop, Object? result) {
                if (didPop) {
                  return;
                }
                unawaited(_requestClose());
              },
              child: Scaffold(
                body: metadataAsync.when(
                  data: (Object? metadata) {
                    if (metadata == null) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            context.l10n.editorNeedsRecoveryKeyMessage,
                          ),
                        ),
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        EditorTopBar(
                          previewMode: _previewMode,
                          saving: _saving,
                          canSaveEntry: _canSaveEntry,
                          canDelete: widget.entryId != null,
                          previewTimestampLabel:
                              '${_formattedDisplayDate(context)} · ${_formattedEntryTime24h()}',
                          onClose: () => unawaited(_requestClose()),
                          onPickDate: _pickEntryDate,
                          onPickTime: _pickEntryTime,
                          onEditTags: _showTagsEditorDialog,
                          onPickImage: () => unawaited(_pickImage()),
                          onPickFile: () => unawaited(_pickFile()),
                          onSave: () =>
                              unawaited(_saveCurrentEntry(session, entry)),
                          onDelete: () =>
                              unawaited(_deleteCurrentEntry(session)),
                          onEnterEditMode: _enterEditMode,
                        ),
                        Expanded(
                          child: SafeArea(
                            top: false,
                            child: Builder(
                              builder: (BuildContext context) {
                                final bool keyboardVisible =
                                    MediaQuery.viewInsetsOf(
                                      this.context,
                                    ).bottom >
                                    0;
                                final bool hideEditorChromeForKeyboard =
                                    _isEditing && keyboardVisible;
                                final bool showVisualEditorChrome =
                                    !hideEditorChromeForKeyboard;
                                final bool hasNonImageAttachments =
                                    savedNonImages.isNotEmpty ||
                                    pendingNonImages.isNotEmpty;
                                final bool shouldShowSidebarAttachments =
                                    (!_previewMode || hasNonImageAttachments) &&
                                    showVisualEditorChrome;
                                final Widget sidebar = Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    if (shouldShowSidebarAttachments)
                                      EditorAttachmentStrip(
                                        savedImages: savedImages,
                                        pendingImages: pendingImages,
                                        savedNonImages: savedNonImages,
                                        pendingNonImages: pendingNonImages,
                                        editable: _isEditing,
                                        draggingIndex:
                                            _draggingEditorImageIndex,
                                        encryptedPathFuture:
                                            _cachedEncryptedPathFuture,
                                        onRemoveSaved: _removeSavedAttachment,
                                        onRemovePending:
                                            _removePendingAttachment,
                                        onReorder:
                                            (int oldIndex, int newIndex) =>
                                                _reorderEditorImages(
                                                  allSaved: allSavedAttachments,
                                                  oldIndex: oldIndex,
                                                  newIndex: newIndex,
                                                ),
                                        onDragStart: (int index) => setState(
                                          () =>
                                              _draggingEditorImageIndex = index,
                                        ),
                                        onDragEnd: (int index) {
                                          if (_draggingEditorImageIndex !=
                                              null) {
                                            setState(
                                              () => _draggingEditorImageIndex =
                                                  null,
                                            );
                                          }
                                        },
                                      ),
                                  ],
                                );
                                final Widget
                                animatedAttachmentArea = AnimatedSwitcher(
                                  duration: kEditorChromeEnterDuration,
                                  reverseDuration: kEditorChromeExitDuration,
                                  switchInCurve: Curves.easeOutCubic,
                                  switchOutCurve: Curves.easeInCubic,
                                  transitionBuilder:
                                      editorKeyboardChromeTransition,
                                  child: shouldShowSidebarAttachments
                                      ? Padding(
                                          key: kEditorAttachmentAreaVisibleKey,
                                          padding: const EdgeInsets.only(
                                            bottom: _editorSectionGap,
                                          ),
                                          child: sidebar,
                                        )
                                      : const SizedBox.shrink(
                                          key: kEditorAttachmentAreaHiddenKey,
                                        ),
                                );
                                final Widget editorPane = Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: <Widget>[
                                    if (_previewMode && showVisualEditorChrome)
                                      EditorPreviewGallery(
                                        savedImages: savedImages,
                                        pendingImages: pendingImages,
                                        encryptedPathFuture:
                                            _cachedEncryptedPathFuture,
                                        onOpenGallery: (int index) => unawaited(
                                          _openImagePreviewGallery(
                                            savedImages: savedImages,
                                            pendingImages: pendingImages,
                                            initialIndex: index,
                                          ),
                                        ),
                                      ),
                                    Expanded(
                                      child: Padding(
                                        padding: EdgeInsets.only(
                                          bottom:
                                              8 +
                                              MediaQuery.paddingOf(
                                                context,
                                              ).bottom,
                                        ),
                                        child: EditorBodySection(
                                          previewMode: _previewMode,
                                          bodyController: _bodyController,
                                          typography: typography,
                                        ),
                                      ),
                                    ),
                                  ],
                                );

                                return Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    10,
                                    12,
                                    6,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: <Widget>[
                                      EditorTitleSection(
                                        previewMode: _previewMode,
                                        titleController: _titleController,
                                        bodyController: _bodyController,
                                        tagsController: _tagsController,
                                        typography: typography,
                                        formattedDisplayDate:
                                            _formattedDisplayDate(context),
                                        formattedEntryTime:
                                            _formattedEntryTime24h(),
                                        showEntryRequiredHint:
                                            _showEntryRequiredHint,
                                        showUnsavedTag: showUnsavedTag,
                                        showMetadataTags:
                                            showVisualEditorChrome,
                                        tagAccentArgbMap:
                                            _watchedTagAccentArgbMap(),
                                      ),
                                      const SizedBox(height: _editorSectionGap),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: <Widget>[
                                            animatedAttachmentArea,
                                            Expanded(child: editorPane),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (Object error, StackTrace _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        userFacingErrorMessage(error, l10n: context.l10n),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (Object error, StackTrace _) => Scaffold(
            appBar: AppBar(title: Text(context.l10n.editorPageTitle)),
            body: Center(
              child: Text(userFacingErrorMessage(error, l10n: context.l10n)),
            ),
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (Object error, StackTrace _) => Scaffold(
        appBar: AppBar(title: Text(context.l10n.editorPageTitle)),
        body: Center(
          child: Text(userFacingErrorMessage(error, l10n: context.l10n)),
        ),
      ),
    );
  }

  void _loadExistingEntryIfNeeded(DiaryEntry? entry) {
    if (_didLoadExisting || entry == null) {
      return;
    }
    _didLoadExisting = true;
    _applyEntryToControllers(entry);
  }

  Future<void> _pickEntryDate() async {
    DateTime anchor;
    try {
      final DateOnly parsed = DateOnly.parse(_dateController.text.trim());
      final DateTime base = parsed.toDateTime();
      anchor = DateTime(base.year, base.month, base.day);
    } catch (_) {
      anchor = DateTime.now();
    }
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: anchor,
      firstDate: DateTime(1970),
      lastDate: DateTime(2100, 12, 31),
    );
    if (!mounted || picked == null) {
      return;
    }
    setState(() {
      _dateController.text = DateOnly.fromDateTime(picked).value;
    });
    _onDraftChanged();
  }

  Future<void> _pickEntryTime() async {
    DateTime anchor;
    try {
      final DateOnly parsed = DateOnly.parse(_dateController.text.trim());
      final DateTime base = parsed.toDateTime();
      anchor = DateTime(
        base.year,
        base.month,
        base.day,
        _entryTime.hour,
        _entryTime.minute,
      );
    } catch (_) {
      anchor = DateTime.now();
    }
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(anchor),
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (!mounted || picked == null) {
      return;
    }
    setState(() => _entryTime = picked);
    _onDraftChanged();
  }

  String _formattedDisplayDate(BuildContext context) {
    try {
      final DateOnly parsed = DateOnly.parse(_dateController.text.trim());
      return DisplayFormat.formatDateOnlyWithWeekday(context.l10n, parsed);
    } catch (_) {
      final String raw = _dateController.text.trim();
      return raw.isEmpty ? '--' : raw;
    }
  }

  String _formattedEntryTime24h() {
    final int hour = _entryTime.hour;
    final int minute = _entryTime.minute;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  Future<List<TagCatalogUsageItem>> _tagSuggestionsFromIndexAsync() async {
    try {
      final List<EntryIndexRecord> records = await ref.read(
        allEntryIndexRecordsProvider.future,
      );
      final catalog = await ref.read(tagCatalogProvider.future);
      return mergeTagCatalogWithUsage(catalog, diaryPresenceTagCounts(records));
    } catch (_) {
      return const <TagCatalogUsageItem>[];
    }
  }

  void _applyTagsCsv(String commaSeparatedTags) {
    final String trimmed = commaSeparatedTags.trim();
    _suppressTagDraftListener = true;
    _tagsController.value = TextEditingValue(
      text: trimmed,
      selection: TextSelection.collapsed(offset: trimmed.length),
    );
    _suppressTagDraftListener = false;
    if (mounted && !_previewMode) {
      setState(() {});
    }
    _onDraftChanged();
  }

  void _enterEditMode() {
    setState(() {
      _previewMode = false;
      if (_activeEntry != null) {
        _lastSavedSnapshot = editorDraftSnapshotFromEntry(_activeEntry!);
      }
    });
  }

  Future<bool?> _showRestoreDraftDialog(
    EditorDraftRecord record, {
    required bool hasExistingEntry,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return _RestoreDraftDialog(
          record: record,
          hasExistingEntry: hasExistingEntry,
        );
      },
    );
  }

  Future<bool?> _showDiscardDraftDialog() {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return const _DiscardDraftDialog();
      },
    );
  }

  Future<void> _deleteCurrentEntry(UnlockedVaultSession session) async {
    if (widget.entryId == null || _saving) {
      return;
    }
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(context.l10n.editorConfirmDeleteTitle),
        content: Text(context.l10n.editorConfirmDeleteBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.commonActionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: Text(context.l10n.commonActionDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await _editorFlow.deleteEntry(session: session, entryId: widget.entryId!);
    if (mounted) {
      context.pop();
    }
  }

  Future<void> _saveCurrentEntry(
    UnlockedVaultSession session,
    DiaryEntry? entry,
  ) async {
    if (_saving) {
      return;
    }
    await _persistDraftNow();
    if (!_canSaveEntry) {
      _notifyEntryRequired();
      return;
    }
    _draftPersistQueued = false;
    setState(() => _saving = true);
    try {
      final EditorSaveResult result = await _editorFlow.saveEntry(
        EditorSaveRequest(
          draftKey: _draftKey,
          session: session,
          existingEntry: entry,
          titleRaw: _titleController.text,
          dateValue: _dateController.text,
          entryTime: _entryTime,
          tagsRaw: _tagsController.text,
          markdownBodyRaw: _bodyController.text,
          keptAttachmentIds: List<AssetId>.from(_keptExistingAttachmentIds),
          pendingAttachments: List<PendingAttachment>.from(_pendingAttachments),
          provisionalEntryId: _provisionalEntryId ??=
              widget.entryId ?? generateEntryId(),
          switchToPreview: true,
        ),
      );
      final DiaryEntry saved = result.savedEntry;
      if (!mounted) {
        return;
      }
      setState(() {
        _savedAssetPathFutures.clear();
        _keptExistingAttachmentIds = List<AssetId>.from(saved.attachmentIds);
        _pendingAttachments.clear();
        _entryTime = TimeOfDay(
          hour: saved.createdAt.hour,
          minute: saved.createdAt.minute,
        );
        _lastSavedSnapshot = editorDraftSnapshotFromEntry(saved);
        _lastPersistedDraftSnapshot = null;
        _provisionalEntryId = saved.id;
        _draftCreatedAt = saved.createdAt;
        _activeEntry = saved;
        _previewMode = result.switchToPreview;
      });
      if (widget.entryId == null && mounted) {
        context.pushReplacement(result.routeLocation);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _removePendingAttachment(PendingAttachment attachment) {
    setState(() {
      _pendingAttachments.remove(attachment);
    });
    _scheduleDraftPersist();
  }

  void _removeSavedAttachment(AssetAttachment attachment) {
    setState(() {
      _savedAssetPathFutures.removeWhere(
        (String id, Future<String> _) => id == attachment.id,
      );
      _keptExistingAttachmentIds.remove(attachment.id);
    });
    _scheduleDraftPersist();
  }

  List<AssetAttachment> _orderedSavedImages(List<AssetAttachment> all) {
    if (all.isEmpty || _keptExistingAttachmentIds.isEmpty) {
      return <AssetAttachment>[];
    }
    final Map<AssetId, AssetAttachment> byId = <AssetId, AssetAttachment>{
      for (final AssetAttachment attachment in all) attachment.id: attachment,
    };
    final List<AssetAttachment> ordered = <AssetAttachment>[];
    for (final AssetId id in _keptExistingAttachmentIds) {
      final AssetAttachment? attachment = byId[id];
      if (attachment != null && attachment.mimeType.startsWith('image/')) {
        ordered.add(attachment);
      }
    }
    return ordered;
  }

  List<AssetAttachment> _savedNonImageAttachments(List<AssetAttachment> all) {
    return all
        .where(
          (AssetAttachment attachment) =>
              !attachment.mimeType.startsWith('image/') &&
              _keptExistingAttachmentIds.contains(attachment.id),
        )
        .toList();
  }

  void _reorderEditorImages({
    required List<AssetAttachment> allSaved,
    required int oldIndex,
    required int newIndex,
  }) {
    final List<AssetAttachment> savedImages = _orderedSavedImages(allSaved);
    final List<PendingAttachment> pendingImages = _pendingImageAttachments
        .toList();
    final List<Object> slots = <Object>[
      ...savedImages.map((AssetAttachment attachment) => attachment.id),
      ...pendingImages,
    ];
    if (oldIndex < 0 ||
        oldIndex >= slots.length ||
        newIndex < 0 ||
        newIndex > slots.length) {
      return;
    }

    final Object moved = slots.removeAt(oldIndex);
    slots.insert(newIndex, moved);

    final List<AssetId> newImageKeptIds = <AssetId>[];
    final List<PendingAttachment> newImagePending = <PendingAttachment>[];
    for (final Object slot in slots) {
      if (slot is PendingAttachment) {
        newImagePending.add(slot);
      } else if (slot is String) {
        newImageKeptIds.add(slot);
      }
    }

    final Map<AssetId, AssetAttachment> byId = <AssetId, AssetAttachment>{
      for (final AssetAttachment attachment in allSaved)
        attachment.id: attachment,
    };
    final List<AssetId> nonImageKeptIds = _keptExistingAttachmentIds.where((
      AssetId id,
    ) {
      final AssetAttachment? attachment = byId[id];
      return attachment != null && !attachment.mimeType.startsWith('image/');
    }).toList();
    final List<PendingAttachment> nonImagePending = _pendingNonImageAttachments
        .toList();

    setState(() {
      _draggingEditorImageIndex = null;
      _keptExistingAttachmentIds = <AssetId>[
        ...newImageKeptIds,
        ...nonImageKeptIds,
      ];
      _pendingAttachments
        ..clear()
        ..addAll(<PendingAttachment>[...newImagePending, ...nonImagePending]);
    });
    _scheduleDraftPersist();
  }

  Future<void> _openImagePreviewGallery({
    required List<AssetAttachment> savedImages,
    required List<PendingAttachment> pendingImages,
    required int initialIndex,
  }) async {
    final PreparedEditorGallery gallery = await _editorFlow
        .preparePreviewGalleryItems(
          dateValue: _dateController.text,
          savedImages: savedImages,
          pendingImages: pendingImages,
          initialIndex: initialIndex,
        );
    if (!mounted || gallery.items.isEmpty) {
      return;
    }
    await showDialog<void>(
      context: context,
      barrierColor: context.appColors.scrim,
      builder: (BuildContext dialogContext) => _EntryImageGalleryDialog(
        items: gallery.items,
        initialIndex: gallery.initialIndex,
      ),
    );
  }

  void _clearSavedAssetEncryptedPathFutures() {
    if (_savedAssetPathFutures.isEmpty) {
      return;
    }
    setState(_savedAssetPathFutures.clear);
  }

  Future<String> _cachedEncryptedPathFuture(AssetAttachment attachment) {
    return _savedAssetPathFutures.putIfAbsent(
      attachment.id,
      () => _editorFlow.assetEncryptedPath(
        dateValue: _dateController.text,
        attachment: attachment,
      ),
    );
  }

  Future<void> _showTagsEditorDialog() async {
    if (!mounted) {
      return;
    }
    final List<TagCatalogUsageItem> sorted =
        await _tagSuggestionsFromIndexAsync();
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      barrierColor: context.appColors.scrim,
      builder: (BuildContext dialogContext) {
        return AnimatedPadding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 24,
            bottom: 24 + MediaQuery.viewInsetsOf(dialogContext).bottom,
          ),
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: Align(
            child: Material(
              color: Colors.transparent,
              child: _TagsStudioDialog(
                initialCsv: _tagsController.text,
                suggestions: sorted,
                onDismiss: () => Navigator.of(dialogContext).pop(),
                onApply: (String csv) {
                  Navigator.of(dialogContext).pop();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      _applyTagsCsv(csv);
                    }
                  });
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final LostDataResponse lostData = await picker.retrieveLostData();
    final List<XFile> files = <XFile>[
      if (lostData.file != null) lostData.file!,
      ...?lostData.files,
    ];

    List<XFile> picked = <XFile>[];
    try {
      picked = await picker.pickMultiImage();
    } catch (_) {
      final XFile? one = await picker.pickImage(source: ImageSource.gallery);
      if (one != null) {
        picked = <XFile>[one];
      }
    }

    files.addAll(picked);
    if (files.isEmpty) {
      return;
    }

    final List<PendingAttachment> staged = await _editorFlow.stagePickedImages(
      preset: watchPersonalizationPreferences(ref).imageCompressPreset,
      draftKey: _draftKey,
      sourcePaths: files.map((XFile file) => file.path),
    );
    if (staged.isEmpty) {
      return;
    }

    setState(() {
      _pendingAttachments.addAll(staged);
    });
    _scheduleDraftPersist();
  }

  Future<void> _pickFile() async {
    final FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.any,
    );
    if (result == null) {
      return;
    }

    final List<PendingAttachment> staged = <PendingAttachment>[];
    for (final PlatformFile file in result.files) {
      if (file.path == null || file.path!.trim().isEmpty) {
        continue;
      }
      final PendingAttachment? attachment = await _editorFlow.stagePickedFile(
        draftKey: _draftKey,
        path: file.path!,
        displayName: file.name,
      );
      if (attachment != null) {
        staged.add(attachment);
      }
    }
    if (staged.isEmpty) {
      return;
    }
    setState(() {
      _pendingAttachments.addAll(staged);
    });
    _scheduleDraftPersist();
  }
}
