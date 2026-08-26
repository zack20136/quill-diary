import 'package:flutter/material.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_shell.dart';
import 'package:quill_diary/l10n/l10n.dart';

import 'package:quill_diary/app/app_colors.dart';
import 'home_pin_glyph.dart';

const double kHomeSearchRowControlHeight = 46;
const double kHomeToolbarActionCircleSize = 44;
const double kHomeTabWideBreakpoint = 600;

class HomeSearchTextField extends StatelessWidget {
  const HomeSearchTextField({
    super.key,
    required this.hintText,
    this.controller,
    this.onChanged,
    this.enabled = true,
    this.semanticLabel,
  });

  final String hintText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final OutlineInputBorder capsuleBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(kHomeSearchRowControlHeight / 2),
      borderSide: BorderSide(color: context.appColors.outlineMuted),
    );
    final OutlineInputBorder focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(kHomeSearchRowControlHeight / 2),
      borderSide: BorderSide(color: cs.primary, width: 1.5),
    );

    return Semantics(
      label: semanticLabel ?? hintText,
      textField: true,
      child: TextField(
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
          focusedBorder: focusedBorder,
          errorBorder: capsuleBorder,
          focusedErrorBorder: focusedBorder,
          disabledBorder: capsuleBorder,
          contentPadding: const EdgeInsets.only(right: 14),
        ),
        onTapOutside: (_) => FocusScope.of(context).unfocus(),
        onChanged: onChanged,
      ),
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
    this.iconWidget,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool destructive;
  final bool enabled;
  final Widget? iconWidget;
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
        key: const Key('home-selection-status-capsule'),
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(kHomeSearchRowControlHeight / 2),
          border: Border.all(color: context.appColors.outlineMuted),
        ),
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
            _SelectionToolbarActionButton(
              tooltip: allSelected
                  ? context.l10n.homeSelectionDeselectAll
                  : context.l10n.homeSelectionSelectAll,
              onPressed: onSelectAll,
              icon: allSelected
                  ? Icons.check_box_outline_blank_rounded
                  : Icons.check_box_rounded,
            ),
            if (onTogglePin != null)
              _SelectionToolbarActionButton(
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
                  size: 22,
                  color: pinToggleEnabled
                      ? cs.onSurfaceVariant
                      : cs.onSurfaceVariant.withValues(alpha: 0.38),
                ),
              ),
            for (final HomeSelectionAction action in actions)
              _SelectionToolbarActionButton(
                tooltip: action.tooltip,
                onPressed: action.enabled ? action.onPressed : null,
                icon: action.icon,
                iconWidget: action.iconWidget,
                destructive: action.destructive,
              ),
            const SizedBox(width: 4),
          ],
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
      style: IconButton.styleFrom(
        minimumSize: const Size(44, 44),
        maximumSize: const Size(44, 44),
        tapTargetSize: MaterialTapTargetSize.padded,
        visualDensity: VisualDensity.standard,
        padding: EdgeInsets.zero,
      ),
      icon: Icon(icon, size: 22, color: cs.onSurfaceVariant),
    );
  }
}

/// 選取工具列右側輕量動作：無色塊圓底，觸控區仍 ≥ 44。
class _SelectionToolbarActionButton extends StatelessWidget {
  const _SelectionToolbarActionButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.destructive = false,
    this.iconWidget,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool destructive;
  final Widget? iconWidget;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool enabled = onPressed != null;
    final Color color = !enabled
        ? cs.onSurfaceVariant.withValues(alpha: 0.38)
        : destructive
        ? cs.error
        : cs.onSurfaceVariant;

    return IconButton(
      key: Key('home-selection-action-$tooltip'),
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        minimumSize: const Size(44, 44),
        maximumSize: const Size(44, 44),
        tapTargetSize: MaterialTapTargetSize.padded,
        visualDensity: VisualDensity.standard,
        padding: EdgeInsets.zero,
        foregroundColor: color,
      ),
      icon: iconWidget ?? Icon(icon, size: 22, color: color),
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

    return Semantics(
      button: true,
      enabled: enabled,
      label: tooltip,
      child: Tooltip(
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
              child: iconWidget ?? Icon(icon, size: size * 0.5, color: fg),
            ),
          ),
        ),
      ),
    );
  }
}

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
  return showAppConfirmDialog(
    context: context,
    title: context.l10n.commonConfirmDeleteTitle,
    content: Text(context.l10n.commonConfirmDeleteEntries(count)),
    cancelLabel: context.l10n.commonActionCancel,
    confirmLabel: context.l10n.commonActionDelete,
    confirmStyle: AppConfirmStyle.destructive,
  );
}
