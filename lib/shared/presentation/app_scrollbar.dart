import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

import 'package:quill_diary/shared/presentation/page_style.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_shell.dart';

abstract final class AppScrollbarMetrics {
  static const double thickness = 6;
  static const double radius = 5;
  static const double crossAxisMargin = 0;

  static const double homeCrossAxisEdgeInset = 4;
  static const double settingsCrossAxisEdgeInset = 5;

  static const double minHitTargetWidth = 12;
  static const double mainAxisMarginStart = 12;
  static const double mainAxisMarginEnd = 32;

  static const double frameMainAxisInset = 12;

  static const double nestedMainAxisMarginStart = 6;
  static const double nestedMainAxisMarginEnd = 8;
  static const double minThumbLength = 32;

  static const double nestedThickness = 5;
}

/// 瀏覽用直向捲動：拉過盡頭再彈回。內容比畫面短時也拉得動。
const ScrollPhysics appBouncingScrollPhysics = BouncingScrollPhysics(
  parent: AlwaysScrollableScrollPhysics(),
);

const ScrollbarThemeData kPrimaryScrollbarTheme = ScrollbarThemeData(
  thumbVisibility: WidgetStatePropertyAll<bool>(true),
  interactive: true,
  thickness: WidgetStatePropertyAll<double>(AppScrollbarMetrics.thickness),
  radius: Radius.circular(AppScrollbarMetrics.radius),
  crossAxisMargin: AppScrollbarMetrics.crossAxisMargin,
  mainAxisMargin: AppScrollbarMetrics.mainAxisMarginEnd,
  minThumbLength: AppScrollbarMetrics.minThumbLength,
);

class _AppScrollbarGeometry {
  const _AppScrollbarGeometry({
    required this.thumbExtent,
    required this.thumbOffset,
    required this.pixelsPerTrackPixel,
  });

  final double thumbExtent;
  final double thumbOffset;
  final double pixelsPerTrackPixel;
}

enum AppScrollbarTrack { viewport, frame }

enum AppScrollbarPlacement { overlay, gutter, trailingColumn, nestedPanel }

class AppScrollbar extends StatefulWidget {
  const AppScrollbar({
    required this.child,
    required this.controller,
    this.placement = AppScrollbarPlacement.overlay,
    this.track = AppScrollbarTrack.viewport,
    this.onThumbDragChanged,
    this.crossAxisEdgeInset = AppScrollbarMetrics.homeCrossAxisEdgeInset,
    this.gutterWidth,
    super.key,
  }) : assert(gutterWidth == null || placement == AppScrollbarPlacement.gutter);

  final ScrollController controller;
  final ValueChanged<bool>? onThumbDragChanged;
  final Widget child;
  final AppScrollbarPlacement placement;
  final AppScrollbarTrack track;
  final double crossAxisEdgeInset;

  final double? gutterWidth;

  @override
  State<AppScrollbar> createState() => _AppScrollbarState();
}

class _AppScrollbarState extends State<AppScrollbar> {
  ScrollHoldController? _outerScrollHold;
  ScrollPosition? _dragPosition;

  bool get _isNested => widget.placement == AppScrollbarPlacement.nestedPanel;

  double get _edgeInset => _isNested ? 0 : widget.crossAxisEdgeInset;

  double get _gutterWidth =>
      widget.gutterWidth ?? AppScrollbarMetrics.minHitTargetWidth + _edgeInset;

  ScrollPosition? get _position {
    final positions = widget.controller.positions;
    if (positions.length != 1) return null;
    final position = positions.single;
    return position.hasContentDimensions ? position : null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _position != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _endThumbDrag(notify: false);
    super.dispose();
  }

  ({double start, double end}) _trackInsets(bool inDialog) {
    if (inDialog &&
        widget.placement == AppScrollbarPlacement.gutter &&
        _gutterWidth > 0) {
      return (start: 0, end: 0);
    }
    if (widget.track == AppScrollbarTrack.frame) {
      const inset = AppScrollbarMetrics.frameMainAxisInset;
      return (start: inset, end: inset);
    }
    if (_isNested) {
      return (
        start: AppScrollbarMetrics.nestedMainAxisMarginStart,
        end: AppScrollbarMetrics.nestedMainAxisMarginEnd,
      );
    }
    return (
      start: AppScrollbarMetrics.mainAxisMarginStart,
      end:
          AppScrollbarMetrics.mainAxisMarginEnd -
          (inDialog ? AppDialogInsets.content.bottom : 0),
    );
  }

