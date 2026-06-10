import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/features/settings/legal_disclosures.dart';

void main() {
  test('privacyEffectiveDateLabel 與 docs/privacy-policy.md 一致', () {
    final String markdown = File('docs/privacy-policy.md').readAsStringSync();
    expect(markdown, contains('2026 年 6 月 6 日'));
    expect(LegalDisclosures.privacyEffectiveDateLabel, contains('2026 年 6 月 6 日'));
  });

  test('billing 短句共用 vault 隱私說明', () {
    expect(LegalDisclosures.billingPrivacyOneLiner, contains(LegalDisclosures.billingVaultPrivacyNote));
    expect(LegalDisclosures.billingSupportPageBody, contains(LegalDisclosures.billingVaultPrivacyNote));
  });
}
