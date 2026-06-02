import 'package:flutter/material.dart';

import '../../../shared/presentation/page_style.dart';
import '../settings_copy.dart';

class SecurityInfoPage extends StatelessWidget {
  const SecurityInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color pageBackground = PageStyle.scaffoldWash(cs);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: pageBackground,
        appBar: AppBar(
          title: const Text(SettingsAboutCopy.pageTitle),
          backgroundColor: pageBackground,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          bottom: TabBar(
            tabs: const <Widget>[
              Tab(text: SettingsAboutCopy.tabOverview),
              Tab(text: SettingsAboutCopy.tabData),
              Tab(text: SettingsAboutCopy.tabSecurity),
            ],
          ),
        ),
        body: const TabBarView(
          children: <Widget>[
            _AboutTabBody(
              children: <Widget>[
                _OverviewHeroCard(),
                SizedBox(height: 16),
                _AppFeaturesCard(),
                SizedBox(height: 16),
                _PlatformLimitCard(),
              ],
            ),
            _AboutTabBody(
              children: <Widget>[
                _TagCatalogCard(),
                SizedBox(height: 16),
                _BackupDataCard(),
                SizedBox(height: 16),
                _ImportExportCard(),
              ],
            ),
            _AboutTabBody(
              children: <Widget>[
                _HeroCard(),
                SizedBox(height: 16),
                _SecurityFlowCard(),
                SizedBox(height: 16),
                _SecurityHighlightsCard(),
                SizedBox(height: 16),
                _BackupRestoreCard(),
                SizedBox(height: 16),
                _RecoveryKeyCard(),
                SizedBox(height: 16),
                _SecurityLimitsCard(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutTabBody extends StatelessWidget {
  const _AboutTabBody({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: children,
      ),
    );
  }
}

class _OverviewHeroCard extends StatelessWidget {
  const _OverviewHeroCard();

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
            Icon(Icons.menu_book_rounded, color: cs.primary, size: 28),
            const SizedBox(height: 14),
            Text(
              SettingsAboutCopy.overviewHeroTitle,
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(
              SettingsAboutCopy.overviewHeroBody,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: SettingsAboutCopy.overviewChips
                  .map((String label) => _FactChip(label: label))
                  .toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppFeaturesCard extends StatelessWidget {
  const _AppFeaturesCard();

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      title: SettingsAboutCopy.featuresSectionTitle,
      subtitle: SettingsAboutCopy.featuresSectionSubtitle,
      child: const Column(
        children: <Widget>[
          _BulletPanel(
            icon: Icons.home_outlined,
            title: SettingsAboutCopy.featuresHomeTitle,
            body: SettingsAboutCopy.featuresHomeBody,
          ),
          SizedBox(height: 10),
          _BulletPanel(
            icon: Icons.edit_note_rounded,
            title: SettingsAboutCopy.featuresEditorTitle,
            body: SettingsAboutCopy.featuresEditorBody,
          ),
          SizedBox(height: 10),
          _BulletPanel(
            icon: Icons.search_rounded,
            title: SettingsAboutCopy.featuresSearchTitle,
            body: SettingsAboutCopy.featuresSearchBody,
          ),
        ],
      ),
    );
  }
}

class _PlatformLimitCard extends StatelessWidget {
  const _PlatformLimitCard();

  @override
  Widget build(BuildContext context) {
    return const _SectionShell(
      title: SettingsAboutCopy.platformSectionTitle,
      subtitle: SettingsAboutCopy.platformSectionBody,
    );
  }
}

class _TagCatalogCard extends StatelessWidget {
  const _TagCatalogCard();

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      title: SettingsAboutCopy.tagCatalogSectionTitle,
      subtitle: SettingsAboutCopy.tagCatalogSectionSubtitle,
      child: const Column(
        children: <Widget>[
          _InfoRow(
            label: SettingsAboutCopy.tagCatalogFileLabel,
            body: SettingsAboutCopy.tagCatalogFileBody,
          ),
          SizedBox(height: 10),
          _InfoRow(
            label: SettingsAboutCopy.tagCatalogSyncLabel,
            body: SettingsAboutCopy.tagCatalogSyncBody,
          ),
        ],
      ),
    );
  }
}

class _BackupDataCard extends StatelessWidget {
  const _BackupDataCard();

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      title: SettingsAboutCopy.backupSectionTitle,
      subtitle: SettingsAboutCopy.backupSectionSubtitle,
      child: const Column(
        children: <Widget>[
          _InfoRow(
            label: SettingsAboutCopy.backupLocalLabel,
            body: SettingsAboutCopy.backupLocalBody,
          ),
          SizedBox(height: 10),
          _InfoRow(
            label: SettingsAboutCopy.backupDriveLabel,
            body: SettingsAboutCopy.backupDriveBody,
          ),
          SizedBox(height: 10),
          _InfoRow(
            label: SettingsAboutCopy.backupRestoreAfterLabel,
            body: SettingsAboutCopy.backupRestoreAfterBody,
          ),
        ],
      ),
    );
  }
}

class _ImportExportCard extends StatelessWidget {
  const _ImportExportCard();

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      title: SettingsAboutCopy.portableSectionTitle,
      subtitle: SettingsAboutCopy.portableSectionSubtitle,
      child: const Column(
        children: <Widget>[
          _InfoRow(
            label: SettingsAboutCopy.portableExportLabel,
            body: SettingsAboutCopy.portableExportBody,
          ),
          SizedBox(height: 10),
          _InfoRow(
            label: SettingsAboutCopy.portableImportLabel,
            body: SettingsAboutCopy.portableImportBody,
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

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
            Color.alphaBlend(cs.primary.withValues(alpha: 0.18), cs.surface),
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
            DecoratedBox(
              decoration: BoxDecoration(
                color: cs.surface.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(Icons.verified_user_outlined, color: cs.primary, size: 28),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              SettingsAboutCopy.securityHeroTitle,
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(
              SettingsAboutCopy.securityHeroBody,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: SettingsAboutCopy.securityChips
                  .map((String label) => _FactChip(label: label))
                  .toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecurityFlowCard extends StatelessWidget {
  const _SecurityFlowCard();

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      title: SettingsAboutCopy.securityFlowSectionTitle,
      subtitle: SettingsAboutCopy.securityFlowSectionSubtitle,
      child: Column(
        children: const <Widget>[
          _FlowStep(
            icon: Icons.edit_note_rounded,
            title: SettingsAboutCopy.securityFlowStep1Title,
            body: SettingsAboutCopy.securityFlowStep1Body,
          ),
          _FlowConnector(),
          _FlowStep(
            icon: Icons.vpn_key_outlined,
            title: SettingsAboutCopy.securityFlowStep2Title,
            body: SettingsAboutCopy.securityFlowStep2Body,
          ),
          _FlowConnector(),
          _FlowStep(
            icon: Icons.lock_rounded,
            title: SettingsAboutCopy.securityFlowStep3Title,
            body: SettingsAboutCopy.securityFlowStep3Body,
          ),
          _FlowConnector(),
          _FlowStep(
            icon: Icons.folder_special_outlined,
            title: SettingsAboutCopy.securityFlowStep4Title,
            body: SettingsAboutCopy.securityFlowStep4Body,
          ),
          _FlowConnector(),
          _FlowSplitStep(),
        ],
      ),
    );
  }
}

class _SecurityHighlightsCard extends StatelessWidget {
  const _SecurityHighlightsCard();

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      title: SettingsAboutCopy.securityHighlightsSectionTitle,
      subtitle: SettingsAboutCopy.securityHighlightsSectionSubtitle,
      child: const Column(
        children: <Widget>[
          _BulletPanel(
            icon: Icons.lock_outline_rounded,
            title: SettingsAboutCopy.securityHighlightEncryptTitle,
            body: SettingsAboutCopy.securityHighlightEncryptBody,
          ),
          SizedBox(height: 10),
          _BulletPanel(
            icon: Icons.security_rounded,
            title: SettingsAboutCopy.securityHighlightScopeTitle,
            body: SettingsAboutCopy.securityHighlightScopeBody,
          ),
          SizedBox(height: 10),
          _BulletPanel(
            icon: Icons.warning_amber_rounded,
            title: SettingsAboutCopy.securityHighlightLimitTitle,
            body: SettingsAboutCopy.securityHighlightLimitBody,
          ),
        ],
      ),
    );
  }
}

class _BackupRestoreCard extends StatelessWidget {
  const _BackupRestoreCard();

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      title: SettingsAboutCopy.securityBackupSectionTitle,
      subtitle: SettingsAboutCopy.securityBackupSectionSubtitle,
      child: const Column(
        children: <Widget>[
          _InfoRow(
            label: SettingsAboutCopy.securityBackupEncryptedLabel,
            body: SettingsAboutCopy.securityBackupEncryptedBody,
          ),
          SizedBox(height: 10),
          _InfoRow(
            label: SettingsAboutCopy.securityBackupUnlockLabel,
            body: SettingsAboutCopy.securityBackupUnlockBody,
          ),
          SizedBox(height: 10),
          _InfoRow(
            label: SettingsAboutCopy.securityBackupOtherLabel,
            body: SettingsAboutCopy.securityBackupOtherBody,
          ),
        ],
      ),
    );
  }
}

class _RecoveryKeyCard extends StatelessWidget {
  const _RecoveryKeyCard();

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      title: SettingsAboutCopy.securityRecoverySectionTitle,
      subtitle: SettingsAboutCopy.securityRecoverySectionSubtitle,
      child: const Column(
        children: <Widget>[
          _BulletPanel(
            icon: Icons.key_rounded,
            title: SettingsAboutCopy.securityRecoveryRoleTitle,
            body: SettingsAboutCopy.securityRecoveryRoleBody,
          ),
          SizedBox(height: 10),
          _BulletPanel(
            icon: Icons.smartphone_rounded,
            title: SettingsAboutCopy.securityRecoveryDeviceTitle,
            body: SettingsAboutCopy.securityRecoveryDeviceBody,
          ),
          SizedBox(height: 10),
          _BulletPanel(
            icon: Icons.history_toggle_off_rounded,
            title: SettingsAboutCopy.securityRecoveryRotateTitle,
            body: SettingsAboutCopy.securityRecoveryRotateBody,
          ),
        ],
      ),
    );
  }
}

class _SecurityLimitsCard extends StatelessWidget {
  const _SecurityLimitsCard();

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      title: SettingsAboutCopy.securityLimitsSectionTitle,
      subtitle: SettingsAboutCopy.securityLimitsSectionSubtitle,
      child: const Column(
        children: <Widget>[
          _InfoRow(
            label: SettingsAboutCopy.securityLimitBackupLabel,
            body: SettingsAboutCopy.securityLimitBackupBody,
          ),
          SizedBox(height: 10),
          _InfoRow(
            label: SettingsAboutCopy.securityLimitKeyLabel,
            body: SettingsAboutCopy.securityLimitKeyBody,
          ),
          SizedBox(height: 10),
          _InfoRow(
            label: SettingsAboutCopy.securityLimitVerifyLabel,
            body: SettingsAboutCopy.securityLimitVerifyBody,
          ),
        ],
      ),
    );
  }
}

