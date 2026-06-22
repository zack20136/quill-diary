import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../../l10n/l10n.dart';

const double _kBackToTopVisibilityOffset = 240;
const Duration _kBackToTopScrollDuration = Duration(milliseconds: 240);
const Duration _kBackToTopAnimationDuration = Duration(milliseconds: 180);

class HomeScrollAffordance extends StatefulWidget {
  const HomeScrollAffordance({
    required this.controller,
    required this.child,
    this.backToTopPadding = const EdgeInsets.only(left: 8, bottom: 16),
    super.key,
  });

  final ScrollController controller;
  final Widget child;
  final EdgeInsets backToTopPadding;

  @override
  State<HomeScrollAffordance> createState() => _HomeScrollAffordanceState();
}

class _HomeScrollAffordanceState extends State<HomeScrollAffordance> {
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
    final ColorScheme cs = Theme.of(context).colorScheme;
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
              child: Padding(
                padding: widget.backToTopPadding,
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
                      child: Semantics(
                        button: true,
                        label: context.l10n.homeTooltipBackToTop,
                        child: Tooltip(
                          message: context.l10n.homeTooltipBackToTop,
                          child: Material(
                            color: cs.secondaryContainer,
                            elevation: 3,
                            shadowColor: cs.shadow.withValues(alpha: 0.18),
                            shape: const CircleBorder(),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: _scrollToTop,
                              customBorder: const CircleBorder(),
                              child: SizedBox(
                                width: 44,
                                height: 44,
                                child: Icon(
                                  Icons.keyboard_arrow_up_rounded,
                                  color: cs.onSecondaryContainer,
                                  size: 26,
                                ),
                              ),
                            ),
                          ),
                        ),
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
