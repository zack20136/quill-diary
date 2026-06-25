import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class FakeInAppPurchaseAndroidPlatformAddition extends Fake
    with MockPlatformInterfaceMixin
    implements InAppPurchaseAndroidPlatformAddition {
  FakeInAppPurchaseAndroidPlatformAddition({this.consumeError});

  final Object? consumeError;
  bool consumePurchaseCalled = false;
  final List<PurchaseDetails> consumedPurchases = <PurchaseDetails>[];

  @override
  Future<BillingResultWrapper> consumePurchase(PurchaseDetails purchase) async {
    consumePurchaseCalled = true;
    consumedPurchases.add(purchase);
    if (consumeError != null) {
      throw consumeError!;
    }
    return const BillingResultWrapper(responseCode: BillingResponse.ok);
  }
}

class FakeInAppPurchase extends Fake
    with MockPlatformInterfaceMixin
    implements InAppPurchase {
  FakeInAppPurchase({
    this.available = true,
    this.queryProductDetailsError,
    this.buyConsumableError,
    List<Object?>? restorePurchasesErrors,
    this.androidAddition,
  }) : restorePurchasesErrors = restorePurchasesErrors ?? <Object?>[];

  final bool available;
  final Object? queryProductDetailsError;
  final Object? buyConsumableError;
  final List<Object?> restorePurchasesErrors;
  final FakeInAppPurchaseAndroidPlatformAddition? androidAddition;

  final StreamController<List<PurchaseDetails>> purchaseController =
      StreamController<List<PurchaseDetails>>.broadcast();

  final List<MethodCall> log = <MethodCall>[];
  bool completePurchaseCalled = false;

  @override
  Future<bool> isAvailable() async {
    log.add(const MethodCall('isAvailable'));
    return available;
  }

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => purchaseController.stream;

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async {
    log.add(MethodCall('queryProductDetails', identifiers.toList()));
    if (queryProductDetailsError != null) {
      throw queryProductDetailsError!;
    }
    final List<ProductDetails> products = identifiers
        .map(
          (String id) => ProductDetails(
            id: id,
            title: 'title-$id',
            description: 'desc-$id',
            price: r'$1.00',
            rawPrice: 1,
            currencyCode: 'USD',
          ),
        )
        .toList(growable: false);
    return ProductDetailsResponse(
      productDetails: products,
      notFoundIDs: <String>[],
    );
  }

  @override
  Future<bool> buyConsumable({
    required PurchaseParam purchaseParam,
    bool autoConsume = true,
  }) async {
    log.add(
      MethodCall('buyConsumable', <String, Object?>{
        'purchaseParam': purchaseParam,
        'autoConsume': autoConsume,
      }),
    );
    if (buyConsumableError != null) {
      throw buyConsumableError!;
    }
    return true;
  }

  @override
  Future<bool> buyNonConsumable({
    required PurchaseParam purchaseParam,
  }) async {
    log.add(MethodCall('buyNonConsumable', <String, Object?>{
      'purchaseParam': purchaseParam,
    }));
    return false;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completePurchaseCalled = true;
    log.add(const MethodCall('completePurchase'));
  }

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {
    log.add(const MethodCall('restorePurchases'));
    if (restorePurchasesErrors.isNotEmpty) {
      final Object? error = restorePurchasesErrors.removeAt(0);
      if (error != null) {
        throw error;
      }
    }
  }

  @override
  Future<String> countryCode() async {
    return 'TW';
  }

  @override
  T getPlatformAddition<T extends InAppPurchasePlatformAddition?>() {
    final FakeInAppPurchaseAndroidPlatformAddition? addition = androidAddition;
    if (addition == null) {
      throw StateError('androidAddition is not set');
    }
    return addition as T;
  }

  void emitPurchases(List<PurchaseDetails> purchases) {
    purchaseController.add(purchases);
  }

  Future<void> close() => purchaseController.close();
}

PurchaseDetails buildPurchaseDetails({
  required String productId,
  required PurchaseStatus status,
  bool pendingCompletePurchase = false,
  String? errorMessage,
}) {
  final PurchaseDetails purchase = PurchaseDetails(
    productID: productId,
    purchaseID: 'order-1',
    verificationData: PurchaseVerificationData(
      localVerificationData: 'local',
      serverVerificationData: 'server-token',
      source: 'google_play',
    ),
    transactionDate: '2026-06-11',
    status: status,
  );
  purchase.pendingCompletePurchase = pendingCompletePurchase;
  if (errorMessage != null) {
    purchase.error = IAPError(
      source: 'google_play',
      code: 'error',
      message: errorMessage,
    );
  }
  return purchase;
}
