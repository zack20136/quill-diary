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
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../../../domain/attachment/asset_attachment.dart';
import '../../../domain/diary/diary_entry.dart';
import '../../../domain/security/unlocked_vault_session.dart';
import '../../../domain/shared/value_objects.dart';
import '../../../infrastructure/database/index_database.dart';
import '../../../infrastructure/storage/vault_repository.dart';
import '../../../shared/presentation/page_style.dart';
import '../../../shared/utils/user_facing_error.dart';
import '../../../shared/presentation/tag_visual.dart';
import '../../../shared/presentation/widgets/entry_cover_thumbnail.dart';
import '../../../shared/presentation/widgets/local_file_thumbnail.dart';
import '../../../shared/presentation/widgets/tag_accent_composer_dialog.dart';
import '../../../shared/providers/core_providers.dart';
import '../../../shared/providers/tag_providers.dart';
import '../../../shared/utils/diary_presence_tag_counts.dart';
import '../../../shared/utils/weekday_zh.dart';
import '../../../shared/utils/tag_catalog_merge.dart';
import '../../home/providers/home_providers.dart';
import '../../session/providers/session_providers.dart';
import '../../session/session_messages.dart';
import '../../session/state/app_session_state.dart';
import '../../settings/providers/settings_providers.dart';
import '../editor_draft.dart';
import '../providers/editor_providers.dart';

part '../widgets/editor_dialogs.dart';

enum _SaveStatus { idle, dirty, saving, saved }

enum _PreviewGallerySourceKind { encrypted, local }

class _PreviewGalleryImage {
  const _PreviewGalleryImage.encrypted({
    required this.previewId,
    required this.path,
  }) : sourceKind = _PreviewGallerySourceKind.encrypted;

  const _PreviewGalleryImage.local({
    required this.previewId,
    required this.path,
  }) : sourceKind = _PreviewGallerySourceKind.local;

  final String previewId;
  final String path;
  final _PreviewGallerySourceKind sourceKind;
}

class _MarkdownPreviewBody extends StatelessWidget {
  const _MarkdownPreviewBody({required this.markdown});

  final String markdown;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final TextStyle bodyStyle = theme.textTheme.bodyLarge?.copyWith(
          height: 1.76,
          fontWeight: FontWeight.w400,
        ) ??
        const TextStyle(height: 1.76);
    final List<String> lines = markdown.replaceAll('\r\n', '\n').split('\n');
    final List<Widget> children = <Widget>[];
    var inCodeBlock = false;
    final StringBuffer codeBuffer = StringBuffer();

