import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:quill_diary/features/settings/pages/support_page.dart';
import 'package:quill_diary/features/settings/providers/billing_providers.dart';
import 'package:quill_diary/features/settings/state/sponsor_billing_state.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/services/google_billing_service.dart';

import '../../helpers/fake_in_app_purchase_platform.dart';
import '../../helpers/test_l10n.dart';

ProductDetails _product(String id) {
  return ProductDetails(
    id: id,
    title: '支持開發者 $id',
    description: '一次性支持開發者，不解鎖任何額外功能。',
    price: r'NT$50',
    rawPrice: 50,
    currencyCode: 'TWD',
  );
}

void main() {
  late FakeInAppPurchasePlatform platform;

  setUp(() {
    platform = FakeInAppPurchasePlatform();
    InAppPurchasePlatform.instance = platform;
  });

  tearDown(() async {
    await platform.close();
  });

  testWidgets('pending 時禁用購買按鈕', (WidgetTester tester) async {
    final GoogleBillingService service = GoogleBillingService();
    addTearDown(service.dispose);
    service.debugSetState(
      SponsorBillingState(
        isInitialized: true,
        isAvailable: true,
        products: <ProductDetails>[_product('sponsor_coffee')],
        purchasePhase: SponsorPurchasePhase.pending,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [googleBillingServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
          locale: appZhLocale,
          supportedLocales: appSupportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const SupportPage(),
        ),
      ),
    );
    await tester.pump();
    service.debugSetState(
      SponsorBillingState(
        isInitialized: true,
        isAvailable: true,
        products: <ProductDetails>[_product('sponsor_coffee')],
        purchasePhase: SponsorPurchasePhase.pending,
      ),
    );
    await tester.pump();

    expect(find.text(testL10n.settingsSupportPendingMessage), findsOneWidget);
    final FilledButton button = tester.widget<FilledButton>(
      find.byType(FilledButton),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('感謝贊助訊息會顯示在頁面上', (WidgetTester tester) async {
    final GoogleBillingService service = GoogleBillingService();
    addTearDown(service.dispose);
    service.debugSetState(
      SponsorBillingState(
        isInitialized: true,
        isAvailable: true,
        products: <ProductDetails>[_product('sponsor_lunch')],
        purchasePhase: SponsorPurchasePhase.thanks,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [googleBillingServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
          locale: appZhLocale,
          supportedLocales: appSupportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const SupportPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text(testL10n.settingsSupportThanksMessage), findsWidgets);
  });
}
