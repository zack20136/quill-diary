import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:quill_diary/infrastructure/drive/drive_backup_service.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/presentation/app_feedback.dart';
import 'package:quill_diary/shared/utils/user_facing_error.dart';
import 'package:quill_diary/application/settings/vault_transfer_capabilities.dart';
import 'package:quill_diary/application/settings/settings_providers.dart';
import 'package:quill_diary/application/settings/settings_text.dart';
import 'drive_account_status.dart';
import 'settings_sections.dart';

class DriveBackupSection extends ConsumerWidget {
  const DriveBackupSection({
    required this.access,
    required this.canManageDriveAccount,
    required this.isGoogleDriveConfigured,
    required this.busy,
    required this.onLink,
    required this.onSwitchAccount,
    required this.onDisconnect,
    required this.onUpload,
    required this.onRestore,
    super.key,
  });

  final VaultTransferCapabilities access;
  final bool canManageDriveAccount;
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
                  error: (Object error, StackTrace _) =>
                      _DriveConnectionErrorContent(
                        message: userFacingErrorMessage(error, l10n: l10n),
                        access: access,
                        busy: busy,
                        onRetry: () =>
                            ref.invalidate(settingsDriveConnectionProvider),
                      ),
                  data: (DriveConnectionState connectionState) =>
                      _DriveBackupContent(
                        connectionState: connectionState,
                        access: access,
                        canManageDriveAccount: canManageDriveAccount,
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

class _DriveConnectionErrorContent extends StatelessWidget {
  const _DriveConnectionErrorContent({
    required this.message,
    required this.access,
    required this.busy,
    required this.onRetry,
  });

  final String message;
  final VaultTransferCapabilities access;
  final bool busy;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DriveAccountStatus(
          isConnected: false,
          disconnectedLabel: l10n.settingsDriveBackupConnectionErrorLabel,
          disconnectedIcon: Icons.error_outline_rounded,
        ),
        const SizedBox(height: 10),
        AppFeedbackBanner(
          icon: Icons.error_outline_rounded,
          message: message,
          tone: AppFeedbackTone.error,
        ),
        const SizedBox(height: 10),
        SettingsActionButton(
          label: l10n.settingsDriveBackupConnectionRetryButton,
          icon: Icons.refresh_rounded,
          appearance: SettingsActionButtonAppearance.outlined,
          fullWidth: true,
          onPressed: busy ? null : onRetry,
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

class _DriveBackupContent extends StatelessWidget {
  const _DriveBackupContent({
    required this.connectionState,
    required this.access,
    required this.canManageDriveAccount,
    required this.busy,
    required this.onLink,
    required this.onSwitchAccount,
    required this.onDisconnect,
    required this.onUpload,
    required this.onRestore,
  });

  final DriveConnectionState connectionState;
  final VaultTransferCapabilities access;
  final bool canManageDriveAccount;
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
