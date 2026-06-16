import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/presentation/page_style.dart';
import '../../../l10n/l10n.dart';
import '../about_content.dart';
import '../providers/personalization_providers.dart';
import '../widgets/settings_info_cards.dart';

class SettingsAboutPage extends ConsumerWidget {
  const SettingsAboutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color pageBackground = PageStyle.scaffoldWash(cs);
    final AppLocalizations l10n = context.l10n;
    final List<AboutTab> tabs = buildAboutTabs(
      l10n,
      watchPersonalizationPreferences(ref).sessionTimeout,
    );

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        backgroundColor: pageBackground,
        appBar: AppBar(
          title: Text(l10n.aboutPageTitle),
          backgroundColor: pageBackground,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: tabs
                .map((AboutTab tab) => Tab(text: tab.label))
                .toList(growable: false),
          ),
        ),
        body: TabBarView(
          children: tabs
              .map((AboutTab tab) => _AboutTabBody(tab: tab))
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _AboutTabBody extends StatelessWidget {
  const _AboutTabBody({required this.tab});

  final AboutTab tab;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
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
            final AboutSection section = tab.sections[index];
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

  final AboutSection section;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(PageStyle.radiusCard),
        border: Border.fromBorderSide(PageStyle.outlineSide(cs)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              section.title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              section.subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            ...List<Widget>.generate(section.items.length, (int index) {
              final AboutItem item = section.items[index];
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == section.items.length - 1 ? 0 : 10,
                ),
                child: _ItemPanel(item: item),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _ItemPanel extends StatelessWidget {
  const _ItemPanel({required this.item});

  final AboutItem item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(PageStyle.radiusPanel),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                color: Color.alphaBlend(
                  cs.primary.withValues(alpha: 0.12),
                  cs.surface,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(item.icon, color: cs.primary, size: 20),
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
                    ),
                  ),
                  const SizedBox(height: 6),
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
      ),
    );
  }
}
