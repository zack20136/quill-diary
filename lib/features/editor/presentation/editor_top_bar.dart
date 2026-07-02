import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';

class EditorTopBar extends StatelessWidget {
  const EditorTopBar({
    super.key,
    required this.previewMode,
    required this.saving,
    required this.canSaveEntry,
    required this.canDelete,
    required this.timestampLabel,
    required this.onClose,
    required this.onSave,
    required this.onDelete,
    required this.onEnterEditMode,
  });

  final bool previewMode;
  final bool saving;
  final bool canSaveEntry;
  final bool canDelete;
  final String timestampLabel;
  final VoidCallback? onClose;
  final VoidCallback? onSave;
  final VoidCallback? onDelete;
  final VoidCallback? onEnterEditMode;

  static const double _barIconSize = 22;

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
            padding: const EdgeInsets.fromLTRB(0, 0, 4, 0),
            child: Row(
              children: <Widget>[
                IconButton(
                  key: const Key('editor-top-bar-close'),
                  visualDensity: VisualDensity.compact,
                  tooltip: l10n.editorTooltipCancel,
                  onPressed: saving ? null : onClose,
                  icon: const Icon(Icons.close_rounded, size: _barIconSize),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: Text(
                        timestampLabel,
                        style: barTheme.textTheme.titleSmall?.copyWith(
                          color: barTheme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
                if (previewMode) ...<Widget>[
                  IconButton(
                    key: const Key('editor-top-bar-edit'),
                    visualDensity: VisualDensity.compact,
                    tooltip: l10n.editorTooltipEdit,
                    onPressed: saving ? null : onEnterEditMode,
                    icon: const Icon(Icons.edit_outlined, size: _barIconSize),
                  ),
                  if (canDelete)
                    IconButton(
                      key: const Key('editor-top-bar-delete'),
                      visualDensity: VisualDensity.compact,
                      tooltip: l10n.editorTooltipDelete,
                      onPressed: saving ? null : onDelete,
                      style: IconButton.styleFrom(
                        foregroundColor: deleteButtonColor,
                      ),
                      icon: const Icon(Icons.delete_outline, size: _barIconSize),
                    ),
                ] else ...<Widget>[
                  IconButton(
                    key: const Key('editor-top-bar-save'),
                    visualDensity: VisualDensity.compact,
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
                    icon: const Icon(Icons.save_outlined, size: _barIconSize),
                  ),
                  if (canDelete)
                    IconButton(
                      key: const Key('editor-top-bar-delete'),
                      visualDensity: VisualDensity.compact,
                      tooltip: l10n.editorTooltipDelete,
                      onPressed: saving ? null : onDelete,
                      style: IconButton.styleFrom(
                        foregroundColor: deleteButtonColor,
                      ),
                      icon: const Icon(Icons.delete_outline, size: _barIconSize),
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

class EditorActionToolbar extends StatelessWidget {
  const EditorActionToolbar({
    super.key,
    required this.saving,
    required this.onPickDate,
    required this.onPickTime,
    required this.onEditTags,
    required this.onPickImage,
    required this.onPickFile,
    required this.onInsertCheckbox,
  });

  final bool saving;
  final VoidCallback? onPickDate;
  final VoidCallback? onPickTime;
  final VoidCallback? onEditTags;
  final VoidCallback? onPickImage;
  final VoidCallback? onPickFile;
  final VoidCallback? onInsertCheckbox;

  static const double _toolbarHeight = 30;
  static const double _toolbarIconSize = 18;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;

    return Column(
      key: const Key('editor-action-toolbar'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          height: _toolbarHeight,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _ToolbarIconButton(
                  tooltip: l10n.editorTooltipDate,
                  onPressed: saving ? null : onPickDate,
                  icon: Icons.calendar_today_outlined,
                ),
                _ToolbarIconButton(
                  tooltip: l10n.editorTooltipTime,
                  onPressed: saving ? null : onPickTime,
                  icon: Icons.schedule_outlined,
                ),
                _ToolbarIconButton(
                  tooltip: l10n.editorTooltipEditTags,
                  onPressed: saving ? null : onEditTags,
                  icon: Icons.sell_outlined,
                ),
                _ToolbarIconButton(
                  tooltip: l10n.editorTooltipUploadImages,
                  onPressed: saving ? null : onPickImage,
                  icon: Icons.image_outlined,
                ),
                _ToolbarIconButton(
                  tooltip: l10n.editorTooltipAddAttachment,
                  onPressed: saving ? null : onPickFile,
                  icon: Icons.attach_file,
                ),
                _ToolbarIconButton(
                  tooltip: l10n.editorTooltipInsertCheckbox,
                  onPressed: saving ? null : onInsertCheckbox,
                  icon: Icons.check_box_outlined,
                ),
              ],
            ),
          ),
        ),
        Divider(
          height: 1,
          thickness: 1,
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.34),
        ),
      ],
    );
  }
}

class _ToolbarIconButton extends StatelessWidget {
  const _ToolbarIconButton({
    required this.tooltip,
    required this.onPressed,
    required this.icon,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(
        width: 32,
        height: EditorActionToolbar._toolbarHeight,
      ),
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: EditorActionToolbar._toolbarIconSize),
    );
  }
}
