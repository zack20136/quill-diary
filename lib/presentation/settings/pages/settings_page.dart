import 'dart:async' show unawaited;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:quill_diary/app/app_colors.dart';
import 'package:quill_diary/app/app_identifiers.dart';
import 'package:quill_diary/app/router.dart';
import 'package:quill_diary/application/session/providers/session_providers.dart';
import 'package:quill_diary/application/session/session_messages.dart';
import 'package:quill_diary/application/session/state/app_session_state.dart';
import 'package:quill_diary/application/settings/personalization_providers.dart';
import 'package:quill_diary/application/settings/settings_flow_controller.dart';
import 'package:quill_diary/application/settings/settings_providers.dart';
import 'package:quill_diary/application/settings/settings_text.dart';
import 'package:quill_diary/application/settings/vault_transfer_capabilities.dart';
import 'package:quill_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_diary/infrastructure/drive/drive_backup_service.dart';
import 'package:quill_diary/infrastructure/drive/google_oauth_config.dart';
import 'package:quill_diary/infrastructure/security/app_unlock_mode.dart';
import 'package:quill_diary/infrastructure/storage/backup_status_store.dart';
import 'package:quill_diary/infrastructure/storage/backup_task_progress.dart';
import 'package:quill_diary/infrastructure/storage/restore_precheck.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';
import 'package:quill_diary/infrastructure/storage/vault_transfer_models.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/restore/widgets/post_restore_outcome_dialog.dart';
import 'package:quill_diary/presentation/restore/widgets/restore_recovery_key_dialog.dart';
import 'package:quill_diary/shared/presentation/app_feedback.dart';
import 'package:quill_diary/shared/presentation/app_scrollbar.dart';
import 'package:quill_diary/shared/presentation/display_format.dart';
import 'package:quill_diary/shared/presentation/page_style.dart';
import 'package:quill_diary/shared/utils/external_url.dart';
import 'package:quill_diary/shared/utils/user_facing_error.dart';

import '../backup/backup_pick_list_item.dart';
import '../settings_capabilities.dart';
import '../widgets/drive_backup_section.dart';
import '../widgets/local_backup_section.dart';
import '../widgets/recovery_key_save_dialog.dart';
import '../widgets/settings_action_dialogs.dart';
import '../widgets/settings_flow_feedback.dart';
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

  BuildContext get pageContext => context;

  bool get isMounted => mounted;

  WidgetRef get pageRef => ref;

  void updatePageState(VoidCallback callback) {
    setState(callback);
  }

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
    final SettingsPageCapabilities pageAccess =
        SettingsPageCapabilities.fromSessionState(
          l10n: l10n,
          sessionState: sessionState,
          hasRecoveryKey: recoveryMetadata != null,
        );
    final VaultTransferCapabilities transferAccess =
        pageAccess.vaultTransferCapabilities;
    final bool isGoogleDriveConfigured =
        !Platform.isIOS || OAuthConfig.isIosGoogleDriveConfigured;
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsPageTitle),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            NotificationListener<OverscrollIndicatorNotification>(
              onNotification: (OverscrollIndicatorNotification notification) {
                notification.disallowIndicator();
                return false;
              },
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
                      error: (Object error, StackTrace _) => AppFeedbackBanner(
                        icon: Icons.error_outline_rounded,
                        message: userFacingErrorMessage(error, l10n: l10n),
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
                          appearance: SettingsActionButtonAppearance.tonal,
                          fullWidth: true,
                          onPressed: _busy || !transferAccess.canBackup
                              ? null
                              : () => _runBusy(
                                  _importDocuments,
                                  message:
                                      l10n.settingsImportExportImportProgress,
                                ),
                        ),
                        SettingsActionButton(
                          label: l10n.settingsImportExportExportButton,
                          icon: Icons.file_upload_outlined,
                          appearance: SettingsActionButtonAppearance.filled,
                          fullWidth: true,
                          onPressed: _busy || !transferAccess.canBackup
                              ? null
                              : () => _runBusy(
                                  _exportMarkdown,
                                  message:
                                      l10n.settingsImportExportExportProgress,
                                ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  LocalBackupSection(
                    access: transferAccess,
                    busy: _busy,
                    onCreate: () => _runWithBackupProgress(_createLocalBackup),
                    onRestore: _runRestoreFromAppLocalBackup,
                    onExport: () => _runWithBackupProgress(_exportLocalBackup),
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
                    onUpload: () => _runWithBackupProgress(_uploadDriveBackup),
                    onRestore: _runRestoreFromGoogleDrive,
                  ),
                  const SizedBox(height: 16),
                  _buildLegalSection(context, cs),
                ],
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
    );
  }
}
