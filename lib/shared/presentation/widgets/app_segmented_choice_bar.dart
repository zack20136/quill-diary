import 'dart:async' show unawaited;

import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/shared/presentation/page_style.dart';

class AppSegmentChoice<T> {
  const AppSegmentChoice({
    required this.value,
    required this.label,
    this.icon,
    this.flex = 2,
    this.enabled = true,
  });

  final T value;
  final String label;
  final IconData? icon;
  final int flex;
  final bool enabled;
}

class AppSegmentedChoiceBar<T> extends StatelessWidget {
  const AppSegmentedChoiceBar({
    required this.choices,
    required this.selected,
    required this.onSelected,
    this.busy = false,
    super.key,
  });

  final List<AppSegmentChoice<T>> choices;
  final T selected;
  final bool busy;
  final Future<void> Function(T value) onSelected;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(PageStyle.radiusPanel),
      child: Row(
        children: <Widget>[
          for (var index = 0; index < choices.length; index++) ...<Widget>[
            if (index > 0)
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: cs.outlineVariant.withValues(alpha: 0.35),
              ),
            Expanded(
              flex: choices[index].flex,
              child: _AppSegment(
                label: choices[index].label,
                icon: choices[index].icon,
                selected: selected == choices[index].value,
                enabled: choices[index].enabled && !busy,
                onTap: choices[index].enabled && !busy
                    ? () => unawaited(onSelected(choices[index].value))
                    : null,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AppSegment extends StatelessWidget {
  const _AppSegment({
    required this.label,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final TextStyle? labelStyle = Theme.of(context).textTheme.labelLarge
        ?.copyWith(
          color: selected
              ? cs.onPrimaryContainer
              : enabled
              ? cs.onSurfaceVariant
              : cs.onSurfaceVariant.withValues(alpha: 0.45),
        );
    return Material(
      color: selected
          ? cs.primaryContainer
          : cs.surfaceContainerHighest.withValues(alpha: enabled ? 0.55 : 0.35),
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(
                  icon,
                  size: 18,
                  color: selected
                      ? cs.onPrimaryContainer
                      : enabled
                      ? cs.onSurfaceVariant
                      : cs.onSurfaceVariant.withValues(alpha: 0.45),
                ),
                const SizedBox(height: 4),
              ],
              Text(
                label,
                style: labelStyle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                softWrap: true,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
