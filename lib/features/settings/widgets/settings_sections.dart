import 'package:flutter/material.dart';

import '../../../domain/recovery/recovery_metadata.dart';
import '../../../infrastructure/security/app_unlock_mode.dart';
import '../../session/session_messages.dart';
import '../../session/state/app_session_state.dart';
import '../../session/state/resume_unlock_action.dart';
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
    this.onRetryTrustedUnlock,
    this.onUnlockWithDeviceCredential,
    this.onCancelUnlock,
    this.retryActionLabel = '重新驗證',
    super.key,
  });

  final AppSessionState sessionState;
  final bool busy;
  final TextEditingController recoveryKeyInputController;
  final IconData bannerIcon;
  final String bannerMessage;
  final SettingsBannerTone bannerTone;
  final VoidCallback? onUnlockWithRecovery;
  final VoidCallback? onRetryTrustedUnlock;
  final VoidCallback? onUnlockWithDeviceCredential;
  final VoidCallback? onCancelUnlock;
  final String retryActionLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SettingsInfoBanner(
          icon: bannerIcon,
          message: bannerMessage,
          tone: bannerTone,
        ),
        if (sessionState.status == AppLockStatus.unlocking) ...<Widget>[
          const SizedBox(height: 12),
          Text(
            '若等候過久，可能是驗證視窗被擋住。可取消後改用手動驗證。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          const Center(child: CircularProgressIndicator()),
          if (onCancelUnlock != null) ...<Widget>[
            const SizedBox(height: 14),
            SettingsActionButton(
              label: '取消並改用手動驗證',
              icon: Icons.close_rounded,
              onPressed: busy ? null : onCancelUnlock,
            ),
          ],
        ],
        if (sessionState.status == AppLockStatus.locked) ...<Widget>[
          if (sessionState.resumeAction == ResumeUnlockAction.deviceCredentialFallback &&
              onUnlockWithDeviceCredential != null) ...<Widget>[
            const SizedBox(height: 14),
            SettingsActionButton(
              label: '使用裝置螢幕鎖解鎖',
              icon: Icons.lock_outline,
              emphasized: true,
              onPressed: busy ? null : onUnlockWithDeviceCredential,
            ),
          ],
          if (onRetryTrustedUnlock != null) ...<Widget>[
            const SizedBox(height: 10),
            SettingsActionButton(
              label: retryActionLabel,
              icon: Icons.lock_open_rounded,
              emphasized:
                  sessionState.resumeAction != ResumeUnlockAction.deviceCredentialFallback,
              onPressed: busy ? null : onRetryTrustedUnlock,
            ),
          ],
        ],
        if (sessionState.status == AppLockStatus.recoveryRequired) ...<Widget>[
          const SizedBox(height: 16),
          TextField(
            controller: recoveryKeyInputController,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: '輸入復原金鑰',
              hintText: 'ABCD-EFGH-IJKL-MNOP-QRST-UVWX',
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '輸入建立此備份時保存的復原金鑰後，即可在這台裝置重新解鎖。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          SettingsActionButton(
            label: '使用復原金鑰解鎖',
            icon: Icons.lock_open_rounded,
            emphasized: true,
            onPressed: busy ? null : onUnlockWithRecovery,
          ),
        ],
      ],
    );
  }
}

/// 顯示 Recovery Key 是否已建立，以及必要的建立入口與 metadata。
class RecoveryKeySectionBody extends StatelessWidget {
  const RecoveryKeySectionBody({
    required this.metadata,
    required this.busy,
    required this.onCreateRecoveryKey,
    this.onRotateRecoveryKey,
    super.key,
  });

  final RecoveryMetadata? metadata;
  final bool busy;
  final VoidCallback? onCreateRecoveryKey;
  final VoidCallback? onRotateRecoveryKey;

