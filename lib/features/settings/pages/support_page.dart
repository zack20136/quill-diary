import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/presentation/app_feedback.dart';
import '../../../shared/presentation/app_scrollbar.dart';
import '../../../app/app_colors.dart';
import '../../../shared/presentation/page_style.dart';
import '../providers/billing_providers.dart';
import '../settings_messages.dart';
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
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final SponsorBillingState billing = ref.watch(sponsorBillingProvider);

    ref.listen<SponsorBillingState>(sponsorBillingProvider, (
      SponsorBillingState? previous,
      SponsorBillingState next,
    ) {
      if (previous?.purchasePhase != SponsorPurchasePhase.thanks &&
          next.purchasePhase == SponsorPurchasePhase.thanks) {
        showAppFeedbackSnackBar(context, l10n.settingsSupportThanksMessage);
        ref.read(sponsorBillingProvider.notifier).clearPurchaseSuccess();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsSupportPageTitle),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: ListViewWithScrollbar(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: <Widget>[
            SettingsGradientHeroCard(
              icon: Icons.local_cafe_rounded,
              title: l10n.settingsSupportHeroTitle,
              body: l10n.settingsSupportHeroBody,
              chips: settingsSupportHeroChips(l10n),
              accentColor: cs.secondary,
              startAlpha: 0.20,
              endAlpha: 0.12,
            ),
            const SizedBox(height: 20),
            _ProductsSection(
              billing: billing,
              onBuy: (String productId) {
                unawaited(
                  ref
                      .read(sponsorBillingProvider.notifier)
                      .buyProduct(productId),
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
            _SupportInfoCard(
              icon: Icons.payments_outlined,
              title: l10n.settingsSupportComplianceCardTitle,
              body: l10n.settingsSupportComplianceCardBody,
            ),
            const SizedBox(height: 14),
            Text(
              l10n.settingsSupportFooterNote,
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
