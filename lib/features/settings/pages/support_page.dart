import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../shared/presentation/page_style.dart';
import '../providers/billing_providers.dart';
import '../settings_copy.dart';
import '../state/sponsor_billing_state.dart';
import '../widgets/settings_info_cards.dart';

part 'support_page_widgets.dart';

class SupportPage extends ConsumerStatefulWidget {
  const SupportPage({super.key});

  @override
  ConsumerState<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends ConsumerState<SupportPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(sponsorBillingProvider.notifier).loadProducts());
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final Color pageBackground = PageStyle.scaffoldWash(cs);
    final SponsorBillingState billing = ref.watch(sponsorBillingProvider);

    ref.listen<SponsorBillingState>(sponsorBillingProvider, (
      SponsorBillingState? previous,
      SponsorBillingState next,
    ) {
      if (next.purchasePhase == SponsorPurchasePhase.thanks) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(SettingsSupportCopy.thanksMessage),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: pageBackground,
      appBar: AppBar(
        title: const Text(SettingsSupportCopy.pageTitle),
        backgroundColor: pageBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: <Widget>[
            SettingsGradientHeroCard(
              icon: Icons.local_cafe_rounded,
              title: SettingsSupportCopy.heroTitle,
              body: SettingsSupportCopy.heroBody,
              chips: SettingsSupportCopy.heroChips,
              accentColor: cs.secondary,
              startAlpha: 0.20,
              endAlpha: 0.12,
            ),
            const SizedBox(height: 20),
            _ProductsSection(
              billing: billing,
              onBuy: (String productId) {
                unawaited(
                  ref.read(sponsorBillingProvider.notifier).buyProduct(productId),
                );
              },
              onRetryLoad: () {
                unawaited(
                  ref
                      .read(sponsorBillingProvider.notifier)
                      .loadProducts(retry: true),
                );
              },
            ),
            const SizedBox(height: 16),
            const _SupportInfoCard(
              icon: Icons.payments_outlined,
              title: SettingsSupportCopy.complianceCardTitle,
              body: SettingsSupportCopy.complianceCardBody,
            ),
            const SizedBox(height: 14),
            Text(
              SettingsSupportCopy.footerNote,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.outline,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
