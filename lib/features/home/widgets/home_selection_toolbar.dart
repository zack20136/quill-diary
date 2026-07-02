import 'package:flutter/material.dart';
import '../../../l10n/l10n.dart';

import '../../../app/app_colors.dart';
import 'home_pin_glyph.dart';

const double kHomeSearchRowControlHeight = 46;
const double kHomeToolbarActionCircleSize = 34;

/// 首頁時間軸與標籤面板共用的膠囊形搜尋欄。
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
    final OutlineInputBorder capsuleBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(kHomeSearchRowControlHeight / 2),
      borderSide: BorderSide(color: context.appColors.outlineMuted),
    );

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
        fillColor: context.appColors.sectionCard,
        border: capsuleBorder,
        enabledBorder: capsuleBorder,
        focusedBorder: capsuleBorder,
        errorBorder: capsuleBorder,
        focusedErrorBorder: capsuleBorder,
        disabledBorder: capsuleBorder,
        contentPadding: const EdgeInsets.only(right: 14),
      ),
      onTapOutside: (_) => FocusScope.of(context).unfocus(),
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
    this.allPinned = false,
    this.onTogglePin,
    this.pinToggleEnabled = false,
  });

  final int selectedCount;
  final bool allSelected;
  final VoidCallback onCancel;
  final VoidCallback onSelectAll;
  final List<HomeSelectionAction> actions;
  final bool allPinned;
  final VoidCallback? onTogglePin;
  final bool pinToggleEnabled;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final Color fillColor = context.appColors.sectionCard;

    return SizedBox(
      height: kHomeSearchRowControlHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(kHomeSearchRowControlHeight / 2),
          border: Border.all(color: context.appColors.outlineMuted),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 6, 0),
          child: Row(
            children: <Widget>[
              _ToolbarPlainIconButton(
                tooltip: context.l10n.homeTooltipDeselectTag,
                onPressed: onCancel,
                icon: Icons.close_rounded,
              ),
              Expanded(
                child: Text(
                  selectedCount > 0
                      ? context.l10n.homeSelectionSelectedCount(selectedCount)
                      : context.l10n.homeSelectionSelectDiary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: selectedCount > 0
                        ? cs.onSurface
                        : cs.onSurfaceVariant,
                  ),
                ),
              ),
              HomeCircleIconButton(
                tooltip: allSelected
                    ? context.l10n.homeSelectionDeselectAll
                    : context.l10n.homeSelectionSelectAll,
                onPressed: onSelectAll,
                icon: allSelected
                    ? Icons.check_box_outline_blank_rounded
                    : Icons.check_box_rounded,
                size: kHomeToolbarActionCircleSize,
                backgroundColor: cs.primaryContainer,
                foregroundColor: cs.onPrimaryContainer,
              ),
              if (onTogglePin != null) ...<Widget>[
                const SizedBox(width: 6),
                HomeCircleIconButton(
                  tooltip: allPinned
                      ? context.l10n.homeTooltipUnpin
                      : context.l10n.homeTooltipPin,
                  onPressed: pinToggleEnabled ? onTogglePin : null,
                  icon: allPinned
                      ? Icons.push_pin_outlined
                      : Icons.push_pin_rounded,
                  iconWidget: HomePinGlyph(
                    icon: allPinned
                        ? Icons.push_pin_outlined
                        : Icons.push_pin_rounded,
                    size: kHomeToolbarActionCircleSize * 0.5,
                    color: pinToggleEnabled
                        ? cs.onSecondaryContainer
                        : cs.onSurfaceVariant.withValues(alpha: 0.38),
                  ),
                  size: kHomeToolbarActionCircleSize,
                  backgroundColor: cs.secondaryContainer,
                  foregroundColor: cs.onSecondaryContainer,
                  disabledBackgroundColor: cs.surfaceContainerHighest,
                  disabledForegroundColor: cs.onSurfaceVariant.withValues(
                    alpha: 0.38,
                  ),
                ),
              ],
              for (final HomeSelectionAction action in actions) ...<Widget>[
                const SizedBox(width: 6),
                HomeCircleIconButton(
                  tooltip: action.tooltip,
                  onPressed: action.enabled ? action.onPressed : null,
                  icon: action.icon,
                  size: kHomeToolbarActionCircleSize,
                  backgroundColor: action.destructive
                      ? cs.errorContainer
                      : cs.secondaryContainer,
                  foregroundColor: action.destructive
                      ? cs.error
                      : cs.onSecondaryContainer,
                  disabledBackgroundColor: cs.surfaceContainerHighest,
                  disabledForegroundColor: cs.onSurfaceVariant.withValues(
                    alpha: 0.38,
                  ),
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
    this.iconWidget,
  });

  final String tooltip;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback? onPressed;
  final double size;
  final Color? disabledBackgroundColor;
  final Color? disabledForegroundColor;
  final Widget? iconWidget;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color bg = enabled
        ? backgroundColor
        : (disabledBackgroundColor ?? cs.surfaceContainerHighest);
    final Color fg = enabled
        ? foregroundColor
        : (disabledForegroundColor ??
              cs.onSurfaceVariant.withValues(alpha: 0.45));

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
            child: iconWidget ??
                Icon(icon, size: size * 0.5, color: fg),
          ),
        ),
      ),
    );
  }
}

/// 與首頁搜尋 [TextField] 高度對齊的圓形切換按鈕。
class HomeSearchSelectionToggleButton extends StatelessWidget {
  const HomeSearchSelectionToggleButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return HomeCircleIconButton(
      tooltip: context.l10n.homeSelectionSelectDiary,
      onPressed: onPressed,
      icon: Icons.checklist_rounded,
      size: kHomeSearchRowControlHeight,
      backgroundColor: cs.primaryContainer,
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
      title: Text(context.l10n.commonConfirmDeleteTitle),
      content: Text(context.l10n.commonConfirmDeleteEntries(count)),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(context.l10n.commonActionCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(dialogContext).colorScheme.error,
          ),
          child: Text(context.l10n.commonActionDelete),
        ),
      ],
    ),
  );
}
