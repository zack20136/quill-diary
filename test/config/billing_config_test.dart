import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/config/billing_config.dart';
import 'package:quill_diary/features/settings/settings_messages.dart';

import '../helpers/test_l10n.dart';

void main() {
  test('贊助梯次 productId 與 BillingConfig 順序一致', () {
    expect(
      sponsorTiers(testL10n).map((SponsorTier tier) => tier.productId).toList(),
      BillingConfig.sponsorProductIdsOrdered,
    );
    expect(
      BillingConfig.sponsorProductIds,
      BillingConfig.sponsorProductIdsOrdered.toSet(),
    );
  });
}
