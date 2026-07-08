import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import 'package:quill_diary/application/settings/sponsor_billing_state.dart';
import 'package:quill_diary/infrastructure/billing/billing_catalog.dart';

/// Google Play Billing 的 client-side 封裝。
class GoogleBillingService {
  GoogleBillingService({InAppPurchase? inAppPurchase})
    : _inAppPurchase = inAppPurchase ?? InAppPurchase.instance;

  final InAppPurchase _inAppPurchase;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  Future<void>? _initializationFuture;

  void Function(SponsorBillingState state)? onStateChanged;

  SponsorBillingState _state = const SponsorBillingState();
  SponsorBillingState get state => _state;

  void _emit(SponsorBillingState next) {
    _state = next;
    onStateChanged?.call(next);
  }

  /// 初始化 purchase stream 並同步既有購買狀態。
  Future<void> initialize() async {
    await _ensureInitialized();
  }

  Future<void> _ensureInitialized() {
    final Future<void>? inFlight = _initializationFuture;
    if (inFlight != null) {
      return inFlight;
    }

    if (_state.isInitialized &&
        _purchaseSubscription != null &&
        _state.productLoadError == null) {
      return Future<void>.value();
    }

    final Future<void> future = _initialize();
    _initializationFuture = future;
    return future.whenComplete(() {
      if (identical(_initializationFuture, future)) {
        _initializationFuture = null;
      }
    });
  }

  Future<void> _initialize() async {
    final bool retryingInitFailed = _state.productLoadError == 'init_failed';
    if (_state.isInitialized &&
        _purchaseSubscription != null &&
        !retryingInitFailed) {
      return;
    }

    if (retryingInitFailed) {
      await _purchaseSubscription?.cancel();
      _purchaseSubscription = null;
    }

    try {
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
    } catch (error) {
      _emit(
        _state.copyWith(
          isInitialized: true,
          isAvailable: false,
          productLoadError: 'init_failed',
          clearPurchaseErrorMessage: true,
        ),
      );
    }
  }

  void dispose() {
    unawaited(_purchaseSubscription?.cancel());
    _purchaseSubscription = null;
    onStateChanged = null;
  }

  Future<void> loadProducts({bool isRetry = false}) async {
    if (isRetry) {
      _emit(_state.copyWith(isRefreshingProducts: true));
    }

    await _ensureInitialized();
    if (!_state.isAvailable) {
      if (isRetry) {
        _emit(_state.copyWith(isRefreshingProducts: false));
      }
      return;
    }

    if (!isRetry) {
      _emit(
        _state.copyWith(isLoadingProducts: true, clearProductLoadError: true),
      );
    }

    try {
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

      final List<ProductDetails> sorted = _sortProducts(
        response.productDetails,
      );
      _emitProductLoadResult(
        products: sorted,
        notFoundProductIds: response.notFoundIDs.toList(growable: false),
        productLoadError: sorted.isEmpty ? 'no_products' : null,
      );
    } catch (_) {
      _emitProductLoadResult(
        products: const <ProductDetails>[],
        notFoundProductIds: const <String>[],
        productLoadError: 'query_failed',
      );
    }
  }

  Future<bool> buySponsorProduct(ProductDetails product) async {
    await _ensureInitialized();
    if (!_state.isAvailable || _state.isPurchaseBusy) {
      return false;
    }

    _emit(
      _state.copyWith(
        purchasePhase: SponsorPurchasePhase.buying,
        clearPurchaseErrorMessage: true,
      ),
    );

    try {
      final bool started = await _inAppPurchase.buyConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
        autoConsume: false,
      );

      if (!started) {
        _emit(_state.copyWith(purchasePhase: SponsorPurchasePhase.idle));
      }

      return started;
    } catch (error) {
      _emit(
        _state.copyWith(
          purchasePhase: SponsorPurchasePhase.error,
          purchaseErrorMessage: error.toString(),
        ),
      );
      return false;
    }
  }

  void clearPurchaseSuccess() {
    if (_state.purchasePhase != SponsorPurchasePhase.thanks) {
      return;
    }
    _emit(_state.copyWith(purchasePhase: SponsorPurchasePhase.idle));
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
        return;
      case PurchaseStatus.error:
        _emit(
          _state.copyWith(
            purchasePhase: SponsorPurchasePhase.error,
            purchaseErrorMessage: purchase.error?.message ?? 'purchase_error',
          ),
        );
        return;
      case PurchaseStatus.canceled:
        _emit(
          _state.copyWith(
            purchasePhase: SponsorPurchasePhase.idle,
            clearPurchaseErrorMessage: true,
          ),
        );
        return;
      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        await _finalizePurchase(purchase);
        return;
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
