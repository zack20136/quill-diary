import 'dart:async' show unawaited;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../config/app_identifiers.dart';
import '../../../config/oauth_config.dart';
import '../../../domain/recovery/recovery_metadata.dart';
import '../../../infrastructure/drive/drive_backup_service.dart';
import '../../../infrastructure/security/app_unlock_mode.dart';
import '../../../infrastructure/storage/backup_task_progress.dart';
import '../../../infrastructure/storage/restore_precheck.dart';
import '../../../infrastructure/storage/vault_repository.dart';
import '../../../infrastructure/storage/vault_transfer_service.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/presentation/app_feedback.dart';
import '../../../shared/presentation/display_format.dart';
import '../../../shared/presentation/app_scrollbar.dart';
import '../../../shared/presentation/page_style.dart';
import '../../../shared/utils/external_url.dart';
import '../../../shared/utils/user_facing_error.dart';
import '../../home/providers/home_providers.dart';
import '../../restore/restore_backup_flow.dart';
import '../../restore/restore_prepared_context.dart';
import '../../session/providers/session_providers.dart';
import '../../session/session_messages.dart';
import '../../session/state/app_session_state.dart';
import '../application/settings_actions.dart';
import '../application/settings_flow_controller.dart';
import '../backup/backup_pick_list_item.dart';
import '../presentation/settings_dialogs.dart';
import '../presentation/settings_feedback.dart';
import '../providers/personalization_providers.dart';
import '../providers/settings_providers.dart';
import '../settings_messages.dart';
import '../settings_page_access.dart';
import '../vault_transfer_access.dart';
import '../widgets/drive_backup_section.dart';
import '../widgets/local_backup_section.dart';
import '../widgets/recovery_key_save_dialog.dart';
import '../widgets/settings_sections.dart';

