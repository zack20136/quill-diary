import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:quill_diary/application/settings/drive_upload_coordinator.dart';
import 'package:quill_diary/application/settings/settings_providers.dart';
import 'package:quill_diary/application/settings/settings_text.dart';
import 'package:quill_diary/application/settings/vault_transfer_capabilities.dart';
import 'package:quill_diary/infrastructure/drive/drive_backup_service.dart';
import 'package:quill_diary/infrastructure/drive/drive_upload_job.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/presentation/app_feedback.dart';
import 'package:quill_diary/shared/presentation/widgets/app_action_button.dart';
import 'package:quill_diary/shared/presentation/widgets/app_loading_state.dart';
import 'package:quill_diary/shared/presentation/widgets/app_surface.dart';
import 'package:quill_diary/shared/utils/user_facing_error.dart';
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
    required this.onCancelUpload,
    required this.onAbandonCancelCleanup,
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
  final VoidCallback onCancelUpload;
  final VoidCallback onAbandonCancelCleanup;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final DriveUploadJobSnapshot? uploadJob = ref
        .watch(driveUploadCoordinatorProvider)
        .job;
    final bool uploadBusy = uploadJob?.blocksConflictingDriveActions ?? false;
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
                  loading: () => const AppLoadingState(),
                  error: (Object error, StackTrace _) =>
                      _DriveConnectionErrorContent(
                        message: userFacingErrorMessage(error, l10n: l10n),
                        access: access,
                        pageBusy: busy,
                        uploadJob: uploadJob,
                        canManageDriveAccount: canManageDriveAccount,
                        onRetry: () =>
                            ref.invalidate(settingsDriveConnectionProvider),
                        onLink: onLink,
                        onAbandonCancelCleanup: onAbandonCancelCleanup,
                      ),
                  data: (DriveConnectionState connectionState) =>
                      _DriveBackupContent(
                        connectionState: connectionState,
                        access: access,
                        canManageDriveAccount: canManageDriveAccount,
                        busy: busy,
                        uploadJob: uploadJob,
                        onLink: onLink,
                        onSwitchAccount: onSwitchAccount,
                        onDisconnect: onDisconnect,
                        onUpload: onUpload,
                        onRestore: onRestore,
                        onCancelUpload: onCancelUpload,
                        onAbandonCancelCleanup: onAbandonCancelCleanup,
                      ),
                ),
    );
  }
}

class _DriveConnectionErrorContent extends StatelessWidget {
  const _DriveConnectionErrorContent({
    required this.message,
    required this.access,
    required this.pageBusy,
    required this.uploadJob,
    required this.canManageDriveAccount,
    required this.onRetry,
    required this.onLink,
    required this.onAbandonCancelCleanup,
  });

