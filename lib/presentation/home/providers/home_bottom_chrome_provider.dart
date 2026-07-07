import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final homeBottomChromeSnackBarCountProvider =
    NotifierProvider<HomeBottomChromeSnackBarCount, int>(
      HomeBottomChromeSnackBarCount.new,
    );

bool homeBottomChromeLifted(WidgetRef ref) {
  return ref.watch(homeBottomChromeSnackBarCountProvider) > 0;
}

class HomeBottomChromeSnackBarCount extends Notifier<int> {
  @override
  int build() => 0;

  void register() => state++;

  void unregister() {
    if (!ref.mounted) {
      return;
    }
    if (state > 0) {
      state--;
    }
  }

  void reset() => state = 0;
}

HomeBottomChromeSnackBarLift? beginHomeSnackBarLift(BuildContext context) {
  final ProviderContainer container;
  try {
    container = ProviderScope.containerOf(context);
  } catch (_) {
    return null;
  }
  final HomeBottomChromeSnackBarCount notifier = container.read(
    homeBottomChromeSnackBarCountProvider.notifier,
  );
  notifier.register();
  return HomeBottomChromeSnackBarLift._(notifier);
}

class HomeBottomChromeSnackBarLift {
  HomeBottomChromeSnackBarLift._(this._notifier);

  final HomeBottomChromeSnackBarCount _notifier;
  bool _released = false;

  void bind(Future<void> whenDismissed) {
    unawaited(whenDismissed.whenComplete(_release));
  }

  void _release() {
    if (_released) {
      return;
    }
    _released = true;
    _notifier.unregister();
  }
}
