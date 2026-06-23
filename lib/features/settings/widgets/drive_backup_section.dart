import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../infrastructure/drive/drive_backup_service.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/presentation/app_feedback.dart';
import '../providers/settings_providers.dart';
import '../settings_messages.dart';
import '../vault_transfer_access.dart';
import 'drive_account_status.dart';
import 'settings_sections.dart';

/// 設定頁的 Google Drive 備份與還原區塊。
class DriveBackupSection extends ConsumerWidget {
  const DriveBackupSection({
    required this.access,
    required this.canManageDriveAccount,
    required this.accountLockedMessage,
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
  final bool canManageDriveAccount;
  final String accountLockedMessage;
  final bool isGoogleDriveConfigured;
  final bool busy;
  final VoidCallback onLink;
  final VoidCallback onSwitchAccount;
  final VoidCallback onDisconnect;
  final VoidCallback onUpload;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String description = isGoogleDriveConfigured
        ? (access.canBackup
              ? settingsDriveBackupSectionDescriptionEnabled(l10n)
              : l10n.vaultTransferDriveSectionDescriptionBackupLocked)
        : l10n.settingsDriveBackupSectionDescriptionOAuthNotConfigured;

    return SettingsSectionCard(
      icon: Icons.cloud_outlined,
      title: l10n.settingsDriveBackupSectionTitle,
      description: description,
      child: !isGoogleDriveConfigured
          ? AppFeedbackBanner(
              icon: Icons.cloud_off_rounded,
              message:
                  l10n.settingsDriveBackupSectionDescriptionOAuthNotConfigured,
            )
          : ref
                .watch(settingsDriveConnectionProvider)
                .when(
                  loading: () => const SettingsSectionLoading(),
                  error: (_, _) => _DriveBackupContent(
                    connectionState: const DriveConnectionState.disconnected(),
                    access: access,
                    canManageDriveAccount: canManageDriveAccount,
                    accountLockedMessage: accountLockedMessage,
                    busy: busy,
                    onLink: onLink,
                    onSwitchAccount: onSwitchAccount,
                    onDisconnect: onDisconnect,
                    onUpload: onUpload,
                    onRestore: onRestore,
                  ),
                  data: (DriveConnectionState connectionState) =>
                      _DriveBackupContent(
                        connectionState: connectionState,
                        access: access,
                        canManageDriveAccount: canManageDriveAccount,
                        accountLockedMessage: accountLockedMessage,
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
    required this.canManageDriveAccount,
    required this.accountLockedMessage,
    required this.busy,
    required this.onLink,
    required this.onSwitchAccount,
    required this.onDisconnect,
    required this.onUpload,
    required this.onRestore,
  });

  final DriveConnectionState connectionState;
  final VaultTransferAccess access;
  final bool canManageDriveAccount;
  final String accountLockedMessage;
  final bool busy;
  final VoidCallback onLink;
  final VoidCallback onSwitchAccount;
  final VoidCallback onDisconnect;
  final VoidCallback onUpload;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool isConnected = connectionState.isConnected;
    final bool canUseAccountActions = !busy && canManageDriveAccount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DriveAccountStatus(
          isConnected: isConnected,
          accountLabel: connectionState.accountLabel(l10n),
        ),
        const SizedBox(height: 10),
        SettingsActionGroup(
          actions: <SettingsActionButton>[
            if (!isConnected)
              SettingsActionButton(
                label: l10n.settingsDriveBackupLinkButton,
                icon: Icons.link_rounded,
                appearance: SettingsActionButtonAppearance.filled,
                fullWidth: true,
                onPressed: canUseAccountActions ? onLink : null,
              ),
            if (isConnected) ...<SettingsActionButton>[
              SettingsActionButton(
                label: l10n.settingsDriveBackupUploadButton,
                icon: Icons.cloud_upload_outlined,
                appearance: SettingsActionButtonAppearance.filled,
                fullWidth: true,
                onPressed: busy || !access.canBackup ? null : onUpload,
              ),
              SettingsActionButton(
                label: l10n.settingsDriveBackupRestoreButton,
                icon: Icons.cloud_download_outlined,
                appearance: SettingsActionButtonAppearance.tonal,
                fullWidth: true,
                onPressed: busy || !access.canRestore ? null : onRestore,
              ),
              SettingsActionButton(
                label: l10n.settingsDriveBackupSwitchAccountButton,
                icon: Icons.swap_horiz_rounded,
                appearance: SettingsActionButtonAppearance.outlined,
                fullWidth: true,
                onPressed: canUseAccountActions ? onSwitchAccount : null,
              ),
              SettingsActionButton(
                label: l10n.settingsDriveBackupDisconnectButton,
                icon: Icons.link_off_rounded,
                appearance: SettingsActionButtonAppearance.destructive,
                fullWidth: true,
                onPressed: canUseAccountActions ? onDisconnect : null,
              ),
            ],
          ],
        ),
        if (_lockedBannerMessage(l10n) != null) ...<Widget>[
          const SizedBox(height: 12),
          AppFeedbackBanner(
            icon: Icons.lock_outline_rounded,
            message: _lockedBannerMessage(l10n)!,
            tone: AppFeedbackTone.warning,
          ),
        ],
      ],
    );
  }

  String? _lockedBannerMessage(AppLocalizations l10n) {
    if (!canManageDriveAccount) {
      return accountLockedMessage;
    }
    if (!access.canBackup && !access.canRestore) {
      return access.restoreDisabledReason ?? access.backupDisabledReason;
    }
    if (!access.canBackup) {
      return access.backupDisabledReason ??
          l10n.vaultTransferDriveBackupActionsLockedHint;
    }
    if (!access.canRestore) {
      return access.restoreDisabledReason;
    }
    return null;
  }
}
