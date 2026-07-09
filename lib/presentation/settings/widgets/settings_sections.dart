import 'dart:async' show unawaited;

import 'package:flutter/material.dart';

import 'package:quill_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_diary/infrastructure/security/app_unlock_mode.dart';
import 'package:quill_diary/infrastructure/storage/backup_status_store.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/application/settings/settings_health_level.dart';
import 'package:quill_diary/application/settings/settings_text.dart';
import 'package:quill_diary/presentation/settings/backup_security_overview.dart';
import 'package:quill_diary/presentation/settings/security_overview_item.dart';
import 'package:quill_diary/presentation/session/widgets/session_locked_pane.dart';
import 'package:quill_diary/application/session/state/app_session_state.dart';
import 'package:quill_diary/shared/presentation/app_feedback.dart';
import 'package:quill_diary/shared/presentation/app_typography.dart';
import 'package:quill_diary/shared/presentation/widgets/recovery_key_text_field.dart';
import 'package:quill_diary/app/app_colors.dart';
import 'package:quill_diary/shared/presentation/page_style.dart';

class SettingsSectionCard extends StatelessWidget {
  const SettingsSectionCard({
    required this.title,
    required this.description,
    required this.child,
    this.icon,
    super.key,
  });

  final String title;
  final String description;
  final Widget child;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final AppColors colors = context.appColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.sectionCard,
        borderRadius: BorderRadius.circular(PageStyle.radiusCard),
        border: Border.fromBorderSide(colors.outlineBorder()),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.sectionInset,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Icon(icon, color: cs.primary, size: 22),
                    ),
                  ),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class SettingsActionGroup extends StatelessWidget {
  const SettingsActionGroup({required this.actions, super.key});

  final List<SettingsActionButton> actions;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.appColors.sectionInset,
        borderRadius: BorderRadius.circular(PageStyle.radiusPanel),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (int index = 0; index < actions.length; index++) ...<Widget>[
              if (index > 0) const SizedBox(height: 10),
              actions[index],
            ],
          ],
        ),
      ),
    );
  }
}

class SettingsStatusPanel extends StatelessWidget {
  const SettingsStatusPanel({
    required this.sessionState,
    required this.busy,
    required this.recoveryKeyInputController,
    required this.bannerIcon,
    required this.bannerMessage,
    required this.bannerTone,
    required this.onUnlockWithRecovery,
    this.recoveryKeyHint,
    this.onCancelUnlock,
    this.showBanner = true,
    super.key,
  });

  final AppSessionState sessionState;
  final bool busy;
  final TextEditingController recoveryKeyInputController;
  final String? recoveryKeyHint;
  final IconData bannerIcon;
  final String bannerMessage;
  final AppFeedbackTone bannerTone;
  final VoidCallback? onUnlockWithRecovery;
  final VoidCallback? onCancelUnlock;
  final bool showBanner;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final bool isUnlocking = sessionState.status == AppLockStatus.unlocking;
    final bool needsRecovery =
        sessionState.status == AppLockStatus.recoveryRequired;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (showBanner)
          AppFeedbackBanner(
            icon: bannerIcon,
            message: bannerMessage,
            tone: bannerTone,
          ),
        if (isUnlocking) ...<Widget>[
          if (showBanner) const SizedBox(height: 12),
          Text(
            l10n.settingsSecurityLockUnlockingWaitHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          const Center(child: CircularProgressIndicator()),
          if (onCancelUnlock != null) ...<Widget>[
            const SizedBox(height: 14),
            SettingsActionButton(
              label: l10n.settingsSecurityLockCancelUnlockButton,
              icon: Icons.close_rounded,
              appearance: SettingsActionButtonAppearance.outlined,
              onPressed: busy ? null : onCancelUnlock,
            ),
          ],
        ],
        if (needsRecovery) ...<Widget>[
          if (showBanner || isUnlocking) const SizedBox(height: 16),
          if (recoveryKeyHint != null &&
              recoveryKeyHint!.isNotEmpty) ...<Widget>[
            Text(
              settingsRecoveryKeyHintLine(l10n, recoveryKeyHint!),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
          ],
          RecoveryKeyTextField(controller: recoveryKeyInputController),
          const SizedBox(height: 12),
          Text(
            l10n.settingsSecurityLockRecoveryUnlockHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          SettingsActionButton(
            label: l10n.settingsSecurityLockUnlockWithRecoveryButton,
            icon: Icons.lock_open_rounded,
            appearance: SettingsActionButtonAppearance.filled,
            onPressed: busy ? null : onUnlockWithRecovery,
          ),
        ],
      ],
    );
  }
}