  @override
  Widget build(BuildContext context) {
    final RecoveryMetadata? currentMetadata = metadata;
    if (currentMetadata == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SettingsInfoBanner(
            icon: Icons.key_off_outlined,
            message: '尚未建立復原金鑰。日記庫無法自動解鎖時，將無法重新進入。',
            tone: SettingsBannerTone.warning,
          ),
          const SizedBox(height: 14),
          SettingsActionButton(
            label: '建立復原金鑰',
            icon: Icons.key_outlined,
            emphasized: true,
            onPressed: busy ? null : onCreateRecoveryKey,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SettingsInfoBanner(
          icon: Icons.verified_user_outlined,
          message: '復原金鑰已建立。需要時可用它重新解鎖這台裝置。',
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            SettingsFactChip(label: '日記庫', value: currentMetadata.vaultId),
            SettingsFactChip(label: '提示', value: currentMetadata.recoveryKeyHint),
            SettingsFactChip(label: '加密方式', value: currentMetadata.kdf.name),
          ],
        ),
        if (onRotateRecoveryKey != null) ...<Widget>[
          const SizedBox(height: 14),
          SettingsActionButton(
            label: '更新復原金鑰',
            icon: Icons.refresh_rounded,
            onPressed: busy ? null : onRotateRecoveryKey,
          ),
        ],
      ],
    );
  }
}

/// 解鎖方式：無／裝置螢幕鎖／生物驗證。
class UnlockMethodSectionBody extends StatelessWidget {
  const UnlockMethodSectionBody({
    required this.enabled,
    required this.busy,
    required this.unlockMode,
    required this.onModeSelected,
    super.key,
  });

  final bool enabled;
  final bool busy;
  final AppUnlockMode unlockMode;
  final Future<void> Function(AppUnlockMode mode) onModeSelected;

  static String labelForMode(AppUnlockMode mode) {
    return switch (mode) {
      AppUnlockMode.none => '無',
      AppUnlockMode.deviceLock => '裝置螢幕鎖',
      AppUnlockMode.biometric => '生物驗證',
    };
  }

  static String descriptionForMode(AppUnlockMode mode) {
    return switch (mode) {
      AppUnlockMode.none => kUnlockModeNoneDescription,
      AppUnlockMode.deviceLock => kUnlockModeDeviceLockDescription,
      AppUnlockMode.biometric => kUnlockModeBiometricDescription,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return const SettingsInfoBanner(
        icon: Icons.lock_outline,
        message: '請先建立復原金鑰，才能設定解鎖方式。',
        tone: SettingsBannerTone.warning,
      );
    }

    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '選擇背景逾時後回到 App 時如何重新進入日記庫。',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        ...<AppUnlockMode>[
          AppUnlockMode.none,
          AppUnlockMode.deviceLock,
          AppUnlockMode.biometric,
        ].map(
          (AppUnlockMode mode) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _UnlockModeOptionTile(
              title: labelForMode(mode),
              subtitle: descriptionForMode(mode),
              icon: switch (mode) {
                AppUnlockMode.none => Icons.shield_outlined,
                AppUnlockMode.deviceLock => Icons.lock_outline,
                AppUnlockMode.biometric => Icons.fingerprint_rounded,
              },
              selected: unlockMode == mode,
              enabled: !busy,
              onTap: () => onModeSelected(mode),
            ),
          ),
        ),
        if (unlockMode == AppUnlockMode.biometric) ...<Widget>[
          const SizedBox(height: 10),
          Text(
            '須已設定裝置螢幕鎖，指紋驗證取消時才能改以螢幕鎖解鎖。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _UnlockModeOptionTile extends StatelessWidget {
  const _UnlockModeOptionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final Color borderColor = selected ? cs.primary : PageStyle.outlineSide(cs).color;
    final Color fill = selected
        ? Color.alphaBlend(cs.primary.withValues(alpha: 0.08), cs.surfaceContainerLow)
        : cs.surfaceContainerLow;

    return Material(
      color: fill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PageStyle.radiusPanel),
        side: BorderSide(color: borderColor, width: selected ? 1.5 : 1),
      ),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(PageStyle.radiusPanel),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, color: selected ? cs.primary : cs.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: selected ? cs.primary : cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded, color: cs.primary, size: 22),
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

/// 包住 `SwitchListTile` 的外觀元件，讓設定列維持一致的 panel 風格。
class SettingsToggleTile extends StatelessWidget {
  const SettingsToggleTile({
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(PageStyle.radiusPanel),
      ),
      child: SwitchListTile.adaptive(
        value: value,
        onChanged: onChanged,
        title: Text(title),
        subtitle: Text(
          description,
          style: onChanged == null
              ? theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)
              : theme.textTheme.bodySmall,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
    );
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

/// 顯示 Recovery Key metadata 等短資訊的 pill 樣式元件。
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
