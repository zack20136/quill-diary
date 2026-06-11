part of 'support_page.dart';

const List<IconData> _sponsorTierIcons = <IconData>[
  Icons.local_cafe_rounded,
  Icons.cookie_rounded,
  Icons.lunch_dining_rounded,
  Icons.card_giftcard_rounded,
  Icons.auto_awesome_rounded,
];

class _ProductsSection extends StatelessWidget {
  const _ProductsSection({
    required this.billing,
    required this.onBuy,
    required this.onRetryLoad,
  });

  final SponsorBillingState billing;
  final ValueChanged<String> onBuy;
  final VoidCallback onRetryLoad;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final bool buttonsEnabled = billing.isAvailable && !billing.isPurchaseBusy;
    final _PurchaseStatusBanner? statusBanner =
        _PurchaseStatusBanner.fromBilling(billing);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(PageStyle.radiusCard),
        border: Border.fromBorderSide(PageStyle.outlineSide(cs)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color.alphaBlend(
                      cs.secondary.withValues(alpha: 0.12),
                      cs.surfaceContainerLow,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(9),
                    child: Icon(
                      Icons.volunteer_activism_rounded,
                      color: cs.secondary,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        SettingsSupportCopy.productsSectionTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        SettingsSupportCopy.productsSectionBody,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (statusBanner != null) ...<Widget>[
              const SizedBox(height: 14),
              statusBanner,
            ],
            const SizedBox(height: 16),
            if (billing.showsInitialProductLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ),
              )
            else if (!billing.isAvailable)
              _InlineMessage(
                icon: Icons.storefront_outlined,
                message: SettingsSupportCopy.billingUnavailableMessage,
                color: cs.onSurfaceVariant,
              )
            else ...<Widget>[
              if (billing.productLoadError != null) ...<Widget>[
                _ProductLoadNotice(
                  notice: SettingsSupportCopy.noticeForProductLoadError(
                    billing.productLoadError,
                  ),
                  onRetry: onRetryLoad,
                  isRefreshing: billing.isRefreshingProducts,
                  isError: billing.productLoadError == 'query_failed',
                ),
                const SizedBox(height: 12),
                for (
                  int index = 0;
                  index < SettingsSupportCopy.sponsorTiers.length;
                  index++
                ) ...<Widget>[
                  if (index > 0) const SizedBox(height: 10),
                  _SponsorTierPlaceholderTile(
                    tier: SettingsSupportCopy.sponsorTiers[index],
                  ),
                ],
              ] else ...<Widget>[
                if (billing.notFoundProductIds.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _InlineMessage(
                      icon: Icons.info_outline_rounded,
                      message: SettingsSupportCopy.productsPartialMessage,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                for (int index = 0; index < billing.products.length; index++) ...<Widget>[
                  if (index > 0) const SizedBox(height: 10),
                  _SponsorProductTile(
                    product: billing.products[index],
                    tierIndex: index,
                    tierCount: billing.products.length,
                    enabled: buttonsEnabled,
                    onPressed: () => onBuy(billing.products[index].id),
                  ),
                ],
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _PurchaseStatusBanner extends StatelessWidget {
  const _PurchaseStatusBanner({
    required this.icon,
    required this.message,
    required this.color,
  });

  final IconData icon;
  final String message;
  final Color color;

  static _PurchaseStatusBanner? fromBilling(SponsorBillingState billing) {
    return switch (billing.purchasePhase) {
      SponsorPurchasePhase.pending => _PurchaseStatusBanner(
        icon: Icons.hourglass_top_rounded,
        message: SettingsSupportCopy.pendingMessage,
        color: const Color(0xFF5C6BC0),
      ),
      SponsorPurchasePhase.error => _PurchaseStatusBanner(
        icon: Icons.info_outline_rounded,
        message: SettingsSupportCopy.errorMessage,
        color: const Color(0xFFC62828),
      ),
      SponsorPurchasePhase.thanks => _PurchaseStatusBanner(
        icon: Icons.check_circle_rounded,
        message: SettingsSupportCopy.thanksMessage,
        color: const Color(0xFF2E7D32),
      ),
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          color.withValues(alpha: 0.10),
          cs.surfaceContainerLow,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: <Widget>[
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SponsorProductTile extends StatelessWidget {
  const _SponsorProductTile({
    required this.product,
    required this.tierIndex,
    required this.tierCount,
    required this.enabled,
    required this.onPressed,
  });

  final ProductDetails product;
  final int tierIndex;
  final int tierCount;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final SponsorTierCopy? tier = SettingsSupportCopy.tierForProduct(product.id);
    final bool recommended = tier?.recommended ?? false;
    final double tierProgress =
        tierCount <= 1 ? 0 : tierIndex / (tierCount - 1);
    final Color accent =
        Color.lerp(cs.secondary, cs.primary, tierProgress) ?? cs.secondary;
    final IconData tierIcon =
        _sponsorTierIcons[tierIndex.clamp(0, _sponsorTierIcons.length - 1)];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: recommended
            ? Color.alphaBlend(
                accent.withValues(alpha: 0.06),
                cs.surfaceContainerLow,
              )
            : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: recommended
              ? accent.withValues(alpha: 0.45)
              : PageStyle.outlineSide(cs).color,
          width: recommended ? 1.5 : 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ColoredBox(
                color: accent.withValues(alpha: 0.50),
                child: const SizedBox(width: 4),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(7),
                              child: Icon(tierIcon, color: accent, size: 18),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: <Widget>[
                                    if (tier != null)
                                      Text(
                                        tier.label,
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    if (recommended)
                                      _RecommendedBadge(color: accent),
                                  ],
                                ),
                                if (tier != null) ...<Widget>[
                                  const SizedBox(height: 2),
                                  Text(
                                    tier.hint,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            product.price,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: accent,
                            ),
                          ),
                        ],
                      ),
                      if (product.description.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 6),
                        Text(
                          product.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: enabled ? onPressed : null,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            visualDensity: VisualDensity.compact,
                          ),
                          child: Text(
                            '${SettingsSupportCopy.buyButtonPrefix} ${product.price}',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecommendedBadge extends StatelessWidget {
  const _RecommendedBadge({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          SettingsSupportCopy.recommendedTierBadge,
          style: theme.textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ProductLoadNotice extends StatelessWidget {
  const _ProductLoadNotice({
    required this.notice,
    required this.onRetry,
    required this.isRefreshing,
    required this.isError,
  });

  final SupportNoticeCopy notice;
  final VoidCallback onRetry;
  final bool isRefreshing;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final Color tone = isError ? cs.error : cs.onSurfaceVariant;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            color: tone.withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              isError ? Icons.cloud_off_outlined : Icons.schedule_rounded,
              color: tone,
              size: 18,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                notice.title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                notice.body,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: isRefreshing ? null : onRetry,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                child: isRefreshing
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: cs.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(SettingsSupportCopy.retryLoadProductsLabel),
                        ],
                      )
                    : Text(SettingsSupportCopy.retryLoadProductsLabel),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SponsorTierPlaceholderTile extends StatelessWidget {
  const _SponsorTierPlaceholderTile({required this.tier});

  final SponsorTierCopy tier;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
        border: Border.fromBorderSide(
          PageStyle.outlineSide(cs, opacity: 0.18),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: cs.outline.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    tier.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  Text(
                    tier.hint,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.outline,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({
    required this.icon,
    required this.message,
    required this.color,
  });

  final IconData icon;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: color,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportInfoCard extends StatelessWidget {
  const _SupportInfoCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(PageStyle.radiusCard),
        border: Border.fromBorderSide(PageStyle.outlineSide(cs)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: cs.onSurfaceVariant, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    body,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
