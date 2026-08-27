import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
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
                _HeroChipScroller(
                  controller: _chipScrollController,
                  accentColor: startColor,
                  chips: widget.chips,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 按下即佔用指標，避免外層垂直頁面／TabBarView 同時捲動。
/// 只把水平位移交給 chip 列；垂直分量直接吞掉。
final class _ChipPanGestureRecognizer extends OneSequenceGestureRecognizer {
  _ChipPanGestureRecognizer({
    required this.onUpdate,
    this.onEnd,
    super.debugOwner,
  });

  final void Function(double deltaDx) onUpdate;
  final void Function(double velocityDx)? onEnd;

  VelocityTracker? _velocityTracker;

  @override
  void addPointer(PointerDownEvent event) {
    startTrackingPointer(event.pointer, event.transform);
    _velocityTracker = VelocityTracker.withKind(event.kind);
    _velocityTracker!.addPosition(event.timeStamp, event.localPosition);
    // 立刻接受，外層 Scrollable／TabBarView 不會再收到這次拖曳。
    resolve(GestureDisposition.accepted);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent) {
      _velocityTracker?.addPosition(event.timeStamp, event.localPosition);
      final double dx = event.localDelta.dx;
      if (dx != 0) {
        onUpdate(dx);
      }
      return;
    }
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      final double velocityDx =
          _velocityTracker?.getVelocity().pixelsPerSecond.dx ?? 0;
      stopTrackingPointer(event.pointer);
      onEnd?.call(velocityDx);
      _velocityTracker = null;
    }
  }

  @override
  void acceptGesture(int pointer) {}

  @override
  void rejectGesture(int pointer) {
    stopTrackingPointer(pointer);
    _velocityTracker = null;
  }

  @override
  String get debugDescription => 'chip pan';

  @override
  void didStopTrackingLastPointer(int pointer) {}
}

/// 橫向 chip 列：細指示條 + 主動水平手勢，避免巢狀捲動搶手勢。
class _HeroChipScroller extends StatefulWidget {
  const _HeroChipScroller({
    required this.controller,
    required this.accentColor,
    required this.chips,
  });

  final ScrollController controller;
  final Color accentColor;
  final List<String> chips;

  @override
  State<_HeroChipScroller> createState() => _HeroChipScrollerState();
}

class _HeroChipScrollerState extends State<_HeroChipScroller> {
  static const double _indicatorThickness = 3;
  static const double _indicatorHitExtent = 16;
  static const double _indicatorGap = 6;
  static const double _chipHitPadding = 6;
  static const double _minThumbFraction = 0.18;

