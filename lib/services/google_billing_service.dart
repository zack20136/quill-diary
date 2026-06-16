import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import '../config/billing_config.dart';
import '../features/settings/state/sponsor_billing_state.dart';

/// Google Play Billing 贊助整合（client-only，無後端驗證）。
class GoogleBillingService {
  GoogleBillingService({InAppPurchase? inAppPurchase})
    : _inAppPurchase = inAppPurchase ?? InAppPurchase.instance;

  final InAppPurchase _inAppPurchase;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  void Function(SponsorBillingState state)? onStateChanged;

  SponsorBillingState _state = const SponsorBillingState();
  SponsorBillingState get state => _state;

  void _emit(SponsorBillingState next) {
    _state = next;
    onStateChanged?.call(next);
  }

  /// 訂閱 [purchaseStream] 並補抓未完成交易。
  Future<void> initialize() async {
    if (_state.isInitialized) {
      return;
    }

    final bool available = await _inAppPurchase.isAvailable();
    _emit(_state.copyWith(isInitialized: true, isAvailable: available));

    if (!available) {
      return;
    }

    await _purchaseSubscription?.cancel();
    _purchaseSubscription = _inAppPurchase.purchaseStream.listen(
      _onPurchaseUpdates,
      onError: (Object error, StackTrace stackTrace) {
        _emit(
          _state.copyWith(
            purchasePhase: SponsorPurchasePhase.error,
            purchaseErrorMessage: error.toString(),
          ),
        );
      },
    );

    await _inAppPurchase.restorePurchases();
  }

  void dispose() {
    unawaited(_purchaseSubscription?.cancel());
    _purchaseSubscription = null;
    onStateChanged = null;
  }

  Future<void> loadProducts({bool isRetry = false}) async {
    if (!_state.isAvailable) {
      return;
    }

    if (isRetry) {
      _emit(_state.copyWith(isRefreshingProducts: true));
    } else {
      _emit(
        _state.copyWith(isLoadingProducts: true, clearProductLoadError: true),
      );
    }

    final ProductDetailsResponse response = await _inAppPurchase
        .queryProductDetails(BillingConfig.sponsorProductIds);

    if (response.error != null) {
      _emitProductLoadResult(
        products: const <ProductDetails>[],
        notFoundProductIds: const <String>[],
        productLoadError: 'query_failed',
      );
      return;
    }

    final List<ProductDetails> sorted = _sortProducts(response.productDetails);
    _emitProductLoadResult(
      products: sorted,
      notFoundProductIds: response.notFoundIDs.toList(growable: false),
      productLoadError: sorted.isEmpty ? 'no_products' : null,
    );
  }

  Future<bool> buySponsorProduct(ProductDetails product) async {
    if (!_state.isAvailable || _state.isPurchaseBusy) {
      return false;
    }

    _emit(
      _state.copyWith(
        purchasePhase: SponsorPurchasePhase.buying,
        clearPurchaseErrorMessage: true,
      ),
    );

    final bool started = await _inAppPurchase.buyConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
    );

    if (!started) {
      _emit(_state.copyWith(purchasePhase: SponsorPurchasePhase.idle));
    }

    return started;
  }

  @visibleForTesting
  void debugSetState(SponsorBillingState state) => _emit(state);

  void _emitProductLoadResult({
    required List<ProductDetails> products,
    required List<String> notFoundProductIds,
    String? productLoadError,
  }) {
    _emit(
      _state.copyWith(
        isLoadingProducts: false,
        isRefreshingProducts: false,
        products: products,
        notFoundProductIds: notFoundProductIds,
        productLoadError: productLoadError,
        clearProductLoadError: productLoadError == null,
      ),
    );
  }

  List<ProductDetails> _sortProducts(List<ProductDetails> products) {
    final Map<String, ProductDetails> byId = <String, ProductDetails>{
      for (final ProductDetails product in products) product.id: product,
    };
    return BillingConfig.sponsorProductIdsOrdered
        .map((String id) => byId[id])
        .whereType<ProductDetails>()
        .toList(growable: false);
  }

  Future<void> _onPurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final PurchaseDetails purchase in purchases) {
      await _handlePurchase(purchase);
    }
  }

  Future<void> _handlePurchase(PurchaseDetails purchase) async {
    switch (purchase.status) {
      case PurchaseStatus.pending:
        _emit(_state.copyWith(purchasePhase: SponsorPurchasePhase.pending));
      case PurchaseStatus.error:
        _emit(
          _state.copyWith(
            purchasePhase: SponsorPurchasePhase.error,
            purchaseErrorMessage: purchase.error?.message ?? 'purchase_error',
          ),
        );
      case PurchaseStatus.canceled:
        _emit(
          _state.copyWith(
            purchasePhase: SponsorPurchasePhase.idle,
            clearPurchaseErrorMessage: true,
          ),
        );
      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        await _finalizePurchase(purchase);
    }
  }

  Future<void> _finalizePurchase(PurchaseDetails purchase) async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final InAppPurchaseAndroidPlatformAddition android = _inAppPurchase
            .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
        await android.consumePurchase(purchase);
      }

      if (purchase.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchase);
      }

      _emit(
        _state.copyWith(
          purchasePhase: SponsorPurchasePhase.thanks,
          clearPurchaseErrorMessage: true,
        ),
      );
    } on Object catch (error) {
      _emit(
        _state.copyWith(
          purchasePhase: SponsorPurchasePhase.error,
          purchaseErrorMessage: error.toString(),
        ),
      );
    }
  }
}
