import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 全站 SnackBar 顯示中的數量；首頁圓形按鈕在數量大於 0 時上移到通知帶上方。
/// 非 autoDispose，以便從設定等子頁返回首頁時仍能對齊仍顯示中的 SnackBar。
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
    if (state > 0) {
      state--;
    }
  }

  void reset() => state = 0;
}

/// 在顯示 SnackBar 前呼叫；須在 [hideCurrentSnackBar] 之前 register，避免替換時閃爍。
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

  void bind(ScaffoldFeatureController<SnackBar, SnackBarClosedReason> controller) {
    controller.closed.whenComplete(_release);
  }

  void _release() {
    if (_released) {
      return;
    }
    _released = true;
    _notifier.unregister();
  }
}