  _AppScrollbarGeometry? _geometry(
    ScrollPosition position,
    double frameHeight,
    bool inDialog,
  ) {
    final insets = _trackInsets(inDialog);
    final height = widget.track == AppScrollbarTrack.frame
        ? frameHeight
        : position.viewportDimension;
    final trackExtent = height - insets.start - insets.end;
    final scrollExtent = position.maxScrollExtent - position.minScrollExtent;
    if (trackExtent <= AppScrollbarMetrics.minThumbLength ||
        !scrollExtent.isFinite ||
        scrollExtent <= 0 ||
        position.viewportDimension <= 0) {
      return null;
    }

    final fractionVisible =
        position.viewportDimension /
        (scrollExtent + position.viewportDimension);
    final thumbExtent = (trackExtent * fractionVisible).clamp(
      AppScrollbarMetrics.minThumbLength,
      trackExtent,
    );
    final travel = trackExtent - thumbExtent;
    if (travel <= 0) return null;
    final progress =
        ((position.pixels - position.minScrollExtent) / scrollExtent).clamp(
          0.0,
          1.0,
        );
    final reversed = position.axisDirection == AxisDirection.up;
    return _AppScrollbarGeometry(
      thumbExtent: thumbExtent,
      thumbOffset: insets.start + travel * (reversed ? 1 - progress : progress),
      pixelsPerTrackPixel: (reversed ? -scrollExtent : scrollExtent) / travel,
    );
  }

  void _startThumbDrag(ScrollPosition position) {
    _dragPosition = position;
    final onDrag = widget.onThumbDragChanged;
    if (onDrag != null) {
      onDrag(true);
    } else {
      _outerScrollHold = Scrollable.maybeOf(context)?.position.hold(() {});
    }
  }

  void _endThumbDrag({bool notify = true}) {
    if (_dragPosition == null) return;
    _dragPosition = null;
    _outerScrollHold?.cancel();
    _outerScrollHold = null;
    if (notify) widget.onThumbDragChanged?.call(false);
  }

  void _dragThumb(double delta, _AppScrollbarGeometry geometry) {
    final position = _dragPosition;
    if (position == null || !identical(position, _position)) return;
    position.jumpTo(
      (position.pixels + delta * geometry.pixelsPerTrackPixel).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
    );
  }

  Widget _buildThumbLayer(bool inDialog) {
    return LayoutBuilder(
      builder: (context, constraints) => ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final position = _position;
          final geometry = position == null
              ? null
              : _geometry(position, constraints.maxHeight, inDialog);
          final dragPosition = _dragPosition;
          if (dragPosition != null &&
              (geometry == null || !identical(position, dragPosition))) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && identical(_dragPosition, dragPosition)) {
                _endThumbDrag();
              }
            });
          }
          if (position == null || geometry == null) {
            return const SizedBox.shrink();
          }
          final thickness = _isNested
              ? AppScrollbarMetrics.nestedThickness
              : AppScrollbarMetrics.thickness;
          const hitWidth = AppScrollbarMetrics.minHitTargetWidth;
          final gutterWidth = widget.gutterWidth;
          final rightInset = switch (gutterWidth) {
            final width? => ((width - hitWidth) / 2).clamp(0.0, width),
            null => _edgeInset,
          };
          final theme = Theme.of(context);
          final color =
              theme.scrollbarTheme.thumbColor?.resolve({}) ??
              theme.colorScheme.onSurface.withValues(
                alpha: _isNested ? 0.30 : 0.35,
              );
          return Stack(
            children: [
              Positioned(
                top: geometry.thumbOffset,
                right: rightInset,
                width: hitWidth,
                height: geometry.thumbExtent,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  dragStartBehavior: DragStartBehavior.down,
                  onVerticalDragStart: (_) => _startThumbDrag(position),
                  onVerticalDragUpdate: (details) =>
                      _dragThumb(details.delta.dy, geometry),
                  onVerticalDragEnd: (_) => _endThumbDrag(),
                  onVerticalDragCancel: _endThumbDrag,
                  child: Align(
                    alignment: gutterWidth == null
                        ? Alignment.centerRight
                        : Alignment.center,
                    child: SizedBox(
                      key: const ValueKey<String>('app-scrollbar-thumb'),
                      width: thickness,
                      height: geometry.thumbExtent,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(
                            AppScrollbarMetrics.radius,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inDialog =
        context.dependOnInheritedWidgetOfExactType<AppDialogScope>() != null;
    final scrollable = NotificationListener<ScrollMetricsNotification>(
      onNotification: (notification) {
        if (notification.depth == 0 &&
            notification.metrics.axis == Axis.vertical) {
          setState(() {});
        }
        return false;
      },
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: widget.child,
      ),
    );
    final thumb = _buildThumbLayer(inDialog);
    switch (widget.placement) {
      case AppScrollbarPlacement.trailingColumn:
      case AppScrollbarPlacement.nestedPanel:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: scrollable),
            SizedBox(width: _gutterWidth, child: thumb),
          ],
        );
      case AppScrollbarPlacement.overlay:
      case AppScrollbarPlacement.gutter:
        return Stack(
          fit: StackFit.passthrough,
          children: [
            if (widget.placement == AppScrollbarPlacement.gutter &&
                _gutterWidth > 0)
              Padding(
                padding: EdgeInsets.only(right: _gutterWidth),
                child: scrollable,
              )
            else
              scrollable,
            Positioned.fill(child: thumb),
          ],
        );
    }
  }
}

