import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../home_layout.dart';
import '../providers/home_bottom_chrome_provider.dart';
import 'home_circle_action_button.dart';

const double _kBackToTopVisibilityOffset = 240;
const Duration _kBackToTopScrollDuration = Duration(milliseconds: 240);
const Duration _kBackToTopAnimationDuration = Duration(milliseconds: 180);

class HomeScrollAffordance extends ConsumerStatefulWidget {
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
  ConsumerState<HomeScrollAffordance> createState() =>
      _HomeScrollAffordanceState();
}

class _HomeScrollAffordanceState extends ConsumerState<HomeScrollAffordance> {
  bool _showBackToTop = false;
  bool _attachCheckScheduled = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleScrollChanged);
  }

  @override
  void didUpdateWidget(HomeScrollAffordance oldWidget) {
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

    final bool shouldShow =
        widget.controller.offset > _kBackToTopVisibilityOffset;
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
    final bool hasScrollPosition = widget.controller.hasClients;
    if (!hasScrollPosition) {
      _scheduleAttachmentCheck();
    }
    final TargetPlatform platform = Theme.of(context).platform;
    final bool desktopLike = switch (platform) {
      TargetPlatform.macOS ||
      TargetPlatform.linux ||
      TargetPlatform.windows => true,
      _ => kIsWeb,
    };
    final bool snackBarLifted = homeBottomChromeLifted(ref);
    final double backToTopBottom = HomeLayout.bottomActionsInsetFor(
      snackBarVisible: snackBarLifted,
    );
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: Scrollbar(
            controller: widget.controller,
            thumbVisibility: hasScrollPosition && desktopLike,
            interactive: hasScrollPosition && desktopLike,
            child: widget.child,
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !_showBackToTop,
            child: SafeArea(
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
                    duration: _kBackToTopAnimationDuration,
                    curve: Curves.easeOut,
                    offset: _showBackToTop
                        ? Offset.zero
                        : const Offset(0, 0.2),
                    child: AnimatedOpacity(
                      duration: _kBackToTopAnimationDuration,
                      curve: Curves.easeOut,
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
        ),
      ],
    );
  }

  void _scheduleAttachmentCheck() {
    if (_attachCheckScheduled) {
      return;
    }
    _attachCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _attachCheckScheduled = false;
      if (!mounted || !widget.controller.hasClients) {
        return;
      }
      setState(() {});
    });
  }
}
