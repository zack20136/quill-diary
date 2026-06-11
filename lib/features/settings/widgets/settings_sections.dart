import 'dart:async' show unawaited;

import 'package:flutter/material.dart';

import '../../../domain/recovery/recovery_metadata.dart';
import '../../../infrastructure/security/app_unlock_mode.dart';
import '../settings_copy.dart';
import '../../session/session_messages.dart';
import '../../session/state/app_session_state.dart';
import '../../../shared/presentation/app_typography.dart';
import '../../../shared/presentation/page_style.dart';

/// 設定頁可重用的提示色系。
enum SettingsBannerTone {
  neutral,
  warning,
  error,
}

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
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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
  const SettingsActionGroup({
    required this.actions,
    super.key,
  });

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
    final ThemeData theme = Theme.of(context);
    final bool isUnlocking = sessionState.status == AppLockStatus.unlocking;
    final bool isLocked = sessionState.status == AppLockStatus.locked;
    final bool needsRecovery = sessionState.status == AppLockStatus.recoveryRequired;
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
            SettingsSecurityLockCopy.unlockingWaitHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          const Center(child: CircularProgressIndicator()),
          if (onCancelUnlock != null) ...<Widget>[
            const SizedBox(height: 14),
            SettingsActionButton(
              label: SettingsSecurityLockCopy.cancelUnlockButton,
              icon: Icons.close_rounded,
              onPressed: busy ? null : onCancelUnlock,
            ),
          ],
        ],
        if (isLocked) ...<Widget>[
          if (onRetryTrustedUnlock != null) ...<Widget>[
            const SizedBox(height: 10),
            SettingsActionButton(
              label: SettingsSecurityLockCopy.retryVerificationButton,
              icon: Icons.lock_open_rounded,
              emphasized: true,
              onPressed: busy ? null : onRetryTrustedUnlock,
            ),
          ],
        ],
        if (needsRecovery) ...<Widget>[
          const SizedBox(height: 16),
          if (recoveryKeyHint != null && recoveryKeyHint!.isNotEmpty) ...<Widget>[
            Text(
              SettingsCopy.recoveryKeyHintLine(recoveryKeyHint!),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: recoveryKeyInputController,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: SettingsCopy.recoveryKeyFieldLabel,
              hintText: SettingsCopy.recoveryKeyFieldHint,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            SettingsSecurityLockCopy.recoveryUnlockHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          SettingsActionButton(
            label: SettingsSecurityLockCopy.unlockWithRecoveryButton,
            icon: Icons.lock_open_rounded,
            emphasized: true,
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
    final RecoveryMetadata? currentMetadata = metadata;
    if (currentMetadata == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SettingsInfoBanner(
            icon: Icons.key_off_outlined,
            message: SettingsRecoveryKeyCopy.notSetupBanner,
            tone: SettingsBannerTone.warning,
          ),
          if (showActions) ...<Widget>[
            const SizedBox(height: 14),
            SettingsActionButton(
              label: SettingsRecoveryKeyCopy.createButton,
              icon: Icons.key_outlined,
              emphasized: true,
              onPressed: busy ? null : onCreateRecoveryKey,
            ),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SettingsInfoBanner(
          icon: Icons.verified_user_outlined,
          message: SettingsRecoveryKeyCopy.setupBanner,
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            SettingsFactChip(
              label: SettingsRecoveryKeyCopy.factVaultLabel,
              value: currentMetadata.vaultId,
            ),
            SettingsFactChip(
              label: SettingsRecoveryKeyCopy.factHintLabel,
              value: currentMetadata.recoveryKeyHint,
            ),
            SettingsFactChip(
              label: SettingsRecoveryKeyCopy.factKdfLabel,
              value: currentMetadata.kdf.name,
            ),
          ],
        ),
        if (showActions && onRotateRecoveryKey != null) ...<Widget>[
          const SizedBox(height: 14),
          SettingsActionButton(
            label: SettingsRecoveryKeyCopy.rotateButton,
            icon: Icons.lock_reset_outlined,
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

  static String descriptionForMode(AppUnlockMode mode) {
    return SettingsUnlockMethodCopy.unlockModeDescription(mode);
  }

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return const SettingsInfoBanner(
        icon: Icons.lock_outline,
        message: SettingsUnlockMethodCopy.needsRecoveryKeyBanner,
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
          const SettingsInfoBanner(
            icon: Icons.info_outline_rounded,
            message: kUnlockModeChangeNeedsUnlockMessage,
            tone: SettingsBannerTone.neutral,
          ),
        ],
        const SizedBox(height: 12),
        Text(
          descriptionForMode(unlockMode),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.45,
          ),
        ),
        if (unlockMode == AppUnlockMode.biometric) ...<Widget>[
          const SizedBox(height: 10),
          const SettingsInfoBanner(
            icon: Icons.info_outline_rounded,
            message: SettingsUnlockMethodCopy.biometricNeedsDeviceLockHint,
            tone: SettingsBannerTone.neutral,
          ),
        ],
      ],
    );
  }
}

/// 解鎖方式分段列：無（窄） / 螢幕鎖 / 生物驗證（寬）。
class _UnlockModeChoiceBar extends StatelessWidget {
  const _UnlockModeChoiceBar({
    required this.selected,
    required this.busy,
    required this.onSelected,
  });

  final AppUnlockMode selected;
  final bool busy;
  final Future<void> Function(AppUnlockMode mode) onSelected;

  static const List<({AppUnlockMode mode, int flex, IconData icon, String label})> _choices =
      <({AppUnlockMode mode, int flex, IconData icon, String label})>[
    (
      mode: AppUnlockMode.none,
      flex: 2,
      icon: Icons.no_encryption_gmailerrorred_outlined,
      label: SettingsUnlockMethodCopy.segmentNone,
    ),
    (
      mode: AppUnlockMode.deviceLock,
      flex: 3,
      icon: Icons.lock_outline,
      label: SettingsUnlockMethodCopy.segmentDeviceLock,
    ),
    (
      mode: AppUnlockMode.biometric,
      flex: 4,
      icon: Icons.fingerprint_rounded,
      label: SettingsUnlockMethodCopy.segmentBiometric,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(PageStyle.radiusPanel),
      child: Row(
        children: <Widget>[
          for (var index = 0; index < _choices.length; index++) ...<Widget>[
            if (index > 0)
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: cs.outlineVariant.withValues(alpha: 0.35),
              ),
            Expanded(
              flex: _choices[index].flex,
              child: _UnlockModeSegment(
                label: _choices[index].label,
                icon: _choices[index].icon,
                selected: selected == _choices[index].mode,
                compact: _choices[index].mode == AppUnlockMode.none,
                onTap: busy
                    ? null
                    : () => unawaited(onSelected(_choices[index].mode)),
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
    final TextStyle? labelStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
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
            vertical: compact ? 10 : 12,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                icon,
                size: 18,
                color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: labelStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 設定頁使用的標準動作按鈕，可切換成主要或次要樣式。
class SettingsActionButton extends StatelessWidget {
  const SettingsActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.emphasized = false,
    this.fullWidth = false,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool emphasized;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final Widget button = emphasized
        ? FilledButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label),
          )
        : OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label),
          );
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
  const SettingsFactChip({
    required this.label,
    required this.value,
    super.key,
  });

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
          style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
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
    final List<_SecurityOverviewItem> items = <_SecurityOverviewItem>[
      _SecurityOverviewItem(
        icon: Icons.key_outlined,
        title: SettingsSecurityOverviewCopy.recoveryKeyTitle,
        message: hasRecoveryKey
            ? SettingsSecurityOverviewCopy.recoveryKeyReadySaved
            : SettingsSecurityOverviewCopy.recoveryKeyMissingOverview,
        subtitle: hasRecoveryKey
            ? SettingsCopy.recoveryKeyHintLine(recoveryKeyHint ?? '----')
            : null,
        level: hasRecoveryKey ? SettingsHealthLevel.ok : SettingsHealthLevel.warning,
      ),
      _SecurityOverviewItem(
        icon: Icons.phonelink_lock_outlined,
        title: SettingsSecurityOverviewCopy.unlockModeTitle,
        message: hasRecoveryKey
            ? SettingsSecurityOverviewCopy.unlockModeProtectedMessage(unlockModeLabel)
            : SettingsSecurityOverviewCopy.unlockModeNeedsRecoveryKeyMessage,
        level: hasRecoveryKey ? SettingsHealthLevel.ok : SettingsHealthLevel.warning,
      ),
      _SecurityOverviewItem(
        icon: Icons.verified_user_outlined,
        title: SettingsSecurityOverviewCopy.trustedDeviceTitle,
        message: hasTrustedDevice
            ? SettingsSecurityOverviewCopy.trustedDeviceReadyOverview
            : SettingsSecurityOverviewCopy.trustedDeviceMissing,
        level: hasTrustedDevice ? SettingsHealthLevel.ok : SettingsHealthLevel.warning,
      ),
      _SecurityOverviewItem(
        icon: Icons.storage_rounded,
        title: SettingsSecurityOverviewCopy.indexTitle,
        message: hasUnlockedSession ? indexMessage : SettingsIndexCopy.lockedOverviewMessage,
        level: hasUnlockedSession ? SettingsHealthLevel.ok : SettingsHealthLevel.warning,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items
              .map((item) => _SecurityOverviewTile(item: item))
              .toList(growable: false),
        ),
        const SizedBox(height: 14),
        SettingsActionGroup(
          actions: <SettingsActionButton>[
            SettingsActionButton(
              label: hasRecoveryKey
                  ? SettingsSecurityOverviewCopy.rotateRecoveryKeyButton
                  : SettingsSecurityOverviewCopy.createRecoveryKeyButton,
              icon: hasRecoveryKey ? Icons.lock_reset_outlined : Icons.key_outlined,
              emphasized: !hasRecoveryKey,
              onPressed: busy
                  ? null
                  : hasRecoveryKey
                      ? onRotateRecoveryKey
                      : onCreateRecoveryKey,
            ),
            SettingsActionButton(
              label: SettingsSecurityOverviewCopy.rebuildIndexButton,
              icon: Icons.manage_search_outlined,
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
  const _SecurityOverviewTile({required this.item});

  final _SecurityOverviewItem item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final Color background = switch (item.level) {
      SettingsHealthLevel.ok => Color.alphaBlend(
          cs.primary.withValues(alpha: 0.08),
          cs.surfaceContainerLow,
        ),
      SettingsHealthLevel.warning => cs.secondaryContainer.withValues(alpha: 0.75),
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
      SettingsHealthLevel.ok => SettingsSecurityOverviewCopy.healthLevelOk,
      SettingsHealthLevel.warning => SettingsSecurityOverviewCopy.healthLevelWarning,
      SettingsHealthLevel.error => SettingsSecurityOverviewCopy.healthLevelError,
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
                        style: AppTypography.mono(
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
    super.key,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.18),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(PageStyle.radiusCard),
                border: Border.fromBorderSide(PageStyle.outlineSide(theme.colorScheme)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 3),
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
