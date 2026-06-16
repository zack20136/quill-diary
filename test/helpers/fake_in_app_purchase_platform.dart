import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class FakeInAppPurchasePlatform extends Fake
    with MockPlatformInterfaceMixin
    implements InAppPurchasePlatform {
  FakeInAppPurchasePlatform({this.available = true});

  final bool available;
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
    return true;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completePurchaseCalled = true;
    log.add(const MethodCall('completePurchase'));
  }

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {
    log.add(const MethodCall('restorePurchases'));
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
