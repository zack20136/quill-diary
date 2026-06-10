import 'package:flutter/material.dart';

import '../../../shared/presentation/page_style.dart';
import '../about_copy.dart';

class SettingsAboutPage extends StatelessWidget {
  const SettingsAboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color pageBackground = PageStyle.scaffoldWash(cs);

    return DefaultTabController(
      length: SettingsAboutCopy.tabs.length,
      child: Scaffold(
        backgroundColor: pageBackground,
        appBar: AppBar(
          title: const Text(SettingsAboutCopy.pageTitle),
          backgroundColor: pageBackground,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: SettingsAboutCopy.tabs
                .map((AboutTabCopy tab) => Tab(text: tab.label))
                .toList(growable: false),
          ),
        ),
        body: TabBarView(
          children: SettingsAboutCopy.tabs
              .map((AboutTabCopy tab) => _AboutTabBody(tab: tab))
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _AboutTabBody extends StatelessWidget {
  const _AboutTabBody({required this.tab});

  final AboutTabCopy tab;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: <Widget>[
          _HeroCard(tab: tab),
          const SizedBox(height: 16),
          ...List<Widget>.generate(tab.sections.length, (int index) {
            final AboutSectionCopy section = tab.sections[index];
            return Padding(
              padding: EdgeInsets.only(bottom: index == tab.sections.length - 1 ? 0 : 16),
              child: _SectionCard(section: section),
            );
          }),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.tab});

  final AboutTabCopy tab;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(PageStyle.radiusCard),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color.alphaBlend(cs.primary.withValues(alpha: 0.16), cs.surface),
            Color.alphaBlend(cs.tertiary.withValues(alpha: 0.10), cs.surfaceContainerLow),
          ],
        ),
        border: Border.fromBorderSide(PageStyle.outlineSide(cs)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(tab.heroIcon, color: cs.primary, size: 28),
            const SizedBox(height: 14),
            Text(
              tab.heroTitle,
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(
              tab.heroBody,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.6,
              ),
            ),
            if (tab.chips.isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: tab.chips
                    .map((String label) => _FactChip(label: label))
                    .toList(growable: false),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.section});

  final AboutSectionCopy section;

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
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
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
              final AboutItemCopy item = section.items[index];
              return Padding(
                padding: EdgeInsets.only(bottom: index == section.items.length - 1 ? 0 : 10),
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

  final AboutItemCopy item;

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
                color: Color.alphaBlend(cs.primary.withValues(alpha: 0.12), cs.surface),
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
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
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

class _FactChip extends StatelessWidget {
  const _FactChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(999),
        border: Border.fromBorderSide(PageStyle.outlineSide(cs, opacity: 0.24)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
