import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:quill_diary/config/billing_config.dart';
import 'package:quill_diary/features/settings/state/sponsor_billing_state.dart';
import 'package:quill_diary/services/google_billing_service.dart';

import '../helpers/fake_in_app_purchase_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeInAppPurchasePlatform platform;
  late GoogleBillingService service;
  late List<SponsorBillingState> states;

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
    platform = FakeInAppPurchasePlatform();
    InAppPurchasePlatform.instance = platform;
    service = GoogleBillingService();
    states = <SponsorBillingState>[];
    service.onStateChanged = states.add;
  });

  tearDown(() async {
    service.dispose();
    await platform.close();
    debugDefaultTargetPlatformOverride = null;
  });

  test('initialize 訂閱 purchaseStream 並標記可用', () async {
    await service.initialize();

    expect(states.last.isInitialized, isTrue);
    expect(states.last.isAvailable, isTrue);
    expect(platform.log.map((MethodCall call) => call.method), contains('restorePurchases'));
  });

  test('loadProducts 依 BillingConfig 順序排序商品', () async {
    await service.initialize();
    await service.loadProducts();

    expect(
      service.state.products.map((ProductDetails product) => product.id).toList(),
      BillingConfig.sponsorProductIdsOrdered,
    );
  });

  test('pending 進入付款處理中', () async {
    await service.initialize();
    platform.emitPurchases(<PurchaseDetails>[
      buildPurchaseDetails(
        productId: 'sponsor_coffee',
        status: PurchaseStatus.pending,
      ),
    ]);
    await Future<void>.delayed(Duration.zero);

    expect(service.state.purchasePhase, SponsorPurchasePhase.pending);
  });

  test('error 顯示錯誤', () async {
    await service.initialize();
    platform.emitPurchases(<PurchaseDetails>[
      buildPurchaseDetails(
        productId: 'sponsor_coffee',
        status: PurchaseStatus.error,
        errorMessage: 'card_declined',
      ),
    ]);
    await Future<void>.delayed(Duration.zero);

    expect(service.state.purchasePhase, SponsorPurchasePhase.error);
    expect(service.state.purchaseErrorMessage, 'card_declined');
  });

  test('canceled 不進入感謝狀態', () async {
    await service.initialize();
    platform.emitPurchases(<PurchaseDetails>[
      buildPurchaseDetails(
        productId: 'sponsor_coffee',
        status: PurchaseStatus.canceled,
      ),
    ]);
    await Future<void>.delayed(Duration.zero);

    expect(service.state.purchasePhase, SponsorPurchasePhase.idle);
  });

  test('purchased 顯示感謝並 completePurchase', () async {
    await service.initialize();
    platform.emitPurchases(<PurchaseDetails>[
      buildPurchaseDetails(
        productId: 'sponsor_coffee',
        status: PurchaseStatus.purchased,
        pendingCompletePurchase: true,
      ),
    ]);
    await Future<void>.delayed(Duration.zero);

    expect(service.state.purchasePhase, SponsorPurchasePhase.thanks);
    expect(platform.completePurchaseCalled, isTrue);
  });
}
