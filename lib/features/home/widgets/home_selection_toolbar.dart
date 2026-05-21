import 'package:flutter/material.dart';

import '../../../shared/presentation/page_style.dart';

const double kHomeSearchRowControlHeight = 46;
const double kHomeToolbarActionCircleSize = 34;

/// Pill-shaped search field shared by home timeline and tags panes.
class HomeSearchTextField extends StatelessWidget {
  const HomeSearchTextField({
    super.key,
    required this.hintText,
    this.controller,
    this.onChanged,
    this.enabled = true,
  });

  final String hintText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return TextField(
      controller: controller,
      enabled: enabled,
      style: theme.textTheme.bodyMedium,
      textAlignVertical: TextAlignVertical.center,
      decoration: InputDecoration(
        isDense: true,
        hintText: hintText,
        hintStyle: theme.textTheme.bodyMedium?.copyWith(
          color: cs.onSurfaceVariant.withValues(alpha: 0.72),
        ),
        prefixIcon: Icon(
          Icons.search_rounded,
          size: 20,
          color: cs.primary.withValues(alpha: 0.85),
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 40,
          maxWidth: 40,
          minHeight: kHomeSearchRowControlHeight,
          maxHeight: kHomeSearchRowControlHeight,
        ),
        constraints: const BoxConstraints(
          minHeight: kHomeSearchRowControlHeight,
          maxHeight: kHomeSearchRowControlHeight,
        ),
        filled: true,
        fillColor: Color.alphaBlend(
          cs.tertiary.withValues(alpha: 0.05),
          cs.surfaceContainerLowest,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kHomeSearchRowControlHeight / 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kHomeSearchRowControlHeight / 2),
          borderSide: BorderSide(color: PageStyle.primaryMutedOutline(cs)),
        ),
        contentPadding: const EdgeInsets.only(right: 14),
      ),
      onChanged: onChanged,
    );
  }
}

class HomeSelectionAction {
  const HomeSelectionAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.destructive = false,
    this.enabled = true,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool destructive;
  final bool enabled;
}

class HomeSelectionToolbar extends StatelessWidget {
  const HomeSelectionToolbar({
    super.key,
    required this.selectedCount,
    required this.allSelected,
    required this.onCancel,
    required this.onSelectAll,
    required this.actions,
  });

  final int selectedCount;
  final bool allSelected;
  final VoidCallback onCancel;
  final VoidCallback onSelectAll;
  final List<HomeSelectionAction> actions;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final Color fillColor = Color.alphaBlend(
      cs.tertiary.withValues(alpha: 0.05),
      cs.surfaceContainerLowest,
    );

    return SizedBox(
      height: kHomeSearchRowControlHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(kHomeSearchRowControlHeight / 2),
          border: Border.all(color: PageStyle.primaryMutedOutline(cs)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 6, 0),
          child: Row(
            children: <Widget>[
              _ToolbarPlainIconButton(
                tooltip: '取消選取',
                onPressed: onCancel,
                icon: Icons.close_rounded,
              ),
              Expanded(
                child: Text(
                  selectedCount > 0 ? '已選 $selectedCount 項' : '選取日記',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: selectedCount > 0 ? cs.onSurface : cs.onSurfaceVariant,
                  ),
                ),
              ),
              HomeCircleIconButton(
                tooltip: allSelected ? '取消全選' : '全選',
                onPressed: onSelectAll,
                icon: allSelected
                    ? Icons.check_box_outline_blank_rounded
                    : Icons.check_box_rounded,
                size: kHomeToolbarActionCircleSize,
                backgroundColor: Color.alphaBlend(
                  cs.primaryContainer.withValues(alpha: 0.82),
                  cs.surface,
                ),
                foregroundColor: cs.onPrimaryContainer,
              ),
              for (final HomeSelectionAction action in actions) ...<Widget>[
                const SizedBox(width: 6),
                HomeCircleIconButton(
                  tooltip: action.tooltip,
                  onPressed: action.enabled ? action.onPressed : null,
                  icon: action.icon,
                  size: kHomeToolbarActionCircleSize,
                  backgroundColor: action.destructive
                      ? cs.errorContainer
                      : Color.alphaBlend(cs.secondaryContainer.withValues(alpha: 0.65), cs.surface),
                  foregroundColor:
                      action.destructive ? cs.onErrorContainer : cs.onSecondaryContainer,
                  disabledBackgroundColor:
                      Color.alphaBlend(cs.errorContainer.withValues(alpha: 0.35), cs.surface),
                  disabledForegroundColor: cs.onSurfaceVariant.withValues(alpha: 0.38),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolbarPlainIconButton extends StatelessWidget {
  const _ToolbarPlainIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      icon: Icon(icon, size: 22, color: cs.onSurfaceVariant),
    );
  }
}

class HomeCircleIconButton extends StatelessWidget {
  const HomeCircleIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    this.onPressed,
    this.size = kHomeToolbarActionCircleSize,
    this.disabledBackgroundColor,
    this.disabledForegroundColor,
  });

  final String tooltip;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback? onPressed;
  final double size;
  final Color? disabledBackgroundColor;
  final Color? disabledForegroundColor;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color bg = enabled
        ? backgroundColor
        : (disabledBackgroundColor ?? cs.surfaceContainerHighest);
    final Color fg = enabled
        ? foregroundColor
        : (disabledForegroundColor ?? cs.onSurfaceVariant.withValues(alpha: 0.45));

    return Tooltip(
      message: tooltip,
      child: Material(
        color: bg,
        shape: CircleBorder(
          side: enabled
              ? BorderSide(color: fg.withValues(alpha: 0.14))
              : BorderSide(color: cs.outlineVariant.withValues(alpha: 0.35)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, size: size * 0.5, color: fg),
          ),
        ),
      ),
    );
  }
}

/// Circular toggle aligned with the home search [TextField] height.
class HomeSearchSelectionToggleButton extends StatelessWidget {
  const HomeSearchSelectionToggleButton({
    super.key,
    required this.onPressed,
  });

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return HomeCircleIconButton(
      tooltip: '選取日記',
      onPressed: onPressed,
      icon: Icons.checklist_rounded,
      size: kHomeSearchRowControlHeight,
      backgroundColor: Color.alphaBlend(
        cs.primaryContainer.withValues(alpha: 0.78),
        cs.surfaceContainerLow,
      ),
      foregroundColor: cs.onPrimaryContainer,
      disabledBackgroundColor: cs.surfaceContainerHighest,
      disabledForegroundColor: cs.onSurfaceVariant.withValues(alpha: 0.4),
    );
  }
}

Future<bool?> confirmDeleteHomeEntries(BuildContext context, int count) {
  return showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      title: const Text('確認刪除'),
      content: Text('確定要刪除 $count 篇日記嗎？刪除後無法復原。'),
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
}
