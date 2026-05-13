import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../../app/providers.dart';
import '../../domain/diary/diary_entry.dart';
import '../../domain/shared/value_objects.dart';
import '../../infrastructure/storage/vault_repository.dart';

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
  bool _previewMode = false;
  bool _didLoadExisting = false;
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _dateController.dispose();
    _tagsController.dispose();
    _moodController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<DiaryEntry?> entryAsync = widget.entryId == null
        ? const AsyncValue<DiaryEntry?>.data(null)
        : ref.watch(entryProvider(widget.entryId!));
    final AsyncValue metadataAsync = ref.watch(recoveryMetadataProvider);

    return entryAsync.when(
      data: (DiaryEntry? entry) {
        _loadExistingEntryIfNeeded(entry);
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.entryId == null ? '新增日記' : '編輯日記'),
            actions: [
              IconButton(
                tooltip: _previewMode ? '切換編輯' : '切換預覽',
                onPressed: () => setState(() => _previewMode = !_previewMode),
                icon: Icon(_previewMode ? Icons.edit : Icons.visibility_outlined),
              ),
              if (widget.entryId != null)
                IconButton(
                  tooltip: '刪除',
                  onPressed: _saving
                      ? null
                      : () async {
                          await ref
                              .read(vaultRepositoryProvider)
                              .deleteEntry(widget.entryId!);
                          if (context.mounted) {
                            ref.invalidate(timelineEntriesProvider);
                            context.pop();
                          }
                        },
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ),
          body: metadataAsync.when(
            data: (metadata) {
              if (metadata == null) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('請先建立 Recovery Key，才能開始寫入加密日記。'),
                  ),
                );
              }
              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _EditorToolbar(
                        onInsertHeading: () => _appendToBody('\n# 標題\n'),
                        onInsertChecklist: () => _appendToBody('\n- [ ] 待辦\n'),
                        onInsertImage: _pickImage,
                        onInsertFile: _pickFile,
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView(
                          children: [
                            TextField(
                              controller: _titleController,
                              decoration: const InputDecoration(labelText: '標題'),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _dateController,
                                    decoration:
                                        const InputDecoration(labelText: '日期 YYYY-MM-DD'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _moodController,
                                    decoration: const InputDecoration(labelText: '心情'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _tagsController,
                              decoration: const InputDecoration(labelText: '標籤（以逗號分隔）'),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _previewMode ? '預覽' : '正文',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            if (_previewMode)
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceContainerLowest,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: MarkdownBody(
                                    data: _bodyController.text.isEmpty
                                        ? '*尚未輸入內容*'
                                        : _bodyController.text,
                                  ),
                                ),
                              )
                            else
                              TextField(
                                controller: _bodyController,
                                maxLines: 18,
                                minLines: 12,
                                decoration: const InputDecoration(
                                  hintText: '開始寫下今天的內容...',
                                  alignLabelWithHint: true,
                                ),
                              ),
                            const SizedBox(height: 16),
                            if (_pendingAttachments.isNotEmpty) ...[
                              Text(
                                '待加入附件',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _pendingAttachments
                                    .map(
                                      (PendingAttachment attachment) => Chip(
                                        label: Text(attachment.originalFilename),
                                        onDeleted: () => setState(
                                          () => _pendingAttachments.remove(attachment),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          OutlinedButton(
                            onPressed: _saving ? null : () => context.pop(),
                            child: const Text('取消'),
                          ),
                          const Spacer(),
                          FilledButton.icon(
                            onPressed: _saving ? null : () => _saveEntry(entry),
                            icon: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: Text(_saving ? '儲存中' : '儲存'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (Object error, StackTrace stackTrace) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('無法讀取 editor 狀態：$error'),
              ),
            ),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (Object error, StackTrace stackTrace) => Scaffold(
        appBar: AppBar(title: const Text('編輯器')),
        body: Center(child: Text('載入日記失敗：$error')),
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
  }

  Future<void> _saveEntry(DiaryEntry? existing) async {
    setState(() => _saving = true);
    try {
      final DateTime now = DateTime.now();
      final DiaryEntry draft = DiaryEntry(
        id: existing?.id ?? generateEntryId(),
        vaultId: existing?.vaultId ?? 'vlt_LOCAL',
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
        attachmentIds: existing?.attachmentIds ?? const <String>[],
        isDeleted: false,
      );
      await ref.read(createEntryUseCaseProvider).call(
            draft,
            pendingAttachments: List<PendingAttachment>.from(_pendingAttachments),
          );
      ref.invalidate(timelineEntriesProvider);
      ref.invalidate(monthEntryDatesProvider);
      if (!mounted) return;
      context.pop();
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _appendToBody(String snippet) {
    _bodyController.text = '${_bodyController.text}$snippet';
    _bodyController.selection =
        TextSelection.collapsed(offset: _bodyController.text.length);
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
        _appendToBody('\n![圖片](${p.basename(file.path)})\n');
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

class _EditorToolbar extends StatelessWidget {
  const _EditorToolbar({
    required this.onInsertHeading,
    required this.onInsertChecklist,
    required this.onInsertImage,
    required this.onInsertFile,
  });

  final VoidCallback onInsertHeading;
  final VoidCallback onInsertChecklist;
  final Future<void> Function() onInsertImage;
  final Future<void> Function() onInsertFile;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: onInsertHeading,
          icon: const Icon(Icons.title),
          label: const Text('標題'),
        ),
        OutlinedButton.icon(
          onPressed: onInsertChecklist,
          icon: const Icon(Icons.check_box_outlined),
          label: const Text('清單'),
        ),
        OutlinedButton.icon(
          onPressed: onInsertImage,
          icon: const Icon(Icons.image_outlined),
          label: const Text('圖片'),
        ),
        OutlinedButton.icon(
          onPressed: onInsertFile,
          icon: const Icon(Icons.attach_file),
          label: const Text('附件'),
        ),
      ],
    );
  }
}
