import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// 全站 scrollbar 尺寸常數。
abstract final class AppScrollbarMetrics {
  static const double thickness = 6;
  static const double radius = 5;
  static const double crossAxisMargin = 0;

  static const double homeCrossAxisEdgeInset = 4;
  static const double settingsCrossAxisEdgeInset = 5;

  /// 嵌套列表右側 gutter；thumb 畫在欄內，避免與內容重疊或被卡片裁切。
  static const double nestedScrollbarGutter = 10;
  static const double nestedCrossAxisEdgeInset = 0;

  static const double minHitTargetWidth = 12;
  static const double mainAxisMarginStart = 12;
  static const double mainAxisMarginEnd = 32;
  static const double nestedMainAxisMarginStart = 6;
  static const double nestedMainAxisMarginEnd = 8;
  static const double minThumbLength = 32;
  static const Duration extentSmoothDuration = Duration(milliseconds: 160);

  static const double nestedThickness = 5;
  static const double nestedRadius = 5;

  /// 掛載後輪詢 layout 的 frame 數（內容非同步變長時 thumb 需重算）。
  static const int initialMetricsSyncFrames = 3;
}

const ScrollbarThemeData kPrimaryScrollbarTheme = ScrollbarThemeData(
  thumbVisibility: WidgetStatePropertyAll<bool>(true),
  interactive: true,
  thickness: WidgetStatePropertyAll<double>(AppScrollbarMetrics.thickness),
  radius: Radius.circular(AppScrollbarMetrics.radius),
  crossAxisMargin: AppScrollbarMetrics.crossAxisMargin,
  mainAxisMargin: AppScrollbarMetrics.mainAxisMarginEnd,
  minThumbLength: AppScrollbarMetrics.minThumbLength,
);

const ScrollbarThemeData kNestedPanelScrollbarTheme = ScrollbarThemeData(
  thumbVisibility: WidgetStatePropertyAll<bool>(true),
  interactive: true,
  thickness: WidgetStatePropertyAll<double>(
    AppScrollbarMetrics.nestedThickness,
  ),
  radius: Radius.circular(AppScrollbarMetrics.nestedRadius),
  crossAxisMargin: AppScrollbarMetrics.crossAxisMargin,
  mainAxisMargin: AppScrollbarMetrics.nestedMainAxisMarginEnd,
  minThumbLength: AppScrollbarMetrics.minThumbLength,
);

class _AppScrollbarGeometry {
  const _AppScrollbarGeometry({
    required this.show,
    required this.thumbExtent,
    required this.thumbOffset,
  });

  final bool show;
  final double thumbExtent;
  final double thumbOffset;
}

class AppScrollbar extends StatefulWidget {
  const AppScrollbar({
    required this.child,
    this.controller,
    this.nested = false,
    this.trailingGutter = false,
    this.onThumbDragChanged,
    this.crossAxisEdgeInset = AppScrollbarMetrics.homeCrossAxisEdgeInset,
    super.key,
  });

  final ScrollController? controller;
  final ValueChanged<bool>? onThumbDragChanged;
  final Widget child;
  final bool nested;
  final bool trailingGutter;
  final double crossAxisEdgeInset;

  @override
  State<AppScrollbar> createState() => _AppScrollbarState();
}

