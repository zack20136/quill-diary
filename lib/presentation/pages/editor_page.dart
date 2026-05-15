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

import '../../application/diary/diary_presence_tag_counts.dart';
import '../../infrastructure/database/index_database.dart';
import '../../domain/attachment/asset_attachment.dart';
import '../../domain/diary/diary_entry.dart';
import '../../domain/security/unlocked_vault_session.dart';
import '../../domain/shared/value_objects.dart';
import '../../features/editor/providers/editor_providers.dart';
import '../../features/home/providers/home_providers.dart';
import '../../features/session/providers/session_providers.dart';
import '../../features/session/session_messages.dart';
import '../../features/settings/providers/settings_providers.dart';
import '../../shared/providers/core_providers.dart';
import '../../infrastructure/storage/vault_repository.dart';
import '../page_style.dart';
import '../tag_visual.dart';
import '../state/app_session_state.dart';
import '../widgets/entry_cover_thumbnail.dart';
import '../widgets/tag_accent_composer_dialog.dart';
import '../widgets/local_file_thumbnail.dart';


class EditorPage extends ConsumerStatefulWidget {
  const EditorPage({super.key, this.entryId});

  final String? entryId;

  @override
  ConsumerState<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends ConsumerState<EditorPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _dateController = TextEditingController(
    text: DateOnly.fromDateTime(DateTime.now()).value,
  );
  final TextEditingController _tagsController = TextEditingController();
  final TextEditingController _moodController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final List<PendingAttachment> _pendingAttachments = <PendingAttachment>[];
  List<AssetId> _keptExistingAttachmentIds = <AssetId>[];
  final Map<String, Future<String>> _savedAssetPathFutures = <String, Future<String>>{};
  late bool _previewMode;
  TimeOfDay _entryTime = TimeOfDay.now();
  bool _didLoadExisting = false;
  bool _saving = false;
  bool _suppressTagDraftListener = false;
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
    _previewMode = widget.entryId != null;
    _dateController.addListener(_clearSavedAssetEncryptedPathFutures);
    _tagsController.addListener(_onTagsDraftChanged);
  }

  void _onTagsDraftChanged() {
    if (_suppressTagDraftListener || _previewMode || !mounted) {
      return;
    }
    setState(() {});
  }

  void _clearSavedAssetEncryptedPathFutures() {
    if (_savedAssetPathFutures.isEmpty) {
      return;
    }
    setState(_savedAssetPathFutures.clear);
  }

  @override
  void dispose() {
    _dateController.removeListener(_clearSavedAssetEncryptedPathFutures);
    _tagsController.removeListener(_onTagsDraftChanged);
    _titleController.dispose();
    _dateController.dispose();
    _tagsController.dispose();
    _moodController.dispose();
    _bodyController.dispose();
    _savedAssetPathFutures.clear();
    super.dispose();
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
                  sessionState.status == AppLockStatus.recoveryRequired
                      ? '請先使用 Recovery Key 解鎖，再繼續編輯日記。'
                      : sessionState.message ?? '請先完成裝置驗證後再繼續。',
                ),
              ),
            ),
          );
        }

        return entryAsync.when(
          data: (DiaryEntry? entry) {
            _loadExistingEntryIfNeeded(entry);
            final AsyncValue<List<AssetAttachment>> attachmentsAsync = widget.entryId == null
                ? const AsyncValue<List<AssetAttachment>>.data(<AssetAttachment>[])
                : ref.watch(entryAttachmentsProvider(widget.entryId!));
            return Scaffold(
              backgroundColor:
                  _previewMode ? Theme.of(context).colorScheme.surfaceContainerLow : null,
              body: metadataAsync.when(
                data: (Object? metadata) {
                  if (metadata == null) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('請先建立 Recovery Key，才能開始建立或編輯日記。'),
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
                              child: _previewMode
                                  ? SingleChildScrollView(
                                      padding: EdgeInsets.only(
                                        bottom: 12 + MediaQuery.paddingOf(context).bottom,
                                      ),
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: PageStyle.previewPanelFill(paneTheme.colorScheme),
                                          borderRadius:
                                              BorderRadius.circular(PageStyle.radiusPanel),
                                          border: Border.fromBorderSide(
                                            PageStyle.outlineSide(paneTheme.colorScheme),
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                                          child: _bodyController.text.isEmpty
                                              ? SelectableText(
                                                  '尚未輸入內容',
                                                  style: paneTheme.textTheme.bodyLarge?.copyWith(
                                                    fontStyle: FontStyle.italic,
                                                    height: 1.72,
                                                    color: paneTheme.colorScheme.onSurfaceVariant
                                                        .withValues(alpha: 0.85),
                                                  ),
                                                )
                                              : SelectableText(
                                                  _bodyController.text,
                                                  style: paneTheme.textTheme.bodyLarge?.copyWith(
                                                    height: 1.76,
                                                    fontWeight: FontWeight.w400,
                                                    letterSpacing: 0.2,
                                                  ),
                                                ),
                                        ),
                                      ),
                                    )
                                  : SingleChildScrollView(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: TextField(
                                        controller: _bodyController,
                                        minLines: 6,
                                        maxLines: null,
                                        textAlignVertical: TextAlignVertical.top,
                                        decoration: _editorFieldDecoration(
                                          context,
                                          hintText: '在這裡輸入內容…',
                                        ),
                                      ),
                                    ),
                            ),
                          ],
                        );

                        return Padding(
                          padding: EdgeInsets.fromLTRB(
                            _previewMode ? 20 : 16,
                            _previewMode ? 10 : 6,
                            _previewMode ? 20 : 16,
                            _previewMode ? 14 : 8,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              _buildTitleHeader(context),
                              SizedBox(height: _previewMode ? 10 : 8),
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
                    child: Text('$error'),
                  ),
                ),
              ),
            );
          },
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (Object error, StackTrace _) => Scaffold(
            appBar: AppBar(title: const Text('編輯日記')),
            body: Center(child: Text('$error')),
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (Object error, StackTrace _) => Scaffold(
        appBar: AppBar(title: const Text('編輯日記')),
        body: Center(child: Text('$error')),
      ),
    );
  }

  void _loadExistingEntryIfNeeded(DiaryEntry? entry) {
    if (_didLoadExisting || entry == null) {
      return;
    }
    _didLoadExisting = true;
    _titleController.text = entry.title ?? '';
    _dateController.text = entry.date.value;
    _tagsController.text = entry.tags.join(', ');
    _moodController.text = entry.mood ?? '';
    _bodyController.text = entry.markdownBody;
    _keptExistingAttachmentIds = List<AssetId>.from(entry.attachmentIds);
    _entryTime = TimeOfDay(hour: entry.createdAt.hour, minute: entry.createdAt.minute);
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
    );
    if (!mounted || picked == null) {
      return;
    }
    setState(() {
      _dateController.text = DateOnly.fromDateTime(picked).value;
    });
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
  }

  String _formattedDisplayDate(BuildContext context) {
    try {
      final DateOnly parsed = DateOnly.parse(_dateController.text.trim());
      final DateTime d = parsed.toDateTime();
      try {
        return DateFormat('yyyy年M月d日', 'zh_Hant').format(d);
      } catch (_) {
        return DateFormat('yyyy年M月d日').format(d);
      }
    } catch (_) {
      final String raw = _dateController.text.trim();
      return raw.isEmpty ? '—' : raw;
    }
  }

  Future<Map<String, int>> _tagFrequencyFromIndexAsync() async {
    try {
      final List<EntryIndexRecord> records =
          await ref.read(allEntryIndexRecordsProvider.future);
      return diaryPresenceTagCounts(records);
    } catch (_) {
      return <String, int>{};
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

  Widget _buildEditorMetaSubtitleRow(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<String> tags = _editableTagListPreview();
    final TextStyle? metaStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w500,
      height: 1.25,
      letterSpacing: 0.15,
    );
    final TextStyle? chipLabelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSecondaryContainer,
      fontWeight: FontWeight.w600,
      height: 1.15,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Text(
          '${_formattedDisplayDate(context)} · ${_formattedEntryTime24h()}',
          style: metaStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Expanded(
          child: tags.isEmpty
              ? const SizedBox.shrink()
              : Align(
                  alignment: Alignment.centerRight,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          for (final String tag in tags.take(14))
                            Padding(
                              padding: const EdgeInsets.only(left: 5),
                              child: Builder(
                                builder: (BuildContext context) {
                                  final (Color bg, Color fg) = tagResolvedAccentPair(
                                      tag,
                                      theme.colorScheme,
                                      _watchedTagAccentArgbMap(),
                                    );
                                  return Chip(
                                    label: Text(
                                      tag,
                                      style: chipLabelStyle?.copyWith(color: fg),
                                    ),
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                    padding:
                                        const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                    labelPadding:
                                        const EdgeInsets.symmetric(horizontal: 4),
                                    side: BorderSide(
                                      color: fg.withValues(alpha: 0.32),
                                      width: 0.95,
                                    ),
                                    backgroundColor: bg.withValues(alpha: 0.95),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildTitleHeader(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    if (_previewMode) {
      final String titleText = _titleController.text.trim();
      final List<String> previewTags = _editableTagListPreview();
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
          if (previewTags.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: previewTags
                  .take(24)
                  .map((String tag) {
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
                  })
                  .toList(),
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
        const SizedBox(height: 10),
        TextField(
          controller: _titleController,
          textInputAction: TextInputAction.next,
          decoration: _editorFieldDecoration(
            context,
            hintText: '輸入標題',
          ),
        ),
      ],
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
      await _saveEntry(session, entry);
    }

    final ThemeData barTheme = Theme.of(context);

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 2, 4, 2),
        child: Row(
          children: <Widget>[
            IconButton(
              tooltip: '取消',
              onPressed: _saving ? null : () => context.pop(),
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
                icon: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
              ),
              if (widget.entryId != null)
                IconButton(
                  tooltip: '刪除',
                  onPressed: _saving ? null : deleteEntry,
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
                onPressed: _saving ? null : () => setState(() => _previewMode = false),
                icon: const Icon(Icons.edit_outlined),
              ),
              if (widget.entryId != null)
                IconButton(
                  tooltip: '刪除',
                  onPressed: _saving ? null : deleteEntry,
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _saveEntry(
    UnlockedVaultSession session,
    DiaryEntry? existing,
  ) async {
    setState(() => _saving = true);
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
        tags: _tagsController.text
            .split(',')
            .map((String tag) => tag.trim())
            .where((String tag) => tag.isNotEmpty)
            .toList(),
        mood: _moodController.text.trim().isEmpty ? null : _moodController.text.trim(),
        markdownBody: _bodyController.text.trim(),
        attachmentIds: List<AssetId>.from(_keptExistingAttachmentIds),
        isDeleted: false,
      );
      final DiaryEntry saved = await ref.read(createEntryUseCaseProvider).call(
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
        if (widget.entryId != null) {
          _previewMode = true;
        }
      });
      if (widget.entryId == null && mounted) {
        // 保留首頁在堆疊底層，關閉編輯器時才能 pop 回首頁（go 會整段取代路由）。
        context.pushReplacement('/editor/${saved.id}');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  /// Pending-only: removes local file from the upload queue; persists only after [儲存].
  void _removePendingAttachment(PendingAttachment attachment) {
    setState(() {
      _pendingAttachments.remove(attachment);
    });
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
      return Material(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(PageStyle.radiusThumb),
        clipBehavior: Clip.antiAlias,
        child: image,
      );
    }
    return Tooltip(
      message: '點一下從待上傳清單移除（須按儲存才會寫入日記）',
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(PageStyle.radiusThumb),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _removePendingAttachment(attachment),
          child: image,
        ),
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
    ThemeData theme,
    double thumbSide, {
    double leadingInset = 6,
  }) {
    final double edge = thumbSide.clamp(40.0, 400.0);
    return Padding(
      padding: EdgeInsets.only(left: leadingInset, right: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openSavedAttachmentImagePreview(attachment),
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
    ThemeData theme,
    double thumbSide, {
    double leadingInset = 6,
  }) {
    final double edge = thumbSide.clamp(40.0, 400.0);
    return Padding(
      padding: EdgeInsets.only(left: leadingInset, right: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openPendingImagePreview(attachment.sourcePath),
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

    final ThemeData theme = Theme.of(context);

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
                    theme,
                    thumbSide,
                    leadingInset: first ? 0 : 6,
                  );
                }
                return _previewPhotoTilePending(
                  pending[index - savedImages.length],
                  theme,
                  thumbSide,
                  leadingInset: first ? 0 : 6,
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _openSavedAttachmentImagePreview(AssetAttachment attachment) async {
    final String path = await _cachedEncryptedPathFuture(attachment);
    if (!mounted || path.trim().isEmpty) {
      return;
    }
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (BuildContext dialogContext) =>
          _DecryptedImageFullScreenDialog(encryptedPath: path),
    );
  }

  void _openPendingImagePreview(String sourcePath) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(12),
          child: Stack(
            children: <Widget>[
              Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4,
                  child: Image.file(
                    File(sourcePath),
                    fit: BoxFit.contain,
                    errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) =>
                        const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                ),
              ),
              PositionedDirectional(
                top: 4,
                end: 4,
                child: IconButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _removeSavedAttachment(AssetAttachment attachment) {
    setState(() {
      _savedAssetPathFutures.remove(attachment.id);
      _keptExistingAttachmentIds.remove(attachment.id);
    });
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
        return Material(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(PageStyle.radiusThumb),
          clipBehavior: Clip.antiAlias,
          child: image,
        );
      }
      return Tooltip(
        message: '點一下移除此圖（須按儲存才會從日記移除）',
        child: Material(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(PageStyle.radiusThumb),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _removeSavedAttachment(attachment),
            child: image,
          ),
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
    final Map<String, int> freqMap = await _tagFrequencyFromIndexAsync();
    if (!mounted) {
      return;
    }
    final List<MapEntry<String, int>> sorted = freqMap.entries.toList()
      ..sort((MapEntry<String, int> a, MapEntry<String, int> b) {
        final int cmp = b.value.compareTo(a.value);
        if (cmp != 0) {
          return cmp;
        }
        return a.key.compareTo(b.key);
      });

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
  }

  Future<void> _pickFile() async {
    final FilePickerResult? result = await FilePicker.pickFiles(
      allowMultiple: true,
      withData: false,
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

class _TagsStudioDialog extends ConsumerStatefulWidget {
  const _TagsStudioDialog({
    required this.initialCsv,
    required this.suggestions,
    required this.onApply,
    required this.onDismiss,
  });

  final String initialCsv;
  final List<MapEntry<String, int>> suggestions;
  final ValueChanged<String> onApply;
  final VoidCallback onDismiss;

  @override
  ConsumerState<_TagsStudioDialog> createState() => _TagsStudioDialogState();
}

class _TagsStudioDialogState extends ConsumerState<_TagsStudioDialog> {
  late final LinkedHashSet<String> _chosen;
  late final TextEditingController _filterCtrl;

  String _norm(String s) => s.trim().replaceAll(RegExp(r'\s+'), ' ');

  Set<String> get _chosenNormSet => _chosen.map((String s) => normalizeText(s)).toSet();

  @override
  void initState() {
    super.initState();
    _chosen = LinkedHashSet<String>();
    _filterCtrl = TextEditingController();
    for (final String chunk in widget.initialCsv.split(',')) {
      final String t = _norm(chunk);
      if (t.isNotEmpty) {
        _chosen.add(t);
      }
    }
    _filterCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _filterCtrl.dispose();
    super.dispose();
  }

  Future<void> _openTagAccentComposer() async {
    final String? createdTag = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black45,
      builder: (BuildContext dialogContext) {
        return AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(
            left: 22,
            right: 22,
            top: 26,
            bottom: 26 + MediaQuery.viewInsetsOf(dialogContext).bottom,
          ),
          child: const Align(
            alignment: Alignment.center,
            child: Material(
              color: Colors.transparent,
              child: TagAccentComposerDialog(),
            ),
          ),
        );
      },
    );
    if (!mounted || createdTag == null || createdTag.trim().isEmpty) {
      return;
    }
    final String t = _norm(createdTag);
    if (t.isNotEmpty) {
      _chosen.add(t);
      setState(() {});
    }
  }

  Widget _chosenTagChip(String tag, ThemeData theme, Map<String, int> accents) {
    final (Color bg, Color fg) =
        tagResolvedAccentPair(tag, theme.colorScheme, accents);
    return Padding(
      padding: const EdgeInsets.only(right: 4, bottom: 4),
      child: InputChip(
        label: Text(tag, style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        onDeleted: () {
          _chosen.remove(tag);
          setState(() {});
        },
        deleteIconColor: fg.withValues(alpha: 0.82),
        backgroundColor: bg.withValues(alpha: 0.92),
        side: BorderSide(color: fg.withValues(alpha: 0.38), width: 0.95),
      ),
    );
  }

  Widget _suggestionChip(String label, ThemeData theme, Map<String, int> accents) {
    final (Color bg0, Color fg0) =
        tagResolvedAccentPair(label, theme.colorScheme, accents);
    return ActionChip(
      avatar: Icon(
        Icons.add_rounded,
        size: 16,
        color: fg0.withValues(alpha: 0.95),
      ),
      label: Text(label),
      labelStyle: theme.textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w700,
        height: 1.22,
        color: fg0,
      ),
      onPressed: () {
        _chosen.add(label);
        setState(() {});
      },
      side: BorderSide(
        color: fg0.withValues(alpha: 0.28),
        width: 0.95,
      ),
      elevation: 0,
      shadowColor: Colors.transparent,
      backgroundColor: Color.alphaBlend(
        fg0.withValues(alpha: 0.08),
        bg0,
      ).withValues(alpha: 0.96),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Map<String, int> accentArgbByNorm = ref.watch(tagAccentArgbMapProvider).maybeWhen(
          data: (Map<String, int> m) => m,
          orElse: () => const <String, int>{},
        );
    final String qlow = _filterCtrl.text.trim().toLowerCase();
    final Iterable<MapEntry<String, int>> pool = widget.suggestions.where(
      (MapEntry<String, int> e) =>
          !_chosenNormSet.contains(normalizeText(e.key)) &&
          (qlow.isEmpty || e.key.toLowerCase().contains(qlow)),
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: const Alignment(0.15, 0.45),
              colors: <Color>[
                Color.lerp(theme.colorScheme.primary, theme.colorScheme.surface, 0.86)!,
                theme.colorScheme.surface,
              ],
            ),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.18),
              width: 1.1,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: theme.shadowColor.withValues(alpha: 0.17),
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 16, 12, 16),
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.label_rounded, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '標籤',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '新增標籤與顏色',
                    visualDensity: VisualDensity.compact,
                    onPressed: _openTagAccentComposer,
                    icon: Icon(Icons.palette_outlined, color: theme.colorScheme.primary),
                  ),
                  IconButton(
                    tooltip: '關閉',
                    visualDensity: VisualDensity.compact,
                    onPressed: widget.onDismiss,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              Text(
                '右上角可建立新標籤與顏色；下方為文庫標籤，輕觸加入。',
                style: theme.textTheme.bodySmall?.copyWith(
                  height: 1.4,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              if (_chosen.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '尚未套用任何標籤',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ),
              ConstrainedBox(
                constraints:
                    BoxConstraints(maxHeight: math.min(MediaQuery.sizeOf(context).height * 0.18, 108)),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      for (final String t in _chosen)
                        _chosenTagChip(t, theme, accentArgbByNorm),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _filterCtrl,
                decoration: InputDecoration(
                  hintText: '搜尋已用過的標籤…',
                  prefixIcon: const Icon(Icons.search_rounded, size: 22),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.75),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: _filterCtrl.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: '清除搜尋',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _filterCtrl.clear(),
                          icon: const Icon(Icons.clear_rounded),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '文庫裡的標籤 · 輕觸加入',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints:
                    BoxConstraints(maxHeight: math.min(MediaQuery.sizeOf(context).height * 0.34, 240)),
                child: Scrollbar(
                  thumbVisibility: true,
                  thickness: 4,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.start,
                      children: <Widget>[
                        if (pool.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 8),
                            child: Text(
                              qlow.isEmpty ? '索引裡尚無可用標籤，或已全部加入目前清單' : '沒有符合的標籤',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontStyle: FontStyle.italic,
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ),
                        for (final String label
                            in pool.map((MapEntry<String, int> e) => e.key).take(60))
                          _suggestionChip(label, theme, accentArgbByNorm),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  TextButton(onPressed: widget.onDismiss, child: const Text('取消')),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => widget.onApply(_chosen.join(',')),
                    child: const Text('套用'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}


class _DecryptedImageFullScreenDialog extends ConsumerWidget {
  const _DecryptedImageFullScreenDialog({required this.encryptedPath});

  final String encryptedPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Uint8List?> async =
        ref.watch(entryCoverPreviewBytesProvider(encryptedPath));
    final Size mq = MediaQuery.sizeOf(context);
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(12),
      child: SizedBox(
        width: mq.width - 24,
        height: mq.height * 0.88,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: async.when(
                data: (Uint8List? bytes) {
                  if (bytes == null || bytes.isEmpty) {
                    return Center(
                      child: Text(
                        '無法預覽',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
                      ),
                    );
                  }
                  return InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4,
                    child: Center(
                      child: Image.memory(
                        bytes,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                      ),
                    ),
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                error: (Object _, StackTrace _) => const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white,
                  size: 56,
                ),
              ),
            ),
            PositionedDirectional(
              top: 4,
              end: 4,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

InputDecoration _editorFieldDecoration(
  BuildContext context, {
  required String hintText,
}) {
  final ColorScheme cs = Theme.of(context).colorScheme;
  final OutlineInputBorder border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: PageStyle.outlineSide(cs, opacity: 0.45),
  );
  return InputDecoration(
    hintText: hintText,
    filled: true,
    fillColor: cs.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    border: border,
    enabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: BorderSide(
        color: cs.primary,
        width: 1.5,
      ),
    ),
  );
}