  final String message;
  final VaultTransferCapabilities access;
  final bool pageBusy;
  final DriveUploadJobSnapshot? uploadJob;
  final bool canManageDriveAccount;
  final VoidCallback onRetry;
  final VoidCallback onLink;
  final VoidCallback onAbandonCancelCleanup;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool cleanupPending = uploadJob?.isCancelCleanupPending ?? false;
    final bool canLinkDuringCleanup =
        !pageBusy && canManageDriveAccount && cleanupPending;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DriveAccountStatus(
          isConnected: false,
          disconnectedLabel: l10n.settingsDriveBackupConnectionErrorLabel,
          disconnectedIcon: Icons.error_outline_rounded,
        ),
        if (uploadJob != null) ...<Widget>[
          const SizedBox(height: 10),
          _DriveUploadStatusCard(
            job: uploadJob!,
            busy: pageBusy,
            onCancel: () {},
            onAbandonCancelCleanup: onAbandonCancelCleanup,
          ),
        ],
        const SizedBox(height: 10),
        AppFeedbackBanner(
          icon: Icons.error_outline_rounded,
          message: message,
          tone: AppFeedbackTone.error,
        ),
        const SizedBox(height: 10),
        if (cleanupPending)
          AppActionButton(
            label: l10n.settingsDriveBackupLinkButton,
            icon: Icons.link_rounded,
            appearance: AppActionButtonAppearance.primary,
            fullWidth: true,
            onPressed: canLinkDuringCleanup ? onLink : null,
          )
        else
          AppActionButton(
            label: l10n.settingsDriveBackupConnectionRetryButton,
            icon: Icons.refresh_rounded,
            appearance: AppActionButtonAppearance.outlined,
            fullWidth: true,
            onPressed: pageBusy ? null : onRetry,
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
    required this.uploadJob,
    required this.onLink,
    required this.onSwitchAccount,
    required this.onDisconnect,
    required this.onUpload,
    required this.onRestore,
    required this.onCancelUpload,
    required this.onAbandonCancelCleanup,
  });

  final DriveConnectionState connectionState;
  final VaultTransferCapabilities access;
  final bool canManageDriveAccount;
  final bool busy;
  final DriveUploadJobSnapshot? uploadJob;
  final VoidCallback onLink;
  final VoidCallback onSwitchAccount;
  final VoidCallback onDisconnect;
  final VoidCallback onUpload;
  final VoidCallback onRestore;
  final VoidCallback onCancelUpload;
  final VoidCallback onAbandonCancelCleanup;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool isConnected = connectionState.isConnected;
    final bool uploadBusy = uploadJob?.blocksConflictingDriveActions ?? false;
    final bool cleanupPending = uploadJob?.isCancelCleanupPending ?? false;
    final bool cleanupRecovery =
        uploadJob?.needsCancelCleanupAccountRecovery ?? false;
    // 取消清理中：未連線或授權錯誤時允許重連原帳號；其餘仍鎖住切換／中斷。
    final bool accountActionsUnlocked =
        !uploadBusy ||
        cleanupRecovery ||
        (cleanupPending && !isConnected);
    final bool canUseAccountActions =
        !busy && canManageDriveAccount && accountActionsUnlocked;
    final bool showBusyBanner = uploadBusy && !cleanupPending;
    final bool showCleanupBanner = cleanupPending;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DriveAccountStatus(
          isConnected: isConnected,
          accountLabel: connectionState.accountLabel(l10n),
        ),
        if (uploadJob != null) ...<Widget>[
          const SizedBox(height: 10),
          _DriveUploadStatusCard(
            job: uploadJob!,
            busy: busy,
            onCancel: onCancelUpload,
            onAbandonCancelCleanup: onAbandonCancelCleanup,
          ),
        ],
        const SizedBox(height: 10),
        AppActionGroup(
          actions: <Widget>[
            if (!isConnected)
              AppActionButton(
                label: l10n.settingsDriveBackupLinkButton,
                icon: Icons.link_rounded,
                appearance: AppActionButtonAppearance.primary,
                fullWidth: true,
                onPressed: canUseAccountActions ? onLink : null,
              ),
            if (isConnected) ...<Widget>[
              AppActionButton(
                label: l10n.settingsDriveBackupUploadButton,
                icon: Icons.cloud_upload_outlined,
                appearance: AppActionButtonAppearance.primary,
                fullWidth: true,
                onPressed: busy || uploadBusy || !access.canBackup
                    ? null
                    : onUpload,
              ),
              AppActionButton(
                label: l10n.settingsDriveBackupRestoreButton,
                icon: Icons.cloud_download_outlined,
                appearance: AppActionButtonAppearance.tonal,
                fullWidth: true,
                onPressed: busy || uploadBusy || !access.canRestore
                    ? null
                    : onRestore,
              ),
              AppActionButton(
                label: l10n.settingsDriveBackupSwitchAccountButton,
                icon: Icons.swap_horiz_rounded,
                appearance: AppActionButtonAppearance.outlined,
                fullWidth: true,
                // 帳號不符時允許切回原帳；一般上傳／清理中仍鎖住。
                onPressed: canUseAccountActions &&
                        (!uploadBusy || cleanupRecovery)
                    ? onSwitchAccount
                    : null,
              ),
              AppActionButton(
                label: l10n.settingsDriveBackupDisconnectButton,
                icon: Icons.link_off_rounded,
                appearance: AppActionButtonAppearance.destructive,
                fullWidth: true,
                onPressed: canUseAccountActions &&
                        (!uploadBusy || cleanupRecovery)
                    ? onDisconnect
                    : null,
              ),
            ],
          ],
        ),
        if (showBusyBanner) ...<Widget>[
          const SizedBox(height: 12),
          AppFeedbackBanner(
            icon: Icons.info_outline_rounded,
            message: l10n.driveUploadBusyBlocksAccountActions,
          ),
        ],
        if (showCleanupBanner) ...<Widget>[
          const SizedBox(height: 12),
          AppFeedbackBanner(
            icon: Icons.info_outline_rounded,
            message: l10n.driveUploadCancelCleanupBlocksAccountActions,
          ),
        ],
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

