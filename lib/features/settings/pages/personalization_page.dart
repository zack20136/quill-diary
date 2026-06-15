import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../infrastructure/preferences/personalization_preferences.dart';
import '../../../shared/presentation/page_style.dart';
import '../personalization_copy.dart';
import '../providers/personalization_providers.dart';
import '../widgets/personalization_sections.dart';
import '../widgets/settings_sections.dart';

class PersonalizationPage extends ConsumerWidget {
  const PersonalizationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color pageBackground = PageStyle.scaffoldWash(cs);
    final AsyncValue<PersonalizationPreferences> prefsAsync =
        ref.watch(personalizationPreferencesProvider);

    return Scaffold(
      backgroundColor: pageBackground,
      appBar: AppBar(
        title: const Text(PersonalizationCopy.pageTitle),
        backgroundColor: pageBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: prefsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const Center(
            child: Text(PersonalizationCopy.loadErrorMessage),
          ),
          data: (PersonalizationPreferences prefs) {
            final PersonalizationPreferencesController controller =
                ref.read(personalizationPreferencesProvider.notifier);

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: <Widget>[
                SettingsSectionCard(
                  icon: Icons.translate_rounded,
                  title: PersonalizationCopy.languageSectionTitle,
                  description: PersonalizationCopy.languageSectionDescription,
                  child: PersonalizationLanguageSectionBody(
                    selected: prefs.locale,
                    onSelected: controller.setLocale,
                  ),
                ),
                const SizedBox(height: 16),
                SettingsSectionCard(
                  icon: Icons.lock_clock_outlined,
                  title: PersonalizationCopy.sessionTimeoutSectionTitle,
                  description: PersonalizationCopy.sessionTimeoutSectionDescription,
                  child: PersonalizationSessionTimeoutSectionBody(
                    selected: prefs.sessionTimeoutMinutes,
                    onSelected: controller.setSessionTimeoutMinutes,
                  ),
                ),
                const SizedBox(height: 16),
                SettingsSectionCard(
                  icon: Icons.image_outlined,
                  title: PersonalizationCopy.imageCompressSectionTitle,
                  description: PersonalizationCopy.imageCompressSectionDescription,
                  child: PersonalizationImageCompressSectionBody(
                    selected: prefs.imageCompressPreset,
                    onSelected: controller.setImageCompressPreset,
                  ),
                ),
                const SizedBox(height: 16),
                SettingsSectionCard(
                  icon: Icons.palette_outlined,
                  title: PersonalizationCopy.appearanceSectionTitle,
                  description: PersonalizationCopy.appearanceSectionDescription,
                  child: PersonalizationAppearanceSectionBody(
                    selected: prefs.themeMode,
                    onSelected: controller.setThemeMode,
                  ),
                ),
                const SizedBox(height: 16),
                SettingsSectionCard(
                  icon: Icons.text_fields_rounded,
                  title: PersonalizationCopy.typographySectionTitle,
                  description: PersonalizationCopy.typographySectionDescription,
                  child: PersonalizationTypographySectionBody(
                    typography: prefs.typography,
                    controller: controller,
                    onTypographyChanged: (typography) {
                      unawaited(controller.setTypography(typography));
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