    void flushCodeBlock() {
      if (codeBuffer.isEmpty) {
        return;
      }
      children.add(
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(PageStyle.radiusPanel),
          ),
          child: SelectableText(
            codeBuffer.toString().trimRight(),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
              height: 1.45,
            ),
          ),
        ),
      );
      codeBuffer.clear();
    }

    for (final String rawLine in lines) {
      final String line = rawLine.trimRight();
      if (line.trimLeft().startsWith('```')) {
        if (inCodeBlock) {
          inCodeBlock = false;
          flushCodeBlock();
        } else {
          inCodeBlock = true;
        }
        continue;
      }
      if (inCodeBlock) {
        codeBuffer.writeln(rawLine);
        continue;
      }
      if (line.trim().isEmpty) {
        children.add(const SizedBox(height: 10));
        continue;
      }

      final RegExpMatch? heading = RegExp(r'^(#{1,6})\s+(.+)$').firstMatch(line);
      if (heading != null) {
        final int level = heading.group(1)!.length;
        final String text = heading.group(2)!.trim();
        final TextStyle? headingStyle = switch (level) {
          1 => theme.textTheme.headlineSmall,
          2 => theme.textTheme.titleLarge,
          3 => theme.textTheme.titleMedium,
          _ => theme.textTheme.titleSmall,
        };
        children.add(
          Padding(
            padding: EdgeInsets.only(top: children.isEmpty ? 0 : 8, bottom: 8),
            child: SelectableText.rich(
              _inlineMarkdownSpan(
                text,
                (headingStyle ?? bodyStyle).copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
            ),
          ),
        );
        continue;
      }

      if (line.startsWith('>')) {
        children.add(
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh.withValues(alpha: 0.58),
              border: Border(
                left: BorderSide(color: cs.primary, width: 3),
              ),
            ),
            child: SelectableText.rich(
              _inlineMarkdownSpan(
                line.replaceFirst(RegExp(r'^>\s?'), ''),
                bodyStyle.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          ),
        );
        continue;
      }

      final RegExpMatch? listItem = RegExp(r'^(\s*)([-*]|\d+\.)\s+(.+)$').firstMatch(line);
      if (listItem != null) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: 28,
                  child: Text(
                    listItem.group(2)!,
                    style: bodyStyle.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
                Expanded(
                  child: SelectableText.rich(
                    _inlineMarkdownSpan(listItem.group(3)!.trim(), bodyStyle),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SelectableText.rich(
            _inlineMarkdownSpan(line, bodyStyle),
          ),
        ),
      );
    }

    if (inCodeBlock) {
      flushCodeBlock();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  TextSpan _inlineMarkdownSpan(String text, TextStyle baseStyle) {
    final List<InlineSpan> spans = <InlineSpan>[];
    final RegExp pattern = RegExp(
      r'(\[[^\]]+\]\([^)]+\)|\*\*[^*]+\*\*|__[^_]+__|\*[^*]+\*|_[^_]+_|`[^`]+`)',
    );
    var cursor = 0;
    for (final RegExpMatch match in pattern.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      final String token = match.group(0)!;
      final RegExpMatch? link = RegExp(r'^\[([^\]]+)\]\(([^)]+)\)$').firstMatch(token);
      if (link != null) {
        spans.add(
          TextSpan(
            text: '${link.group(1)} (${link.group(2)})',
            style: const TextStyle(
              decoration: TextDecoration.underline,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      } else if (token.startsWith('**') || token.startsWith('__')) {
        spans.add(
          TextSpan(
            text: token.substring(2, token.length - 2),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        );
      } else if (token.startsWith('`')) {
        spans.add(
          TextSpan(
            text: token.substring(1, token.length - 1),
            style: TextStyle(
              fontFamily: 'monospace',
              backgroundColor: Colors.black.withValues(alpha: 0.06),
            ),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: token.substring(1, token.length - 1),
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        );
      }
      cursor = match.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }
    return TextSpan(style: baseStyle, children: spans);
  }
}

/// Entry editor responsible for creating and updating diary content plus attachments.
class EditorPage extends ConsumerStatefulWidget {
  const EditorPage({super.key, this.entryId, this.startInEditMode = false});

  final String? entryId;
  final bool startInEditMode;

  @override
  ConsumerState<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends ConsumerState<EditorPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _dateController = TextEditingController(
    text: DateOnly.fromDateTime(DateTime.now()).value,
  );
  final TextEditingController _tagsController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final List<PendingAttachment> _pendingAttachments = <PendingAttachment>[];
  List<AssetId> _keptExistingAttachmentIds = <AssetId>[];
  final Map<String, Future<String>> _savedAssetPathFutures = <String, Future<String>>{};
  late bool _previewMode;
  TimeOfDay _entryTime = TimeOfDay.now();
  bool _didLoadExisting = false;
  bool _saving = false;
  bool _suppressTagDraftListener = false;
  bool _suppressDraftListener = false;
  late final ProviderSubscription<AsyncValue<AppSessionState>> _sessionSubscription;
  Timer? _autoSaveTimer;
  Timer? _savedStatusTimer;
  _SaveStatus _saveStatus = _SaveStatus.idle;
  EditorDraftSnapshot? _lastSavedSnapshot;
  UnlockedVaultSession? _activeSession;
  DiaryEntry? _activeEntry;
  static const Duration _autoSaveDebounce = Duration(seconds: 5);
  static const Duration _savedStatusVisible = Duration(seconds: 3);
  bool get _isEditing => !_previewMode;

  Map<String, int> _watchedTagAccentArgbMap() {
    return ref.watch(tagAccentArgbMapProvider).maybeWhen(
          data: (Map<String, int> m) => m,
          orElse: () => const <String, int>{},
        );
  }

  Iterable<PendingAttachment> get _pendingImageAttachments =>
      _pendingAttachments.where((PendingAttachment a) => a.mimeType.startsWith('image/'));

  Iterable<PendingAttachment> get _pendingNonImageAttachments =>
      _pendingAttachments.where((PendingAttachment a) => !a.mimeType.startsWith('image/'));

  @override
  void initState() {
    super.initState();
    _previewMode = widget.entryId != null && !widget.startInEditMode;
    _dateController.addListener(_clearSavedAssetEncryptedPathFutures);
    _tagsController.addListener(_onTagsDraftChanged);
    _titleController.addListener(_onDraftFieldChanged);
    _bodyController.addListener(_onDraftFieldChanged);
    _dateController.addListener(_onDraftFieldChanged);
    _sessionSubscription = ref.listenManual<AsyncValue<AppSessionState>>(
      effectiveAppSessionProvider,
      (_, AsyncValue<AppSessionState> next) {
        next.whenData((AppSessionState sessionState) {
          if (!sessionState.isUnlocked || sessionState.session == null) {
            _clearSensitiveLocalState();
          }
        });
      },
    );
  }

  void _onTagsDraftChanged() {
    if (_suppressTagDraftListener || _previewMode || !mounted) {
      return;
    }
    setState(() {});
    _onDraftFieldChanged();
  }

  void _onDraftFieldChanged() {
    if (_previewMode || !mounted || _suppressDraftListener) {
      return;
    }
    _updateDirtySaveStatus();
    _scheduleAutoSave();
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

  bool _shouldSkipAutoSave() {
    if (!_isEditing || _saving) {
      return true;
    }
    final EditorDraftSnapshot current = _currentDraftSnapshot();
    if (!editorDraftIsDirty(current: current, saved: _lastSavedSnapshot)) {
      return true;
    }
    if (widget.entryId == null && editorDraftIsEmpty(current)) {
      return true;
    }
    return false;
  }

  void _updateDirtySaveStatus() {
    if (_saving || _saveStatus == _SaveStatus.saving) {
      return;
    }
    final bool dirty = _isDraftDirty();
    final _SaveStatus next = dirty ? _SaveStatus.dirty : _SaveStatus.idle;
    if (next != _saveStatus && _saveStatus != _SaveStatus.saved) {
      setState(() => _saveStatus = next);
    } else if (next == _SaveStatus.dirty && _saveStatus != _SaveStatus.dirty) {
      setState(() => _saveStatus = _SaveStatus.dirty);
    }
  }

  void _scheduleAutoSave() {
    if (_previewMode) {
      return;
    }
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(_autoSaveDebounce, () {
      unawaited(_performAutoSave());
    });
  }

  void _cancelAutoSaveTimer() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
  }

  void _markSaved() {
    _savedStatusTimer?.cancel();
    setState(() => _saveStatus = _SaveStatus.saved);
    _savedStatusTimer = Timer(_savedStatusVisible, () {
      if (!mounted) {
        return;
      }
      setState(() {
        if (_saveStatus == _SaveStatus.saved) {
          _saveStatus = _SaveStatus.idle;
        }
      });
    });
  }

  Future<void> _performAutoSave() async {
    if (_shouldSkipAutoSave()) {
      return;
    }
    final UnlockedVaultSession? session = _activeSession;
    if (session == null) {
      return;
    }
    await _saveEntry(session, _activeEntry);
  }

  Future<void> _flushSaveIfNeeded() async {
    _cancelAutoSaveTimer();
    if (_shouldSkipAutoSave()) {
      return;
    }
    final UnlockedVaultSession? session = _activeSession;
    if (session == null) {
      return;
    }
    await _saveEntry(session, _activeEntry);
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
    await _flushSaveIfNeeded();
    if (mounted) {
      context.pop();
    }
  }

  void _clearSavedAssetEncryptedPathFutures() {
    if (_savedAssetPathFutures.isEmpty) {
      return;
    }
    setState(_savedAssetPathFutures.clear);
  }

  @override
  void dispose() {
    _sessionSubscription.close();
    _cancelAutoSaveTimer();
    _savedStatusTimer?.cancel();
    _dateController.removeListener(_clearSavedAssetEncryptedPathFutures);
    _dateController.removeListener(_onDraftFieldChanged);
    _tagsController.removeListener(_onTagsDraftChanged);
    _titleController.removeListener(_onDraftFieldChanged);
    _bodyController.removeListener(_onDraftFieldChanged);
    _titleController.dispose();
    _dateController.dispose();
    _tagsController.dispose();
    _bodyController.dispose();
    _savedAssetPathFutures.clear();
    super.dispose();
  }

  void _clearSensitiveLocalState() {
    _titleController.clear();
    _dateController.text = DateOnly.fromDateTime(DateTime.now()).value;
    _tagsController.clear();
    _bodyController.clear();
    _pendingAttachments.clear();
    _keptExistingAttachmentIds = <AssetId>[];
    _savedAssetPathFutures.clear();
    _cancelAutoSaveTimer();
    _savedStatusTimer?.cancel();
    _lastSavedSnapshot = null;
    _saveStatus = _SaveStatus.idle;
    _didLoadExisting = false;
    _previewMode = widget.entryId != null && !widget.startInEditMode;
    _entryTime = TimeOfDay.now();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isSupportedPlatform = ref.watch(supportedPlatformProvider);
    final AsyncValue<AppSessionState> sessionAsync = ref.watch(effectiveAppSessionProvider);
    final AsyncValue<DiaryEntry?> entryAsync = widget.entryId == null
        ? const AsyncValue<DiaryEntry?>.data(null)
        : ref.watch(entryProvider(widget.entryId!));
    final AsyncValue<Object?> metadataAsync = ref.watch(recoveryMetadataProvider);

    if (!isSupportedPlatform) {
      return Scaffold(
        appBar: AppBar(title: const Text('編輯日記')),
        body: const Center(child: Text(kAndroidOnlyMessage)),
      );
    }

    return sessionAsync.when(
      data: (AppSessionState sessionState) {
        final UnlockedVaultSession? session = sessionState.session;
        if (!sessionState.isUnlocked || session == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('編輯日記')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  switch (sessionState.status) {
                    AppLockStatus.recoveryRequired =>
                      sessionState.message ?? kRecoveryRequiredAfterRestoreMessage,
                    AppLockStatus.unlocking =>
                      sessionState.message ?? kTrustedUnlockInProgressMessage,
                    AppLockStatus.locked =>
                      sessionState.message ?? kLockedRetryVerificationMessage,
                    _ => sessionState.message ?? '請先重新解鎖日記庫後再繼續。',
                  },
                ),
              ),
            ),
          );
        }

        return entryAsync.when(
          data: (DiaryEntry? entry) {
            _loadExistingEntryIfNeeded(entry);
            _activeSession = session;
            _activeEntry = entry;
            final AsyncValue<List<AssetAttachment>> attachmentsAsync = widget.entryId == null
                ? const AsyncValue<List<AssetAttachment>>.data(<AssetAttachment>[])
                : ref.watch(entryAttachmentsProvider(widget.entryId!));
            final ColorScheme colorScheme = Theme.of(context).colorScheme;
            return PopScope(
              canPop: false,
              onPopInvokedWithResult: (bool didPop, Object? result) {
                if (didPop) {
                  return;
                }
                unawaited(_requestClose());
              },
              child: Scaffold(
                backgroundColor: PageStyle.scaffoldWash(colorScheme),
                body: metadataAsync.when(
                data: (Object? metadata) {
                  if (metadata == null) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('請先建立復原金鑰，才能開始建立或編輯日記。'),
                      ),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _buildEditorTopBar(session, entry),
                      Expanded(
                        child: SafeArea(
                          top: false,
                          child: LayoutBuilder(
                            builder: (BuildContext context, BoxConstraints constraints) {
                              final bool wide = constraints.maxWidth >= 960;
                        final Widget sidebar = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            if (!_previewMode)
                              _buildSavedAndPendingImageStrip(
                                attachmentsAsync,
                                editable: true,
                              ),
                            if (!_previewMode &&
                                (_savedNonImageAttachments(attachmentsAsync).isNotEmpty ||
                                    _pendingNonImageAttachments.isNotEmpty))
                              const SizedBox(height: 6),
                            if (_savedNonImageAttachments(attachmentsAsync).isNotEmpty ||
                                _pendingNonImageAttachments.isNotEmpty)
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: <Widget>[
                                  ..._savedNonImageAttachments(attachmentsAsync).map(
                                    (AssetAttachment a) =>
                                        _savedNonImageChip(a, editable: _isEditing),
                                  ),
                                  ..._pendingNonImageAttachments.map(
                                    (PendingAttachment a) =>
                                        _pendingNonImageChip(a, editable: _isEditing),
                                  ),
                                ],
                              ),
                          ],
                        );

                        final ThemeData paneTheme = Theme.of(context);
                        final bool hasSidebarNonImage =
                            _savedNonImageAttachments(attachmentsAsync).isNotEmpty ||
                            _pendingNonImageAttachments.isNotEmpty;
                        final bool showWideSidebarWithStrip =
                            wide && (!_previewMode || hasSidebarNonImage);
                        final bool narrowGapAfterSidebar = !_previewMode || hasSidebarNonImage;
                        final Widget editorPane = Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            if (_previewMode)
                              _buildPreviewImageGallery(attachmentsAsync),
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  bottom: 8 + MediaQuery.paddingOf(context).bottom,
                                ),
                                child: _buildBodyContentPanel(paneTheme),
                              ),
                            ),
                          ],
                        );

                        return Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              _buildTitleHeader(context),
                              const SizedBox(height: 8),
                              Expanded(
                                child: showWideSidebarWithStrip
                                    ? Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: <Widget>[
                                          SizedBox(
                                            width: 320,
                                            child: SingleChildScrollView(child: sidebar),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(child: editorPane),
                                        ],
                                      )
                                    : !wide
                                        ? Column(
                                            crossAxisAlignment: CrossAxisAlignment.stretch,
                                            children: <Widget>[
                                              sidebar,
                                              if (narrowGapAfterSidebar) const SizedBox(height: 8),
                                              Expanded(child: editorPane),
                                            ],
                                          )
                                        : editorPane,
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
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (Object error, StackTrace _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(userFacingErrorMessage(error)),
                  ),
                ),
              ),
            ),
            );
          },
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (Object error, StackTrace _) => Scaffold(
            appBar: AppBar(title: const Text('編輯日記')),
            body: Center(child: Text(userFacingErrorMessage(error))),
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (Object error, StackTrace _) => Scaffold(
        appBar: AppBar(title: const Text('編輯日記')),
        body: Center(child: Text(userFacingErrorMessage(error))),
      ),
    );
  }

  void _loadExistingEntryIfNeeded(DiaryEntry? entry) {
    if (_didLoadExisting || entry == null) {
      return;
    }
    _didLoadExisting = true;
    _suppressDraftListener = true;
    _titleController.text = entry.title ?? '';
    _dateController.text = entry.date.value;
    _tagsController.text = entry.tags.join(', ');
    _bodyController.text = entry.markdownBody;
    _keptExistingAttachmentIds = List<AssetId>.from(entry.attachmentIds);
    _entryTime = TimeOfDay(hour: entry.createdAt.hour, minute: entry.createdAt.minute);
    _lastSavedSnapshot = editorDraftSnapshotFromEntry(entry);
    _suppressDraftListener = false;
  }

  DateTime _composeEntryCreatedAt({required DateOnly date, required DiaryEntry? existing}) {
    final DateTime d = date.toDateTime();
    if (existing != null) {
      return DateTime(
        d.year,
        d.month,
        d.day,
        _entryTime.hour,
        _entryTime.minute,
        existing.createdAt.second,
        existing.createdAt.millisecond,
        existing.createdAt.microsecond,
      );
    }
    final DateTime n = DateTime.now();
    return DateTime(
      d.year,
      d.month,
      d.day,
      _entryTime.hour,
      _entryTime.minute,
      n.second,
      n.millisecond,
      n.microsecond,
    );
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
      locale: const Locale('zh', 'TW'),
    );
    if (!mounted || picked == null) {
      return;
    }
    setState(() {
      _dateController.text = DateOnly.fromDateTime(picked).value;
    });
    _onDraftFieldChanged();
  }

  Future<void> _pickEntryTime() async {
    DateTime anchor;
    try {
      final DateOnly parsed = DateOnly.parse(_dateController.text.trim());
      final DateTime base = parsed.toDateTime();
      anchor = DateTime(base.year, base.month, base.day, _entryTime.hour, _entryTime.minute);
    } catch (_) {
      anchor = DateTime.now();
    }
    final TimeOfDay initial = TimeOfDay.fromDateTime(anchor);
    if (!mounted) {
      return;
    }
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (BuildContext context, Widget? child) {
        return Localizations.override(
          context: context,
          locale: const Locale('zh', 'TW'),
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
    if (!mounted || picked == null) {
      return;
    }
    setState(() => _entryTime = picked);
    _onDraftFieldChanged();
  }

  String _formattedDisplayDate(BuildContext context) {
    try {
      final DateOnly parsed = DateOnly.parse(_dateController.text.trim());
      final DateTime d = parsed.toDateTime();
      final String datePart = _formatEditorDatePartZh(d);
      return '$datePart ${weekdayZhLong(d)}';
    } catch (_) {
      final String raw = _dateController.text.trim();
      return raw.isEmpty ? '—' : raw;
    }
  }

  String _formatEditorDatePartZh(DateTime date) {
    try {
      return DateFormat('yyyy年M月d日', 'zh_Hant').format(date);
    } catch (_) {
      return DateFormat('yyyy年M月d日').format(date);
    }
  }

  int _bodyMarkdownCharCount() => _bodyController.text.runes.length;

  Future<List<TagCatalogUsageItem>> _tagSuggestionsFromIndexAsync() async {
    try {
      final List<EntryIndexRecord> records =
          await ref.read(allEntryIndexRecordsProvider.future);
      final catalog = await ref.read(tagCatalogProvider.future);
      return mergeTagCatalogWithUsage(catalog, diaryPresenceTagCounts(records));
    } catch (_) {
      return const <TagCatalogUsageItem>[];
    }
  }

  void _applyTagsCsv(String commaSeparatedTags) {
    final String trimmed = commaSeparatedTags.trim();
    final int caret = trimmed.length;
    _suppressTagDraftListener = true;
    _tagsController.value = TextEditingValue(
      text: trimmed,
      selection: TextSelection.collapsed(offset: caret),
    );
    _suppressTagDraftListener = false;
    if (mounted && !_previewMode) {
      setState(() {});
    }
    _onDraftFieldChanged();
  }
  /// 固定 24 小時制顯示（與時間選擇器一致）。
  String _formattedEntryTime24h() {
    final int h = _entryTime.hour;
    final int m = _entryTime.minute;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  /// 標籤欄（逗號分隔）解析後供編輯畫面上方顯示。
  List<String> _editableTagListPreview() {
    return _tagsController.text
        .split(',')
        .map((String t) => t.trim())
        .where((String t) => t.isNotEmpty)
        .toList();
  }

  Widget _buildCharCountTagPill(ThemeData theme, int charCount) {
    final ColorScheme cs = theme.colorScheme;
    final Color bg = Color.alphaBlend(cs.onSurfaceVariant.withValues(alpha: 0.12), cs.surface);
    final Color fg = cs.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: bg.withValues(alpha: 0.92),
        border: Border.all(
          color: fg.withValues(alpha: 0.32),
          width: 0.9,
        ),
      ),
      child: Text(
        '$charCount字',
        style: theme.textTheme.labelMedium?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
          height: 1.15,
        ),
      ),
    );
  }

  Widget _buildTagPill(String tag, ThemeData theme) {
    final (Color bg, Color fg) = tagResolvedAccentPair(
      tag,
      theme.colorScheme,
      _watchedTagAccentArgbMap(),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: bg.withValues(alpha: 0.88),
        border: Border.all(
          color: fg.withValues(alpha: 0.34),
          width: 0.9,
        ),
      ),
      child: Text(
        tag,
        style: theme.textTheme.labelMedium?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
          height: 1.15,
        ),
      ),
    );
  }

  Widget _buildEditorMetaSubtitleRow(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle? metaStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w500,
      height: 1.25,
      letterSpacing: 0.15,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Text(
          '${_formattedDisplayDate(context)} · ${_formattedEntryTime24h()}',
          style: metaStyle,
          maxLines: 1,
        ),
        if (_isEditing && _saveStatus != _SaveStatus.idle) ...<Widget>[
          Text(' · ', style: metaStyle),
          _buildSaveStatusLabel(theme),
        ],
      ],
    );
  }

  Widget _buildTagsWrap(
    ThemeData theme, {
    bool showCharCount = false,
    required int bodyCharCount,
  }) {
    final List<String> tags = _editableTagListPreview();
    if (tags.isEmpty && (!showCharCount || bodyCharCount <= 0)) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: <Widget>[
        if (showCharCount && bodyCharCount > 0) _buildCharCountTagPill(theme, bodyCharCount),
        ...tags
            .take(24)
            .map((String tag) => _buildTagPill(tag, theme)),
      ],
    );
  }

  Widget _buildTitleHeader(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int bodyCharCount = _bodyMarkdownCharCount();
    final bool showTagsRow =
        _editableTagListPreview().isNotEmpty || bodyCharCount > 0;
    if (_previewMode) {
      final String titleText = _titleController.text.trim();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            titleText.isEmpty ? '無標題' : titleText,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.28,
              letterSpacing: -0.35,
              color:
                  titleText.isEmpty ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onSurface,
            ),
          ),
          if (showTagsRow) ...<Widget>[
            const SizedBox(height: 10),
            _buildTagsWrap(
              theme,
              showCharCount: true,
              bodyCharCount: bodyCharCount,
            ),
          ],
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _buildEditorMetaSubtitleRow(context),
        const SizedBox(height: 8),
        TextField(
          controller: _titleController,
          textInputAction: TextInputAction.next,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.28,
            letterSpacing: -0.35,
          ),
          decoration: _titleFieldDecoration(
            context,
            hintText: '輸入標題',
          ),
        ),
        if (showTagsRow) ...<Widget>[
          const SizedBox(height: 10),
          _buildTagsWrap(
            theme,
            showCharCount: true,
            bodyCharCount: bodyCharCount,
          ),
        ],
      ],
    );
  }

  /// 內容區外框固定填滿可用高度，僅框內文字捲動或編輯。
  Widget _buildBodyContentPanel(ThemeData paneTheme) {
    final Widget body = _previewMode
        ? SingleChildScrollView(
            child: _bodyController.text.isEmpty
                ? SelectableText(
                    '尚未輸入內容',
                    style: paneTheme.textTheme.bodyLarge?.copyWith(
                      fontStyle: FontStyle.italic,
                      height: 1.72,
                      color: paneTheme.colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
                    ),
                  )
                : _MarkdownPreviewBody(markdown: _bodyController.text),
          )
        : TextField(
            controller: _bodyController,
            expands: true,
            maxLines: null,
            minLines: null,
            textAlignVertical: TextAlignVertical.top,
            style: paneTheme.textTheme.bodyLarge?.copyWith(
              height: 1.76,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.2,
            ),
            decoration: _bodyFieldDecoration(
              context,
              hintText: '在這裡輸入內容…',
            ),
          );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: PageStyle.previewPanelFill(paneTheme.colorScheme),
        borderRadius: BorderRadius.circular(PageStyle.radiusPanel),
        border: Border.fromBorderSide(
          PageStyle.outlineSide(paneTheme.colorScheme),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
        child: body,
      ),
    );
  }

  Widget _buildEditorTopBar(UnlockedVaultSession session, DiaryEntry? entry) {
    Future<void> deleteEntry() async {
      if (widget.entryId == null || _saving) {
        return;
      }
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: const Text('確認刪除'),
          content: const Text('確定要刪除這篇日記嗎？刪除後無法復原。'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              child: const Text('刪除'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) {
        return;
      }
      await ref.read(vaultRepositoryProvider).deleteEntry(session, widget.entryId!);
      if (!mounted) {
        return;
      }
      await refreshEntryIndexCaches(ref, editedEntryId: widget.entryId);
      if (!mounted) {
        return;
      }
      context.pop();
    }

    Future<void> saveEntry() async {
      _cancelAutoSaveTimer();
      await _saveEntry(session, entry, switchToPreview: true);
    }

    final ThemeData barTheme = Theme.of(context);
    final Color saveButtonColor = barTheme.colorScheme.primary;
    final Color deleteButtonColor = barTheme.colorScheme.error;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 2, 4, 2),
            child: Row(
              children: <Widget>[
                IconButton(
                  tooltip: '取消',
                  onPressed: _saving ? null : () => unawaited(_requestClose()),
                  icon: const Icon(Icons.close_rounded),
                ),
                if (_isEditing) ...<Widget>[
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          IconButton(
                            tooltip: '日期',
                            onPressed: _saving ? null : _pickEntryDate,
                            icon: const Icon(Icons.calendar_today_outlined),
                          ),
                          IconButton(
                            tooltip: '時間',
                            onPressed: _saving ? null : _pickEntryTime,
                            icon: const Icon(Icons.schedule_outlined),
                          ),
                          IconButton(
                            tooltip: '編輯標籤',
                            onPressed: _saving ? null : _showTagsEditorDialog,
                            icon: const Icon(Icons.sell_outlined),
                          ),
                          IconButton(
                            tooltip: '上傳圖片（可一次選多張）',
                            onPressed: _saving ? null : () => _pickImage(),
                            icon: const Icon(Icons.image_outlined),
                          ),
                          IconButton(
                            tooltip: '新增附件',
                            onPressed: _saving ? null : () => _pickFile(),
                            icon: const Icon(Icons.attach_file),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '儲存',
                    onPressed: _saving ? null : saveEntry,
                    style: IconButton.styleFrom(foregroundColor: saveButtonColor),
                    icon: const Icon(Icons.save_outlined),
                  ),
                  if (widget.entryId != null)
                    IconButton(
                      tooltip: '刪除',
                      onPressed: _saving ? null : deleteEntry,
                      style: IconButton.styleFrom(foregroundColor: deleteButtonColor),
                      icon: const Icon(Icons.delete_outline),
                    ),
                ] else ...<Widget>[
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: Text(
                          '${_formattedDisplayDate(context)} · ${_formattedEntryTime24h()}',
                          style: barTheme.textTheme.titleSmall?.copyWith(
                            color: barTheme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '編輯',
                    onPressed: _saving
                        ? null
                        : () => setState(() {
                              _previewMode = false;
                              if (_activeEntry != null) {
                                _lastSavedSnapshot =
                                    editorDraftSnapshotFromEntry(_activeEntry!);
                              }
                            }),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  if (widget.entryId != null)
                    IconButton(
                      tooltip: '刪除',
                      onPressed: _saving ? null : deleteEntry,
                      style: IconButton.styleFrom(foregroundColor: deleteButtonColor),
                      icon: const Icon(Icons.delete_outline),
                    ),
                ],
              ],
            ),
          ),
        ),
        Divider(
          height: 1,
          thickness: 1,
          color: barTheme.colorScheme.outlineVariant.withValues(alpha: 0.34),
        ),
      ],
    );
  }

  Widget _buildSaveStatusLabel(ThemeData theme) {
    final String label;
    final Color color;
    switch (_saveStatus) {
      case _SaveStatus.dirty:
        label = '有未儲存變更';
        color = theme.colorScheme.onSurfaceVariant;
      case _SaveStatus.saving:
        label = '儲存中…';
        color = theme.colorScheme.primary;
      case _SaveStatus.saved:
        label = '已儲存';
        color = theme.colorScheme.primary;
      case _SaveStatus.idle:
        label = '';
        color = theme.colorScheme.onSurfaceVariant;
    }
    if (label.isEmpty) {
      return const SizedBox.shrink();
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        if (_saveStatus == _SaveStatus.saving)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        if (_saveStatus == _SaveStatus.saved)
          Padding(
            padding: const EdgeInsets.only(right: 3),
            child: Icon(
              Icons.check_circle_outline,
              size: 14,
              color: theme.colorScheme.primary,
            ),
          ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
            height: 1.25,
          ),
        ),
      ],
    );
  }

  Future<void> _saveEntry(
    UnlockedVaultSession session,
    DiaryEntry? existing, {
    bool switchToPreview = false,
  }) async {
    if (_saving) {
      return;
    }
    _cancelAutoSaveTimer();
    setState(() {
      _saving = true;
      _saveStatus = _SaveStatus.saving;
    });
    try {
      final DateTime now = DateTime.now();
      final DateOnly parsedDate = DateOnly.parse(_dateController.text.trim());
      final DiaryEntry draft = DiaryEntry(
        id: existing?.id ?? generateEntryId(),
        vaultId: existing?.vaultId ?? session.vaultId,
        title: _titleController.text.trim().isEmpty ? null : _titleController.text.trim(),
        date: parsedDate,
        createdAt: _composeEntryCreatedAt(date: parsedDate, existing: existing),
        updatedAt: now,
        tags: parseEditorTagsCsv(_tagsController.text),
        markdownBody: _bodyController.text.trim(),
        attachmentIds: List<AssetId>.from(_keptExistingAttachmentIds),
      );
      final DiaryEntry saved = await ref.read(vaultRepositoryProvider).saveEntry(
            session,
            draft,
            pendingAttachments: List<PendingAttachment>.from(_pendingAttachments),
          );
      await refreshEntryIndexCaches(ref, editedEntryId: saved.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _savedAssetPathFutures.clear();
        _keptExistingAttachmentIds = List<AssetId>.from(saved.attachmentIds);
        _pendingAttachments.clear();
        _entryTime = TimeOfDay(hour: saved.createdAt.hour, minute: saved.createdAt.minute);
        _lastSavedSnapshot = editorDraftSnapshotFromEntry(saved);
        _activeEntry = saved;
        if (switchToPreview) {
          _previewMode = true;
          _saveStatus = _SaveStatus.idle;
        }
      });
      if (!switchToPreview) {
        _markSaved();
      }
      if (widget.entryId == null && mounted) {
        // 保留首頁在堆疊底層，關閉編輯器時才能 pop 回首頁（go 會整段取代路由）。
        final String route = switchToPreview
            ? '/editor/${saved.id}'
            : '/editor/${saved.id}?edit=1';
        context.pushReplacement(route);
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
    _onDraftFieldChanged();
  }

  Widget _pendingImageThumbnailTile(PendingAttachment attachment, {required bool editable}) {
    final ThemeData theme = Theme.of(context);
    final Widget image = SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          localFileThumbnail(
            attachment.sourcePath,
            size: 64,
            borderRadius: BorderRadius.circular(PageStyle.radiusThumbSmall),
          ),
          if (editable)
            Positioned(
              right: 4,
              top: 4,
              child: Icon(
                Icons.cancel_rounded,
                size: 20,
                color: theme.colorScheme.error.withValues(alpha: 0.9),
                shadows: const <Shadow>[
                  Shadow(blurRadius: 4, color: Color(0x66000000)),
                ],
              ),
            ),
        ],
      ),
    );
    if (!editable) {
      return image;
    }
    return Tooltip(
      message: '點一下從待上傳清單移除（須按儲存才會寫入日記）',
      child: InkWell(
        onTap: () => _removePendingAttachment(attachment),
        borderRadius: BorderRadius.circular(PageStyle.radiusThumbSmall),
        child: image,
      ),
    );
  }

  Widget _pendingNonImageChip(PendingAttachment attachment, {required bool editable}) {
    return Chip(
      label: Text(
        attachment.originalFilename,
        overflow: TextOverflow.ellipsis,
      ),
      onDeleted: editable ? () => _removePendingAttachment(attachment) : null,
    );
  }

  List<AssetAttachment> _savedNonImageAttachments(
    AsyncValue<List<AssetAttachment>> savedAsync,
  ) {
    return savedAsync.maybeWhen(
      data: (List<AssetAttachment> list) => list
          .where(
            (AssetAttachment a) =>
                !a.mimeType.startsWith('image/') &&
                _keptExistingAttachmentIds.contains(a.id),
          )
          .toList(),
      orElse: () => <AssetAttachment>[],
    );
  }

  Widget _buildSavedAndPendingImageStrip(
    AsyncValue<List<AssetAttachment>> savedAsync, {
    required bool editable,
  }) {
    final List<AssetAttachment> savedImages = savedAsync.maybeWhen(
      data: (List<AssetAttachment> list) => list
          .where(
            (AssetAttachment a) =>
                a.mimeType.startsWith('image/') &&
                _keptExistingAttachmentIds.contains(a.id),
          )
          .toList(),
      orElse: () => <AssetAttachment>[],
    );
    final List<PendingAttachment> pending = _pendingImageAttachments.toList();
    if (savedImages.isEmpty && pending.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 4),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ...savedImages.map(
                (AssetAttachment a) => Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: _savedImageThumbnailTile(a, editable: editable),
                ),
              ),
              ...pending.map(
                (PendingAttachment a) => Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: _pendingImageThumbnailTile(a, editable: editable),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _previewPhotoTileSaved(
    AssetAttachment attachment,
    double thumbSide, {
    double leadingInset = 6,
    required VoidCallback onTap,
  }) {
    final double edge = thumbSide.clamp(40.0, 400.0);
    return Padding(
      padding: EdgeInsets.only(left: leadingInset, right: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(PageStyle.radiusThumb),
          child: FutureBuilder<String>(
            future: _cachedEncryptedPathFuture(attachment),
            builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
              return EntryCoverThumbnail(
                encryptedFilePath: snapshot.data ?? '',
                size: edge,
                borderRadius: BorderRadius.circular(PageStyle.radiusThumb),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _previewPhotoTilePending(
    PendingAttachment attachment,
    double thumbSide, {
    double leadingInset = 6,
    required VoidCallback onTap,
  }) {
    final double edge = thumbSide.clamp(40.0, 400.0);
    return Padding(
      padding: EdgeInsets.only(left: leadingInset, right: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(PageStyle.radiusThumb),
          child: localFileThumbnail(
            attachment.sourcePath,
            size: edge,
            borderRadius: BorderRadius.circular(PageStyle.radiusThumb),
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewImageGallery(AsyncValue<List<AssetAttachment>> savedAsync) {
    final List<AssetAttachment> savedImages = savedAsync.maybeWhen(
      data: (List<AssetAttachment> list) => list
          .where(
            (AssetAttachment a) =>
                a.mimeType.startsWith('image/') &&
                _keptExistingAttachmentIds.contains(a.id),
          )
          .toList(),
      orElse: () => <AssetAttachment>[],
    );
    final List<PendingAttachment> pending = _pendingImageAttachments.toList();
    final int total = savedImages.length + pending.length;
    if (total == 0) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double maxW = constraints.maxWidth.isFinite ? constraints.maxWidth : 360;
        // 與兩欄格狀約略同級的邊長：半寬扣除間距後再留內距
        final double thumbSide = (((maxW - 12) / 2) - 22).clamp(108.0, 320.0);
        final double rowHeight = thumbSide;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SizedBox(
            height: rowHeight,
            child: ListView.separated(
              padding: EdgeInsets.zero,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: total,
              separatorBuilder: (BuildContext _, int _) =>
                  const SizedBox(width: 10),
              itemBuilder: (BuildContext context, int index) {
                final bool first = index == 0;
                if (index < savedImages.length) {
                  return _previewPhotoTileSaved(
                    savedImages[index],
                    thumbSide,
                    leadingInset: first ? 0 : 6,
                    onTap: () => unawaited(
                      _openImagePreviewGallery(
                        savedImages: savedImages,
                        pendingImages: pending,
                        initialIndex: index,
                      ),
                    ),
                  );
                }
                return _previewPhotoTilePending(
                  pending[index - savedImages.length],
                  thumbSide,
                  leadingInset: first ? 0 : 6,
                  onTap: () => unawaited(
                    _openImagePreviewGallery(
                      savedImages: savedImages,
                      pendingImages: pending,
                      initialIndex: index,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _openImagePreviewGallery({
    required List<AssetAttachment> savedImages,
    required List<PendingAttachment> pendingImages,
    required int initialIndex,
  }) async {
    final List<_PreviewGalleryImage> items = <_PreviewGalleryImage>[];
    for (final AssetAttachment attachment in savedImages) {
      final String path = await _cachedEncryptedPathFuture(attachment);
      if (path.trim().isEmpty) {
        continue;
      }
      items.add(
        _PreviewGalleryImage.encrypted(
          previewId: attachment.id,
          path: path,
        ),
      );
    }
    for (final PendingAttachment attachment in pendingImages) {
      final String? path = attachment.sourcePath?.trim();
      if (path == null || path.isEmpty) {
        continue;
      }
      items.add(
        _PreviewGalleryImage.local(
          previewId: path,
          path: path,
        ),
      );
    }
    if (!mounted || items.isEmpty) {
      return;
    }
    final int safeInitialIndex = initialIndex.clamp(0, items.length - 1);
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (BuildContext dialogContext) =>
          _EntryImageGalleryDialog(items: items, initialIndex: safeInitialIndex),
    );
  }

  void _removeSavedAttachment(AssetAttachment attachment) {
    setState(() {
      _savedAssetPathFutures.removeWhere(
        (String id, Future<String> _) => id == attachment.id,
      );
      _keptExistingAttachmentIds.remove(attachment.id);
    });
    _onDraftFieldChanged();
  }

  Future<String> _assetEncryptedPath(AssetAttachment attachment) async {
    DateOnly date;
    try {
      date = DateOnly.parse(_dateController.text.trim());
    } catch (_) {
      date = DateOnly.fromDateTime(DateTime.now());
    }
    String ext = p.extension(attachment.safeFilename).replaceFirst('.', '');
    if (ext.isEmpty) {
      ext = 'bin';
    }
    return ref.read(vaultPathStrategyProvider).assetAbsolutePath(
          date: date,
          assetId: attachment.id,
          extension: ext,
        );
  }

  Future<String> _cachedEncryptedPathFuture(AssetAttachment attachment) {
    return _savedAssetPathFutures.putIfAbsent(
      attachment.id,
      () => _assetEncryptedPath(attachment),
    );
  }

  Widget _savedImageThumbnailTile(AssetAttachment attachment, {required bool editable}) {
    final ThemeData theme = Theme.of(context);
    Widget thumb(String path) {
      final Widget image = SizedBox(
        width: 72,
        height: 72,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            EntryCoverThumbnail(
              encryptedFilePath: path.isEmpty ? null : path,
              size: 64,
              borderRadius: BorderRadius.circular(PageStyle.radiusThumbSmall),
            ),
            if (editable)
              Positioned(
                right: 4,
                top: 4,
                child: Icon(
                  Icons.cancel_rounded,
                  size: 20,
                  color: theme.colorScheme.error.withValues(alpha: 0.9),
                  shadows: const <Shadow>[
                    Shadow(blurRadius: 4, color: Color(0x66000000)),
                  ],
                ),
              ),
          ],
        ),
      );
      if (!editable) {
        return image;
      }
      return Tooltip(
        message: '點一下移除此圖（須按儲存才會從日記移除）',
        child: InkWell(
          onTap: () => _removeSavedAttachment(attachment),
          borderRadius: BorderRadius.circular(PageStyle.radiusThumbSmall),
          child: image,
        ),
      );
    }

    return FutureBuilder<String>(
      future: _cachedEncryptedPathFuture(attachment),
      builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
        return thumb(snapshot.data ?? '');
      },
    );
  }

  Widget _savedNonImageChip(AssetAttachment attachment, {required bool editable}) {
    return Chip(
      label: Text(
        attachment.originalFilename ?? attachment.safeFilename,
        overflow: TextOverflow.ellipsis,
      ),
      onDeleted: editable ? () => _removeSavedAttachment(attachment) : null,
    );
  }

  Future<void> _showTagsEditorDialog() async {
    if (!mounted) {
      return;
    }
    final List<TagCatalogUsageItem> sorted = await _tagSuggestionsFromIndexAsync();
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
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

    final Set<String> seenPaths = <String>{};
    final List<PendingAttachment> next = <PendingAttachment>[];
    for (final XFile file in files) {
      final String path = file.path;
      if (path.isEmpty || !seenPaths.add(path)) {
        continue;
      }
      next.add(
        PendingAttachment(
          sourcePath: path,
          mimeType: _mimeTypeFromPath(path),
          originalFilename: p.basename(path),
        ),
      );
    }
    if (next.isEmpty) {
      return;
    }

    setState(() {
      _pendingAttachments.addAll(next);
    });
    _onDraftFieldChanged();
  }

  Future<void> _pickFile() async {
    final FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.any,
    );
    if (result == null) {
      return;
    }

    setState(() {
      for (final PlatformFile file in result.files) {
        if (file.path == null) {
          continue;
        }
        _pendingAttachments.add(
          PendingAttachment(
            sourcePath: file.path!,
            mimeType: _mimeTypeFromPath(file.path!),
            originalFilename: file.name,
          ),
        );
      }
    });
    _onDraftFieldChanged();
  }

  String _mimeTypeFromPath(String pathValue) {
    switch (p.extension(pathValue).toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.gif':
        return 'image/gif';
      case '.md':
        return 'text/markdown';
      default:
        return 'application/octet-stream';
    }
  }
}
