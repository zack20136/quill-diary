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

import 'package:quill_diary/domain/attachment/asset_attachment.dart';
import 'package:quill_diary/domain/diary/diary_entry.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/domain/diary/diary_date_policy.dart';
import 'package:quill_diary/infrastructure/database/index_database.dart';
import 'package:quill_diary/infrastructure/preferences/editor_typography_preferences.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';
import 'package:quill_diary/infrastructure/storage/vault_salvage_models.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/app/router.dart';
import 'package:quill_diary/shared/presentation/app_feedback.dart';
import 'package:quill_diary/shared/presentation/app_scrollbar.dart';
import 'package:quill_diary/shared/presentation/date_picker/app_date_picker_dialog.dart';
import 'package:quill_diary/shared/presentation/time_picker/app_time_picker_dialog.dart';
import 'package:quill_diary/shared/presentation/display_format.dart';
import 'package:quill_diary/app/app_colors.dart';
import 'package:quill_diary/shared/presentation/tag_visual.dart';
import 'package:quill_diary/shared/presentation/widgets/tag_accent_composer_dialog.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_shell.dart';
import 'package:quill_diary/shared/presentation/widgets/app_loading_state.dart';
import 'package:quill_diary/shared/presentation/widgets/app_state_card.dart';
import 'package:quill_diary/application/tag/tag_providers.dart';
import 'package:quill_diary/application/tag/tag_catalog_usage.dart';
import 'package:quill_diary/shared/utils/user_facing_error.dart';
import 'package:quill_diary/application/home/home_entry_query_providers.dart';
import 'package:quill_diary/presentation/session/widgets/session_locked_pane.dart';
import 'package:quill_diary/application/session/providers/session_providers.dart';
import 'package:quill_diary/application/session/state/app_session_state.dart';
import 'package:quill_diary/application/settings/personalization_providers.dart';
import 'package:quill_diary/application/settings/settings_providers.dart';
import 'package:quill_diary/application/editor/editor_attachment_items.dart';
import 'package:quill_diary/application/editor/editor_draft_models.dart';
import 'package:quill_diary/application/editor/editor_gallery_export.dart';
import 'package:quill_diary/application/editor/editor_flow_controller.dart';
import 'package:quill_diary/application/editor/editor_person_mention_controller.dart';
import 'package:quill_diary/application/people/people_providers.dart';
import 'package:quill_diary/domain/people/person.dart';
import 'package:quill_diary/domain/people/relationship_type.dart';
import 'package:quill_diary/presentation/editor/gallery_image_download.dart';
import '../widgets/editor_attachment_strip.dart';
import '../widgets/editor_form_sections.dart';
import '../widgets/editor_hybrid_body.dart';
import '../widgets/editor_keyboard_chrome.dart';
import '../widgets/editor_person_suggestion_panel.dart';
import 'package:quill_diary/presentation/people/widgets/person_composer_dialog.dart';
import '../widgets/editor_preview_gallery.dart';
import '../widgets/editor_top_bar.dart';
import 'package:quill_diary/application/editor/editor_draft_providers.dart';
import 'package:quill_diary/application/editor/editor_entry_providers.dart';

part '../widgets/editor_dialogs.dart';

class EditorPage extends ConsumerStatefulWidget {
  const EditorPage({
    super.key,
    this.entryId,
    this.salvageToken,
    this.startInEditMode = false,
  });

  final String? entryId;
  final String? salvageToken;
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
  final EditorPersonMentionController _personMentionController =
      EditorPersonMentionController();
  final GlobalKey<EditorHybridBodyState> _hybridBodyKey =
      GlobalKey<EditorHybridBodyState>();
  final List<PendingAttachment> _pendingAttachments = <PendingAttachment>[];
  final Map<String, Future<String>> _savedAssetPathFutures =
      <String, Future<String>>{};

