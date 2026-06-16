import 'dart:async' show unawaited;

import 'package:flutter/material.dart';

import '../../../domain/recovery/recovery_metadata.dart';
import '../../../infrastructure/security/app_unlock_mode.dart';
import '../../../l10n/l10n.dart';
import '../settings_messages.dart';
import '../../session/state/app_session_state.dart';
import '../../../shared/presentation/app_typography.dart';
import '../../../shared/presentation/page_style.dart';

/// 設定頁可重用的提示色系。
enum SettingsBannerTone { neutral, warning, error }

/// 設定頁的標準卡片容器，統一標題、說明與外框風格。
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color.alphaBlend(
                        cs.primary.withValues(alpha: 0.08),
                        cs.surfaceContainerLow,
                      ),
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

/// 將多個設定動作按鈕排成一致的全寬直向列表。
class SettingsActionGroup extends StatelessWidget {
  const SettingsActionGroup({required this.actions, super.key});

  final List<SettingsActionButton> actions;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
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

/// 顯示目前 session 狀態，並在需要時提供 Recovery Key 解鎖入口。
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
    this.onRetryTrustedUnlock,
    this.onCancelUnlock,
    super.key,
  });

  final AppSessionState sessionState;
  final bool busy;
  final TextEditingController recoveryKeyInputController;
  final String? recoveryKeyHint;
  final IconData bannerIcon;
  final String bannerMessage;
  final SettingsBannerTone bannerTone;
  final VoidCallback? onUnlockWithRecovery;
  final VoidCallback? onRetryTrustedUnlock;
  final VoidCallback? onCancelUnlock;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final bool isUnlocking = sessionState.status == AppLockStatus.unlocking;
    final bool isLocked = sessionState.status == AppLockStatus.locked;
    final bool needsRecovery =
        sessionState.status == AppLockStatus.recoveryRequired;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SettingsInfoBanner(
          icon: bannerIcon,
          message: bannerMessage,
          tone: bannerTone,
        ),
        if (isUnlocking) ...<Widget>[
          const SizedBox(height: 12),
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
        if (isLocked) ...<Widget>[
          if (onRetryTrustedUnlock != null) ...<Widget>[
            const SizedBox(height: 10),
            SettingsActionButton(
              label: l10n.settingsSecurityLockRetryVerificationButton,
              icon: Icons.lock_open_rounded,
              appearance: SettingsActionButtonAppearance.filled,
              onPressed: busy ? null : onRetryTrustedUnlock,
            ),
          ],
        ],
        if (needsRecovery) ...<Widget>[
          const SizedBox(height: 16),
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
          TextField(
            controller: recoveryKeyInputController,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: l10n.settingsRecoveryKeyFieldLabel,
              hintText: l10n.settingsRecoveryKeyFieldHint,
            ),
          ),
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

/// 顯示 Recovery Key 是否已建立，以及必要的建立入口與中繼資料。
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
          SettingsInfoBanner(
            icon: Icons.key_off_outlined,
            message: l10n.settingsRecoveryKeyNotSetupBanner,
            tone: SettingsBannerTone.warning,
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
        SettingsInfoBanner(
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

/// 解鎖方式：無 / 裝置螢幕鎖 / 生物驗證。
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
    if (!enabled) {
      return SettingsInfoBanner(
        icon: Icons.lock_outline,
        message: l10n.settingsUnlockMethodNeedsRecoveryKeyBanner,
        tone: SettingsBannerTone.warning,
      );
    }

    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
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
          SettingsInfoBanner(
            icon: Icons.info_outline_rounded,
            message: l10n.sessionUnlockModeChangeNeedsUnlockMessage,
            tone: SettingsBannerTone.neutral,
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
        if (unlockMode == AppUnlockMode.biometric) ...<Widget>[
          const SizedBox(height: 10),
          SettingsInfoBanner(
            icon: Icons.info_outline_rounded,
            message: l10n.settingsUnlockMethodBiometricNeedsDeviceLockHint,
            tone: SettingsBannerTone.neutral,
          ),
        ],
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
              child: _UnlockModeSegment(
                label: choices[index].label,
                icon: choices[index].icon,
                selected: selected == choices[index].mode,
                compact: choices[index].mode == AppUnlockMode.none,
                onTap: busy
                    ? null
                    : () => unawaited(onSelected(choices[index].mode)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UnlockModeSegment extends StatelessWidget {
  const _UnlockModeSegment({
    required this.label,
    required this.icon,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool multiline = !compact && label.length > 8;
    final TextStyle? labelStyle = Theme.of(context).textTheme.labelLarge
        ?.copyWith(
          color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
          fontSize: compact ? 13 : null,
        );
    return Material(
      color: selected
          ? cs.primaryContainer
          : cs.surfaceContainerHighest.withValues(alpha: 0.55),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 6 : 8,
            vertical: compact ? 10 : (multiline ? 8 : 10),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                icon,
                size: 18,
                color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: labelStyle,
                maxLines: multiline ? 2 : 1,
                overflow: multiline
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
                softWrap: multiline,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 設定頁動作按鈕的外觀層級。
enum SettingsActionButtonAppearance { outlined, tonal, filled, destructive }

/// 設定頁使用的標準動作按鈕，可切換成主要或次要樣式。
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
    final Widget button = switch (_resolvedAppearance) {
      SettingsActionButtonAppearance.filled => FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
      ),
      SettingsActionButtonAppearance.tonal => FilledButton.tonalIcon(
        onPressed: onPressed,
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

/// 顯示中性、警告或錯誤訊息的設定頁橫幅。
class SettingsInfoBanner extends StatelessWidget {
  const SettingsInfoBanner({
    required this.icon,
    required this.message,
    this.tone = SettingsBannerTone.neutral,
    super.key,
  });

  final IconData icon;
  final String message;
  final SettingsBannerTone tone;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color background = switch (tone) {
      SettingsBannerTone.neutral => theme.colorScheme.surfaceContainerLow,
      SettingsBannerTone.warning => theme.colorScheme.secondaryContainer,
      SettingsBannerTone.error => theme.colorScheme.errorContainer,
    };
    final Color foreground = switch (tone) {
      SettingsBannerTone.neutral => theme.colorScheme.onSurface,
      SettingsBannerTone.warning => theme.colorScheme.onSecondaryContainer,
      SettingsBannerTone.error => theme.colorScheme.onErrorContainer,
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(PageStyle.radiusPanel),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: foreground),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 顯示 Recovery Key 中繼資料等短資訊的膠囊樣式元件。
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
          '$label：$value',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// 區塊資料還在載入時使用的簡單佔位元件。
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

enum SettingsHealthLevel { ok, warning, error }

class SettingsSecurityOverview extends StatelessWidget {
  const SettingsSecurityOverview({
    required this.hasRecoveryKey,
    required this.recoveryKeyHint,
    required this.hasUnlockedSession,
    required this.hasTrustedDevice,
    required this.unlockModeLabel,
    required this.indexMessage,
    required this.busy,
    required this.onCreateRecoveryKey,
    required this.onRotateRecoveryKey,
    required this.onRebuildIndex,
    required this.lockPanel,
    super.key,
  });

  final bool hasRecoveryKey;
  final String? recoveryKeyHint;
  final bool hasUnlockedSession;
  final bool hasTrustedDevice;
  final String unlockModeLabel;
  final String indexMessage;
  final bool busy;
  final VoidCallback? onCreateRecoveryKey;
  final VoidCallback? onRotateRecoveryKey;
  final VoidCallback? onRebuildIndex;
  final Widget? lockPanel;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<_SecurityOverviewItem> items = <_SecurityOverviewItem>[
      _SecurityOverviewItem(
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
      _SecurityOverviewItem(
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
      _SecurityOverviewItem(
        icon: Icons.verified_user_outlined,
        title: l10n.settingsSecurityOverviewTrustedDeviceTitle,
        message: hasTrustedDevice
            ? l10n.settingsSecurityOverviewTrustedDeviceReady
            : l10n.settingsSecurityOverviewTrustedDeviceMissing,
        level: hasTrustedDevice
            ? SettingsHealthLevel.ok
            : SettingsHealthLevel.warning,
      ),
      _SecurityOverviewItem(
        icon: Icons.storage_rounded,
        title: l10n.settingsSecurityOverviewIndexTitle,
        message: hasUnlockedSession
            ? indexMessage
            : l10n.settingsIndexLockedMessage,
        level: hasUnlockedSession
            ? SettingsHealthLevel.ok
            : SettingsHealthLevel.warning,
      ),
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
              label: l10n.settingsSecurityOverviewRebuildIndexButton,
              icon: Icons.manage_search_outlined,
              appearance: SettingsActionButtonAppearance.outlined,
              onPressed: busy ? null : onRebuildIndex,
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

class _SecurityOverviewItem {
  const _SecurityOverviewItem({
    required this.icon,
    required this.title,
    required this.message,
    required this.level,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? subtitle;
  final SettingsHealthLevel level;
}

class _SecurityOverviewTile extends StatelessWidget {
  const _SecurityOverviewTile({required this.item, required this.l10n});

  final _SecurityOverviewItem item;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final Color background = switch (item.level) {
      SettingsHealthLevel.ok => Color.alphaBlend(
        cs.primary.withValues(alpha: 0.08),
        cs.surfaceContainerLow,
      ),
      SettingsHealthLevel.warning => cs.secondaryContainer.withValues(
        alpha: 0.75,
      ),
      SettingsHealthLevel.error => cs.errorContainer,
    };
    final Color foreground = switch (item.level) {
      SettingsHealthLevel.ok => cs.onSurface,
      SettingsHealthLevel.warning => cs.onSecondaryContainer,
      SettingsHealthLevel.error => cs.onErrorContainer,
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
    final double? clampedProgress = progress?.clamp(0.0, 1.0);
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.18),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(PageStyle.radiusCard),
                border: Border.fromBorderSide(PageStyle.outlineSide(cs)),
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
