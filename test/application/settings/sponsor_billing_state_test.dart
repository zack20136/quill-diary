import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:quill_diary/application/settings/sponsor_billing_state.dart';

void main() {
  group('SponsorBillingState', () {
    test('isPurchaseBusy 只在 buying 與 pending 為 true', () {
      expect(
        const SponsorBillingState(
          purchasePhase: SponsorPurchasePhase.buying,
        ).isPurchaseBusy,
        isTrue,
      );
      expect(
        const SponsorBillingState(
          purchasePhase: SponsorPurchasePhase.pending,
        ).isPurchaseBusy,
        isTrue,
      );
      expect(
        const SponsorBillingState(
          purchasePhase: SponsorPurchasePhase.idle,
        ).isPurchaseBusy,
        isFalse,
      );
    });

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

    test('copyWith 可清除錯誤訊息', () {
      const SponsorBillingState original = SponsorBillingState(
        productLoadError: 'load-error',
        purchaseErrorMessage: 'purchase-error',
      );

      final SponsorBillingState cleared = original.copyWith(
        clearProductLoadError: true,
        clearPurchaseErrorMessage: true,
      );

      expect(cleared.productLoadError, isNull);
      expect(cleared.purchaseErrorMessage, isNull);
    });
  });
}