  double? _indicatorTrackWidth;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void didUpdateWidget(_HeroChipScroller oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleScroll);
      widget.controller.addListener(_handleScroll);
    }
    if (!listEquals(oldWidget.chips, widget.chips)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleScroll);
    super.dispose();
  }

  void _handleScroll() {
    setState(() {});
  }

  bool get _canScroll {
    if (!widget.controller.hasClients) {
      return false;
    }
    return widget.controller.position.maxScrollExtent > 0;
  }

  void _scrollBy(double deltaDx) {
    if (!widget.controller.hasClients) {
      return;
    }
    final ScrollPosition position = widget.controller.position;
    final double next = (position.pixels - deltaDx).clamp(
      0.0,
      position.maxScrollExtent,
    );
    if (next != position.pixels) {
      widget.controller.jumpTo(next);
    }
  }

  void _scrollToFraction(double fraction) {
    if (!widget.controller.hasClients) {
      return;
    }
    final ScrollPosition position = widget.controller.position;
    final double maxExtent = position.maxScrollExtent;
    if (maxExtent <= 0) {
      return;
    }
    widget.controller.jumpTo(fraction.clamp(0.0, 1.0) * maxExtent);
  }

  void _scrollFromIndicatorLocalDx(double localDx) {
    final double? trackWidth = _indicatorTrackWidth;
    if (trackWidth == null || trackWidth <= 0 || !widget.controller.hasClients) {
      return;
    }
    final ScrollPosition position = widget.controller.position;
    final double maxExtent = position.maxScrollExtent;
    if (maxExtent <= 0) {
      return;
    }
    final double viewport = position.viewportDimension;
    final double content = viewport + maxExtent;
    final double thumbFraction = (viewport / content).clamp(
      _minThumbFraction,
      1.0,
    );
    final double travel = math.max(1.0 - thumbFraction, 0.0001);
    final double thumbCenter = (localDx / trackWidth).clamp(0.0, 1.0);
    final double scrollFraction = ((thumbCenter - thumbFraction / 2) / travel)
        .clamp(0.0, 1.0);
    _scrollToFraction(scrollFraction);
  }

  Map<Type, GestureRecognizerFactory> _chipGestures() {
    return <Type, GestureRecognizerFactory>{
      _ChipPanGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<_ChipPanGestureRecognizer>(
            () => _ChipPanGestureRecognizer(
              debugOwner: this,
              onUpdate: _scrollBy,
              onEnd: (double velocityDx) {
                if (!widget.controller.hasClients) {
                  return;
                }
                if (velocityDx.abs() < 120) {
                  return;
                }
                final ScrollPosition position = widget.controller.position;
                final double target = (position.pixels - velocityDx * 0.12)
                    .clamp(0.0, position.maxScrollExtent);
                widget.controller.animateTo(
                  target,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                );
              },
            ),
            (_ChipPanGestureRecognizer instance) {},
          ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final ScrollController controller = widget.controller;
    final bool canScroll = _canScroll;

    double thumbFraction = 1;
    double thumbOffset = 0;
    if (canScroll) {
      final ScrollPosition position = controller.position;
      final double maxExtent = position.maxScrollExtent;
      final double viewport = position.viewportDimension;
      final double content = viewport + maxExtent;
      thumbFraction = (viewport / content).clamp(_minThumbFraction, 1.0);
      final double travel = 1.0 - thumbFraction;
      thumbOffset = travel <= 0 ? 0 : (position.pixels / maxExtent) * travel;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Listener(
          onPointerSignal: (PointerSignalEvent event) {
            if (event is PointerScrollEvent && canScroll) {
              _scrollBy(-event.scrollDelta.dx - event.scrollDelta.dy);
            }
          },
          child: RawGestureDetector(
            behavior: HitTestBehavior.opaque,
            gestures: canScroll
                ? _chipGestures()
                : const <Type, GestureRecognizerFactory>{},
            child: Padding(
              // 加大垂直命中區，減少「碰到邊緣就捲不動」的感覺。
              padding: const EdgeInsets.symmetric(vertical: _chipHitPadding),
              child: SingleChildScrollView(
                controller: controller,
                scrollDirection: Axis.horizontal,
                // 手勢由按下即佔用的 pan recognizer 接管。
                physics: const NeverScrollableScrollPhysics(),
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
        ),
        SizedBox(
          height: _indicatorHitExtent,
          child: Align(
            alignment: Alignment.center,
            child: canScroll
                ? GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragUpdate: (DragUpdateDetails details) {
                      _scrollFromIndicatorLocalDx(details.localPosition.dx);
                    },
                    onTapDown: (TapDownDetails details) {
                      _scrollFromIndicatorLocalDx(details.localPosition.dx);
                    },
                    child: SizedBox(
                      height: _indicatorHitExtent,
                      width: double.infinity,
                      child: Center(
                        child: SizedBox(
                          height: _indicatorThickness,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: cs.outlineVariant.withValues(alpha: 0.28),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: LayoutBuilder(
                              builder:
                                  (
                                    BuildContext context,
                                    BoxConstraints constraints,
                                  ) {
                                    _indicatorTrackWidth = constraints.maxWidth;
                                    final double trackWidth =
                                        constraints.maxWidth;
                                    final double thumbWidth =
                                        trackWidth * thumbFraction;
                                    return Stack(
                                      children: <Widget>[
                                        Positioned(
                                          left: trackWidth * thumbOffset,
                                          top: 0,
                                          bottom: 0,
                                          width: thumbWidth,
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              color: widget.accentColor
                                                  .withValues(alpha: 0.55),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                : SizedBox(height: _indicatorGap + _indicatorThickness),
          ),
        ),
      ],
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