class _DriveUploadStatusCard extends StatelessWidget {
  const _DriveUploadStatusCard({
    required this.job,
    required this.busy,
    required this.onCancel,
    required this.onAbandonCancelCleanup,
  });

  final DriveUploadJobSnapshot job;
  final bool busy;
  final VoidCallback onCancel;
  final VoidCallback onAbandonCancelCleanup;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final int percent = (job.progressFraction * 100).round().clamp(0, 100);
    final bool finalizing =
        job.phase == DriveUploadPhase.statusPending ||
        job.phase == DriveUploadPhase.prunePending;
    final bool cancelCleanup =
        job.phase == DriveUploadPhase.cancelCleanupPending;
    final String accountEmail = job.accountEmail.trim().isEmpty
        ? 'Google'
        : job.accountEmail.trim();
    final String message = switch (job.phase) {
      DriveUploadPhase.waitingForNetwork =>
        l10n.driveUploadStatusWaitingNetwork(job.fileName),
      DriveUploadPhase.staged => l10n.driveUploadStatusStaged(job.fileName),
      DriveUploadPhase.statusPending ||
      DriveUploadPhase.prunePending =>
        l10n.driveUploadStatusFinalizing,
      DriveUploadPhase.cancelCleanupPending =>
        switch (job.lastErrorCode) {
          'cleanup_needs_reauth' =>
            l10n.driveUploadStatusCancelCleanupNeedsReauth(accountEmail),
          'cleanup_account_mismatch' =>
            l10n.driveUploadStatusCancelCleanupAccountMismatch(accountEmail),
          _ => l10n.driveUploadStatusCancelCleanup,
        },
      DriveUploadPhase.uploading =>
        l10n.driveUploadStatusUploading(job.fileName, percent),
    };
    // 遠端已驗證不可再取消；取消清理改顯示放棄。
    final bool showCancel = !finalizing && !cancelCleanup;
    final bool showAbandon = cancelCleanup;
    final bool showProgress =
        job.phase == DriveUploadPhase.uploading ||
        job.phase == DriveUploadPhase.staged;
    final AppFeedbackTone tone =
        cancelCleanup && job.needsCancelCleanupAccountRecovery
        ? AppFeedbackTone.warning
        : AppFeedbackTone.info;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppFeedbackBanner(
          icon: Icons.cloud_upload_outlined,
          message: message,
          tone: tone,
        ),
        if (showProgress) ...<Widget>[
          const SizedBox(height: 8),
          LinearProgressIndicator(value: job.progressFraction.clamp(0.0, 1.0)),
        ],
        if (showCancel) ...<Widget>[
          const SizedBox(height: 10),
          AppActionButton(
            label: l10n.driveUploadCancelButton,
            icon: Icons.stop_rounded,
            appearance: AppActionButtonAppearance.outlined,
            fullWidth: true,
            onPressed: busy ? null : onCancel,
          ),
        ],
        if (showAbandon) ...<Widget>[
          const SizedBox(height: 10),
          AppActionButton(
            label: l10n.driveUploadAbandonCancelCleanupButton,
            icon: Icons.link_off_rounded,
            appearance: AppActionButtonAppearance.outlined,
            fullWidth: true,
            onPressed: busy ? null : onAbandonCancelCleanup,
          ),
        ],
      ],
    );
  }
}
