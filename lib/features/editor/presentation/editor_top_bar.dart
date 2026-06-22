import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';

class EditorTopBar extends StatelessWidget {
  const EditorTopBar({
    super.key,
    required this.previewMode,
    required this.saving,
    required this.canSaveEntry,
    required this.canDelete,
    required this.previewTimestampLabel,
    required this.onClose,
    required this.onPickDate,
    required this.onPickTime,
    required this.onEditTags,
    required this.onPickImage,
    required this.onPickFile,
    required this.onSave,
    required this.onDelete,
    required this.onEnterEditMode,
  });

  final bool previewMode;
  final bool saving;
  final bool canSaveEntry;
  final bool canDelete;
  final String previewTimestampLabel;
  final VoidCallback? onClose;
  final VoidCallback? onPickDate;
  final VoidCallback? onPickTime;
  final VoidCallback? onEditTags;
  final VoidCallback? onPickImage;
  final VoidCallback? onPickFile;
  final VoidCallback? onSave;
  final VoidCallback? onDelete;
  final VoidCallback? onEnterEditMode;

  @override
  Widget build(BuildContext context) {
    final ThemeData barTheme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final Color saveButtonColor = barTheme.colorScheme.primary;
    final Color deleteButtonColor = barTheme.colorScheme.error;
    final bool canSave = !saving && canSaveEntry;

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
                  key: const Key('editor-top-bar-close'),
                  tooltip: l10n.editorTooltipCancel,
                  onPressed: saving ? null : onClose,
                  icon: const Icon(Icons.close_rounded),
                ),
                if (!previewMode) ...<Widget>[
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          IconButton(
                            tooltip: l10n.editorTooltipDate,
                            onPressed: saving ? null : onPickDate,
                            icon: const Icon(Icons.calendar_today_outlined),
                          ),
                          IconButton(
                            tooltip: l10n.editorTooltipTime,
                            onPressed: saving ? null : onPickTime,
                            icon: const Icon(Icons.schedule_outlined),
                          ),
                          IconButton(
                            tooltip: l10n.editorTooltipEditTags,
                            onPressed: saving ? null : onEditTags,
                            icon: const Icon(Icons.sell_outlined),
                          ),
                          IconButton(
                            tooltip: l10n.editorTooltipUploadImages,
                            onPressed: saving ? null : onPickImage,
                            icon: const Icon(Icons.image_outlined),
                          ),
                          IconButton(
                            tooltip: l10n.editorTooltipAddAttachment,
                            onPressed: saving ? null : onPickFile,
                            icon: const Icon(Icons.attach_file),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('editor-top-bar-save'),
                    tooltip: canSave
                        ? l10n.editorTooltipSave
                        : l10n.editorTooltipSaveNeedsEntry,
                    onPressed: saving ? null : onSave,
                    style: IconButton.styleFrom(
                      foregroundColor: canSave
                          ? saveButtonColor
                          : barTheme.colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.45,
                            ),
                    ),
                    icon: const Icon(Icons.save_outlined),
                  ),
                  if (canDelete)
                    IconButton(
                      key: const Key('editor-top-bar-delete'),
                      tooltip: l10n.editorTooltipDelete,
                      onPressed: saving ? null : onDelete,
                      style: IconButton.styleFrom(
                        foregroundColor: deleteButtonColor,
                      ),
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
                          previewTimestampLabel,
                          style: barTheme.textTheme.titleSmall?.copyWith(
                            color: barTheme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('editor-top-bar-edit'),
                    tooltip: l10n.editorTooltipEdit,
                    onPressed: saving ? null : onEnterEditMode,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  if (canDelete)
                    IconButton(
                      key: const Key('editor-top-bar-delete'),
                      tooltip: l10n.editorTooltipDelete,
                      onPressed: saving ? null : onDelete,
                      style: IconButton.styleFrom(
                        foregroundColor: deleteButtonColor,
                      ),
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
}