  List<AssetId> _attachmentIds = <AssetId>[];
  late bool _previewMode;
  TimeOfDay _entryTime = TimeOfDay.now();
  bool _didLoadExisting = false;
  bool _saving = false;
  bool _showEntryRequiredHint = false;
  int? _draggingEditorImageIndex;
  bool _didOfferDraftRestore = false;
  bool _handlingDraftRestore = false;
  bool _preservesEditorOnLock = false;
  int _previewCheckboxSaveVersion = 0;
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
  DateOnly? _persistedEntryDate;
  EntryId? _provisionalEntryId;
  DateTime? _draftCreatedAt;
  List<VaultFinding> _salvageRetireFindings = <VaultFinding>[];

  static const String _newDraftKey = '__new__';

  EditorFlowController get _editorFlow =>
      ref.read(editorFlowControllerProvider);

  bool get _isEditing => !_previewMode;
  String get _draftKey => widget.salvageToken == null
      ? widget.entryId ?? _newDraftKey
      : VaultSalvageDraft.draftKeyForToken(widget.salvageToken!);
  bool get _hasTitle => _titleController.text.trim().isNotEmpty;
  bool get _hasBody => _bodyController.text.trim().isNotEmpty;
  bool get _canSaveEntry => _hasTitle || _hasBody;

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
    _provisionalEntryId =
        widget.salvageToken ?? widget.entryId ?? generateEntryId();
    _draftCreatedAt = DateTime.now();
    _tagsController.addListener(_onDraftChanged);
    _titleController.addListener(_onDraftChanged);
    _bodyController.addListener(_onBodyControllerChanged);
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
    _dateController.removeListener(_onDraftChanged);
    _tagsController.removeListener(_onDraftChanged);
    _titleController.removeListener(_onDraftChanged);
    _bodyController.removeListener(_onBodyControllerChanged);
    _titleController.dispose();
    _dateController.dispose();
    _tagsController.dispose();
    _bodyController.dispose();
    _personMentionController.dispose();
    _savedAssetPathFutures.clear();
    super.dispose();
  }

  Map<PersonId, int>? _mentionCountByIdHint() {
    // 勿用 read 啟動尚未建立的 FutureProvider，以免首次 @ 觸發全庫重建。
    if (!ref.exists(peopleMentionStatsMapProvider)) {
      return null;
    }
    final Map<PersonId, PersonMentionStats>? stats = ref
        .read(peopleMentionStatsMapProvider)
        .asData
        ?.value;
    if (stats == null) {
      return null;
    }
    return <PersonId, int>{
      for (final MapEntry<PersonId, PersonMentionStats> e in stats.entries)
        e.key: e.value.mentionCount,
    };
  }

  List<EditorPersonSuggestion> _activePersonSuggestions({
    List<Person>? catalog,
  }) {
    return filterEditorPersonSuggestions(
      catalog:
          catalog ??
          ref.read(peopleCatalogProvider).asData?.value.people ??
          const <Person>[],
      query: _personMentionController.query,
      mentionCountById: _mentionCountByIdHint(),
    );
  }

  KeyEventResult _onPersonMentionKeyEvent(FocusNode _, KeyEvent event) {
    final List<EditorPersonSuggestion> suggestions = _activePersonSuggestions();
    final ({KeyEventResult result, bool shouldApplySelection}) handled =
        _personMentionController.handleKeyEvent(
          event,
          suggestionCount: suggestions.length,
        );
    if (handled.shouldApplySelection && suggestions.isNotEmpty) {
      final int index = _personMentionController.highlightIndex.clamp(
        0,
        suggestions.length - 1,
      );
      _applyPersonMention(suggestions[index]);
    }
    return handled.result;
  }

  void _applyPersonMention(EditorPersonSuggestion suggestion) {
    _personMentionController.applyMentionLabel(
      suggestion.person.diaryMentionLabel,
    );
    _onDraftChanged();
  }

  Future<void> _createPersonFromMention() async {
    final PersonMentionReplacementTarget? target = _personMentionController
        .captureReplacementTarget();
    if (target == null) {
      return;
    }
    final Person? person = await showPersonComposerDialog(
      context,
      initialName: _personMentionController.query.trim(),
    );
    if (!mounted || person == null) {
      return;
    }
    if (_personMentionController.applyMentionLabelToTarget(
      target,
      person.diaryMentionLabel,
    )) {
      _onDraftChanged();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      unawaited(_persistDraftNow());
    }
  }

  void _insertCheckboxBlock() {
    if (_previewMode || _saving) {
      return;
    }
    _hybridBodyKey.currentState?.insertCheckboxAtCursor();
    _onDraftChanged();
  }

  void _onBodyChangedFromSection() {
    _onDraftChanged();
  }

  void _onBodyControllerChanged() {
    _onDraftChanged();
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

  void _onPreviewCheckboxChanged(String markdown) {
    if (!mounted) {
      return;
    }
    _bodyController.text = markdown;
    final UnlockedVaultSession? session = _activeSession;
    final DiaryEntry? entry = _activeEntry;
    if (session != null && entry != null) {
      unawaited(_savePreviewCheckboxState(session, entry, markdown));
    }
  }

  Future<void> _savePreviewCheckboxState(
    UnlockedVaultSession session,
    DiaryEntry entry,
    String markdown,
  ) async {
    final int saveVersion = ++_previewCheckboxSaveVersion;
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
          markdownBodyRaw: markdown,
          attachmentIds: List<AssetId>.from(_attachmentIds),
          pendingAttachments: List<PendingAttachment>.from(_pendingAttachments),
          provisionalEntryId: entry.id,
          switchToPreview: true,
        ),
      );
      if (!mounted || saveVersion != _previewCheckboxSaveVersion) {
        return;
      }
      _activeEntry = result.savedEntry;
      _lastSavedSnapshot = editorDraftSnapshotFromEntry(result.savedEntry);
    } catch (_) {
      // Keep optimistic UI; user can retry by toggling again.
    }
  }

  void _notifyEntryRequired() {
    if (!mounted) {
      return;
    }
    setState(() => _showEntryRequiredHint = true);
    showAppFeedbackToast(context, context.l10n.editorSaveNeedsEntryMessage);
  }

  EditorDraftSnapshot _currentDraftSnapshot() {
    _hybridBodyKey.currentState?.flushBodyToController();
    return buildEditorDraftSnapshot(
      titleRaw: _titleController.text,
      dateRaw: _dateController.text,
      entryHour: _entryTime.hour,
      entryMinute: _entryTime.minute,
      tagsRaw: _tagsController.text,
      bodyRaw: _bodyController.text,
      attachmentIds: _attachmentIds,
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
          attachmentIds: List<AssetId>.from(_attachmentIds),
          pendingAttachments: List<PendingAttachment>.from(_pendingAttachments),
          session: session,
          createdAt: _draftCreatedAt ?? DateTime.now(),
          provisionalEntryId: _provisionalEntryId ??=
              widget.entryId ?? generateEntryId(),
          existingEntryId: widget.entryId,
          salvageSourceFindings: <Map<String, Object?>>[
            for (final VaultFinding finding in _salvageRetireFindings)
              finding.toJson(),
          ],
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
    _attachmentIds = List<AssetId>.from(entry.attachmentIds);
    _pendingAttachments.clear();
    _savedAssetPathFutures.clear();
    _entryTime = TimeOfDay(
      hour: entry.createdAt.hour,
      minute: entry.createdAt.minute,
    );
    _provisionalEntryId = entry.id;
    _persistedEntryDate = entry.date;
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
    _attachmentIds = List<AssetId>.from(record.attachmentIds);
    _pendingAttachments
      ..clear()
      ..addAll(decision.pendingAttachments);
    _entryTime = TimeOfDay(hour: record.entryHour, minute: record.entryMinute);
    _provisionalEntryId = record.provisionalEntryId;
    _salvageRetireFindings = <VaultFinding>[
      for (final Map<String, Object?> json in record.salvageSourceFindings)
        if (VaultFinding.fromJson(json) case final VaultFinding finding)
          finding,
    ];
    _draftCreatedAt = record.createdAt;
    _lastPersistedDraftSnapshot = buildEditorDraftSnapshot(
      titleRaw: record.title ?? '',
      dateRaw: record.dateValue,
      entryHour: record.entryHour,
      entryMinute: record.entryMinute,
      tagsRaw: record.tags.join(', '),
      bodyRaw: record.markdownBody,
      attachmentIds: record.attachmentIds,
    );
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
    final bool isSalvage = widget.salvageToken != null;
    final EditorDraftRestoreDecision decision = await _editorFlow
        .restoreDraftIfNeeded(
          draftKey: _draftKey,
          session: session,
          existingEntry: entry,
          decideRestore: (EditorDraftRecord record) async {
            // salvage 草稿是使用者剛建立的修復內容，直接套用，不跳出一般草稿確認。
            if (isSalvage) {
              return true;
            }
            return _showRestoreDraftDialog(
              record,
              hasExistingEntry: entry != null,
            );
          },
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
    _attachmentIds = <AssetId>[];
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
    _persistedEntryDate = null;
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

        // 預覽勾選會 save 並 invalidate entryProvider；勿在 reload 時整頁換成 loading，
        // 否則畫面會閃爍、捲動重置，看起來像核取方塊「跳來跳去」。
        return entryAsync.when(
          skipLoadingOnReload: true,
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
            final List<EditorAttachmentItem> orderedAttachments =
                _orderedAttachments(allSavedAttachments);
            final List<EditorAttachmentItem> images = orderedAttachments
                .where(
                  (EditorAttachmentItem item) =>
                      item.mimeType.startsWith('image/'),
                )
                .toList();
            final List<EditorAttachmentItem> nonImages = orderedAttachments
                .where(
                  (EditorAttachmentItem item) =>
                      !item.mimeType.startsWith('image/'),
                )
                .toList();
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
                      return Padding(
                        padding: const EdgeInsets.all(24),
                        child: AppStateView(
                          icon: Icons.key_outlined,
                          title: context
                              .l10n
                              .sessionBlockedRecoveryRequiredTitle,
                          message: context.l10n.editorNeedsRecoveryKeyMessage,
                          actionLabel: context.l10n.homeGoToSettings,
                          onAction: () =>
                              context.push(AppRouter.settingsRoute),
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
                          timestampLabel: _formattedTimestampLabel(context),
                          onClose: () => unawaited(_requestClose()),
                          onSave: () =>
                              unawaited(_saveCurrentEntry(session, entry)),
                          onInvalidSave: _notifyEntryRequired,
                          onDelete: () =>
                              unawaited(_deleteCurrentEntry(session)),
                          onEnterEditMode: _enterEditMode,
                          bottomToolbar: _isEditing
                              ? EditorActionToolbar(
                                  saving: _saving,
                                  onPickDate: _pickEntryDate,
                                  onPickTime: _pickEntryTime,
                                  onEditTags: _showTagsEditorDialog,
                                  onPickImage: () => unawaited(_pickImage()),
                                  onPickFile: () => unawaited(_pickFile()),
                                  onInsertCheckbox: _insertCheckboxBlock,
                                )
                              : null,
                        ),
                        Expanded(
                          child: Stack(
                            children: <Widget>[
                              SafeArea(
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
                                        nonImages.isNotEmpty;
                                    final bool shouldShowSidebarAttachments =
                                        (!_previewMode ||
                                            hasNonImageAttachments) &&
                                        showVisualEditorChrome;
                                    final Widget sidebar = Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        if (shouldShowSidebarAttachments)
                                          EditorAttachmentStrip(
                                            images: images,
                                            nonImages: nonImages,
                                            editable: _isEditing,
                                            draggingIndex:
                                                _draggingEditorImageIndex,
                                            encryptedPathFuture:
                                                _cachedEncryptedPathFuture,
                                            onRemove: _removeAttachment,
                                            onReorder:
                                                (int oldIndex, int newIndex) =>
                                                    _reorderEditorImages(
                                                      images: images,
                                                      oldIndex: oldIndex,
                                                      newIndex: newIndex,
                                                    ),
                                            onDragStart: (int index) => setState(
                                              () => _draggingEditorImageIndex =
                                                  index,
                                            ),
                                            onDragEnd: (int index) {
                                              if (_draggingEditorImageIndex !=
                                                  null) {
                                                setState(
                                                  () =>
                                                      _draggingEditorImageIndex =
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
                                      reverseDuration:
                                          kEditorChromeExitDuration,
                                      switchInCurve: Curves.easeOutCubic,
                                      switchOutCurve: Curves.easeInCubic,
                                      transitionBuilder:
                                          editorKeyboardChromeTransition,
                                      child: shouldShowSidebarAttachments
                                          ? Padding(
                                              key:
                                                  kEditorAttachmentAreaVisibleKey,
                                              padding: const EdgeInsets.only(
                                                bottom: _editorSectionGap,
                                              ),
                                              child: sidebar,
                                            )
                                          : const SizedBox.shrink(
                                              key:
                                                  kEditorAttachmentAreaHiddenKey,
                                            ),
                                    );
                                    final Widget editorPane = Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: <Widget>[
                                        if (_previewMode &&
                                            showVisualEditorChrome)
                                          EditorPreviewGallery(
                                            images: images,
                                            encryptedPathFuture:
                                                _cachedEncryptedPathFuture,
                                            onOpenGallery: (int index) =>
                                                unawaited(
                                                  _openImagePreviewGallery(
                                                    images: images,
                                                    initialIndex: index,
                                                  ),
                                                ),
                                          ),
                                        Expanded(
                                          child: ListenableBuilder(
                                            listenable:
                                                _personMentionController,
                                            builder: (BuildContext context, Widget? _) {
                                              final double mentionPad =
                                                  _isEditing &&
                                                      _personMentionController
                                                          .isActive
                                                  ? kEditorPersonSuggestionBodyReserve
                                                  : 0;
                                              return Padding(
                                                padding: EdgeInsets.only(
                                                  bottom:
                                                      8 +
                                                      mentionPad +
                                                      MediaQuery.paddingOf(
                                                        context,
                                                      ).bottom,
                                                ),
                                                child: EditorBodySection(
                                                  previewMode: _previewMode,
                                                  bodyController:
                                                      _bodyController,
                                                  typography: typography,
                                                  hybridBodyKey: _hybridBodyKey,
                                                  onBodyChanged:
                                                      _onBodyChangedFromSection,
                                                  onPreviewCheckboxChanged:
                                                      _onPreviewCheckboxChanged,
                                                  mentionController: _isEditing
                                                      ? _personMentionController
                                                      : null,
                                                  onMentionKeyEvent: _isEditing
                                                      ? _onPersonMentionKeyEvent
                                                      : null,
                                                ),
                                              );
                                            },
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
                                            showEntryRequiredHint:
                                                _showEntryRequiredHint,
                                            showUnsavedTag: showUnsavedTag,
                                            showMetadataTags:
                                                showVisualEditorChrome,
                                            tagAccentArgbMap:
                                                _watchedTagAccentArgbMap(),
                                            mentionController: _isEditing
                                                ? _personMentionController
                                                : null,
                                            onMentionKeyEvent: _isEditing
                                                ? _onPersonMentionKeyEvent
                                                : null,
                                          ),
                                          const SizedBox(
                                            height: _editorSectionGap,
                                          ),
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
                              if (_isEditing)
                                ListenableBuilder(
                                  listenable: _personMentionController,
                                  builder: (BuildContext context, Widget? _) {
                                    if (!_personMentionController.isActive) {
                                      return const SizedBox.shrink();
                                    }
                                    // 僅在 @ 作用中才讀名冊，避免編輯器一打開就解密。
                                    final AsyncValue<PeopleCatalog>
                                    catalogAsync = ref.watch(
                                      peopleCatalogProvider,
                                    );
                                    final List<Person> catalog =
                                        catalogAsync.asData?.value.people ??
                                        const <Person>[];
                                    final List<EditorPersonSuggestion>
                                    suggestions = _activePersonSuggestions(
                                      catalog: catalog,
                                    );
                                    // Scaffold 縮放 body 後貼鍵盤上方；無鍵盤時避開 home indicator。
                                    final double keyboardInset =
                                        MediaQuery.viewInsetsOf(context).bottom;
                                    final double bottomSafe = keyboardInset > 0
                                        ? 6
                                        : 8 +
                                              MediaQuery.paddingOf(
                                                context,
                                              ).bottom;
                                    return Positioned(
                                      left: 10,
                                      right: 10,
                                      bottom: bottomSafe,
                                      child: EditorPersonSuggestionPanel(
                                        suggestions: suggestions,
                                        highlightIndex: _personMentionController
                                            .highlightIndex,
                                        catalogEmpty:
                                            catalogAsync.hasValue &&
                                            catalog.isEmpty,
                                        onSelected: _applyPersonMention,
                                        onCreatePerson: () => unawaited(
                                          _createPersonFromMention(),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () => const AppLoadingState(),
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
          loading: () => const Scaffold(
            body: AppLoadingState(layout: AppLoadingStateLayout.page),
          ),
          error: (Object error, StackTrace _) => Scaffold(
            appBar: AppBar(title: Text(context.l10n.editorPageTitle)),
            body: Center(
              child: Text(userFacingErrorMessage(error, l10n: context.l10n)),
            ),
          ),
        );
      },
      loading: () => const Scaffold(
        body: AppLoadingState(layout: AppLoadingStateLayout.page),
      ),
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
    DateOnly? currentDate;
    try {
      currentDate = DateOnly.tryParse(_dateController.text.trim());
      final DateTime base = currentDate?.toDateTime() ?? DateTime.now();
      anchor = DateTime(base.year, base.month, base.day);
    } catch (_) {
      anchor = DateTime.now();
    }
    final ({DateTime first, DateTime last}) range =
        DiaryDatePolicy.selectableRange(includedDate: currentDate);
    final DateTime? picked = await showAppDatePickerDialog(
      context: context,
      initialDate: anchor,
      firstDate: range.first,
      lastDate: range.last,
      title: context.l10n.editorTooltipDate,
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
    final TimeOfDay? picked = await showAppTimePickerDialog(
      context: context,
      initialTime: TimeOfDay.fromDateTime(anchor),
      title: context.l10n.editorTooltipTime,
    );
    if (!mounted || picked == null) {
      return;
    }
    setState(() => _entryTime = picked);
    _onDraftChanged();
  }

  String _formattedTimestampLabel(BuildContext context) {
    try {
      final DateOnly parsed = DateOnly.parse(_dateController.text.trim());
      return DisplayFormat.formatEntryDateTime(
        context.l10n,
        parsed,
        hour: _entryTime.hour,
        minute: _entryTime.minute,
      );
    } catch (_) {
      final String raw = _dateController.text.trim();
      if (raw.isEmpty) {
        return '--';
      }
      final DateTime timeOnly = DateTime(
        1970,
        1,
        1,
        _entryTime.hour,
        _entryTime.minute,
      );
      return '$raw ${DisplayFormat.formatTime24h(timeOnly)}';
    }
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
    return showAppDialog<bool>(
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
    return showAppDialog<bool>(
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
    final bool confirmed = await showAppConfirmDialog(
      context: context,
      title: context.l10n.editorConfirmDeleteTitle,
      content: Text(context.l10n.editorConfirmDeleteBody),
      cancelLabel: context.l10n.commonActionCancel,
      confirmLabel: context.l10n.commonActionDelete,
      confirmStyle: AppConfirmStyle.destructive,
    );
    if (!confirmed || !mounted) {
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
    _hybridBodyKey.currentState?.flushBodyToController();
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
          attachmentIds: List<AssetId>.from(_attachmentIds),
          pendingAttachments: List<PendingAttachment>.from(_pendingAttachments),
          provisionalEntryId: _provisionalEntryId ??=
              widget.entryId ?? generateEntryId(),
          switchToPreview: true,
          retireFindingsAfterSave: _salvageRetireFindings,
        ),
      );
      final DiaryEntry saved = result.savedEntry;
      if (!mounted) {
        return;
      }
      setState(() {
        _savedAssetPathFutures.clear();
        _attachmentIds = List<AssetId>.from(saved.attachmentIds);
        _pendingAttachments.clear();
        _entryTime = TimeOfDay(
          hour: saved.createdAt.hour,
          minute: saved.createdAt.minute,
        );
        _lastSavedSnapshot = editorDraftSnapshotFromEntry(saved);
        _lastPersistedDraftSnapshot = null;
        _provisionalEntryId = saved.id;
        _persistedEntryDate = saved.date;
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

  void _removeAttachment(EditorAttachmentItem item) {
    setState(() {
      _attachmentIds.remove(item.assetId);
      switch (item) {
        case SavedEditorAttachmentItem(:final attachment):
          _savedAssetPathFutures.removeWhere(
            (String id, Future<String> _) => id == attachment.id,
          );
        case PendingEditorAttachmentItem(:final attachment):
          _pendingAttachments.remove(attachment);
      }
    });
    _scheduleDraftPersist();
  }

  List<EditorAttachmentItem> _orderedAttachments(
    List<AssetAttachment> allSaved,
  ) {
    return resolveEditorAttachmentItems(
      attachmentIds: _attachmentIds,
      savedAttachments: allSaved,
      pendingAttachments: _pendingAttachments,
    );
  }

  void _reorderEditorImages({
    required List<EditorAttachmentItem> images,
    required int oldIndex,
    required int newIndex,
  }) {
    setState(() {
      _draggingEditorImageIndex = null;
      _attachmentIds = reorderEditorImageAttachmentIds(
        attachmentIds: _attachmentIds,
        imageIds: images
            .map((EditorAttachmentItem item) => item.assetId)
            .toList(),
        oldIndex: oldIndex,
        newIndex: newIndex,
      );
    });
    _scheduleDraftPersist();
  }

  Future<void> _openImagePreviewGallery({
    required List<EditorAttachmentItem> images,
    required int initialIndex,
  }) async {
    final PreparedEditorGallery gallery = await _editorFlow
        .preparePreviewGalleryItems(
          savedAttachmentDateValue: _savedAttachmentDateValue,
          images: images,
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

  String get _savedAttachmentDateValue =>
      _persistedEntryDate?.value ?? _dateController.text;

  Future<String> _cachedEncryptedPathFuture(AssetAttachment attachment) {
    return _savedAssetPathFutures.putIfAbsent(
      attachment.id,
      () => _editorFlow.assetEncryptedPath(
        savedAttachmentDateValue: _savedAttachmentDateValue,
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

    final UnlockedVaultSession? session = _activeSession;
    if (session == null) {
      return;
    }

    final List<PendingAttachment> staged = await _editorFlow.stagePickedImages(
      preset: watchPersonalizationPreferences(ref).imageCompressPreset,
      draftKey: _draftKey,
      sourcePaths: files.map((XFile file) => file.path),
      session: session,
    );
    if (staged.isEmpty) {
      return;
    }

    setState(() {
      _pendingAttachments.addAll(staged);
      _attachmentIds.addAll(
        staged.map((PendingAttachment attachment) => attachment.assetId),
      );
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

    final UnlockedVaultSession? session = _activeSession;
    if (session == null) {
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
        session: session,
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
      _attachmentIds.addAll(
        staged.map((PendingAttachment attachment) => attachment.assetId),
      );
    });
    _scheduleDraftPersist();
  }
}
