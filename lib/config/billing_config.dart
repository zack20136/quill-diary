/// Google Play Billing 贊助商品設定。
abstract final class BillingConfig {
  /// 由低到高排列，對齊常見一次性支持梯次（實際價格在 Play Console 設定）。
  static const List<String> sponsorProductIdsOrdered = <String>[
    'sponsor_coffee',
    'sponsor_snack',
    'sponsor_lunch',
    'sponsor_boost',
    'sponsor_super',
  ];

  static final Set<String> sponsorProductIds =
      Set<String>.unmodifiable(sponsorProductIdsOrdered);
}