class AppScrollablePageBody extends StatefulWidget {
  const AppScrollablePageBody({
    this.padding = const EdgeInsets.fromLTRB(
      PageStyle.pageHorizontalPadding,
      PageStyle.pageTopPadding,
      PageStyle.pageHorizontalPadding,
      PageStyle.pageBottomPadding,
    ),
    required this.children,
    this.controller,
    super.key,
  });

  final EdgeInsetsGeometry padding;
  final List<Widget> children;
  final ScrollController? controller;

  @override
  State<AppScrollablePageBody> createState() => _AppScrollablePageBodyState();
}

class _AppScrollablePageBodyState extends State<AppScrollablePageBody> {
  ScrollController? _ownedController;

  ScrollController get _controller =>
      widget.controller ?? (_ownedController ??= ScrollController());

  @override
  void dispose() {
    _ownedController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final EdgeInsets resolved = widget.padding.resolve(
      Directionality.of(context),
    );

    return SafeArea(
      child: NotificationListener<OverscrollIndicatorNotification>(
        onNotification: (OverscrollIndicatorNotification notification) {
          notification.disallowIndicator();
          return false;
        },
        child: Padding(
          padding: EdgeInsets.only(left: resolved.left, top: resolved.top),
          child: AppScrollbar(
            controller: _controller,
            crossAxisEdgeInset: AppScrollbarMetrics.settingsCrossAxisEdgeInset,
            child: ListView(
              controller: _controller,
              physics: appBouncingScrollPhysics,
              padding: EdgeInsets.only(
                right: resolved.right,
                bottom: resolved.bottom,
              ),
              children: widget.children,
            ),
          ),
        ),
      ),
    );
  }
}

/// 高度受限的對話框、sheet 內容的垂直捲動區：等同 [SingleChildScrollView] 並顯示 [AppScrollbar]。
class AppScrollView extends StatelessWidget {
  const AppScrollView({
    required this.child,
    this.padding,
    this.gutterWidth,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? gutterWidth;

  @override
  Widget build(BuildContext context) {
    return AppScrollableContent(
      gutterWidth: gutterWidth,
      builder: (context, controller) => SingleChildScrollView(
        controller: controller,
        padding: padding,
        child: child,
      ),
    );
  }
}

/// 需要自帶捲動元件（如 [ListView]）時使用：自持 [ScrollController]，外層顯示 [AppScrollbar]。
///
/// [builder] 會收到同一個 controller，交給捲動元件綁定。
class AppScrollableContent extends StatefulWidget {
  const AppScrollableContent({
    required this.builder,
    this.placement = AppScrollbarPlacement.gutter,
    this.gutterWidth,
    super.key,
  });

  final Widget Function(BuildContext context, ScrollController controller)
  builder;
  final AppScrollbarPlacement placement;
  final double? gutterWidth;

  @override
  State<AppScrollableContent> createState() => _AppScrollableContentState();
}

class _AppScrollableContentState extends State<AppScrollableContent> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScrollbar(
      controller: _controller,
      placement: widget.placement,
      gutterWidth: widget.gutterWidth,
      child: widget.builder(context, _controller),
    );
  }
}