class _SectionShell extends StatelessWidget {
  const _SectionShell({
    required this.title,
    required this.subtitle,
    this.child,
  });

  final String title;
  final String subtitle;
  final Widget? child;

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
              title,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            if (child != null) ...<Widget>[
              const SizedBox(height: 16),
              child!,
            ],
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

class _FlowStep extends StatelessWidget {
  const _FlowStep({
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
                child: Icon(icon, color: cs.primary, size: 20),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    body,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.45,
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

class _FlowSplitStep extends StatelessWidget {
  const _FlowSplitStep();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Color.alphaBlend(cs.secondary.withValues(alpha: 0.08), cs.surfaceContainerLow),
        borderRadius: BorderRadius.circular(PageStyle.radiusPanel),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: cs.secondary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(Icons.hub_outlined, color: cs.secondary, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        SettingsAboutCopy.securityFlowStep5Title,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        SettingsAboutCopy.securityFlowStep5Body,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const _FlowRouteCard(
              icon: Icons.smartphone_rounded,
              title: SettingsAboutCopy.securityFlowTrustedTitle,
              badge: SettingsAboutCopy.securityFlowTrustedBadge,
              body: SettingsAboutCopy.securityFlowTrustedBody,
            ),
            const SizedBox(height: 10),
            const _FlowRouteCard(
              icon: Icons.key_rounded,
              title: SettingsAboutCopy.securityFlowRecoveryTitle,
              badge: SettingsAboutCopy.securityFlowRecoveryBadge,
              body: SettingsAboutCopy.securityFlowRecoveryBody,
            ),
          ],
        ),
      ),
    );
  }
}

class _FlowRouteCard extends StatelessWidget {
  const _FlowRouteCard({
    required this.icon,
    required this.title,
    required this.badge,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String badge;
  final String body;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(16),
        border: Border.fromBorderSide(PageStyle.outlineSide(cs, opacity: 0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                color: Color.alphaBlend(cs.secondary.withValues(alpha: 0.12), cs.surface),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(icon, color: cs.secondary, size: 18),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          title,
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: cs.secondary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          child: Text(
                            badge,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: cs.secondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    body,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.45,
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

class _FlowConnector extends StatelessWidget {
  const _FlowConnector();

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Center(
        child: Icon(Icons.south_rounded, color: cs.primary, size: 22),
      ),
    );
  }
}

class _BulletPanel extends StatelessWidget {
  const _BulletPanel({
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
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(PageStyle.radiusPanel),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: cs.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    body,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.45,
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.body,
  });

  final String label;
  final String body;

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
        child: RichText(
          text: TextSpan(
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.5,
            ),
            children: <InlineSpan>[
              TextSpan(
                text: '$label：',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextSpan(text: body),
            ],
          ),
        ),
      ),
    );
  }
}