class RecoveryKeySectionBody extends StatelessWidget {
  const RecoveryKeySectionBody({
    required this.metadata,
    required this.busy,
    required this.onCreateRecoveryKey,
    this.onRotateRecoveryKey,
    this.showActions = true,
    super.key,
  });

  final RecoveryMetadata? metadata;
  final bool busy;
  final VoidCallback? onCreateRecoveryKey;
  final VoidCallback? onRotateRecoveryKey;
  final bool showActions;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final RecoveryMetadata? currentMetadata = metadata;
    if (currentMetadata == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AppFeedbackBanner(
            icon: Icons.key_off_outlined,
            message: l10n.settingsRecoveryKeyNotSetupBanner,
            tone: AppFeedbackTone.warning,
          ),
          if (showActions) ...<Widget>[
            const SizedBox(height: 14),
            SettingsActionButton(
              label: l10n.settingsRecoveryKeyCreateButton,
              icon: Icons.key_outlined,
              appearance: SettingsActionButtonAppearance.filled,
              onPressed: busy ? null : onCreateRecoveryKey,
            ),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AppFeedbackBanner(
          icon: Icons.verified_user_outlined,
          message: l10n.settingsRecoveryKeySetupBanner,
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            SettingsFactChip(
              label: l10n.settingsRecoveryKeyFactVaultLabel,
              value: currentMetadata.vaultId,
            ),
            SettingsFactChip(
              label: l10n.settingsRecoveryKeyFactHintLabel,
              value: currentMetadata.recoveryKeyHint,
            ),
            SettingsFactChip(
              label: l10n.settingsRecoveryKeyFactKdfLabel,
              value: currentMetadata.kdf.name,
            ),
          ],
        ),
        if (showActions && onRotateRecoveryKey != null) ...<Widget>[
          const SizedBox(height: 14),
          SettingsActionButton(
            label: l10n.settingsRecoveryKeyRotateButton,
            icon: Icons.lock_reset_outlined,
            appearance: SettingsActionButtonAppearance.tonal,
            onPressed: busy ? null : onRotateRecoveryKey,
          ),
        ],
      ],
    );
  }
}

class UnlockMethodSectionBody extends StatelessWidget {
  const UnlockMethodSectionBody({
    required this.enabled,
    required this.changeAllowed,
    required this.busy,
    required this.unlockMode,
    required this.onModeSelected,
    super.key,
  });

  final bool enabled;
  final bool changeAllowed;
  final bool busy;
  final AppUnlockMode unlockMode;
  final Future<void> Function(AppUnlockMode mode) onModeSelected;

