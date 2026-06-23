import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_diary/features/home/providers/home_bottom_chrome_provider.dart';

void main() {
  test('register before hide keeps lift while replacing snackbars', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final HomeBottomChromeSnackBarCount notifier = container.read(
      homeBottomChromeSnackBarCountProvider.notifier,
    );

    notifier.register();
    expect(container.read(homeBottomChromeSnackBarCountProvider), 1);

    notifier.unregister();
    expect(container.read(homeBottomChromeSnackBarCountProvider), 0);

    notifier.register();
    notifier.register();
    notifier.unregister();
    expect(container.read(homeBottomChromeSnackBarCountProvider), 1);

    notifier.reset();
    expect(container.read(homeBottomChromeSnackBarCountProvider), 0);
  });
}