class _AppScrollbarState extends State<AppScrollbar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _extentAnimation = AnimationController(
    vsync: this,
    duration: AppScrollbarMetrics.extentSmoothDuration,
  );

  ScrollMetrics? _metrics;
  double _displayedThumbExtent = AppScrollbarMetrics.minThumbLength;
  double _fromThumbExtent = AppScrollbarMetrics.minThumbLength;
  double _toThumbExtent = AppScrollbarMetrics.minThumbLength;
  int? _activeThumbPointer;
  ScrollHoldController? _scrollHold;
  bool _stateUpdateScheduled = false;
  VoidCallback? _pendingStateUpdate;

  double get _thickness => widget.nested
      ? AppScrollbarMetrics.nestedThickness
      : AppScrollbarMetrics.thickness;

  double get _radius => widget.nested
      ? AppScrollbarMetrics.nestedRadius
      : AppScrollbarMetrics.radius;

  double get _mainAxisMarginStart => widget.nested
      ? AppScrollbarMetrics.nestedMainAxisMarginStart
      : AppScrollbarMetrics.mainAxisMarginStart;

  double get _mainAxisMarginEnd => widget.nested
      ? AppScrollbarMetrics.nestedMainAxisMarginEnd
      : AppScrollbarMetrics.mainAxisMarginEnd;

  @override
  void initState() {
    super.initState();
    _extentAnimation.addListener(_handleExtentAnimation);
    widget.controller?.addListener(_handleControllerChanged);
    _scheduleMetricsSync(
      remainingFrames: AppScrollbarMetrics.initialMetricsSyncFrames,
    );
  }

  void _scheduleMetricsSync({int remainingFrames = 1}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _handleControllerChanged();
      if (remainingFrames > 1) {
        _scheduleMetricsSync(remainingFrames: remainingFrames - 1);
      }
    });
  }

  @override
  void didUpdateWidget(AppScrollbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_handleControllerChanged);
      widget.controller?.addListener(_handleControllerChanged);
    }
    _scheduleMetricsSync();
  }

  @override
  void dispose() {
    _releaseScrollHold();
    _extentAnimation.removeListener(_handleExtentAnimation);
    _extentAnimation.dispose();
    widget.controller?.removeListener(_handleControllerChanged);
    super.dispose();
  }

  void _handleExtentAnimation() {
    final double extent = _lerpDouble(
      _fromThumbExtent,
      _toThumbExtent,
      _extentAnimation.value,
    );
    _scheduleStateUpdate(() => _displayedThumbExtent = extent);
  }

  void _scheduleStateUpdate(VoidCallback update) {
    final VoidCallback? previous = _pendingStateUpdate;
    _pendingStateUpdate = () {
      previous?.call();
      update();
    };
    if (_stateUpdateScheduled) {
      return;
    }
    _stateUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _stateUpdateScheduled = false;
      if (!mounted) {
        _pendingStateUpdate = null;
        return;
      }
      final VoidCallback? pending = _pendingStateUpdate;
      _pendingStateUpdate = null;
      if (pending == null) {
        return;
      }
      setState(pending);
    });
  }

  void _handleControllerChanged() {
    final ScrollController? controller = widget.controller;
    if (controller == null || !controller.hasClients) {
      return;
    }
    _applyMetrics(controller.position);
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0) {
      return false;
    }
    _applyMetrics(notification.metrics);
    return false;
  }

  /// 初次 layout 時 [ScrollMetrics.maxScrollExtent] 可能暫時為 0。
  double _scrollExtent(ScrollMetrics metrics) {
    if (metrics.maxScrollExtent > 0) {
      return metrics.maxScrollExtent;
    }
    final double overflow = metrics.extentTotal - metrics.viewportDimension;
    return overflow > 0 ? overflow : 0;
  }

  void _applyMetrics(ScrollMetrics metrics) {
    if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.idle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _applyMetrics(metrics);
        }
      });
      return;
    }

    final double targetThumbExtent = _naturalThumbExtent(metrics);
    final bool firstValidMetrics = _metrics == null && targetThumbExtent > 0;

    if (firstValidMetrics) {
      _displayedThumbExtent = targetThumbExtent;
      _fromThumbExtent = targetThumbExtent;
      _toThumbExtent = targetThumbExtent;
      _extentAnimation.value = 1;
    } else if ((targetThumbExtent - _toThumbExtent).abs() > 0.5) {
      _fromThumbExtent = _displayedThumbExtent;
      _toThumbExtent = targetThumbExtent;
      unawaited(_extentAnimation.forward(from: 0));
    }

    _scheduleStateUpdate(() => _metrics = metrics);
  }

  double _naturalThumbExtent(ScrollMetrics metrics) {
    final double trackLength =
        metrics.viewportDimension - _mainAxisMarginStart - _mainAxisMarginEnd;
    if (trackLength <= 0) {
      return 0;
    }

    final double maxScroll = _scrollExtent(metrics);
    if (maxScroll <= 0) {
      return 0;
    }

    final double totalExtent = maxScroll + metrics.viewportDimension;
    final double naturalThumb =
        trackLength * (metrics.viewportDimension / totalExtent);
    return naturalThumb.clamp(AppScrollbarMetrics.minThumbLength, trackLength);
  }

  _AppScrollbarGeometry _geometryFor(
    ScrollMetrics metrics,
    double thumbExtent,
  ) {
    final double trackLength =
        metrics.viewportDimension - _mainAxisMarginStart - _mainAxisMarginEnd;
    if (trackLength <= 0) {
      return const _AppScrollbarGeometry(
        show: false,
        thumbExtent: 0,
        thumbOffset: 0,
      );
    }

    final double maxScroll = _scrollExtent(metrics);
    if (maxScroll <= 0 || thumbExtent <= 0) {
      return const _AppScrollbarGeometry(
        show: false,
        thumbExtent: 0,
        thumbOffset: 0,
      );
    }

    final double layoutThumb = thumbExtent.clamp(
      AppScrollbarMetrics.minThumbLength,
      trackLength,
    );
    final double scrollableTrack = trackLength - layoutThumb;
    final double thumbOffset =
        _mainAxisMarginStart +
        scrollableTrack * (metrics.pixels / maxScroll);

    return _AppScrollbarGeometry(
      show: true,
      thumbExtent: layoutThumb,
      thumbOffset: thumbOffset,
    );
  }

  void _scrollByThumbDelta(double deltaDy) {
    final ScrollController? controller = widget.controller;
    final ScrollMetrics? metrics = _metrics;
    if (controller == null || metrics == null || !controller.hasClients) {
      return;
    }

    final double trackLength =
        metrics.viewportDimension - _mainAxisMarginStart - _mainAxisMarginEnd;
    final double maxScroll = _scrollExtent(metrics);
    final double scrollableTrack = trackLength - _displayedThumbExtent;
    if (scrollableTrack <= 0 || maxScroll <= 0) {
      return;
    }

    final double deltaPixels = deltaDy / scrollableTrack * maxScroll;
    controller.jumpTo(
      (controller.offset + deltaPixels).clamp(0, metrics.maxScrollExtent),
    );
  }

  void _acquireScrollHold() {
    _releaseScrollHold();
    final ScrollableState? outer =
        context.findAncestorStateOfType<ScrollableState>();
    if (outer != null) {
      _scrollHold = outer.position.hold(() {});
    }
  }

  void _releaseScrollHold() {
    _scrollHold?.cancel();
    _scrollHold = null;
  }

  void _setThumbDragging(bool dragging) {
    if (widget.onThumbDragChanged != null) {
      widget.onThumbDragChanged!(dragging);
      return;
    }
    if (dragging) {
      _acquireScrollHold();
    } else {
      _releaseScrollHold();
    }
  }

  void _handleOverlayPointerDown(PointerDownEvent event) {
    _activeThumbPointer = event.pointer;
  }

  void _handleOverlayPointerMove(PointerMoveEvent event) {
    if (_activeThumbPointer != event.pointer) {
      return;
    }
    _scrollByThumbDelta(event.delta.dy);
  }

  void _handleOverlayPointerEnd(int pointer) {
    if (_activeThumbPointer != pointer) {
      return;
    }
    _activeThumbPointer = null;
  }

  double get _hitTargetWidth =>
      math.max(_thickness, AppScrollbarMetrics.minHitTargetWidth);

  Color _thumbColor(BuildContext context) {
    final ScrollbarThemeData theme = Theme.of(context).scrollbarTheme;
    final Color? themed = theme.thumbColor?.resolve(<WidgetState>{});
    if (themed != null) {
      return themed;
    }
    return Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: widget.nested ? 0.30 : 0.35);
  }

  Widget _buildThumbVisual(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        width: _thickness,
        height: _displayedThumbExtent,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _thumbColor(context),
            borderRadius: BorderRadius.circular(_radius),
          ),
        ),
      ),
    );
  }

  Widget _buildThumb(BuildContext context, _AppScrollbarGeometry geometry) {
    final Widget thumbVisual = _buildThumbVisual(context);

    final Widget hitTarget = widget.trailingGutter
        ? GestureDetector(
            behavior: HitTestBehavior.opaque,
            dragStartBehavior: DragStartBehavior.down,
            onVerticalDragStart: (_) => _setThumbDragging(true),
            onVerticalDragUpdate: (DragUpdateDetails details) {
              _scrollByThumbDelta(details.delta.dy);
            },
            onVerticalDragEnd: (_) => _setThumbDragging(false),
            onVerticalDragCancel: () => _setThumbDragging(false),
            child: thumbVisual,
          )
        : Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: _handleOverlayPointerDown,
            onPointerMove: _handleOverlayPointerMove,
            onPointerUp: (PointerUpEvent event) =>
                _handleOverlayPointerEnd(event.pointer),
            onPointerCancel: (PointerCancelEvent event) =>
                _handleOverlayPointerEnd(event.pointer),
            child: thumbVisual,
          );

    return Positioned(
      top: geometry.thumbOffset,
      right: widget.crossAxisEdgeInset,
      width: _hitTargetWidth,
      height: _displayedThumbExtent,
      child: hitTarget,
    );
  }

  Widget _buildThumbRail(
    BuildContext context,
    _AppScrollbarGeometry geometry,
  ) {
    return SizedBox(
      width: AppScrollbarMetrics.nestedScrollbarGutter,
      child: geometry.show
          ? Stack(
              clipBehavior: Clip.none,
              children: <Widget>[_buildThumb(context, geometry)],
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ScrollMetrics? metrics = _metrics;
    final _AppScrollbarGeometry geometry = metrics == null
        ? const _AppScrollbarGeometry(
            show: false,
            thumbExtent: 0,
            thumbOffset: 0,
          )
        : _geometryFor(metrics, _displayedThumbExtent);

    final Widget scrollable = NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: widget.child,
    );

    if (widget.trailingGutter) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(child: scrollable),
          _buildThumbRail(context, geometry),
        ],
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.passthrough,
      children: <Widget>[
        scrollable,
        if (geometry.show) _buildThumb(context, geometry),
      ],
    );
  }
}

