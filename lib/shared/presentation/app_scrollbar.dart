import 'dart:async' show unawaited;

import 'package:flutter/material.dart';

/// 主捲動區 scrollbar 共用尺寸（首頁與設定頁一致）。
abstract final class AppScrollbarMetrics {
  static const double thickness = 4;
  static const double radius = 4;

  /// 距右緣極小留白，讓 thumb 貼近邊緣但不完全貼死。
  static const double crossAxisMargin = 0;
  static const double mainAxisMargin = 12;
  static const double minThumbLength = 32;
  static const Duration extentSmoothDuration = Duration(milliseconds: 160);

  static const double nestedThickness = 3;
  static const double nestedRadius = 3;
}

/// 全站主 scrollbar 主題（供 Material 預設與測試對照）。
const ScrollbarThemeData kPrimaryScrollbarTheme = ScrollbarThemeData(
  thumbVisibility: WidgetStatePropertyAll<bool>(true),
  interactive: true,
  thickness: WidgetStatePropertyAll<double>(AppScrollbarMetrics.thickness),
  radius: Radius.circular(AppScrollbarMetrics.radius),
  crossAxisMargin: AppScrollbarMetrics.crossAxisMargin,
  mainAxisMargin: AppScrollbarMetrics.mainAxisMargin,
  minThumbLength: AppScrollbarMetrics.minThumbLength,
);

/// 卡片內嵌套列表：較細，邊距與主 scrollbar 一致。
const ScrollbarThemeData kNestedPanelScrollbarTheme = ScrollbarThemeData(
  thumbVisibility: WidgetStatePropertyAll<bool>(true),
  interactive: true,
  thickness: WidgetStatePropertyAll<double>(
    AppScrollbarMetrics.nestedThickness,
  ),
  radius: Radius.circular(AppScrollbarMetrics.nestedRadius),
  crossAxisMargin: AppScrollbarMetrics.crossAxisMargin,
  mainAxisMargin: AppScrollbarMetrics.mainAxisMargin,
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
    super.key,
  });

  final ScrollController? controller;
  final Widget child;
  final bool nested;

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

  double get _thickness => widget.nested
      ? AppScrollbarMetrics.nestedThickness
      : AppScrollbarMetrics.thickness;

  double get _radius => widget.nested
      ? AppScrollbarMetrics.nestedRadius
      : AppScrollbarMetrics.radius;

  @override
  void initState() {
    super.initState();
    _extentAnimation.addListener(_handleExtentAnimation);
    widget.controller?.addListener(_handleControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _handleControllerChanged(),
    );
  }

  @override
  void didUpdateWidget(AppScrollbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) {
      return;
    }
    oldWidget.controller?.removeListener(_handleControllerChanged);
    widget.controller?.addListener(_handleControllerChanged);
    _handleControllerChanged();
  }

  @override
  void dispose() {
    _extentAnimation.removeListener(_handleExtentAnimation);
    _extentAnimation.dispose();
    widget.controller?.removeListener(_handleControllerChanged);
    super.dispose();
  }

  void _handleExtentAnimation() {
    setState(() {
      _displayedThumbExtent = _lerpDouble(
        _fromThumbExtent,
        _toThumbExtent,
        _extentAnimation.value,
      );
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
    if (notification is ScrollMetricsNotification ||
        notification is ScrollUpdateNotification) {
      _applyMetrics(notification.metrics);
    }
    return false;
  }

  /// ListView 初次 layout 時 [ScrollMetrics.maxScrollExtent] 可能暫時為 0，
  /// 改用已量到的內容總高度避免 thumb 先拉滿整條軌道。
  double _scrollExtent(ScrollMetrics metrics) {
    if (metrics.maxScrollExtent > 0) {
      return metrics.maxScrollExtent;
    }
    final double overflow = metrics.extentTotal - metrics.viewportDimension;
    return overflow > 0 ? overflow : 0;
  }

  void _applyMetrics(ScrollMetrics metrics) {
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

    setState(() => _metrics = metrics);
  }

  double _naturalThumbExtent(ScrollMetrics metrics) {
    final double trackLength =
        metrics.viewportDimension - AppScrollbarMetrics.mainAxisMargin * 2;
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
        metrics.viewportDimension - AppScrollbarMetrics.mainAxisMargin * 2;
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
        AppScrollbarMetrics.mainAxisMargin +
        scrollableTrack * (metrics.pixels / maxScroll);

    return _AppScrollbarGeometry(
      show: true,
      thumbExtent: layoutThumb,
      thumbOffset: thumbOffset,
    );
  }

  void _handleThumbDrag(DragUpdateDetails details) {
    final ScrollController? controller = widget.controller;
    final ScrollMetrics? metrics = _metrics;
    if (controller == null || metrics == null || !controller.hasClients) {
      return;
    }

    final double trackLength =
        metrics.viewportDimension - AppScrollbarMetrics.mainAxisMargin * 2;
    final double maxScroll = _scrollExtent(metrics);
    final double scrollableTrack = trackLength - _displayedThumbExtent;
    if (scrollableTrack <= 0 || maxScroll <= 0) {
      return;
    }

    final double deltaPixels = details.delta.dy / scrollableTrack * maxScroll;
    controller.jumpTo(
      (controller.offset + deltaPixels).clamp(0, metrics.maxScrollExtent),
    );
  }

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

    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.passthrough,
      children: <Widget>[
        scrollable,
        if (geometry.show)
          Positioned(
            top: geometry.thumbOffset,
            right: AppScrollbarMetrics.crossAxisMargin,
            width: _thickness,
            height: _displayedThumbExtent,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onVerticalDragUpdate: _handleThumbDrag,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _thumbColor(context),
                  borderRadius: BorderRadius.circular(_radius),
                ),
              ),
            ),
          ),
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
      padding: EdgeInsets.fromLTRB(
        resolved.left,
        resolved.top,
        resolved.right,
        0,
      ),
      child: AppScrollbar(
        controller: _controller,
        child: ListView(
          controller: _controller,
          padding: EdgeInsets.only(bottom: resolved.bottom),
          children: widget.children,
        ),
      ),
    );
  }
}

class NestedPanelScrollbar extends StatelessWidget {
  const NestedPanelScrollbar({
    required this.controller,
    required this.child,
    this.contentPadding,
    super.key,
  });

  final ScrollController controller;
  final Widget child;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    return AppScrollbar(
      controller: controller,
      nested: true,
      child: SingleChildScrollView(
        controller: controller,
        padding: contentPadding,
        child: child,
      ),
    );
  }
}
