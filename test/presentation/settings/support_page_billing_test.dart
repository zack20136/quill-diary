import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/settings/billing_providers.dart';
import 'package:quill_diary/infrastructure/billing/google_billing_service.dart';
import 'package:quill_diary/infrastructure/billing/sponsor_billing_state.dart';
import 'package:quill_diary/presentation/settings/pages/support_page.dart';
import 'package:quill_diary/shared/platform/vault_platform_support.dart';
import 'package:quill_diary/shared/presentation/app_feedback.dart';

import '../../helpers/shared/fake_in_app_purchase_platform.dart';
import '../../helpers/shared/test_l10n.dart';
import '../../helpers/shared/widget_test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer buildContainer({
    required GoogleBillingService service,
    required bool supportedPlatform,
  }) {
    return ProviderContainer(
      overrides: [
        vaultPlatformSupportProvider.overrideWith(
          (Ref ref) => supportedPlatform,
        ),
        googleBillingServiceProvider.overrideWithValue(service),
      ],
    );
  }

  Widget buildApp() {
    return widgetTestApp(
      includeDarkTheme: true,
      center: false,
      child: const SupportPage(),
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
      UncontrolledProviderScope(container: container, child: buildApp()),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('title-sponsor_coffee'), findsOneWidget);
    expect(find.text('desc-sponsor_coffee'), findsOneWidget);
    expect(find.text('title-sponsor_super'), findsOneWidget);
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
      UncontrolledProviderScope(container: container, child: buildApp()),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    final ProductDetails product = service.state.products.first;

    await service.buySponsorProduct(product);
    fakeInAppPurchase.emitPurchases(<PurchaseDetails>[
      buildPurchaseDetails(
        productId: product.id,
        status: PurchaseStatus.purchased,
        pendingCompletePurchase: true,
      ),
    ]);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(fakeAndroidAddition.consumePurchaseCalled, isTrue);
    expect(fakeInAppPurchase.completePurchaseCalled, isTrue);
    expect(service.state.purchasePhase, SponsorPurchasePhase.idle);
    expect(find.text(testL10n.settingsSupportThanksMessage), findsOneWidget);
    expect(find.byType(AppFeedbackBanner), findsNothing);
  });
}
