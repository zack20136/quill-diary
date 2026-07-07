import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'package:quill_diary/infrastructure/billing/google_billing_service.dart';
import 'package:quill_diary/shared/platform/vault_platform_support.dart';
import 'package:quill_diary/presentation/settings/state/sponsor_billing_state.dart';

final googleBillingServiceProvider = Provider<GoogleBillingService>((Ref ref) {
  final GoogleBillingService service = GoogleBillingService();
  ref.onDispose(service.dispose);
  return service;
});

final sponsorBillingProvider =
    NotifierProvider<SponsorBillingController, SponsorBillingState>(
      SponsorBillingController.new,
    );
final sponsorBillingLifecycleProvider = Provider<void>((Ref ref) {
  if (!ref.watch(supportedPlatformProvider)) {
    return;
  }
  unawaited(ref.read(sponsorBillingProvider.notifier).ensureInitialized());
});

class SponsorBillingController extends Notifier<SponsorBillingState> {
  @override
  SponsorBillingState build() {
    final GoogleBillingService service = ref.watch(
      googleBillingServiceProvider,
    );
    service.onStateChanged = (SponsorBillingState next) {
      state = next;
    };
    ref.onDispose(() {
      service.onStateChanged = null;
    });
    return service.state;
  }

  Future<void> ensureInitialized() async {
    await ref.read(googleBillingServiceProvider).initialize();
  }

  Future<void> loadProducts({bool retry = false}) async {
    await ref.read(googleBillingServiceProvider).loadProducts(isRetry: retry);
  }

  Future<bool> buyProduct(String productId) async {
    final ProductDetails? product = _productById(productId);
    if (product == null) {
      return false;
    }
    return ref.read(googleBillingServiceProvider).buySponsorProduct(product);
  }

  void clearPurchaseSuccess() {
    ref.read(googleBillingServiceProvider).clearPurchaseSuccess();
  }

  ProductDetails? _productById(String productId) {
    for (final ProductDetails candidate in state.products) {
      if (candidate.id == productId) {
        return candidate;
      }
    }
    return null;
  }
}
