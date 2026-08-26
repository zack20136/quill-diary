import 'package:flutter/material.dart';

import 'package:quill_diary/app/app_colors.dart';
import 'package:quill_diary/shared/presentation/page_style.dart';

class SettingsGradientHeroCard extends StatefulWidget {
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
  State<SettingsGradientHeroCard> createState() =>
      _SettingsGradientHeroCardState();
}

class _SettingsGradientHeroCardState extends State<SettingsGradientHeroCard> {
  final ScrollController _chipScrollController = ScrollController();

  @override
  void dispose() {
    _chipScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final AppColors colors = context.appColors;
    final Color startColor = widget.accentColor ?? cs.primary;
    final Color endColor = widget.accentColor != null
        ? cs.primary
        : cs.tertiary;
    // 以 surfaceContainerLow 為底再疊 primary，避免與頁面底色幾乎同色、看起來像沒背景。
    final double resolvedStartAlpha = widget.accentColor == null
        ? 0.18
        : widget.startAlpha.clamp(0.14, 1.0);
    final double resolvedEndAlpha = widget.accentColor == null
        ? 0.10
        : widget.endAlpha.clamp(0.08, 1.0);
    final List<Color> gradientColors = <Color>[
      Color.alphaBlend(
        startColor.withValues(alpha: resolvedStartAlpha),
        cs.surfaceContainerLow,
      ),
      Color.alphaBlend(
        endColor.withValues(alpha: resolvedEndAlpha),
        cs.surface,
      ),
    ];

    return Material(
      color: cs.surfaceContainerLow,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PageStyle.radiusCard),
        side: colors.outlineBorder(opacity: 0.2),
      ),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color.alphaBlend(
                        startColor.withValues(alpha: 0.16),
                        cs.surface.withValues(alpha: 0.9),
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(widget.icon, color: startColor, size: 22),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.28,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                widget.body,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.55,
                ),
              ),
              if (widget.chips.isNotEmpty) ...<Widget>[
                const SizedBox(height: 18),
                ScrollbarTheme(
                  data: ScrollbarTheme.of(context).copyWith(
                    thumbVisibility: const WidgetStatePropertyAll<bool>(true),
                    trackVisibility: const WidgetStatePropertyAll<bool>(true),
                    thickness: const WidgetStatePropertyAll<double>(4),
                    radius: const Radius.circular(999),
                    crossAxisMargin: 0,
                    mainAxisMargin: 0,
                    interactive: true,
                  ),
                  child: Scrollbar(
                    controller: _chipScrollController,
                    thumbVisibility: true,
                    trackVisibility: true,
                    interactive: true,
                    child: SingleChildScrollView(
                      controller: _chipScrollController,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: <Widget>[
                          for (
                            int index = 0;
                            index < widget.chips.length;
                            index++
                          ) ...<Widget>[
                            if (index > 0) const SizedBox(width: 8),
                            _FactChip(label: widget.chips[index]),
                          ],
                        ],
                      ),
                    ),
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

class _FactChip extends StatelessWidget {
  const _FactChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final AppColors colors = context.appColors;

    // 用實心 surface，避免跟 Hero 淡藍底混成一塊。
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.fromBorderSide(colors.outlineBorder(opacity: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: cs.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
