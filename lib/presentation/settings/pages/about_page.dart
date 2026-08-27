import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:quill_diary/application/settings/personalization_providers.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/settings/about_tab_catalog.dart';
import 'package:quill_diary/presentation/settings/widgets/settings_info_cards.dart';
import 'package:quill_diary/shared/presentation/app_scrollbar.dart';
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
            tabs: <Widget>[
              for (final AboutPageTabSpec tab in tabs) Tab(text: tab.label),
            ],
          ),
        ),
        body: TabBarView(
          children: <Widget>[
            for (final AboutPageTabSpec tab in tabs) _AboutTabBody(tab: tab),
          ],
        ),
      ),
    );
  }
}

class _AboutTabBody extends StatelessWidget {
  const _AboutTabBody({required this.tab});

  static const EdgeInsets _pagePadding = EdgeInsets.fromLTRB(16, 12, 16, 24);
  static const double _heroStartAlpha = 0.16;
  static const double _sectionGap = 16;

  final AboutPageTabSpec tab;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: AppScrollablePageBody(
        padding: _pagePadding,
        children: <Widget>[
          SettingsGradientHeroCard(
            icon: tab.heroIcon,
            title: tab.heroTitle,
            body: tab.heroBody,
            chips: tab.chips,
            startAlpha: _heroStartAlpha,
          ),
          const SizedBox(height: _sectionGap),
          ..._childrenSeparatedByGap(
            [
              for (final AboutPageSectionSpec section in tab.sections)
                _SectionCard(section: section),
            ],
            gap: _sectionGap,
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.section});

  static const EdgeInsets _padding = EdgeInsets.fromLTRB(18, 18, 18, 16);
  static const double _itemGap = 10;

  final AboutPageSectionSpec section;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: section.title,
      description: section.subtitle,
      style: AppSurfaceStyle.outlinedElevated,
      padding: _padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _childrenSeparatedByGap(
          [
            for (final AboutPageItemSpec item in section.items)
              _ItemPanel(item: item),
          ],
          gap: _itemGap,
        ),
      ),
    );
  }
}

class _ItemPanel extends StatelessWidget {
  const _ItemPanel({required this.item});

  static const EdgeInsets _padding = EdgeInsets.fromLTRB(12, 12, 14, 12);
  static const double _iconTextGap = 12;
  static const double _titleBodyGap = 4;

  final AboutPageItemSpec item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return AppInsetPanel(
      backgroundColor: cs.surfaceContainerLow,
      padding: _padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _ItemIconBadge(icon: item.icon, colorScheme: cs),
          const SizedBox(width: _iconTextGap),
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
                const SizedBox(height: _titleBodyGap),
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

class _ItemIconBadge extends StatelessWidget {
  const _ItemIconBadge({required this.icon, required this.colorScheme});

  static const double _size = 36;
  static const double _glyphSize = 18;

  final IconData icon;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 1),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            colorScheme.primary.withValues(alpha: 0.12),
            colorScheme.surface,
          ),
          shape: BoxShape.circle,
        ),
        child: SizedBox(
          width: _size,
          height: _size,
          child: Icon(icon, color: colorScheme.primary, size: _glyphSize),
        ),
      ),
    );
  }
}

/// 在子項之間插入固定垂直間距；最後一項不加尾巴空白。
List<Widget> _childrenSeparatedByGap(
  List<Widget> children, {
  required double gap,
}) {
  if (children.length <= 1) {
    return children;
  }
  return <Widget>[
    for (int index = 0; index < children.length; index++) ...<Widget>[
      children[index],
      if (index < children.length - 1) SizedBox(height: gap),
    ],
  ];
}
