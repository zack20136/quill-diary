import 'package:flutter/material.dart';

import '../../../shared/presentation/page_style.dart';
import '../settings_copy.dart';

class SupportPage extends StatelessWidget {
  const SupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final Color pageBackground = PageStyle.scaffoldWash(cs);

    return Scaffold(
      backgroundColor: pageBackground,
      appBar: AppBar(
        title: const Text(SettingsSupportCopy.pageTitle),
        backgroundColor: pageBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: <Widget>[
            const _SupportHero(),
            const SizedBox(height: 16),
            const _SupportCard(
              icon: Icons.construction_outlined,
              title: SettingsSupportCopy.statusCardTitle,
              body: SettingsSupportCopy.statusCardBody,
            ),
            const SizedBox(height: 16),
            const _SupportCard(
              icon: Icons.privacy_tip_outlined,
              title: SettingsSupportCopy.complianceCardTitle,
              body: SettingsSupportCopy.complianceCardBody,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: null,
                child: const Text(SettingsSupportCopy.purchaseButtonLabel),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              SettingsSupportCopy.purchaseHint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              SettingsSupportCopy.billingProductDescription,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium?.copyWith(
                color: cs.outline,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportHero extends StatelessWidget {
  const _SupportHero();

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
            Color.alphaBlend(cs.secondary.withValues(alpha: 0.18), cs.surface),
            Color.alphaBlend(cs.primary.withValues(alpha: 0.10), cs.surfaceContainerLow),
          ],
        ),
        border: Border.fromBorderSide(PageStyle.outlineSide(cs)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.favorite_rounded, color: cs.secondary, size: 30),
            const SizedBox(height: 14),
            Text(
              SettingsSupportCopy.heroTitle,
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(
              SettingsSupportCopy.heroBody,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportCard extends StatelessWidget {
  const _SupportCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                color: Color.alphaBlend(
                  cs.secondary.withValues(alpha: 0.10),
                  cs.surfaceContainerLow,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(icon, color: cs.secondary, size: 22),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    body,
                    style: theme.textTheme.bodyMedium?.copyWith(
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
