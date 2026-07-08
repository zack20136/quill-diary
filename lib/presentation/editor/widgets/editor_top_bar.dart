import 'package:flutter/material.dart';

import 'package:quill_diary/l10n/l10n.dart';

abstract final class _EditorChromeMetrics {
  static const double iconSize = 26;
  static const double buttonSize = 40;
  static const double toolbarHeight = 40;
  static const double toolbarIconGap = 8;
  static const EdgeInsets horizontalPadding = EdgeInsets.symmetric(
    horizontal: 4,
  );
}

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
    this.bottomToolbar,
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
  final Widget? bottomToolbar;

  @override
  Widget build(BuildContext context) {
    final ThemeData barTheme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final ColorScheme cs = barTheme.colorScheme;
    final Color saveButtonColor = cs.primary;
    final Color deleteButtonColor = cs.error;
    final bool canSave = !saving && canSaveEntry;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: _EditorChromeMetrics.horizontalPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                _EditorChromeIconButton(
                  key: const Key('editor-top-bar-close'),
                  tooltip: l10n.editorTooltipCancel,
                  onPressed: saving ? null : onClose,
                  icon: Icons.close_rounded,
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
                          fontSize: 15,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
                if (previewMode) ...<Widget>[
                  _EditorChromeIconButton(
                    key: const Key('editor-top-bar-edit'),
                    tooltip: l10n.editorTooltipEdit,
                    onPressed: saving ? null : onEnterEditMode,
                    foregroundColor: cs.primary,
                    icon: Icons.edit_outlined,
                  ),
                  if (canDelete)
                    _EditorChromeIconButton(
                      key: const Key('editor-top-bar-delete'),
                      tooltip: l10n.editorTooltipDelete,
                      onPressed: saving ? null : onDelete,
                      foregroundColor: deleteButtonColor,
                      icon: Icons.delete_outline,
                    ),
                ] else ...<Widget>[
                  _EditorChromeIconButton(
                    key: const Key('editor-top-bar-save'),
                    tooltip: canSave
                        ? l10n.editorTooltipSave
                        : l10n.editorTooltipSaveNeedsEntry,
                    onPressed: saving ? null : onSave,
                    foregroundColor: canSave
                        ? saveButtonColor
                        : cs.onSurfaceVariant.withValues(alpha: 0.45),
                    icon: Icons.save_outlined,
                  ),
                  if (canDelete)
                    _EditorChromeIconButton(
                      key: const Key('editor-top-bar-delete'),
                      tooltip: l10n.editorTooltipDelete,
                      onPressed: saving ? null : onDelete,
                      foregroundColor: deleteButtonColor,
                      icon: Icons.delete_outline,
                    ),
                ],
              ],
            ),
            if (bottomToolbar != null) ...<Widget>[
              const SizedBox(height: 4),
              _EditorChromeDivider(
                key: const Key('editor-chrome-toolbar-divider'),
                colorScheme: barTheme.colorScheme,
              ),
              const SizedBox(height: 4),
              bottomToolbar!,
            ],
            const SizedBox(height: 4),
            _EditorChromeDivider(
              key: const Key('editor-chrome-divider'),
              colorScheme: barTheme.colorScheme,
            ),
          ],
        ),
      ),
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

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return SizedBox(
      key: const Key('editor-action-toolbar'),
      height: _EditorChromeMetrics.toolbarHeight,
      child: Align(
        alignment: Alignment.centerLeft,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              _EditorChromeIconButton(
                tooltip: l10n.editorTooltipDate,
                onPressed: saving ? null : onPickDate,
                icon: Icons.calendar_today_outlined,
              ),
              const SizedBox(width: _EditorChromeMetrics.toolbarIconGap),
              _EditorChromeIconButton(
                tooltip: l10n.editorTooltipTime,
                onPressed: saving ? null : onPickTime,
                icon: Icons.schedule_outlined,
              ),
              const SizedBox(width: _EditorChromeMetrics.toolbarIconGap),
              _EditorChromeIconButton(
                tooltip: l10n.editorTooltipEditTags,
                onPressed: saving ? null : onEditTags,
                icon: Icons.sell_outlined,
              ),
              const SizedBox(width: _EditorChromeMetrics.toolbarIconGap),
              _EditorChromeIconButton(
                tooltip: l10n.editorTooltipInsertCheckbox,
                onPressed: saving ? null : onInsertCheckbox,
                icon: Icons.check_box_outlined,
              ),
              const SizedBox(width: _EditorChromeMetrics.toolbarIconGap),
              _EditorChromeIconButton(
                tooltip: l10n.editorTooltipUploadImages,
                onPressed: saving ? null : onPickImage,
                icon: Icons.image_outlined,
              ),
              const SizedBox(width: _EditorChromeMetrics.toolbarIconGap),
              _EditorChromeIconButton(
                tooltip: l10n.editorTooltipAddAttachment,
                onPressed: saving ? null : onPickFile,
                icon: Icons.attach_file,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditorChromeDivider extends StatelessWidget {
  const _EditorChromeDivider({super.key, required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1.4,
      color: colorScheme.outlineVariant.withValues(alpha: 0.62),
    );
  }
}

class _EditorChromeIconButton extends StatelessWidget {
  const _EditorChromeIconButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    required this.icon,
    this.foregroundColor,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final IconData icon;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool enabled = onPressed != null;
    final Color resolvedForeground =
        foregroundColor ??
        (enabled
            ? cs.onSurfaceVariant
            : cs.onSurfaceVariant.withValues(alpha: 0.38));

    return IconButton(
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        fixedSize: const Size(
          _EditorChromeMetrics.buttonSize,
          _EditorChromeMetrics.buttonSize,
        ),
        foregroundColor: resolvedForeground,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Icon(icon, size: _EditorChromeMetrics.iconSize),
    );
  }
}
