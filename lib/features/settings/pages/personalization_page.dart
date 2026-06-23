import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../infrastructure/preferences/personalization_preferences.dart';
import '../../../domain/recovery/recovery_metadata.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/presentation/page_style.dart';
import '../../session/providers/session_providers.dart';
import '../../session/state/app_session_state.dart';
import '../providers/personalization_providers.dart';
import '../providers/settings_providers.dart';
import '../settings_page_access.dart';
import '../widgets/personalization_sections.dart';
import '../widgets/settings_sections.dart';

class PersonalizationPage extends ConsumerWidget {
  const PersonalizationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color pageBackground = PageStyle.scaffoldWash(cs);
    final AsyncValue<PersonalizationPreferences> prefsAsync = ref.watch(
      personalizationPreferencesProvider,
    );
    final AsyncValue<AppSessionState> sessionAsync = ref.watch(
      effectiveAppSessionProvider,
    );
    final AsyncValue<RecoveryMetadata?> recoveryMetadataAsync = ref.watch(
      recoveryMetadataProvider,
    );
    final AppSessionState? sessionState = sessionAsync.asData?.value;
    final SettingsPageAccess pageAccess = SettingsPageAccess.fromSession(
      l10n: context.l10n,
      sessionState: sessionState,
      hasRecoveryKey: recoveryMetadataAsync.asData?.value != null,
    );
    final String? sessionTimeoutLockedMessage =
        pageAccess.canChangeSessionTimeout
        ? null
        : pageAccess.hasRecoveryKey
        ? pageAccess.lockedSettingMessage(context.l10n)
        : null;

    return Scaffold(
      backgroundColor: pageBackground,
      appBar: AppBar(
        title: Text(context.l10n.personalizationPageTitle),
        backgroundColor: pageBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: prefsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) =>
              Center(child: Text(context.l10n.personalizationLoadErrorMessage)),
          data: (PersonalizationPreferences prefs) {
            final PersonalizationPreferencesController controller = ref.read(
              personalizationPreferencesProvider.notifier,
            );

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: <Widget>[
                SettingsSectionCard(
                  icon: Icons.translate_rounded,
                  title: context.l10n.personalizationLanguageSectionTitle,
                  description:
                      context.l10n.personalizationLanguageSectionDescription,
                  child: PersonalizationLanguageSectionBody(
                    selected: prefs.locale,
                    onSelected: controller.setLocale,
                  ),
                ),
                const SizedBox(height: 16),
                SettingsSectionCard(
                  icon: Icons.lock_clock_outlined,
                  title: context.l10n.personalizationSessionTimeoutSectionTitle,
                  description: context
                      .l10n
                      .personalizationSessionTimeoutSectionDescription,
                  child: PersonalizationSessionTimeoutSectionBody(
                    selected: prefs.sessionTimeoutMinutes,
                    enabled: pageAccess.canChangeSessionTimeout,
                    lockedMessage: sessionTimeoutLockedMessage,
                    onSelected: controller.setSessionTimeoutMinutes,
                  ),
                ),
                const SizedBox(height: 16),
                SettingsSectionCard(
                  icon: Icons.image_outlined,
                  title: context.l10n.personalizationImageCompressSectionTitle,
                  description: context
                      .l10n
                      .personalizationImageCompressSectionDescription,
                  child: PersonalizationImageCompressSectionBody(
                    selected: prefs.imageCompressPreset,
                    onSelected: controller.setImageCompressPreset,
                  ),
                ),
                const SizedBox(height: 16),
                SettingsSectionCard(
                  icon: Icons.palette_outlined,
                  title: context.l10n.personalizationAppearanceSectionTitle,
                  description:
                      context.l10n.personalizationAppearanceSectionDescription,
                  child: PersonalizationAppearanceSectionBody(
                    selected: prefs.themeMode,
                    onSelected: controller.setThemeMode,
                  ),
                ),
                const SizedBox(height: 16),
                SettingsSectionCard(
                  icon: Icons.text_fields_rounded,
                  title: context.l10n.personalizationTypographySectionTitle,
                  description:
                      context.l10n.personalizationTypographySectionDescription,
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