  static String descriptionForMode(AppLocalizations l10n, AppUnlockMode mode) {
    return mode.description(l10n);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    if (!enabled) {
      return _UnlockModeChoiceBar(
        selected: unlockMode,
        busy: true,
        onSelected: onModeSelected,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _UnlockModeChoiceBar(
          selected: unlockMode,
          busy: busy || !changeAllowed,
          onSelected: onModeSelected,
        ),
        if (!changeAllowed) ...<Widget>[
          const SizedBox(height: 10),
          AppFeedbackBanner(
            icon: Icons.info_outline_rounded,
            message: l10n.sessionUnlockModeChangeNeedsUnlockMessage,
          ),
        ],
        const SizedBox(height: 12),
        Text(
          descriptionForMode(l10n, unlockMode),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _UnlockModeChoiceBar extends StatelessWidget {
  const _UnlockModeChoiceBar({
    required this.selected,
    required this.busy,
    required this.onSelected,
  });

  final AppUnlockMode selected;
  final bool busy;
  final Future<void> Function(AppUnlockMode mode) onSelected;

  static List<({AppUnlockMode mode, int flex, IconData icon, String label})>
  _choices(AppLocalizations l10n) =>
      <({AppUnlockMode mode, int flex, IconData icon, String label})>[
        (
          mode: AppUnlockMode.none,
          flex: 2,
          icon: Icons.no_encryption_gmailerrorred_outlined,
          label: l10n.settingsUnlockMethodSegmentNone,
        ),
        (
          mode: AppUnlockMode.deviceLock,
          flex: 3,
          icon: Icons.lock_outline,
          label: l10n.settingsUnlockMethodSegmentDeviceLock,
        ),
        (
          mode: AppUnlockMode.biometric,
          flex: 4,
          icon: Icons.fingerprint_rounded,
          label: l10n.settingsUnlockMethodSegmentBiometric,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final List<({AppUnlockMode mode, int flex, IconData icon, String label})>
    choices = _choices(context.l10n);
    return SettingsSegmentedChoiceBar<AppUnlockMode>(
      choices: choices
          .map(
            (
              ({int flex, IconData icon, String label, AppUnlockMode mode})
              choice,
            ) => SettingsSegmentChoice<AppUnlockMode>(
              value: choice.mode,
              label: choice.label,
              icon: choice.icon,
              flex: choice.flex,
            ),
          )
          .toList(growable: false),
      selected: selected,
      busy: busy,
      onSelected: onSelected,
    );
  }
}

class SettingsSegmentChoice<T> {
  const SettingsSegmentChoice({
    required this.value,
    required this.label,
    this.icon,
    this.flex = 2,
    this.enabled = true,
  });

  final T value;
  final String label;
  final IconData? icon;
  final int flex;
  final bool enabled;
}

class SettingsSegmentedChoiceBar<T> extends StatelessWidget {
  const SettingsSegmentedChoiceBar({
    required this.choices,
    required this.selected,
    required this.onSelected,
    this.busy = false,
    super.key,
  });

  final List<SettingsSegmentChoice<T>> choices;
  final T selected;
  final bool busy;
  final Future<void> Function(T value) onSelected;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(PageStyle.radiusPanel),
      child: Row(
        children: <Widget>[
          for (var index = 0; index < choices.length; index++) ...<Widget>[
            if (index > 0)
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: cs.outlineVariant.withValues(alpha: 0.35),
              ),
            Expanded(
              flex: choices[index].flex,
              child: _SettingsSegment(
                label: choices[index].label,
                icon: choices[index].icon,
                selected: selected == choices[index].value,
                enabled: choices[index].enabled && !busy,
                onTap: choices[index].enabled && !busy
                    ? () => unawaited(onSelected(choices[index].value))
                    : null,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SettingsSegment extends StatelessWidget {
  const _SettingsSegment({
    required this.label,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final TextStyle? labelStyle = Theme.of(context).textTheme.labelLarge
        ?.copyWith(
          color: selected
              ? cs.onPrimaryContainer
              : enabled
              ? cs.onSurfaceVariant
              : cs.onSurfaceVariant.withValues(alpha: 0.45),
        );
    return Material(
      color: selected
          ? cs.primaryContainer
          : cs.surfaceContainerHighest.withValues(alpha: enabled ? 0.55 : 0.35),
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(
                  icon,
                  size: 18,
                  color: selected
                      ? cs.onPrimaryContainer
                      : enabled
                      ? cs.onSurfaceVariant
                      : cs.onSurfaceVariant.withValues(alpha: 0.45),
                ),
                const SizedBox(height: 4),
              ],
              Text(
                label,
                style: labelStyle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                softWrap: true,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum SettingsActionButtonAppearance { outlined, tonal, filled, destructive }

class SettingsActionButton extends StatelessWidget {
  const SettingsActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.emphasized = false,
    this.appearance = SettingsActionButtonAppearance.outlined,
    this.fullWidth = false,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool emphasized;
  final SettingsActionButtonAppearance appearance;
  final bool fullWidth;

  SettingsActionButtonAppearance get _resolvedAppearance {
    if (emphasized) {
      return SettingsActionButtonAppearance.filled;
    }
    return appearance;
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final bool isDark = colorScheme.brightness == Brightness.dark;
    final ({Color background, Color foreground}) filledColors = isDark
        ? (
            background: colorScheme.primaryContainer,
            foreground: colorScheme.onPrimaryContainer,
          )
        : (background: colorScheme.primary, foreground: colorScheme.onPrimary);
    final ({Color background, Color foreground}) tonalColors = isDark
        ? (
            background: colorScheme.surfaceContainerHighest,
            foreground: colorScheme.onSurface,
          )
        : (
            background: colorScheme.secondaryContainer,
            foreground: colorScheme.onSecondaryContainer,
          );
    final Widget button = switch (_resolvedAppearance) {
      SettingsActionButtonAppearance.filled => FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: filledColors.background,
          foregroundColor: filledColors.foreground,
        ),
        icon: Icon(icon),
        label: Text(label),
      ),
      SettingsActionButtonAppearance.tonal => FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: tonalColors.background,
          foregroundColor: tonalColors.foreground,
          side: isDark
              ? BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.72),
                )
              : null,
        ),
        icon: Icon(icon),
        label: Text(label),
      ),
      SettingsActionButtonAppearance.destructive => OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(foregroundColor: colorScheme.error),
        icon: Icon(icon, color: colorScheme.error),
        label: Text(label),
      ),
      SettingsActionButtonAppearance.outlined => OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          side: BorderSide(color: colorScheme.outline),
        ),
        icon: Icon(icon),
        label: Text(label),
      ),
    };
    if (!fullWidth) {
      return button;
    }
    return SizedBox(width: double.infinity, child: button);
  }
}

class SettingsFactChip extends StatelessWidget {
  const SettingsFactChip({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          '$label嚗?value',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class SettingsSectionLoading extends StatelessWidget {
  const SettingsSectionLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class SettingsSecurityOverview extends StatelessWidget {
  const SettingsSecurityOverview({
    required this.hasRecoveryKey,
    required this.recoveryKeyHint,
    required this.hasUnlockedSession,
    required this.hasTrustedDevice,
    required this.unlockModeLabel,
    required this.indexMessage,
    required this.indexHealthLevel,
    required this.backupStatus,
    required this.busy,
    required this.onCreateRecoveryKey,
    required this.onRotateRecoveryKey,
    required this.onRepairVault,
    this.onRetryTrustedUnlock,
    required this.lockPanel,
    super.key,
  });

  final bool hasRecoveryKey;
  final String? recoveryKeyHint;
  final bool hasUnlockedSession;
  final bool hasTrustedDevice;
  final String unlockModeLabel;
  final String indexMessage;
  final SettingsHealthLevel indexHealthLevel;
  final BackupStatusSnapshot backupStatus;
  final bool busy;
  final VoidCallback? onCreateRecoveryKey;
  final VoidCallback? onRotateRecoveryKey;
  final VoidCallback? onRepairVault;
  final VoidCallback? onRetryTrustedUnlock;
  final Widget? lockPanel;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final DateTime now = DateTime.now();
    final SecurityOverviewItem localBackupItem =
        settingsLocalBackupSecurityOverview(l10n, backupStatus, now);
    final SecurityOverviewItem driveBackupItem =
        settingsDriveBackupSecurityOverview(l10n, backupStatus, now);
    final List<SecurityOverviewItem> items = <SecurityOverviewItem>[
      SecurityOverviewItem(
        icon: Icons.key_outlined,
        title: l10n.settingsSecurityOverviewRecoveryKeyTitle,
        message: hasRecoveryKey
            ? l10n.settingsSecurityOverviewRecoveryKeyReady
            : l10n.settingsSecurityOverviewRecoveryKeyMissing,
        subtitle: hasRecoveryKey
            ? settingsRecoveryKeyHintLine(l10n, recoveryKeyHint ?? '----')
            : null,
        level: hasRecoveryKey
            ? SettingsHealthLevel.ok
            : SettingsHealthLevel.warning,
      ),
      SecurityOverviewItem(
        icon: Icons.phonelink_lock_outlined,
        title: l10n.settingsSecurityOverviewUnlockModeTitle,
        message: hasRecoveryKey
            ? settingsSecurityOverviewUnlockModeProtectedMessage(
                l10n,
                unlockModeLabel,
              )
            : l10n.settingsSecurityOverviewUnlockModeNeedsRecoveryKeyMessage,
        level: hasRecoveryKey
            ? SettingsHealthLevel.ok
            : SettingsHealthLevel.warning,
      ),
      SecurityOverviewItem(
        icon: Icons.verified_user_outlined,
        title: l10n.settingsSecurityOverviewTrustedDeviceTitle,
        message: hasTrustedDevice
            ? l10n.settingsSecurityOverviewTrustedDeviceReady
            : l10n.settingsSecurityOverviewTrustedDeviceMissing,
        level: hasTrustedDevice
            ? SettingsHealthLevel.ok
            : SettingsHealthLevel.warning,
      ),
      SecurityOverviewItem(
        icon: Icons.storage_rounded,
        title: l10n.settingsSecurityOverviewIndexTitle,
        message: indexMessage,
        level: indexHealthLevel,
      ),
      localBackupItem,
      driveBackupItem,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items
              .map((item) => _SecurityOverviewTile(item: item, l10n: l10n))
              .toList(growable: false),
        ),
        const SizedBox(height: 14),
        SettingsActionGroup(
          actions: <SettingsActionButton>[
            SettingsActionButton(
              label: hasRecoveryKey
                  ? l10n.settingsSecurityOverviewRotateRecoveryKeyButton
                  : l10n.settingsSecurityOverviewCreateRecoveryKeyButton,
              icon: hasRecoveryKey
                  ? Icons.lock_reset_outlined
                  : Icons.key_outlined,
              appearance: hasRecoveryKey
                  ? SettingsActionButtonAppearance.tonal
                  : SettingsActionButtonAppearance.filled,
              onPressed: busy
                  ? null
                  : hasRecoveryKey
                  ? onRotateRecoveryKey
                  : onCreateRecoveryKey,
            ),
            SettingsActionButton(
              label: l10n.settingsSecurityOverviewRepairVaultButton,
              icon: Icons.build_outlined,
              appearance: SettingsActionButtonAppearance.outlined,
              onPressed: busy ? null : onRepairVault,
            ),
            if (onRetryTrustedUnlock != null)
              SettingsActionButton(
                label: l10n.settingsSecurityLockRetryVerificationButton,
                icon: kSessionRetryVerificationIcon,
                appearance: SettingsActionButtonAppearance.filled,
                onPressed: busy ? null : onRetryTrustedUnlock,
              ),
          ],
        ),
        if (lockPanel != null) ...<Widget>[
          const SizedBox(height: 14),
          lockPanel!,
        ],
      ],
    );
  }
}

class _SecurityOverviewTile extends StatelessWidget {
  const _SecurityOverviewTile({required this.item, required this.l10n});

  final SecurityOverviewItem item;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColors colors = context.appColors;
    final Color background = switch (item.level) {
      SettingsHealthLevel.ok => colors.healthOkFill,
      SettingsHealthLevel.warning => colors.healthWarningFill,
      SettingsHealthLevel.error => colors.healthErrorFill,
    };
    final Color foreground = switch (item.level) {
      SettingsHealthLevel.ok => colors.healthOkForeground,
      SettingsHealthLevel.warning => colors.healthWarningForeground,
      SettingsHealthLevel.error => colors.healthErrorForeground,
    };
    final IconData statusIcon = switch (item.level) {
      SettingsHealthLevel.ok => Icons.check_circle_outline_rounded,
      SettingsHealthLevel.warning => Icons.info_outline_rounded,
      SettingsHealthLevel.error => Icons.error_outline_rounded,
    };
    final String statusLabel = switch (item.level) {
      SettingsHealthLevel.ok => l10n.settingsSecurityOverviewHealthLevelOk,
      SettingsHealthLevel.warning =>
        l10n.settingsSecurityOverviewHealthLevelWarning,
      SettingsHealthLevel.error =>
        l10n.settingsSecurityOverviewHealthLevelError,
    };

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 230, maxWidth: 520),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(PageStyle.radiusPanel),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(item.icon, color: foreground),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            item.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: foreground,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Icon(statusIcon, size: 16, color: foreground),
                        const SizedBox(width: 4),
                        Text(
                          statusLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: foreground,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.message,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: foreground,
                        height: 1.35,
                      ),
                    ),
                    if (item.subtitle != null) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        item.subtitle!,
                        style:
                            AppTypography.mono(
                              theme.textTheme.bodySmall ?? const TextStyle(),
                            ).copyWith(
                              color: foreground,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.6,
                              height: 1.35,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsBlockingProgressOverlay extends StatelessWidget {
  const SettingsBlockingProgressOverlay({
    required this.message,
    this.progress,
    super.key,
  });

  final String message;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final AppColors colors = context.appColors;
    final double? clampedProgress = progress?.clamp(0.0, 1.0);
    return Positioned.fill(
      child: ColoredBox(
        color: colors.overlayDim,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(PageStyle.radiusCard),
                border: Border.fromBorderSide(colors.outlineBorder()),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (clampedProgress == null)
                      const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      )
                    else
                      LinearProgressIndicator(
                        value: clampedProgress,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    const SizedBox(height: 14),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
