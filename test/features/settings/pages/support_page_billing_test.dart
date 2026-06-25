import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:quill_diary/features/settings/pages/support_page.dart';
import 'package:quill_diary/features/settings/providers/billing_providers.dart';
import 'package:quill_diary/features/settings/state/sponsor_billing_state.dart';
import 'package:quill_diary/infrastructure/billing/google_billing_service.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/providers/core_providers.dart';

import '../../../helpers/shared/fake_in_app_purchase_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer buildContainer({
    required GoogleBillingService service,
    required bool supportedPlatform,
  }) {
    return ProviderContainer(
      overrides: [
        supportedPlatformProvider.overrideWith((Ref ref) => supportedPlatform),
        googleBillingServiceProvider.overrideWithValue(service),
      ],
    );
  }

  Widget buildApp() {
    return MaterialApp(
      locale: appZhLocale,
      supportedLocales: appSupportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const SupportPage(),
    );
  }

  testWidgets('贊助頁直接顯示 Play 商品文案', (WidgetTester tester) async {
    final FakeInAppPurchaseAndroidPlatformAddition fakeAndroidAddition =
        FakeInAppPurchaseAndroidPlatformAddition();
    final FakeInAppPurchase fakeInAppPurchase = FakeInAppPurchase(
      androidAddition: fakeAndroidAddition,
    );
    final GoogleBillingService service = GoogleBillingService(
      inAppPurchase: fakeInAppPurchase,
    );

    final ProviderContainer container = buildContainer(
      service: service,
      supportedPlatform: true,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: buildApp(),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('title-sponsor_coffee'), findsOneWidget);
    expect(find.text('desc-sponsor_coffee'), findsOneWidget);
    expect(find.text('title-sponsor_super'), findsOneWidget);
    expect(find.text('請開發者喝杯咖啡'), findsNothing);
    expect(find.text('讓 Quill Diary 持續被照顧與改進'), findsNothing);
  });

  testWidgets('成功購買後會被 listener 收回', (WidgetTester tester) async {
    final FakeInAppPurchaseAndroidPlatformAddition fakeAndroidAddition =
        FakeInAppPurchaseAndroidPlatformAddition();
    final FakeInAppPurchase fakeInAppPurchase = FakeInAppPurchase(
      androidAddition: fakeAndroidAddition,
    );
    final GoogleBillingService service = GoogleBillingService(
      inAppPurchase: fakeInAppPurchase,
    );

    final ProviderContainer container = buildContainer(
      service: service,
      supportedPlatform: true,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: buildApp(),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    final ProductDetails product = service.state.products.first;

    await service.buySponsorProduct(product);
    fakeInAppPurchase.emitPurchases(
      <PurchaseDetails>[
        buildPurchaseDetails(
          productId: product.id,
          status: PurchaseStatus.purchased,
          pendingCompletePurchase: true,
        ),
      ],
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(fakeAndroidAddition.consumePurchaseCalled, isTrue);
    expect(fakeInAppPurchase.completePurchaseCalled, isTrue);
    expect(service.state.purchasePhase, SponsorPurchasePhase.idle);
  });
}
