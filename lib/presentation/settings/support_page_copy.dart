import 'package:quill_diary/l10n/l10n.dart';

class SupportProductLoadNotice {
  const SupportProductLoadNotice({required this.title, required this.body});

  final String title;
  final String body;
}

SupportProductLoadNotice supportProductLoadNotice(
  AppLocalizations l10n,
  String? errorCode,
) {
  return switch (errorCode) {
    'no_products' => SupportProductLoadNotice(
      title: l10n.settingsSupportProductsNotReadyTitle,
      body: l10n.settingsSupportProductsNotReadyBody,
    ),
    'init_failed' => SupportProductLoadNotice(
      title: l10n.settingsSupportProductsInitFailedTitle,
      body: l10n.settingsSupportProductsInitFailedBody,
    ),
    'query_failed' => SupportProductLoadNotice(
      title: l10n.settingsSupportProductsQueryFailedTitle,
      body: l10n.settingsSupportProductsQueryFailedBody,
    ),
    _ => SupportProductLoadNotice(
      title: l10n.settingsSupportProductLoadErrorTitle,
      body: l10n.settingsSupportProductLoadErrorBody,
    ),
  };
}

List<String> settingsSupportHeroChips(AppLocalizations l10n) => <String>[
  l10n.settingsSupportHeroChipNoExtraFeatures,
  l10n.settingsSupportHeroChipRepeatablePurchase,
  l10n.settingsSupportHeroChipGooglePlayPayment,
];
