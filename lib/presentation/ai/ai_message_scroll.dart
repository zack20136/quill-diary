import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/presentation/app_scrollbar.dart';

class AiMessageScroll extends StatefulWidget {
  const AiMessageScroll({required this.builder, this.gutterWidth, super.key});

  final Widget Function(ScrollController controller) builder;
  final double? gutterWidth;

  @override
  State<AiMessageScroll> createState() => AiMessageScrollState();
}

class AiMessageScrollState extends State<AiMessageScroll> {
  final _controller = ScrollController();
  bool _followingLatest = true;
  bool _scrollingByHand = false;
  bool _scrollingWithKeyboard = false;
  bool _draggingThumb = false;
  bool _followScheduled = false;

  bool get _userScrolling =>
      _scrollingByHand || _scrollingWithKeyboard || _draggingThumb;

  late final _keyboardScrollAction = _MessageKeyboardScrollAction(
    _controller,
    () => _scrollingWithKeyboard = true,
  );

  @override
  void initState() {
    super.initState();
    _controller.addListener(_scrollChanged);
    _scheduleFollow();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setFollowingLatest(bool follow) {
    if (follow != _followingLatest) setState(() => _followingLatest = follow);
  }

  void _scrollChanged() {
    if (_userScrolling) _updateFollowingFromPosition();
  }

  void _updateFollowingFromPosition() {
    if (!_controller.hasClients) return;
    final extentAfter = _controller.position.extentAfter;
    final keyboardOnly =
        _scrollingWithKeyboard && !_scrollingByHand && !_draggingThumb;
    _setFollowingLatest(keyboardOnly ? extentAfter == 0 : extentAfter < 80);
  }

  void _scheduleFollow() {
    if (!_followingLatest || _userScrolling || _followScheduled) return;
    _followScheduled = true;
    final binding = WidgetsBinding.instance;
    binding.addPostFrameCallback((_) {
      _followScheduled = false;
      if (mounted &&
          _followingLatest &&
          !_userScrolling &&
          _controller.hasClients &&
          _controller.position.extentAfter > 0) {
        _controller.jumpTo(_controller.position.maxScrollExtent);
      }
    });
    binding.ensureVisualUpdate();
  }

  void followLatest() {
    _setFollowingLatest(true);
    _scheduleFollow();
  }

  Future<void> _jumpToLatest() async {
    if (!_controller.hasClients) return;
    _setFollowingLatest(true);
    await _controller.animateTo(
      _controller.position.maxScrollExtent,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
    if (mounted) _scheduleFollow();
  }

  void _finishUserScroll() {
    _updateFollowingFromPosition();
    _scheduleFollow();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(
        child: NotificationListener<ScrollMetricsNotification>(
          onNotification: (notification) {
            if (notification.depth == 0) _scheduleFollow();
            return false;
          },
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.depth != 0) return false;
              if (notification is UserScrollNotification) {
                _scrollingByHand =
                    notification.direction != ScrollDirection.idle;
                if (!_userScrolling) _finishUserScroll();
              } else if (notification is ScrollEndNotification &&
                  _scrollingWithKeyboard) {
                _updateFollowingFromPosition();
                _scrollingWithKeyboard = false;
                _scheduleFollow();
              }
              return false;
            },
            child: Actions(
              actions: {ScrollIntent: _keyboardScrollAction},
              child: AppScrollbar(
                controller: _controller,
                placement: widget.gutterWidth == null
                    ? AppScrollbarPlacement.overlay
                    : AppScrollbarPlacement.gutter,
                gutterWidth: widget.gutterWidth,
                onThumbDragChanged: (dragging) {
                  _draggingThumb = dragging;
                  if (!_userScrolling) _finishUserScroll();
                },
                child: widget.builder(_controller),
              ),
            ),
          ),
        ),
      ),
      if (!_followingLatest)
        Positioned(
          left: 0,
          right: widget.gutterWidth ?? 0,
          bottom: 8,
          child: Center(
            child: IconButton.filledTonal(
              onPressed: _jumpToLatest,
              tooltip: context.l10n.chatDiaryJumpLatest,
              icon: const Icon(Icons.arrow_downward),
            ),
          ),
        ),
    ],
  );
}

class _MessageKeyboardScrollAction extends ScrollAction {
  _MessageKeyboardScrollAction(this.controller, this.onScrollStarted);

  final ScrollController controller;
  final VoidCallback onScrollStarted;

  @override
  void invoke(ScrollIntent intent, [BuildContext? context]) {
    super.invoke(intent, context);
    final scrollable = context == null ? null : Scrollable.maybeOf(context);
    if (scrollable != null &&
        controller.hasClients &&
        identical(scrollable.position, controller.position) &&
        scrollable.position.isScrollingNotifier.value) {
      onScrollStarted();
    }
  }
}
