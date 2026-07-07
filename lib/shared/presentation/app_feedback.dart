import 'dart:async';

import 'package:flutter/material.dart';

import 'package:quill_diary/presentation/home/providers/home_bottom_chrome_provider.dart';
import 'package:quill_diary/presentation/home/home_layout.dart';
import 'page_style.dart';

enum AppFeedbackTone { info, warning, error }

class AppFeedbackColors {
  const AppFeedbackColors({required this.background, required this.foreground});

  final Color background;
  final Color foreground;
}

AppFeedbackColors resolveAppFeedbackColors(
  ColorScheme colorScheme,
  AppFeedbackTone tone,
) {
  return switch (tone) {
    AppFeedbackTone.info => AppFeedbackColors(
      background: colorScheme.primaryContainer,
      foreground: colorScheme.onPrimaryContainer,
    ),
    AppFeedbackTone.warning => AppFeedbackColors(
      background: colorScheme.secondaryContainer,
      foreground: colorScheme.onSecondaryContainer,
    ),
    AppFeedbackTone.error => AppFeedbackColors(
      background: colorScheme.errorContainer,
      foreground: colorScheme.onErrorContainer,
    ),
  };
}

IconData defaultAppFeedbackIcon(AppFeedbackTone tone) {
  return switch (tone) {
    AppFeedbackTone.info => Icons.info_outline_rounded,
    AppFeedbackTone.warning => Icons.warning_amber_rounded,
    AppFeedbackTone.error => Icons.error_outline_rounded,
  };
}

/// 內嵌於頁面的持久提示橫幅。
class AppFeedbackBanner extends StatelessWidget {
  const AppFeedbackBanner({
    required this.message,
    this.icon,
    this.tone = AppFeedbackTone.info,
    super.key,
  });

  final String message;
  final IconData? icon;
  final AppFeedbackTone tone;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppFeedbackColors colors = resolveAppFeedbackColors(
      theme.colorScheme,
      tone,
    );
    final IconData resolvedIcon = icon ?? defaultAppFeedbackIcon(tone);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(PageStyle.radiusPanel),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(resolvedIcon, color: colors.foreground, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.foreground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const Duration _kFeedbackToastAnimationDuration = Duration(milliseconds: 250);
const Duration _kFeedbackToastDisplayDuration = Duration(seconds: 4);

/// Root overlay 通知；能蓋過 dialog，取代 Scaffold SnackBar。
final _AppFeedbackOverlayHost _feedbackOverlayHost = _AppFeedbackOverlayHost();

class _AppFeedbackOverlayHost {
  _ActiveFeedbackToast? _active;

  void hideCurrent() {
    final _ActiveFeedbackToast? active = _active;
    if (active == null) {
      return;
    }
    _active = null;
    active.entry.remove();
    active.completeDismiss();
  }

  Future<void> show({
    required BuildContext context,
    required String message,
    required AppFeedbackColors colors,
    required TextStyle? textStyle,
  }) {
    final OverlayState? overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      return Future<void>.value();
    }

    hideCurrent();

    final Completer<void> dismissCompleter = Completer<void>();
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (BuildContext overlayContext) => _AppFeedbackToast(
        message: message,
        backgroundColor: colors.background,
        textStyle: textStyle,
        onDismissed: () {
          if (identical(_active?.entry, entry)) {
            _active = null;
            entry.remove();
          }
          if (!dismissCompleter.isCompleted) {
            dismissCompleter.complete();
          }
        },
      ),
    );

    _active = _ActiveFeedbackToast(
      entry: entry,
      dismissCompleter: dismissCompleter,
    );
    overlay.insert(entry);
    return dismissCompleter.future;
  }
}

class _ActiveFeedbackToast {
  _ActiveFeedbackToast({required this.entry, required this.dismissCompleter});

  final OverlayEntry entry;
  final Completer<void> dismissCompleter;

  void completeDismiss() {
    if (!dismissCompleter.isCompleted) {
      dismissCompleter.complete();
    }
  }
}

class _AppFeedbackToast extends StatefulWidget {
  const _AppFeedbackToast({
    required this.message,
    required this.backgroundColor,
    required this.textStyle,
    required this.onDismissed,
  });

  final String message;
  final Color backgroundColor;
  final TextStyle? textStyle;
  final VoidCallback onDismissed;

  @override
  State<_AppFeedbackToast> createState() => _AppFeedbackToastState();
}

class _AppFeedbackToastState extends State<_AppFeedbackToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _kFeedbackToastAnimationDuration,
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
    reverseCurve: Curves.easeIn,
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 1),
    end: Offset.zero,
  ).animate(_fade);
  bool _dismissed = false;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_controller.forward());
    _dismissTimer = Timer(
      _kFeedbackToastAnimationDuration + _kFeedbackToastDisplayDuration,
      () {
        if (!_dismissed && mounted) {
          unawaited(_dismiss());
        }
      },
    );
  }

  Future<void> _dismiss() async {
    if (_dismissed) {
      return;
    }
    _dismissed = true;
    _dismissTimer?.cancel();
    final VoidCallback notify = widget.onDismissed;
    if (_controller.status != AnimationStatus.dismissed &&
        _controller.status != AnimationStatus.reverse) {
      await _controller.reverse();
    }
    notify();
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    if (!_dismissed) {
      _dismissed = true;
      widget.onDismissed();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: HomeLayout.bodyHorizontal,
      right: HomeLayout.bodyHorizontal,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(
            bottom: HomeLayout.snackBarBottomPadding,
          ),
          child: SlideTransition(
            position: _slide,
            child: FadeTransition(
              opacity: _fade,
              child: Material(
                color: widget.backgroundColor,
                elevation: 6,
                shadowColor: Colors.black26,
                borderRadius: BorderRadius.circular(PageStyle.radiusPanel),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Text(widget.message, style: widget.textStyle),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void showAppFeedbackSnackBar(
  BuildContext context,
  String message, {
  AppFeedbackTone tone = AppFeedbackTone.info,
}) {
  if (!context.mounted) {
    return;
  }
  final ThemeData theme = Theme.of(context);
  final AppFeedbackColors colors = resolveAppFeedbackColors(
    theme.colorScheme,
    tone,
  );
  final HomeBottomChromeSnackBarLift? lift = beginHomeSnackBarLift(context);
  final Future<void> dismissed = _feedbackOverlayHost.show(
    context: context,
    message: message,
    colors: colors,
    textStyle: theme.textTheme.bodyMedium?.copyWith(color: colors.foreground),
  );
  lift?.bind(dismissed);
}
