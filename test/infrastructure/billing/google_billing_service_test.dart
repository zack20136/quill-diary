import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:quill_diary/features/settings/state/sponsor_billing_state.dart';
import 'package:quill_diary/infrastructure/billing/google_billing_service.dart';

import '../../helpers/shared/fake_in_app_purchase_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  GoogleBillingService buildService(FakeInAppPurchase fakeInAppPurchase) {
    return GoogleBillingService(inAppPurchase: fakeInAppPurchase);
  }

  test('購買贊助商品時會關閉自動消耗', () async {
    final FakeInAppPurchaseAndroidPlatformAddition fakeAndroidAddition =
        FakeInAppPurchaseAndroidPlatformAddition();
    final FakeInAppPurchase fakeInAppPurchase = FakeInAppPurchase(
      androidAddition: fakeAndroidAddition,
    );
    final GoogleBillingService service = buildService(fakeInAppPurchase);

    await service.initialize();
    await service.loadProducts();

    final ProductDetails product = service.state.products.first;
    final bool started = await service.buySponsorProduct(product);

    expect(started, isTrue);
    expect(
      fakeInAppPurchase.log.any((MethodCall call) {
        final Object? arguments = call.arguments;
        return call.method == 'buyConsumable' &&
            arguments is Map &&
            arguments['autoConsume'] == false &&
            arguments['purchaseParam'] is PurchaseParam;
      }),
      isTrue,
    );
  });

  test('載入商品查詢錯誤時會清除載入狀態', () async {
    final FakeInAppPurchase fakeInAppPurchase = FakeInAppPurchase(
      queryProductDetailsError: StateError('boom'),
      androidAddition: FakeInAppPurchaseAndroidPlatformAddition(),
    );
    final GoogleBillingService service = buildService(fakeInAppPurchase);

    await service.loadProducts();

    expect(service.state.isLoadingProducts, isFalse);
    expect(service.state.isRefreshingProducts, isFalse);
    expect(service.state.productLoadError, 'query_failed');
    expect(service.state.products, isEmpty);
  });

  test('載入商品在 init_failed 後會重試', () async {
    final FakeInAppPurchaseAndroidPlatformAddition fakeAndroidAddition =
        FakeInAppPurchaseAndroidPlatformAddition();
    final FakeInAppPurchase fakeInAppPurchase = FakeInAppPurchase(
      restorePurchasesErrors: <Object?>[StateError('boom')],
      androidAddition: fakeAndroidAddition,
    );
    final GoogleBillingService service = buildService(fakeInAppPurchase);

    await service.loadProducts();

    expect(service.state.productLoadError, 'init_failed');
    expect(service.state.isAvailable, isFalse);
    expect(service.state.isRefreshingProducts, isFalse);
    expect(
      fakeInAppPurchase.log.where((MethodCall call) {
        return call.method == 'restorePurchases';
      }),
      hasLength(1),
    );

    await service.loadProducts(isRetry: true);

    expect(service.state.productLoadError, isNull);
    expect(service.state.isAvailable, isTrue);
    expect(service.state.isRefreshingProducts, isFalse);
    expect(service.state.products, isNotEmpty);
    expect(
      fakeInAppPurchase.log.where((MethodCall call) {
        return call.method == 'restorePurchases';
      }),
      hasLength(2),
    );
    expect(fakeAndroidAddition.consumePurchaseCalled, isFalse);
  });

  test('購買贊助商品時會捕捉購買錯誤', () async {
    final FakeInAppPurchase fakeInAppPurchase = FakeInAppPurchase(
      buyConsumableError: StateError('boom'),
      androidAddition: FakeInAppPurchaseAndroidPlatformAddition(),
    );
    final GoogleBillingService service = buildService(fakeInAppPurchase);

    await service.initialize();
    await service.loadProducts();

    final ProductDetails product = service.state.products.first;
    final bool started = await service.buySponsorProduct(product);

    expect(started, isFalse);
    expect(service.state.purchasePhase, SponsorPurchasePhase.error);
    expect(service.state.purchaseErrorMessage, contains('boom'));
  });

  test('已購買項目會被消耗、完成並可清除', () async {
    final FakeInAppPurchaseAndroidPlatformAddition fakeAndroidAddition =
        FakeInAppPurchaseAndroidPlatformAddition();
    final FakeInAppPurchase fakeInAppPurchase = FakeInAppPurchase(
      androidAddition: fakeAndroidAddition,
    );
    final GoogleBillingService service = buildService(fakeInAppPurchase);

    await service.initialize();
    await service.loadProducts();

    final ProductDetails product = service.state.products.first;
    await service.buySponsorProduct(product);

    fakeInAppPurchase.emitPurchases(<PurchaseDetails>[
      buildPurchaseDetails(
        productId: product.id,
        status: PurchaseStatus.purchased,
        pendingCompletePurchase: true,
      ),
    ]);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(fakeAndroidAddition.consumePurchaseCalled, isTrue);
    expect(fakeInAppPurchase.completePurchaseCalled, isTrue);
    expect(service.state.purchasePhase, SponsorPurchasePhase.thanks);

    service.clearPurchaseSuccess();
    expect(service.state.purchasePhase, SponsorPurchasePhase.idle);
  });
}
