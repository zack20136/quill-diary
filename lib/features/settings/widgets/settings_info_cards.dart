import 'package:flutter/material.dart';

import '../../../shared/presentation/page_style.dart';

class SettingsGradientHeroCard extends StatelessWidget {
  const SettingsGradientHeroCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.chips = const <String>[],
    this.accentColor,
    this.startAlpha = 0.12,
    this.endAlpha = 0.10,
  });

  final IconData icon;
  final String title;
  final String body;
  final List<String> chips;
  final Color? accentColor;
  final double startAlpha;
  final double endAlpha;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final Color startColor = accentColor ?? cs.primary;
    final Color endColor = accentColor != null ? cs.primary : cs.tertiary;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(PageStyle.radiusCard),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color.alphaBlend(
              startColor.withValues(alpha: startAlpha),
              cs.surface,
            ),
            Color.alphaBlend(
              endColor.withValues(alpha: endAlpha),
              cs.surfaceContainerLow,
            ),
          ],
        ),
        border: Border.fromBorderSide(PageStyle.outlineSide(cs)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: startColor, size: 30),
            const SizedBox(height: 14),
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              body,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            if (chips.isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: chips
                    .map((String label) => _FactChip(label: label))
                    .toList(growable: false),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class SettingsTitleBodyCard extends StatelessWidget {
  const SettingsTitleBodyCard({
    super.key,
    required this.title,
    required this.body,
    this.titleStyle,
  });

  final String title;
  final String body;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(PageStyle.radiusCard),
        border: Border.fromBorderSide(PageStyle.outlineSide(cs)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style:
                  titleStyle ??
                  theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FactChip extends StatelessWidget {
  const _FactChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(999),
        border: Border.fromBorderSide(PageStyle.outlineSide(cs, opacity: 0.24)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