part 'settings_page_callbacks.dart';
part 'settings_page_components.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final TextEditingController _recoveryKeyInputController =
      TextEditingController();
  bool _busy = false;
  String? _busyMessage;
  double? _busyProgress;
  VaultRepairReport? _lastVaultRepairReport;

  SettingsFlowController get _settingsFlow =>
      ref.read(settingsFlowControllerProvider);

  @override
  void dispose() {
    _recoveryKeyInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<AppSessionState> sessionAsync = ref.watch(
      effectiveAppSessionProvider,
    );
    final AsyncValue<RecoveryMetadata?> recoveryMetadataAsync = ref.watch(
      recoveryMetadataProvider,
    );
    final AsyncValue<bool> trustedDeviceAccessAsync = ref.watch(
      trustedDeviceAccessProvider,
    );
    final AsyncValue<AppUnlockMode> unlockModeAsync = ref.watch(
      unlockModeProvider,
    );
    final AppSessionState? sessionState = sessionAsync.asData?.value;
    final RecoveryMetadata? recoveryMetadata =
        recoveryMetadataAsync.asData?.value;
    final SettingsPageAccess pageAccess = SettingsPageAccess.fromSession(
      l10n: l10n,
      sessionState: sessionState,
      hasRecoveryKey: recoveryMetadata != null,
    );
    final VaultTransferAccess transferAccess = pageAccess.vaultTransfer;
    final bool isGoogleDriveConfigured =
        !Platform.isIOS || OAuthConfig.isIosGoogleDriveConfigured;

    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color pageBackground = PageStyle.scaffoldWash(cs);

    return Scaffold(
      backgroundColor: pageBackground,
      appBar: AppBar(
        title: Text(l10n.settingsPageTitle),
        backgroundColor: pageBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: ColoredBox(
        color: pageBackground,
        child: SafeArea(
          child: Stack(
            children: <Widget>[
              NotificationListener<OverscrollIndicatorNotification>(
                onNotification: (OverscrollIndicatorNotification notification) {
                  notification.disallowIndicator();
                  return false;
                },
                child: ColoredBox(
                  color: pageBackground,
                  child: ListViewWithScrollbar(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: <Widget>[
                      const _SettingsTopNavSection(),
                      const SizedBox(height: 16),
                      _buildSecurityStatusSection(
                        sessionAsync: sessionAsync,
                        recoveryMetadata: recoveryMetadata,
                        pageAccess: pageAccess,
                        trustedDeviceAccessAsync: trustedDeviceAccessAsync,
                        unlockModeAsync: unlockModeAsync,
                      ),
                      const SizedBox(height: 16),
                      SettingsSectionCard(
                        icon: Icons.phonelink_lock_outlined,
                        title: l10n.settingsUnlockMethodSectionTitle,
                        description: settingsUnlockMethodSectionDescription(
                          l10n,
                          watchPersonalizationPreferences(ref).sessionTimeout,
                        ),
                        child: unlockModeAsync.when(
                          data: (AppUnlockMode unlockMode) =>
                              UnlockMethodSectionBody(
                                enabled:
                                    recoveryMetadataAsync.asData?.value != null,
                                changeAllowed: pageAccess.hasUnlockedSession,
                                busy: _busy,
                                unlockMode: unlockMode,
                                onModeSelected: (AppUnlockMode selected) =>
                                    _runBusy(() => _applyUnlockMode(selected)),
                              ),
                          loading: () => const SettingsSectionLoading(),
                          error: (Object error, StackTrace _) =>
                              AppFeedbackBanner(
                                icon: Icons.error_outline_rounded,
                                message: userFacingErrorMessage(
                                  error,
                                  l10n: l10n,
                                ),
                                tone: AppFeedbackTone.error,
                              ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SettingsSectionCard(
                        icon: Icons.swap_horiz_rounded,
                        title: l10n.settingsImportExportSectionTitle,
                        description: transferAccess.canBackup
                            ? l10n.settingsImportExportSectionDescriptionEnabled
                            : transferAccess.backupDisabledReason ??
                                  l10n.vaultTransferNeedsUnlockForBackup,
                        child: SettingsActionGroup(
                          actions: <SettingsActionButton>[
                            SettingsActionButton(
                              label: l10n.settingsImportExportImportButton,
                              icon: Icons.file_download_outlined,
                              appearance: SettingsActionButtonAppearance.filled,
                              fullWidth: true,
                              onPressed: _busy || !transferAccess.canBackup
                                  ? null
                                  : () => _runBusy(
                                      _importDocuments,
                                      message: l10n
                                          .settingsImportExportImportProgress,
                                    ),
                            ),
                            SettingsActionButton(
                              label: l10n.settingsImportExportExportButton,
                              icon: Icons.file_upload_outlined,
                              appearance: SettingsActionButtonAppearance.tonal,
                              fullWidth: true,
                              onPressed: _busy || !transferAccess.canBackup
                                  ? null
                                  : () => _runBusy(
                                      _exportMarkdown,
                                      message: l10n
                                          .settingsImportExportExportProgress,
                                    ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      LocalBackupSection(
                        access: transferAccess,
                        busy: _busy,
                        onCreate: () =>
                            _runWithBackupProgress(_createLocalBackup),
                        onRestore: _runRestoreFromAppLocalBackup,
                        onExport: () =>
                            _runWithBackupProgress(_exportLocalBackup),
                        onImport: _runRestoreFromLocalBackup,
                      ),
                      const SizedBox(height: 16),
                      DriveBackupSection(
                        access: transferAccess,
                        canManageDriveAccount: pageAccess.canManageDriveAccount,
                        isGoogleDriveConfigured: isGoogleDriveConfigured,
                        busy: _busy,
                        onLink: () => _runBusy(
                          _linkGoogleDrive,
                          message: l10n.settingsIndexLinkDriveProgress,
                        ),
                        onSwitchAccount: () => _runBusy(
                          _switchGoogleDrive,
                          message: l10n.settingsIndexSwitchDriveAccountProgress,
                        ),
                        onDisconnect: _disconnectGoogleDrive,
                        onUpload: () =>
                            _runWithBackupProgress(_uploadDriveBackup),
                        onRestore: _runRestoreFromGoogleDrive,
                      ),
                      const SizedBox(height: 16),
                      _buildLegalSection(context, cs),
                    ],
                  ),
                ),
              ),
              if (_busy)
                SettingsBlockingProgressOverlay(
                  message: _busyMessage ?? l10n.settingsProgressDefault,
                  progress: _busyProgress,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