double _lerpDouble(double from, double to, double t) {
  return from + (to - from) * t;
}

class ListViewWithScrollbar extends StatefulWidget {
  const ListViewWithScrollbar({
    required this.padding,
    required this.children,
    super.key,
  });

  final EdgeInsetsGeometry padding;
  final List<Widget> children;

  @override
  State<ListViewWithScrollbar> createState() => _ListViewWithScrollbarState();
}

class _ListViewWithScrollbarState extends State<ListViewWithScrollbar> {
  late final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final EdgeInsets resolved = widget.padding.resolve(
      Directionality.of(context),
    );

    return Padding(
      padding: EdgeInsets.only(left: resolved.left, top: resolved.top),
      child: AppScrollbar(
        controller: _controller,
        crossAxisEdgeInset: AppScrollbarMetrics.settingsCrossAxisEdgeInset,
        child: ListView(
          controller: _controller,
          padding: EdgeInsets.only(
            right: resolved.right,
            bottom: resolved.bottom,
          ),
          children: widget.children,
        ),
      ),
    );
  }
}

/// 卡片內可捲動面板：內容與 thumb 分列，避免嵌套在外層 [CustomScrollView] 時手勢衝突。
class NestedPanelScrollbar extends StatelessWidget {
  const NestedPanelScrollbar({
    required this.controller,
    required this.child,
    this.contentPadding,
    this.onThumbDragChanged,
    super.key,
  });

  final ScrollController controller;
  final Widget child;
  final EdgeInsetsGeometry? contentPadding;
  final ValueChanged<bool>? onThumbDragChanged;

  @override
  Widget build(BuildContext context) {
    return AppScrollbar(
      controller: controller,
      nested: true,
      trailingGutter: true,
      onThumbDragChanged: onThumbDragChanged,
      crossAxisEdgeInset: AppScrollbarMetrics.nestedCrossAxisEdgeInset,
      child: SingleChildScrollView(
        controller: controller,
        padding: contentPadding,
        child: child,
      ),
    );
  }
}
