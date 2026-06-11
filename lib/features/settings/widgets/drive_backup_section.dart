import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../infrastructure/drive/drive_backup_service.dart';
import '../providers/settings_providers.dart';
import '../settings_copy.dart';
import '../vault_transfer_access.dart';
import 'drive_account_status.dart';
import 'settings_sections.dart';

/// 設定頁的 Google Drive 備份與還原區塊。
class DriveBackupSection extends ConsumerWidget {
  const DriveBackupSection({
    required this.access,
    required this.isGoogleDriveConfigured,
    required this.busy,
    required this.onLink,
    required this.onSwitchAccount,
    required this.onDisconnect,
    required this.onUpload,
    required this.onRestore,
    super.key,
  });

  final VaultTransferAccess access;
  final bool isGoogleDriveConfigured;
  final bool busy;
  final VoidCallback onLink;
  final VoidCallback onSwitchAccount;
  final VoidCallback onDisconnect;
  final VoidCallback onUpload;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String description = isGoogleDriveConfigured
        ? (access.canBackup
            ? SettingsDriveBackupCopy.sectionDescriptionEnabled
            : VaultTransferCopy.driveSectionDescriptionBackupLocked)
        : SettingsDriveBackupCopy.sectionDescriptionOAuthNotConfigured;

    return SettingsSectionCard(
      icon: Icons.cloud_outlined,
      title: SettingsDriveBackupCopy.sectionTitle,
      description: description,
      child: !isGoogleDriveConfigured
          ? const SettingsInfoBanner(
              icon: Icons.cloud_off_rounded,
              message: SettingsDriveBackupCopy.sectionDescriptionOAuthNotConfigured,
            )
          : ref.watch(settingsDriveConnectionProvider).when(
                loading: () => const SettingsSectionLoading(),
                error: (_, _) => _DriveBackupContent(
                  connectionState: const DriveConnectionState.disconnected(),
                  access: access,
                  busy: busy,
                  onLink: onLink,
                  onSwitchAccount: onSwitchAccount,
                  onDisconnect: onDisconnect,
                  onUpload: onUpload,
                  onRestore: onRestore,
                ),
                data: (DriveConnectionState connectionState) => _DriveBackupContent(
                  connectionState: connectionState,
                  access: access,
                  busy: busy,
                  onLink: onLink,
                  onSwitchAccount: onSwitchAccount,
                  onDisconnect: onDisconnect,
                  onUpload: onUpload,
                  onRestore: onRestore,
                ),
              ),
    );
  }
}

class _DriveBackupContent extends StatelessWidget {
  const _DriveBackupContent({
    required this.connectionState,
    required this.access,
    required this.busy,
    required this.onLink,
    required this.onSwitchAccount,
    required this.onDisconnect,
    required this.onUpload,
    required this.onRestore,
  });

  final DriveConnectionState connectionState;
  final VaultTransferAccess access;
  final bool busy;
  final VoidCallback onLink;
  final VoidCallback onSwitchAccount;
  final VoidCallback onDisconnect;
  final VoidCallback onUpload;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final bool isConnected = connectionState.isConnected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DriveAccountStatus(
          isConnected: isConnected,
          accountLabel: connectionState.accountLabel,
        ),
        const SizedBox(height: 10),
        SettingsActionGroup(
          actions: <SettingsActionButton>[
            if (!isConnected)
              SettingsActionButton(
                label: SettingsDriveBackupCopy.linkButton,
                icon: Icons.link_rounded,
                appearance: SettingsActionButtonAppearance.filled,
                fullWidth: true,
                onPressed: busy ? null : onLink,
              ),
            if (isConnected) ...<SettingsActionButton>[
              SettingsActionButton(
                label: SettingsDriveBackupCopy.uploadButton,
                icon: Icons.cloud_upload_outlined,
                appearance: SettingsActionButtonAppearance.filled,
                fullWidth: true,
                onPressed: busy || !access.canBackup ? null : onUpload,
              ),
              SettingsActionButton(
                label: SettingsDriveBackupCopy.restoreButton,
                icon: Icons.cloud_download_outlined,
                appearance: SettingsActionButtonAppearance.tonal,
                fullWidth: true,
                onPressed: busy || !access.canRestore ? null : onRestore,
              ),
              SettingsActionButton(
                label: SettingsDriveBackupCopy.switchAccountButton,
                icon: Icons.swap_horiz_rounded,
                appearance: SettingsActionButtonAppearance.outlined,
                fullWidth: true,
                onPressed: busy ? null : onSwitchAccount,
              ),
              SettingsActionButton(
                label: SettingsDriveBackupCopy.disconnectButton,
                icon: Icons.link_off_rounded,
                appearance: SettingsActionButtonAppearance.destructive,
                fullWidth: true,
                onPressed: busy ? null : onDisconnect,
              ),
            ],
          ],
        ),
        if (isConnected && _lockedBannerMessage != null) ...<Widget>[
          const SizedBox(height: 12),
          SettingsInfoBanner(
            icon: Icons.lock_outline_rounded,
            message: _lockedBannerMessage!,
          ),
        ],
      ],
    );
  }

  String? get _lockedBannerMessage {
    if (!access.canBackup && !access.canRestore) {
      return access.restoreDisabledReason ?? access.backupDisabledReason;
    }
    if (!access.canBackup) {
      return access.backupDisabledReason ??
          VaultTransferCopy.driveBackupActionsLockedHint;
    }
    if (!access.canRestore) {
      return access.restoreDisabledReason;
    }
    return null;
  }
}
