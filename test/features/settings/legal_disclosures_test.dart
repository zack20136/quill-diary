import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/config/app_identifiers.dart';
import 'package:quill_diary/features/settings/legal_disclosures.dart';

const String _privacyPolicyPath = 'docs/public/privacy-policy.md';

void main() {
  test('privacyEffectiveDateLabel 與 docs/public/privacy-policy.md 一致', () {
    final String markdown = File(_privacyPolicyPath).readAsStringSync();
    expect(markdown, contains('2026 年 6 月 6 日'));
    expect(LegalDisclosures.privacyEffectiveDateLabel, contains('2026 年 6 月 6 日'));
  });

  test('privacy-policy.md 含 AppIdentifiers 套件名與 issues 路徑', () {
    final String markdown = File(_privacyPolicyPath).readAsStringSync();
    expect(markdown, contains(AppIdentifiers.androidPackageName));
    expect(markdown, contains(AppIdentifiers.issuesUrl));
  });

  test('billing 短句共用 vault 隱私說明', () {
    expect(LegalDisclosures.billingPrivacyOneLiner, contains(LegalDisclosures.billingVaultPrivacyNote));
    expect(LegalDisclosures.billingSupportPageBody, contains(LegalDisclosures.billingVaultPrivacyNote));
  });
}
