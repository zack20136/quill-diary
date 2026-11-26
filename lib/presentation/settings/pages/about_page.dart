import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:quill_diary/application/settings/personalization_providers.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/settings/about_topic_content.dart';
import 'package:quill_diary/shared/navigation/app_routes.dart';
import 'package:quill_diary/shared/presentation/app_feedback.dart';
import 'package:quill_diary/shared/presentation/app_scrollbar.dart';
import 'package:quill_diary/shared/presentation/widgets/app_surface.dart';

class SettingsAboutPage extends StatelessWidget {
  const SettingsAboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.aboutPageTitle)),
      body: AppScrollablePageBody(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 2, 4, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 6,
              children: [
                Semantics(
                  header: true,
                  child: Text(l10n.appTitle, style: theme.textTheme.titleLarge),
                ),
                Text(
                  l10n.aboutIntro,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          for (final topic in AboutTopic.values) ...[
            if (topic != AboutTopic.values.first) const SizedBox(height: 10),
            _AboutTopicLink(topic: topic),
          ],
          const SizedBox(height: 20),
          _AboutSectionCard(
            section: AboutSection(
              l10n.aboutProjectTitle,
              icon: Icons.info_outline_rounded,
              paragraphs: [
                l10n.aboutProjectLicense,
                l10n.legalBrandDisclaimer,
                l10n.aboutProjectLegal(
                  l10n.settingsPageTitle,
                  l10n.settingsLegalSectionTitle,
                ),
              ],
            ),
            secondary: true,
          ),
        ],
      ),
    );
  }
}

class SettingsAboutTopicPage extends ConsumerWidget {
  const SettingsAboutTopicPage({required this.topic, super.key});

  final AboutTopic topic;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final overview = aboutTopicOverview(topic, l10n);
    final sessionTimeout = watchPersonalizationPreferences(ref).sessionTimeout;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.aboutPageTitle)),
      body: AppScrollablePageBody(
        children: [
          _AboutHeading(
            title: overview.title,
            icon: overview.icon,
            style: Theme.of(context).textTheme.headlineSmall,
            iconExtent: 44,
          ),
          for (final section in aboutTopicSections(topic, l10n, sessionTimeout))
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _AboutSectionCard(section: section),
            ),
          if (topic == AboutTopic.people)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: _AboutTopicLink(topic: AboutTopic.ai),
            ),
        ],
      ),
    );
  }
}

class _AboutTopicLink extends StatelessWidget {
  const _AboutTopicLink({required this.topic});

  final AboutTopic topic;

  @override
  Widget build(BuildContext context) {
    final overview = aboutTopicOverview(topic, context.l10n);
    final theme = Theme.of(context);
    return AppCard(
      key: ValueKey(topic),
      padding: EdgeInsets.zero,
      child: Semantics(
        button: true,
        child: InkWell(
          onTap: () => unawaited(
            context.push<void>(AppRoutes.aboutTopicLocation(topic)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              spacing: 12,
              children: [
                _AboutIcon(icon: overview.icon, extent: 40),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 4,
                    children: [
                      Text(overview.title, style: theme.textTheme.titleMedium),
                      Text(
                        overview.summary,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AboutSectionCard extends StatelessWidget {
  const _AboutSectionCard({required this.section, this.secondary = false});

  final AboutSection section;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final warning = section.warning;
    return AppCard(
      padding: const EdgeInsets.all(16),
      backgroundColor: secondary ? theme.colorScheme.surfaceContainerLow : null,
      child: DefaultTextStyle.merge(
        style: theme.textTheme.bodyMedium?.copyWith(
          color: secondary
              ? theme.colorScheme.onSurfaceVariant
              : theme.colorScheme.onSurface,
          height: 1.55,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: secondary ? 8 : 12,
          children: [
            _AboutHeading(
              title: section.title,
              icon: section.icon,
              style: theme.textTheme.titleMedium,
              iconExtent: 34,
              secondary: secondary,
            ),
            if (warning != null)
              AppFeedbackBanner(
                message: warning,
                tone: AppFeedbackTone.warning,
              ),
            for (final paragraph in section.paragraphs) Text(paragraph),
            for (final (index, step) in section.steps.indexed)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 10,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      child: Text(
                        '${index + 1}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 4,
                      children: [
                        Text(step.title, style: theme.textTheme.titleSmall),
                        Text(step.body),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _AboutHeading extends StatelessWidget {
  const _AboutHeading({
    required this.title,
    required this.icon,
    required this.style,
    required this.iconExtent,
    this.secondary = false,
  });

  final String title;
  final IconData icon;
  final TextStyle? style;
  final double iconExtent;
  final bool secondary;

  @override
  Widget build(BuildContext context) => Row(
    spacing: 10,
    children: [
      _AboutIcon(icon: icon, extent: iconExtent, secondary: secondary),
      Expanded(
        child: Semantics(header: true, child: Text(title, style: style)),
      ),
    ],
  );
}

class _AboutIcon extends StatelessWidget {
  const _AboutIcon({
    required this.icon,
    required this.extent,
    this.secondary = false,
  });

  final IconData icon;
  final double extent;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: extent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: secondary
              ? colors.surfaceContainerHighest
              : colors.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Icon(
            icon,
            size: extent <= 34 ? 18 : 22,
            color: secondary
                ? colors.onSurfaceVariant
                : colors.onPrimaryContainer,
          ),
        ),
      ),
    );
  }
}
