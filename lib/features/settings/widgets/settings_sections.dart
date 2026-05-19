import 'package:flutter/material.dart';

import '../../../domain/recovery/recovery_metadata.dart';
import '../../session/state/app_session_state.dart';
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
    super.key,
  });

  final String title;
  final String description;
  final Widget child;

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
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            child,
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
    super.key,
  });

  final AppSessionState sessionState;
  final bool busy;
  final TextEditingController recoveryKeyInputController;
  final IconData bannerIcon;
  final String bannerMessage;
  final SettingsBannerTone bannerTone;
  final VoidCallback? onUnlockWithRecovery;

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
        if (sessionState.status == AppLockStatus.recoveryRequired) ...<Widget>[
          const SizedBox(height: 16),
          TextField(
            controller: recoveryKeyInputController,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: '輸入 Recovery Key',
              hintText: 'ABCD-EFGH-IJKL-MNOP-QRST-UVWX',
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '輸入正確的 Recovery Key 後，系統會重新建立目前裝置可用的 trusted session。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          SettingsActionButton(
            label: '使用 Recovery Key 解鎖',
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
    super.key,
  });

  final RecoveryMetadata? metadata;
  final bool busy;
  final VoidCallback? onCreateRecoveryKey;

  @override
  Widget build(BuildContext context) {
    final RecoveryMetadata? currentMetadata = metadata;
    if (currentMetadata == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SettingsInfoBanner(
            icon: Icons.key_off_outlined,
            message: '尚未建立 Recovery Key。若 trusted session 失效，你將無法重新進入保險庫。',
            tone: SettingsBannerTone.warning,
          ),
          const SizedBox(height: 14),
          SettingsActionButton(
            label: '建立 Recovery Key',
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
          message: 'Recovery Key 已建立。若 trusted session 失效，可用它重新解鎖並重建目前裝置的 trusted session。',
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            SettingsFactChip(label: 'Vault', value: currentMetadata.vaultId),
            SettingsFactChip(label: '提示', value: currentMetadata.recoveryKeyHint),
            SettingsFactChip(label: 'KDF', value: currentMetadata.kdf.name),
          ],
        ),
      ],
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
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    if (emphasized) {
      return FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
      );
    }
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
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
        subtitle: Text(description),
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
