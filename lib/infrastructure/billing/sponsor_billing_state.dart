import 'package:in_app_purchase/in_app_purchase.dart';

enum SponsorPurchasePhase { idle, buying, pending, error, thanks }

class SponsorBillingState {
  const SponsorBillingState({
    this.isInitialized = false,
    this.isAvailable = false,
    this.isLoadingProducts = false,
    this.isRefreshingProducts = false,
    this.products = const <ProductDetails>[],
    this.productLoadError,
    this.notFoundProductIds = const <String>[],
    this.purchasePhase = SponsorPurchasePhase.idle,
    this.purchaseErrorMessage,
  });

  final bool isInitialized;
  final bool isAvailable;
  final bool isLoadingProducts;
  final bool isRefreshingProducts;
  final List<ProductDetails> products;
  final String? productLoadError;
  final List<String> notFoundProductIds;
  final SponsorPurchasePhase purchasePhase;
  final String? purchaseErrorMessage;

  bool get isPurchaseBusy =>
      purchasePhase == SponsorPurchasePhase.buying ||
      purchasePhase == SponsorPurchasePhase.pending;

  bool get showsInitialProductLoading =>
      isInitialized &&
      isLoadingProducts &&
      products.isEmpty &&
      productLoadError == null;

  SponsorBillingState copyWith({
    bool? isInitialized,
    bool? isAvailable,
    bool? isLoadingProducts,
    bool? isRefreshingProducts,
    List<ProductDetails>? products,
    String? productLoadError,
    bool clearProductLoadError = false,
    List<String>? notFoundProductIds,
    SponsorPurchasePhase? purchasePhase,
    String? purchaseErrorMessage,
    bool clearPurchaseErrorMessage = false,
  }) {
    return SponsorBillingState(
      isInitialized: isInitialized ?? this.isInitialized,
      isAvailable: isAvailable ?? this.isAvailable,
      isLoadingProducts: isLoadingProducts ?? this.isLoadingProducts,
      isRefreshingProducts: isRefreshingProducts ?? this.isRefreshingProducts,
      products: products ?? this.products,
      productLoadError: clearProductLoadError
          ? null
          : (productLoadError ?? this.productLoadError),
      notFoundProductIds: notFoundProductIds ?? this.notFoundProductIds,
      purchasePhase: purchasePhase ?? this.purchasePhase,
      purchaseErrorMessage: clearPurchaseErrorMessage
          ? null
          : (purchaseErrorMessage ?? this.purchaseErrorMessage),
    );
  }
}
