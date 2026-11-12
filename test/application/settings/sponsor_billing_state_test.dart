import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:quill_diary/infrastructure/billing/sponsor_billing_state.dart';

void main() {
  group('SponsorBillingState', () {
    test('showsInitialProductLoading 只在初次載入且沒有既有資料時為 true', () {
      expect(
        const SponsorBillingState(
          isInitialized: true,
          isLoadingProducts: true,
        ).showsInitialProductLoading,
        isTrue,
      );

      expect(
        const SponsorBillingState(
          isInitialized: true,
          isLoadingProducts: true,
          productLoadError: 'failed',
        ).showsInitialProductLoading,
        isFalse,
      );

      expect(
        SponsorBillingState(
          isInitialized: true,
          isLoadingProducts: true,
          products: const <ProductDetails>[],
        ).showsInitialProductLoading,
        isTrue,
      );
    });

  });
}
