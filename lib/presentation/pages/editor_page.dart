import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../../app/providers.dart';
import '../../domain/attachment/asset_attachment.dart';
import '../../domain/diary/diary_entry.dart';
import '../../domain/security/unlocked_vault_session.dart';
import '../../domain/shared/value_objects.dart';
import '../../infrastructure/storage/vault_repository.dart';
import '../state/app_session_state.dart';
import '../widgets/entry_cover_thumbnail.dart';
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
  bool _didLoadExisting = false;
  bool _saving = false;

  bool get _isEditing => !_previewMode;

  Iterable<PendingAttachment> get _pendingImageAttachments =>
      _pendingAttachments.where((PendingAttachment a) => a.mimeType.startsWith('image/'));

  Iterable<PendingAttachment> get _pendingNonImageAttachments =>
      _pendingAttachments.where((PendingAttachment a) => !a.mimeType.startsWith('image/'));

  @override
  void initState() {
    super.initState();
    _previewMode = widget.entryId != null;
  }

  @override
  void dispose() {
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
              appBar: AppBar(
                title: Text(widget.entryId == null ? '新增日記' : '編輯日記'),
                actions: <Widget>[
                  IconButton(
                    tooltip: _previewMode ? '編輯' : '預覽',
                    onPressed: () => setState(() => _previewMode = !_previewMode),
                    icon: Icon(_previewMode ? Icons.edit_outlined : Icons.visibility_outlined),
                  ),
                  if (widget.entryId != null)
                    IconButton(
                      tooltip: '刪除',
                      onPressed: _saving
                          ? null
                          : () async {
                              await ref
                                  .read(vaultRepositoryProvider)
                                  .deleteEntry(session, widget.entryId!);
                              if (!context.mounted) {
                                return;
                              }
                              await refreshEntryIndexCaches(ref, editedEntryId: widget.entryId);
                              if (!context.mounted) {
                                return;
                              }
                              context.pop();
                            },
                      icon: const Icon(Icons.delete_outline),
                    ),
                ],
              ),
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

                  return SafeArea(
                    child: LayoutBuilder(
                      builder: (BuildContext context, BoxConstraints constraints) {
                        final bool wide = constraints.maxWidth >= 960;
                        final Widget sidebar = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            TextField(
                              controller: _titleController,
                              readOnly: _previewMode,
                              decoration: _editorFieldDecoration(
                                context,
                                hintText: '輸入標題',
                              ),
                            ),
                            _buildSavedAndPendingImageStrip(
                              attachmentsAsync,
                              editable: _isEditing,
                            ),
                            if (_isEditing) ...<Widget>[
                              const SizedBox(height: 16),
                              _EditorToolbar(
                                onInsertImage: _pickImage,
                                onInsertFile: _pickFile,
                              ),
                            ],
                            if (_savedNonImageAttachments(attachmentsAsync).isNotEmpty ||
                                _pendingNonImageAttachments.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 16),
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
                          ],
                        );

                        final Widget editorPane = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              child: _previewMode
                                  ? SingleChildScrollView(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 14,
                                      ),
                                      child: MarkdownBody(
                                        data: _bodyController.text.isEmpty
                                            ? '*尚未輸入內容*'
                                            : _bodyController.text,
                                      ),
                                    )
                                  : TextField(
                                      controller: _bodyController,
                                      maxLines: null,
                                      expands: true,
                                      textAlignVertical: TextAlignVertical.top,
                                      decoration: _editorFieldDecoration(
                                        context,
                                        hintText: '在這裡輸入 Markdown 內容...',
                                      ),
                                    ),
                            ),
                          ],
                        );

                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          child: Column(
                            children: <Widget>[
                              Expanded(
                                child: wide
                                    ? Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: <Widget>[
                                          SizedBox(
                                            width: 320,
                                            child: SingleChildScrollView(child: sidebar),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(child: editorPane),
                                        ],
                                      )
                                    : ListView(
                                        children: <Widget>[
                                          sidebar,
                                          const SizedBox(height: 16),
                                          SizedBox(
                                            height: 520,
                                            child: editorPane,
                                          ),
                                        ],
                                      ),
                              ),
                              if (_isEditing) ...<Widget>[
                                const SizedBox(height: 12),
                                _EditorActionBar(
                                  saving: _saving,
                                  onCancel: _saving ? null : () => context.pop(),
                                  onSave: _saving ? null : () => _saveEntry(session, entry),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
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
  }

  Future<void> _saveEntry(
    UnlockedVaultSession session,
    DiaryEntry? existing,
  ) async {
    setState(() => _saving = true);
    try {
      final DateTime now = DateTime.now();
      final DiaryEntry draft = DiaryEntry(
        id: existing?.id ?? generateEntryId(),
        vaultId: existing?.vaultId ?? session.vaultId,
        title: _titleController.text.trim().isEmpty ? null : _titleController.text.trim(),
        date: DateOnly.parse(_dateController.text.trim()),
        createdAt: existing?.createdAt ?? now,
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
      await ref.read(createEntryUseCaseProvider).call(
            session,
            draft,
            pendingAttachments: List<PendingAttachment>.from(_pendingAttachments),
          );
      await refreshEntryIndexCaches(ref, editedEntryId: draft.id);
      if (!mounted) {
        return;
      }
      context.pop();
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _appendToBody(String snippet) {
    _bodyController.text = '${_bodyController.text}$snippet';
    _bodyController.selection = TextSelection.collapsed(offset: _bodyController.text.length);
  }

  String _markdownImageLineForPath(String sourcePath) {
    return '![圖片](${p.basename(sourcePath)})';
  }

  /// Pending-only: removes local file from the upload queue; persists only after [儲存].
  void _removePendingAttachment(PendingAttachment attachment) {
    setState(() {
      _pendingAttachments.remove(attachment);
      if (attachment.mimeType.startsWith('image/')) {
        _stripPendingImageMarkdown(attachment);
      }
    });
  }

  void _stripPendingImageMarkdown(PendingAttachment attachment) {
    final String linkLine = _markdownImageLineForPath(attachment.sourcePath);
    final List<String> lines = _bodyController.text.split('\n');
    final List<String> kept =
        lines.where((String line) => line.trim() != linkLine).toList();
    String next = kept.join('\n');
    next = next.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
    _bodyController.text = next;
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
            borderRadius: BorderRadius.circular(12),
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
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: image,
      );
    }
    return Tooltip(
      message: '點一下從待上傳清單移除（須按儲存才會寫入日記）',
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
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
        const SizedBox(height: 12),
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
      ],
    );
  }

  void _removeSavedAttachment(AssetAttachment attachment) {
    setState(() {
      _savedAssetPathFutures.remove(attachment.id);
      _keptExistingAttachmentIds.remove(attachment.id);
      _stripBodyReferencesToAttachment(attachment);
    });
  }

  void _stripBodyReferencesToAttachment(AssetAttachment attachment) {
    final Set<String> needles = <String>{
      attachment.safeFilename,
      p.basename(attachment.safeFilename),
      if (attachment.originalFilename != null &&
          attachment.originalFilename!.trim().isNotEmpty) ...<String>[
        attachment.originalFilename!,
        p.basename(attachment.originalFilename!),
      ],
    }..removeWhere((String s) => s.isEmpty);

    final RegExp mdLink = RegExp(r'!?\[[^\]]*\]\(([^)]+)\)');
    final List<String> lines = _bodyController.text.split('\n');
    final List<String> kept = <String>[];
    for (final String line in lines) {
      bool drop = false;
      for (final RegExpMatch m in mdLink.allMatches(line)) {
        final String url = m.group(1) ?? '';
        for (final String n in needles) {
          if (n.isNotEmpty &&
              (url == n ||
                  url.endsWith(n) ||
                  p.basename(url) == p.basename(n) ||
                  url.contains(n))) {
            drop = true;
            break;
          }
        }
        if (drop) {
          break;
        }
      }
      if (!drop && needles.any((String n) => n.isNotEmpty && line.contains(n))) {
        drop = true;
      }
      if (!drop) {
        kept.add(line);
      }
    }
    String next = kept.join('\n');
    next = next.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
    _bodyController.text = next;
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
              borderRadius: BorderRadius.circular(12),
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
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: image,
        );
      }
      return Tooltip(
        message: '點一下移除此圖（須按儲存才會從日記移除）',
        child: Material(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(14),
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

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final LostDataResponse lostData = await picker.retrieveLostData();
    final List<XFile> files = <XFile>[
      if (lostData.file != null) lostData.file!,
      ...?lostData.files,
    ];
    final XFile? picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      files.add(picked);
    }
    if (files.isEmpty) {
      return;
    }

    setState(() {
      for (final XFile file in files) {
        _pendingAttachments.add(
          PendingAttachment(
            sourcePath: file.path,
            mimeType: _mimeTypeFromPath(file.path),
            originalFilename: p.basename(file.path),
          ),
        );
        _appendToBody('\n${_markdownImageLineForPath(file.path)}\n');
      }
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

InputDecoration _editorFieldDecoration(
  BuildContext context, {
  required String hintText,
}) {
  final Color borderColor = Theme.of(context).colorScheme.outlineVariant;
  final OutlineInputBorder border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: borderColor),
  );
  return InputDecoration(
    hintText: hintText,
    filled: true,
    fillColor: Theme.of(context).colorScheme.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: border,
    enabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: BorderSide(
        color: Theme.of(context).colorScheme.primary,
        width: 1.5,
      ),
    ),
  );
}

class _EditorActionBar extends StatelessWidget {
  const _EditorActionBar({
    required this.saving,
    required this.onCancel,
    required this.onSave,
  });

  final bool saving;
  final VoidCallback? onCancel;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: <Widget>[
            OutlinedButton(
              onPressed: onCancel,
              child: const Text('取消'),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: onSave,
              icon: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(saving ? '儲存中' : '儲存'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditorToolbar extends StatelessWidget {
  const _EditorToolbar({
    required this.onInsertImage,
    required this.onInsertFile,
  });

  final Future<void> Function() onInsertImage;
  final Future<void> Function() onInsertFile;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ButtonStyle circleOutlined = IconButton.styleFrom(
      shape: const CircleBorder(),
      side: BorderSide(color: theme.colorScheme.outline),
      padding: const EdgeInsets.all(12),
      minimumSize: const Size(44, 44),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        IconButton(
          style: circleOutlined,
          onPressed: onInsertImage,
          icon: const Icon(Icons.image_outlined),
          tooltip: '上傳圖片',
        ),
        IconButton(
          style: circleOutlined,
          onPressed: onInsertFile,
          icon: const Icon(Icons.attach_file),
          tooltip: '新增附件',
        ),
        IconButton(
          style: circleOutlined,
          onPressed: () {},
          icon: const Icon(Icons.sell_outlined),
          tooltip: '新增標籤',
        ),
      ],
    );
  }
}
