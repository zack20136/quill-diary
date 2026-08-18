import 'package:flutter/material.dart';

import 'package:quill_diary/l10n/l10n.dart';

abstract final class _EditorChromeMetrics {
  static const double iconSize = 26;
  static const double compactButtonSize = 44;
  static const double toolbarHeight = 44;
  static const double toolbarIconGap = 8;
  static const double wideToolbarBreakpoint = 720;
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
    required this.onInvalidSave,
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
  final VoidCallback? onInvalidSave;
  final VoidCallback? onDelete;
  final VoidCallback? onEnterEditMode;
  final Widget? bottomToolbar;

  @override
  Widget build(BuildContext context) {
    final ThemeData barTheme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final ColorScheme cs = barTheme.colorScheme;

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
                          color: cs.onSurfaceVariant,
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
                      foregroundColor: cs.error,
                      icon: Icons.delete_outline,
                    ),
                ] else ...<Widget>[
                  _EditorChromeIconButton(
                    key: const Key('editor-top-bar-save'),
                    tooltip: canSaveEntry
                        ? l10n.editorTooltipSave
                        : l10n.editorTooltipSaveNeedsEntry,
                    onPressed: saving
                        ? null
                        : canSaveEntry
                        ? onSave
                        : onInvalidSave,
                    foregroundColor: canSaveEntry
                        ? cs.primary
                        : cs.onSurfaceVariant,
                    icon: Icons.save_outlined,
                    iconWidget: saving
                        ? SizedBox.square(
                            key: const Key('editor-top-bar-saving'),
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: cs.primary,
                            ),
                          )
                        : null,
                  ),
                  if (canDelete)
                    _EditorChromeIconButton(
                      key: const Key('editor-top-bar-delete'),
                      tooltip: l10n.editorTooltipDelete,
                      onPressed: saving ? null : onDelete,
                      foregroundColor: cs.error,
                      icon: Icons.delete_outline,
                    ),
                ],
              ],
            ),
            if (bottomToolbar != null) ...<Widget>[
              const SizedBox(height: 4),
              _EditorChromeDivider(
                key: const Key('editor-chrome-toolbar-divider'),
                colorScheme: cs,
              ),
              const SizedBox(height: 4),
              bottomToolbar!,
            ],
            const SizedBox(height: 4),
            _EditorChromeDivider(
              key: const Key('editor-chrome-divider'),
              colorScheme: cs,
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
    final List<_EditorToolbarAction> actions = <_EditorToolbarAction>[
      _EditorToolbarAction(
        keyName: 'date',
        label: l10n.editorTooltipDate,
        icon: Icons.calendar_today_outlined,
        onPressed: onPickDate,
      ),
      _EditorToolbarAction(
        keyName: 'time',
        label: l10n.editorTooltipTime,
        icon: Icons.schedule_outlined,
        onPressed: onPickTime,
      ),
      _EditorToolbarAction(
        keyName: 'tags',
        label: l10n.editorTooltipEditTags,
        icon: Icons.sell_outlined,
        onPressed: onEditTags,
      ),
      _EditorToolbarAction(
        keyName: 'task',
        label: l10n.editorTooltipInsertCheckbox,
        icon: Icons.check_box_outlined,
        onPressed: onInsertCheckbox,
      ),
      _EditorToolbarAction(
        keyName: 'images',
        label: l10n.editorTooltipUploadImages,
        icon: Icons.image_outlined,
        onPressed: onPickImage,
      ),
      _EditorToolbarAction(
        keyName: 'attachment',
        label: l10n.editorTooltipAddAttachment,
        icon: Icons.attach_file,
        onPressed: onPickFile,
      ),
    ];

    return SizedBox(
      key: const Key('editor-action-toolbar'),
      height: _EditorChromeMetrics.toolbarHeight,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          if (constraints.maxWidth >=
              _EditorChromeMetrics.wideToolbarBreakpoint) {
            return Row(
              key: const Key('editor-action-toolbar-wide'),
              children: <Widget>[
                for (final _EditorToolbarAction action in actions)
                  Expanded(
                    child: _EditorChromeLabeledButton(
                      action: action,
                      onPressed: saving ? null : action.onPressed,
                    ),
                  ),
              ],
            );
          }

          final Widget compactRow = Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              for (int index = 0; index < actions.length; index++) ...<Widget>[
                if (index > 0)
                  const SizedBox(width: _EditorChromeMetrics.toolbarIconGap),
                _EditorChromeIconButton(
                  key: Key('editor-toolbar-${actions[index].keyName}'),
                  tooltip: actions[index].label,
                  onPressed: saving ? null : actions[index].onPressed,
                  icon: actions[index].icon,
                ),
              ],
            ],
          );
          final double compactContentWidth =
              actions.length * _EditorChromeMetrics.compactButtonSize +
              (actions.length - 1) * _EditorChromeMetrics.toolbarIconGap;
          final Widget scrollable = SingleChildScrollView(
            key: const Key('editor-action-toolbar-compact'),
            scrollDirection: Axis.horizontal,
            child: compactRow,
          );
          if (constraints.maxWidth >= compactContentWidth) {
            return Align(alignment: Alignment.centerLeft, child: scrollable);
          }
          return ShaderMask(
            shaderCallback: (Rect bounds) => const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: <Color>[Colors.black, Colors.black, Colors.transparent],
              stops: <double>[0, 0.9, 1],
            ).createShader(bounds),
            blendMode: BlendMode.dstIn,
            child: scrollable,
          );
        },
      ),
    );
  }
}

class _EditorToolbarAction {
  const _EditorToolbarAction({
    required this.keyName,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String keyName;
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
}

class _EditorChromeLabeledButton extends StatelessWidget {
  const _EditorChromeLabeledButton({
    required this.action,
    required this.onPressed,
  });

  final _EditorToolbarAction action;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      key: Key('editor-toolbar-${action.keyName}'),
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, _EditorChromeMetrics.toolbarHeight),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Icon(action.icon, size: 21),
      label: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(action.label, maxLines: 1),
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
    this.iconWidget,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final IconData icon;
  final Color? foregroundColor;
  final Widget? iconWidget;

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
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        fixedSize: const Size.square(_EditorChromeMetrics.compactButtonSize),
        minimumSize: const Size.square(_EditorChromeMetrics.compactButtonSize),
        padding: EdgeInsets.zero,
        foregroundColor: resolvedForeground,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: iconWidget ?? Icon(icon, size: _EditorChromeMetrics.iconSize),
    );
  }
}
