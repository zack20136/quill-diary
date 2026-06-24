import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/presentation/app_scrollbar.dart';
import '../home_layout.dart';
import '../providers/home_bottom_chrome_provider.dart';
import 'home_circle_action_button.dart';

const double _kBackToTopShowOffset = 160;
const double _kBackToTopHideOffset = 72;
const Duration _kBackToTopScrollDuration = Duration(milliseconds: 240);
const Duration _kBackToTopEnterDuration = Duration(milliseconds: 260);
const Duration _kBackToTopExitDuration = Duration(milliseconds: 180);

class HomeScrollAffordance extends StatelessWidget {
  const HomeScrollAffordance({
    required this.controller,
    required this.child,
    this.backToTopLeftPadding = HomeLayout.circleActionSideInset,
    super.key,
  });

  final ScrollController controller;
  final Widget child;
  final double backToTopLeftPadding;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Positioned.fill(
          child: AppScrollbar(
            controller: controller,
            child: child,
          ),
        ),
        _HomeBackToTopOverlay(
          controller: controller,
          backToTopLeftPadding: backToTopLeftPadding,
        ),
      ],
    );
  }
}

class _HomeBackToTopOverlay extends ConsumerStatefulWidget {
  const _HomeBackToTopOverlay({
    required this.controller,
    required this.backToTopLeftPadding,
  });

  final ScrollController controller;
  final double backToTopLeftPadding;

  @override
  ConsumerState<_HomeBackToTopOverlay> createState() =>
      _HomeBackToTopOverlayState();
}

class _HomeBackToTopOverlayState extends ConsumerState<_HomeBackToTopOverlay> {
  bool _showBackToTop = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleScrollChanged);
  }

  @override
  void didUpdateWidget(_HomeBackToTopOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) {
      return;
    }
    oldWidget.controller.removeListener(_handleScrollChanged);
    widget.controller.addListener(_handleScrollChanged);
    _handleScrollChanged();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleScrollChanged);
    super.dispose();
  }

  void _handleScrollChanged() {
    if (!widget.controller.hasClients) {
      if (_showBackToTop) {
        setState(() => _showBackToTop = false);
      }
      return;
    }

    final double offset = widget.controller.offset;
    final bool shouldShow = _showBackToTop
        ? offset > _kBackToTopHideOffset
        : offset > _kBackToTopShowOffset;
    if (shouldShow == _showBackToTop) {
      return;
    }
    setState(() => _showBackToTop = shouldShow);
  }

  Future<void> _scrollToTop() async {
    if (!widget.controller.hasClients) {
      return;
    }
    await widget.controller.animateTo(
      0,
      duration: _kBackToTopScrollDuration,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool snackBarLifted = homeBottomChromeLifted(ref);
    final double backToTopBottom = HomeLayout.bottomActionsInsetFor(
      snackBarVisible: snackBarLifted,
    );
    final Duration backToTopAnimDuration = _showBackToTop
        ? _kBackToTopEnterDuration
        : _kBackToTopExitDuration;
    final Curve backToTopAnimCurve = _showBackToTop
        ? Curves.easeOutCubic
        : Curves.easeInCubic;

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !_showBackToTop,
        child: AnimatedPadding(
          duration: HomeLayout.bottomChromeAnimationDuration,
          curve: HomeLayout.bottomChromeAnimationCurve,
          padding: EdgeInsets.only(
            left: widget.backToTopLeftPadding,
            bottom: backToTopBottom,
          ),
          child: Align(
            alignment: Alignment.bottomLeft,
            child: AnimatedSlide(
              duration: backToTopAnimDuration,
              curve: backToTopAnimCurve,
              offset: _showBackToTop ? Offset.zero : const Offset(0, 0.45),
              child: AnimatedScale(
                duration: backToTopAnimDuration,
                curve: backToTopAnimCurve,
                scale: _showBackToTop ? 1 : 0.72,
                alignment: Alignment.bottomLeft,
                child: AnimatedOpacity(
                  duration: backToTopAnimDuration,
                  curve: backToTopAnimCurve,
                  opacity: _showBackToTop ? 1 : 0,
                  child: HomeCircleActionButton(
                    tooltip: context.l10n.homeTooltipBackToTop,
                    icon: Icons.keyboard_arrow_up_rounded,
                    onPressed: _scrollToTop,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
