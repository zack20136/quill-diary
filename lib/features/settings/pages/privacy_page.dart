import 'package:flutter/material.dart';

import '../../../config/app_identifiers.dart';
import '../../../shared/presentation/page_style.dart';
import '../../../shared/utils/external_url.dart';
import '../legal_disclosures.dart';
import '../privacy_copy.dart';
import '../widgets/settings_info_cards.dart';

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  Future<void> _openPublicPolicy(BuildContext context) async {
    final bool opened = await launchExternalUrl(AppIdentifiers.privacyPolicyUrl);
    if (!context.mounted || opened) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(LegalDisclosures.externalLinkUnavailableMessage)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final Color pageBackground = PageStyle.scaffoldWash(cs);

    return Scaffold(
      backgroundColor: pageBackground,
      appBar: AppBar(
        title: const Text(SettingsPrivacyCopy.pageTitle),
        backgroundColor: pageBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: <Widget>[
            SettingsGradientHeroCard(
              icon: Icons.privacy_tip_outlined,
              title: SettingsPrivacyCopy.heroTitle,
              body: SettingsPrivacyCopy.heroBody,
            ),
            const SizedBox(height: 12),
            Text(
              SettingsPrivacyCopy.effectiveDateLabel,
              style: theme.textTheme.labelMedium?.copyWith(
                color: cs.outline,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            ...SettingsPrivacyCopy.sections.map(
              (PrivacySectionCopy section) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SettingsTitleBodyCard(
                  title: section.title,
                  body: section.body,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openPublicPolicy(context),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text(SettingsPrivacyCopy.openInBrowserLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
