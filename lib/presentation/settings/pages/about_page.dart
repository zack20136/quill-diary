import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:quill_diary/shared/presentation/app_scrollbar.dart';
import 'package:quill_diary/l10n/l10n.dart';
import '../about_tab_catalog.dart';
import 'package:quill_diary/application/settings/personalization_providers.dart';
import '../widgets/settings_info_cards.dart';
import 'package:quill_diary/shared/presentation/widgets/app_surface.dart';

class SettingsAboutPage extends ConsumerWidget {
  const SettingsAboutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final List<AboutPageTabSpec> tabs = buildAboutPageTabSpecs(
      l10n,
      watchPersonalizationPreferences(ref).sessionTimeout,
    );

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.aboutPageTitle),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: tabs
                .map((AboutPageTabSpec tab) => Tab(text: tab.label))
                .toList(growable: false),
          ),
        ),
        body: TabBarView(
          children: tabs
              .map((AboutPageTabSpec tab) => _AboutTabBody(tab: tab))
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _AboutTabBody extends StatelessWidget {
  const _AboutTabBody({required this.tab});

  final AboutPageTabSpec tab;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: AppScrollablePageBody(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: <Widget>[
          SettingsGradientHeroCard(
            icon: tab.heroIcon,
            title: tab.heroTitle,
            body: tab.heroBody,
            chips: tab.chips,
            startAlpha: 0.16,
          ),
          const SizedBox(height: 16),
          ...List<Widget>.generate(tab.sections.length, (int index) {
            final AboutPageSectionSpec section = tab.sections[index];
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == tab.sections.length - 1 ? 0 : 16,
              ),
              child: _SectionCard(section: section),
            );
          }),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.section});

  final AboutPageSectionSpec section;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: section.title,
      description: section.subtitle,
      style: AppSurfaceStyle.outlinedElevated,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List<Widget>.generate(section.items.length, (int index) {
          final AboutPageItemSpec item = section.items[index];
          return Padding(
            padding: EdgeInsets.only(
              bottom: index == section.items.length - 1 ? 0 : 10,
            ),
            child: _ItemPanel(item: item),
          );
        }),
      ),
    );
  }
}

class _ItemPanel extends StatelessWidget {
  const _ItemPanel({required this.item});

  final AboutPageItemSpec item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return AppInsetPanel(
      backgroundColor: cs.surfaceContainerLow,
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color.alphaBlend(
                  cs.primary.withValues(alpha: 0.12),
                  cs.surface,
                ),
                shape: BoxShape.circle,
              ),
              child: SizedBox(
                width: 36,
                height: 36,
                child: Icon(item.icon, color: cs.primary, size: 18),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.body,
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
    );
  }
}
