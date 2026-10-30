import 'dart:async' show unawaited;
import 'dart:io';

import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/errors/user_facing_error.dart';
import 'package:quill_diary/application/session/session_providers.dart';
import 'package:quill_diary/application/session/session_state.dart';
import 'package:quill_diary/application/settings/drive_upload_coordinator.dart';
import 'package:quill_diary/application/settings/personalization_providers.dart';
import 'package:quill_diary/application/settings/settings_capabilities.dart';
import 'package:quill_diary/application/settings/settings_flow_controller.dart';
import 'package:quill_diary/application/settings/settings_health.dart';
import 'package:quill_diary/application/settings/settings_providers.dart';
import 'package:quill_diary/application/settings/settings_text.dart';
import 'package:quill_diary/application/settings/vault_transfer_capabilities.dart';
import 'package:quill_diary/application/transfer/transfer_feedback.dart';
import 'package:quill_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_diary/infrastructure/drive/drive_backup_service.dart';
import 'package:quill_diary/infrastructure/drive/drive_upload_job.dart';
import 'package:quill_diary/infrastructure/drive/google_oauth_config.dart';
import 'package:quill_diary/infrastructure/security/app_unlock_mode.dart';
import 'package:quill_diary/infrastructure/storage/backup_status_store.dart';
import 'package:quill_diary/infrastructure/storage/backup_task_progress.dart';
import 'package:quill_diary/infrastructure/storage/portable/backup_archive_inspection.dart';
import 'package:quill_diary/infrastructure/storage/portable/portable_export_io.dart';
import 'package:quill_diary/infrastructure/storage/portable/portable_import_preview.dart';
import 'package:quill_diary/infrastructure/storage/restore_precheck.dart';
import 'package:quill_diary/infrastructure/storage/vault_maintenance_models.dart';
import 'package:quill_diary/infrastructure/storage/vault_transfer_models.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/ai/ai_connection_settings_dialog.dart';
import 'package:quill_diary/presentation/home/portable_export_confirm.dart';
import 'package:quill_diary/presentation/home/portable_import_confirm.dart';
import 'package:quill_diary/presentation/restore/widgets/post_restore_outcome_dialog.dart';
import 'package:quill_diary/presentation/restore/widgets/restore_recovery_key_dialog.dart';
import 'package:quill_diary/presentation/settings/backup/backup_pick_list_item.dart';
import 'package:quill_diary/presentation/settings/widgets/drive_backup_section.dart';
import 'package:quill_diary/presentation/settings/widgets/local_backup_section.dart';
import 'package:quill_diary/presentation/settings/widgets/recovery_key_save_dialog.dart';
import 'package:quill_diary/presentation/settings/widgets/settings_action_dialogs.dart';
import 'package:quill_diary/presentation/settings/widgets/settings_flow_feedback.dart';
import 'package:quill_diary/presentation/settings/widgets/settings_sections.dart';
import 'package:quill_diary/shared/app_identifiers.dart';
import 'package:quill_diary/shared/navigation/app_routes.dart';
import 'package:quill_diary/shared/presentation/app_colors.dart';
import 'package:quill_diary/shared/presentation/app_feedback.dart';
import 'package:quill_diary/shared/presentation/app_scrollbar.dart';
import 'package:quill_diary/shared/presentation/display_format.dart';
import 'package:quill_diary/shared/presentation/widgets/app_action_button.dart';
import 'package:quill_diary/shared/presentation/widgets/app_loading_state.dart';
import 'package:quill_diary/shared/presentation/widgets/app_surface.dart';
import 'package:quill_diary/shared/utils/external_url.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({this.initialFocus, super.key});

  final SettingsFocusTarget? initialFocus;

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final TextEditingController _recoveryKeyInputController =
      TextEditingController();
  final GlobalKey _recoveryKeySectionKey = GlobalKey();
  final GlobalKey _localBackupSectionKey = GlobalKey();
  final FocusNode _recoveryKeyFocusNode = FocusNode();
  final FocusNode _localBackupFocusNode = FocusNode();
  final ScrollController _pageScrollController = ScrollController();
  bool _busy = false;
  bool _showBusyOverlay = true;
  String? _busyMessage;
  double? _busyProgress;
  bool _initialFocusScheduled = false;

  SettingsFlowController get _settingsFlow =>
      ref.read(settingsFlowControllerProvider);

  @override
  void initState() {
    super.initState();
    // 進設定即可重試成功收尾／停止清理，不單靠 App resumed。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(ref.read(driveUploadCoordinatorProvider.notifier).refresh());
    });
  }

  void _scheduleInitialFocusIfReady({required bool layoutReady}) {
    final SettingsFocusTarget? focus = widget.initialFocus;
    if (focus == null || _initialFocusScheduled || !layoutReady) {
      return;
    }
    _initialFocusScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_focusSection(focus));
    });
  }

  Future<void> _focusSection(
    SettingsFocusTarget focus, {
    int attempt = 0,
  }) async {
    final GlobalKey key = switch (focus) {
      SettingsFocusTarget.recoveryKey => _recoveryKeySectionKey,
      SettingsFocusTarget.externalRestore => _localBackupSectionKey,
    };
    final FocusNode focusNode = switch (focus) {
      SettingsFocusTarget.recoveryKey => _recoveryKeyFocusNode,
      SettingsFocusTarget.externalRestore => _localBackupFocusNode,
    };
    final BuildContext? target = key.currentContext;
    if (target == null && attempt < 5 && mounted) {
      if (_pageScrollController.hasClients) {
        _pageScrollController.jumpTo(
          _pageScrollController.position.maxScrollExtent,
        );
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_focusSection(focus, attempt: attempt + 1));
      });
      return;
    }
    if (target == null || !mounted) {
      return;
    }
    if (focus == SettingsFocusTarget.externalRestore) {
      final bool aligned = _jumpSectionToViewportTop(target);
      // 第一次進頁 maxScrollExtent 常還沒含下方 Drive，多對幾幀才穩。
      if (attempt < 8 && (!aligned || attempt < 3) && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(_focusSection(focus, attempt: attempt + 1));
        });
        return;
      }
      focusNode.requestFocus();
      return;
    }
    await Scrollable.ensureVisible(
      target,
      alignment: 0.08,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
    if (!mounted) {
      return;
    }
    focusNode.requestFocus();
  }

  /// 把區塊頂端對齊 ListView 可視區頂端。
  bool _jumpSectionToViewportTop(BuildContext target) {
    if (!_pageScrollController.hasClients) {
      return false;
    }
    final RenderObject? renderObject = target.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return false;
    }
    final RenderAbstractViewport? viewport = RenderAbstractViewport.maybeOf(
      renderObject,
    );
    if (viewport == null) {
      return false;
    }
    final ScrollPosition position = _pageScrollController.position;
    final double rawOffset = viewport
        .getOffsetToReveal(renderObject, 0.0)
        .offset;
    final double offset = rawOffset
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if ((position.pixels - offset).abs() >= 1) {
      _pageScrollController.jumpTo(offset);
    }
    return rawOffset <= position.maxScrollExtent + 1;
  }

  void updatePageState(VoidCallback callback) {
    setState(callback);
  }

  @override
  void dispose() {
    _recoveryKeyInputController.dispose();
    _recoveryKeyFocusNode.dispose();
    _localBackupFocusNode.dispose();
    _pageScrollController.dispose();
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
    final AsyncValue<VaultRepairSummary?> repairSummaryAsync = ref.watch(
      vaultRepairSummaryProvider,
    );
    final AsyncValue<VaultInspectSummary?> inspectSummaryAsync = ref.watch(
      vaultInspectSummaryProvider,
    );
    final AppSessionState? sessionState = sessionAsync.asData?.value;
    final RecoveryMetadata? recoveryMetadata =
        recoveryMetadataAsync.asData?.value;
    final SettingsPageCapabilities pageAccess =
        SettingsPageCapabilities.fromSessionState(
          sessionState: sessionState,
          hasRecoveryKey: recoveryMetadata != null,
        );
    final VaultTransferCapabilities transferAccess =
        pageAccess.vaultTransferCapabilities;
    _scheduleInitialFocusIfReady(
      layoutReady:
          !sessionAsync.isLoading &&
          !recoveryMetadataAsync.isLoading &&
          !trustedDeviceAccessAsync.isLoading &&
          !unlockModeAsync.isLoading &&
          !repairSummaryAsync.isLoading &&
          !inspectSummaryAsync.isLoading,
    );
    final bool isGoogleDriveConfigured =
        !Platform.isIOS || OAuthConfig.isIosGoogleDriveConfigured;
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsPageTitle)),
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            NotificationListener<OverscrollIndicatorNotification>(
              onNotification: (OverscrollIndicatorNotification notification) {
                notification.disallowIndicator();
                return false;
              },
              child: AppScrollablePageBody(
                controller: _pageScrollController,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: <Widget>[
                  const _SettingsTopNavSection(),
                  const SizedBox(height: 16),
                  Focus(
                    focusNode: _recoveryKeyFocusNode,
                    child: KeyedSubtree(
                      key: _recoveryKeySectionKey,
                      child: _buildSecurityStatusSection(
                        sessionAsync: sessionAsync,
                        recoveryMetadata: recoveryMetadata,
                        pageAccess: pageAccess,
                        trustedDeviceAccessAsync: trustedDeviceAccessAsync,
                        unlockModeAsync: unlockModeAsync,
                        repairSummaryAsync: repairSummaryAsync,
                        inspectSummaryAsync: inspectSummaryAsync,
                      ),
                    ),
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
                      loading: () => const AppLoadingState(),
                      error: (Object error, StackTrace _) => AppFeedbackBanner(
                        icon: Icons.error_outline_rounded,
                        message: userFacingErrorMessage(error, l10n: l10n),
                        tone: AppFeedbackTone.error,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SettingsSectionCard(
                    icon: Icons.chat_bubble_outline,
                    title: l10n.aiSettings,
                    description: l10n.aiSettingsSectionDescription,
                    child: AppActionGroup(
                      actions: [
                        AppActionButton(
                          label: l10n.aiOpenSettings,
                          icon: Icons.tune_rounded,
                          appearance: AppActionButtonAppearance.primary,
                          fullWidth: true,
                          onPressed: _busy
                              ? null
                              : () => unawaited(
                                  showAiConnectionSettingsDialog(context),
                                ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SettingsSectionCard(
                    icon: Icons.swap_horiz_rounded,
                    title: l10n.settingsImportExportSectionTitle,
                    description: transferAccess.canPortableTransfer
                        ? l10n.settingsImportExportSectionDescriptionEnabled
                        : transferAccess.portableTransferDisabledMessage(
                                l10n,
                              ) ??
                              l10n.vaultTransferNeedsUnlockForPortableTransfer,
                    child: AppActionGroup(
                      actions: <Widget>[
                        AppActionButton(
                          label: l10n.settingsImportExportImportButton,
                          icon: Icons.file_download_outlined,
                          appearance: AppActionButtonAppearance.tonal,
                          fullWidth: true,
                          onPressed:
                              _busy || !transferAccess.canPortableTransfer
                              ? null
                              : _importDocuments,
                        ),
                        AppActionButton(
                          label: l10n.settingsImportExportExportButton,
                          icon: Icons.file_upload_outlined,
                          appearance: AppActionButtonAppearance.primary,
                          fullWidth: true,
                          onPressed:
                              _busy || !transferAccess.canPortableTransfer
                              ? null
                              : _exportMarkdown,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Focus(
                    focusNode: _localBackupFocusNode,
                    child: LocalBackupSection(
                      key: _localBackupSectionKey,
                      access: transferAccess,
                      busy: _busy,
                      onCreate: () =>
                          _runWithBackupProgress(_createLocalBackup),
                      onRestore: _runRestoreFromAppLocalBackup,
                      onExport: () =>
                          _runWithBackupProgress(_exportLocalBackup),
                      onImport: _runRestoreFromLocalBackup,
                    ),
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
                    onCancelUpload: _cancelDriveUpload,
                    onAbandonCancelCleanup: _abandonCancelCleanup,
                  ),
                  const SizedBox(height: 16),
                  _buildLegalSection(context, cs),
                ],
              ),
            ),
            if (_busy && _showBusyOverlay)
              SettingsBlockingProgressOverlay(
                title: l10n.settingsProgressWorkingTitle,
                message: _busyMessage ?? l10n.settingsProgressDefault,
                hint: l10n.settingsProgressKeepAppOpenHint,
                progress: _busyProgress,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openExternalLink(String url) async {
    final BuildContext context = this.context;
    final bool opened = await launchExternalUrl(url);
    if (!context.mounted || opened) {
      return;
    }
    final AppLocalizations l10n = context.l10n;
    _showFeedback(
      SettingsFlowFeedback(
        l10n.legalExternalLinkUnavailableMessage,
        tone: SettingsFlowFeedbackTone.error,
      ),
    );
  }

  Widget _buildLegalSection(BuildContext context, ColorScheme cs) {
    final AppLocalizations l10n = context.l10n;
    return SettingsSectionCard(
      icon: Icons.gavel_outlined,
      title: l10n.settingsLegalSectionTitle,
      description: l10n.settingsLegalSectionDescription,
      child: Column(
        children: <Widget>[
          _SettingsLegalRow(
            title: l10n.settingsLegalSourceCodeTitle,
            onTap: () => unawaited(
              _openExternalLink(AppIdentifiers.sourceRepositoryUrl),
            ),
            colorScheme: cs,
          ),
          Divider(height: 1, color: context.appColors.outlineBorder().color),
          _SettingsLegalRow(
            title: l10n.settingsLegalPrivacyPolicyTitle,
            onTap: () =>
                unawaited(_openExternalLink(AppIdentifiers.privacyPolicyUrl)),
            colorScheme: cs,
          ),
          Divider(height: 1, color: context.appColors.outlineBorder().color),
          _SettingsLegalRow(
            title: l10n.settingsLegalThirdPartyNoticesTitle,
            onTap: () => unawaited(
              _openExternalLink(AppIdentifiers.thirdPartyNoticesUrl),
            ),
            colorScheme: cs,
          ),
          Divider(height: 1, color: context.appColors.outlineBorder().color),
          _SettingsLegalRow(
            title: l10n.settingsLegalContactAuthorTitle,
            onTap: () => unawaited(_openExternalLink(AppIdentifiers.issuesUrl)),
            colorScheme: cs,
          ),
          Divider(height: 1, color: context.appColors.outlineBorder().color),
          _SettingsLegalRow(
            title: l10n.settingsLegalRateOnGooglePlayTitle,
            onTap: () =>
                unawaited(_openExternalLink(AppIdentifiers.googlePlayStoreUrl)),
            colorScheme: cs,
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityStatusSection({
    required AsyncValue<AppSessionState> sessionAsync,
    required RecoveryMetadata? recoveryMetadata,
    required SettingsPageCapabilities pageAccess,
    required AsyncValue<bool> trustedDeviceAccessAsync,
    required AsyncValue<AppUnlockMode> unlockModeAsync,
    required AsyncValue<VaultRepairSummary?> repairSummaryAsync,
    required AsyncValue<VaultInspectSummary?> inspectSummaryAsync,
  }) {
    final AppSessionState? sessionState = sessionAsync.asData?.value;
    final bool hasUnlockedSession = pageAccess.hasUnlockedSession;
    final AppUnlockMode mode =
        unlockModeAsync.asData?.value ?? AppUnlockMode.none;
    final AppLocalizations l10n = context.l10n;
    final VaultRepairSummary? repairSummary = repairSummaryAsync.asData?.value;
    final VaultInspectSummary? inspectSummary =
        inspectSummaryAsync.asData?.value;
    return SettingsSectionCard(
      icon: Icons.health_and_safety_outlined,
      title: l10n.settingsSecurityOverviewSectionTitle,
      description: l10n.settingsSecurityOverviewSectionDescription,
      child: ref
          .watch(backupStatusProvider)
          .when(
            loading: () => const AppLoadingState(),
            error: (Object error, StackTrace _) => AppFeedbackBanner(
              icon: Icons.error_outline_rounded,
              message: userFacingErrorMessage(error, l10n: l10n),
              tone: AppFeedbackTone.error,
            ),
            data: (BackupStatusSnapshot backupStatus) =>
                trustedDeviceAccessAsync.when(
                  data: (bool hasTrustedDevice) => SettingsSecurityOverview(
                    hasRecoveryKey: recoveryMetadata != null,
                    recoveryKeyHint: recoveryMetadata?.recoveryKeyHint,
                    hasUnlockedSession: hasUnlockedSession,
                    hasTrustedDevice: hasTrustedDevice,
                    unlockModeLabel: mode.fullLabel(l10n),
                    indexMessage: settingsIndexStatusMessage(
                      l10n,
                      sessionState: sessionState,
                      hasUnlockedSession: hasUnlockedSession,
                      repairSummary: repairSummary,
                      inspectSummary: inspectSummary,
                    ),
                    indexHealthLevel: settingsIndexHealthLevel(
                      sessionState: sessionState,
                      hasUnlockedSession: hasUnlockedSession,
                      repairSummary: repairSummary,
                      inspectSummary: inspectSummary,
                    ),
                    backupStatus: backupStatus,
                    busy: _busy,
                    onCreateRecoveryKey: pageAccess.canCreateRecoveryKey
                        ? () => _runBusy(_createRecoveryKey)
                        : null,
                    onRotateRecoveryKey:
                        recoveryMetadata != null &&
                            pageAccess.vaultTransferCapabilities.canBackup
                        ? () => _runBusy(_rotateRecoveryKey)
                        : null,
                    onInspectVault: hasUnlockedSession
                        ? () => unawaited(_inspectVault())
                        : null,
                    onRetryTrustedUnlock:
                        sessionState?.status == AppLockStatus.locked
                        ? () => _runBusy(_retryTrustedUnlock)
                        : null,
                    lockPanel:
                        sessionState?.status == AppLockStatus.unlocked ||
                            sessionState?.status == AppLockStatus.locked
                        ? null
                        : sessionAsync.when(
                            data: (AppSessionState sessionState) =>
                                SettingsStatusPanel(
                                  sessionState: sessionState,
                                  busy: _busy,
                                  recoveryKeyInputController:
                                      _recoveryKeyInputController,
                                  recoveryKeyHint:
                                      recoveryMetadata?.recoveryKeyHint,
                                  bannerIcon: _sessionIcon(sessionState.status),
                                  bannerMessage: _sessionSummary(
                                    l10n,
                                    sessionState,
                                  ),
                                  bannerTone: _sessionTone(sessionState.status),
                                  onUnlockWithRecovery:
                                      sessionState.status ==
                                          AppLockStatus.recoveryRequired
                                      ? () => _runBusy(() async {
                                          _showFeedback(
                                            await _settingsFlow
                                                .unlockWithRecovery(
                                                  l10n,
                                                  _recoveryKeyInputController
                                                      .text
                                                      .trim(),
                                                ),
                                          );
                                        })
                                      : null,
                                  onCancelUnlock:
                                      sessionState.status ==
                                          AppLockStatus.unlocking
                                      ? () => _runBusy(() async {
                                          await _settingsFlow
                                              .cancelRecoveryUnlock();
                                        })
                                      : null,
                                ),
                            loading: () => const AppLoadingState(),
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
                  loading: () => const AppLoadingState(),
                  error: (Object error, StackTrace _) => AppFeedbackBanner(
                    icon: Icons.error_outline_rounded,
                    message: userFacingErrorMessage(error, l10n: l10n),
                    tone: AppFeedbackTone.error,
                  ),
                ),
          ),
    );
  }

  Future<bool> _confirmDeleteBackup({
    required String title,
    required String body,
  }) {
    return showSettingsDeleteBackupDialog(
      context: context,
      title: title,
      body: body,
    );
  }

  Future<LocalBackupFile?> _pickLocalBackup(
    List<LocalBackupFile> backups,
  ) async {
    final AppLocalizations l10n = context.l10n;
    if (backups.isEmpty) {
      _showFeedback(SettingsFlowFeedback(l10n.settingsLocalBackupNoBackups));
      return null;
    }
    if (!mounted) {
      return null;
    }
    final Map<String, LocalBackupFile> backupsById = <String, LocalBackupFile>{
      for (final LocalBackupFile backup in backups) backup.path: backup,
    };
    final BackupPickListItem? picked = await showSettingsBackupPickerDialog(
      context: context,
      title: l10n.settingsLocalBackupPickDialogTitle,
      emptyMessage: l10n.settingsLocalBackupNoBackups,
      deleteTooltip: l10n.settingsLocalBackupDeleteBackupTooltip,
      actionsDisabled: _busy,
      confirmDelete: (String fileName) => _confirmDeleteBackup(
        title: l10n.settingsLocalBackupDeleteConfirmTitle,
        body: l10n.settingsLocalBackupDeleteConfirmBody(fileName),
      ),
      items: backups
          .map(
            (LocalBackupFile backup) => BackupPickListItem(
              id: backup.path,
              createdAtLabel: _formatLocalBackupTime(backup),
              fileName: backup.name,
              sizeLabel: _formatBytes(backup.sizeBytes),
              onDelete: () async {
                await _settingsFlow.deleteAppLocalBackup(backup);
                _showFeedback(
                  SettingsFlowFeedback(
                    l10n.settingsLocalBackupDeleteBackupSuccess(backup.name),
                    tone: SettingsFlowFeedbackTone.success,
                  ),
                );
              },
            ),
          )
          .toList(),
    );
    return picked == null ? null : backupsById[picked.id];
  }

  Future<DriveBackupFile?> _pickDriveBackup(
    List<DriveBackupFile> backups,
  ) async {
    final AppLocalizations l10n = context.l10n;
    if (backups.isEmpty) {
      _showFeedback(SettingsFlowFeedback(l10n.settingsDriveBackupNoBackups));
      return null;
    }
    if (!mounted) {
      return null;
    }
    final Map<String, DriveBackupFile> backupsById = <String, DriveBackupFile>{
      for (final DriveBackupFile backup in backups) backup.id: backup,
    };
    final BackupPickListItem? picked = await showSettingsBackupPickerDialog(
      context: context,
      title: l10n.settingsDriveBackupPickDialogTitle,
      emptyMessage: l10n.settingsDriveBackupNoBackups,
      deleteTooltip: l10n.settingsDriveBackupDeleteBackupTooltip,
      actionsDisabled: _busy,
      confirmDelete: (String fileName) => _confirmDeleteBackup(
        title: l10n.settingsDriveBackupDeleteConfirmTitle,
        body: l10n.settingsDriveBackupDeleteConfirmBody(fileName),
      ),
      items: backups
          .map(
            (DriveBackupFile backup) => BackupPickListItem(
              id: backup.id,
              createdAtLabel: formatDriveBackupTime(l10n, backup.createdAt),
              fileName: backup.name,
              sizeLabel: backup.sizeBytes == null
                  ? null
                  : _formatBytes(backup.sizeBytes!),
              onDelete: () async {
                await _settingsFlow.deleteDriveBackup(backup);
                _showFeedback(
                  SettingsFlowFeedback(
                    l10n.settingsDriveBackupDeleteBackupSuccess(backup.name),
                    tone: SettingsFlowFeedbackTone.success,
                  ),
                );
              },
            ),
          )
          .toList(),
    );
    return picked == null ? null : backupsById[picked.id];
  }

  Future<void> _importDocuments() async {
    final BuildContext context = this.context;
    final AppLocalizations l10n = context.l10n;
    await _runBusy(() async {
      _showFeedback(
        await _settingsFlow.importDocuments(
          l10n,
          confirmPreview: (PortableImportPreview preview) async {
            // 確認／選篇期間只擋操作、不蓋「請稍候」遮罩
            if (mounted) {
              updatePageState(() {
                _showBusyOverlay = false;
              });
            }
            if (!context.mounted) {
              return const PortableImportConfirmResult(
                confirmed: false,
                selectedPreviewIndices: <int>{},
              );
            }
            final PortableImportConfirmResult result =
                await confirmPortableImport(context: context, preview: preview);
            if (mounted && result.confirmed) {
              updatePageState(() {
                _showBusyOverlay = true;
                _busyMessage = l10n.settingsImportExportImportProgress;
              });
            }
            return result;
          },
        ),
      );
    }, message: l10n.settingsImportExportPrepareProgress);
  }

  Future<void> _exportMarkdown() async {
    final BuildContext context = this.context;
    final AppLocalizations l10n = context.l10n;
    final MarkdownExportEstimate estimate = await _settingsFlow
        .estimateMarkdownExport();
    if (!context.mounted) {
      return;
    }
    if (estimate.entryCount == 0) {
      _showFeedback(
        SettingsFlowFeedback(l10n.settingsImportExportExportNoEntriesMessage),
      );
      return;
    }
    final MarkdownExportConfirmResult confirmation =
        await confirmMarkdownExport(context: context, estimate: estimate);
    if (!confirmation.confirmed || !context.mounted) {
      return;
    }
    await _runBusy(() async {
      _showFeedback(
        await _settingsFlow.exportMarkdown(
          l10n,
          entryIds: confirmation.selectedEntryIds,
          options: confirmation.options,
        ),
      );
    }, message: l10n.settingsImportExportExportProgress);
  }

  Future<void> _createRecoveryKey() async {
    final BuildContext context = this.context;
    final AppLocalizations l10n = context.l10n;
    final SettingsRecoveryKeyResult result = await _settingsFlow
        .createRecoveryKey(l10n);
    if (!context.mounted) {
      return;
    }
    _showFeedback(result.feedback);
    await showRecoveryKeySaveDialog(
      context,
      title: l10n.settingsRecoveryKeySaveDialogTitle,
      recoveryKey: result.recoveryKey,
    );
  }

  Future<void> _createLocalBackup(
    BackupTaskProgressListener reportProgress,
  ) async {
    final AppLocalizations l10n = context.l10n;
    final BackupPersistResult result = await _settingsFlow.createLocalBackup(
      onProgress: reportProgress,
    );
    await _recordBackupPersistResult(
      result,
      action: BackupStatusAction.localBackup,
      onSuccess: (String path) =>
          l10n.settingsLocalBackupBackupSuccessInApp(path),
    );
  }

  Future<void> _exportLocalBackup(
    BackupTaskProgressListener reportProgress,
  ) async {
    final AppLocalizations l10n = context.l10n;
    final BackupPersistResult result = await _settingsFlow.exportLocalBackup(
      l10n: l10n,
      onProgress: reportProgress,
    );
    await _recordBackupPersistResult(
      result,
      action: BackupStatusAction.externalExport,
      onSuccess: (String path) =>
          l10n.settingsLocalBackupBackupExportSuccess(path),
    );
  }

  Future<void> _uploadDriveBackup(
    BackupTaskProgressListener reportProgress,
  ) async {
    final AppLocalizations l10n = context.l10n;
    final DriveUploadCoordinator coordinator = ref.read(
      driveUploadCoordinatorProvider.notifier,
    );
    final BackupPersistResult result = await coordinator.startBackgroundUpload(
      onProgress: (BackupTaskProgress progress) {
        if (!mounted) {
          return;
        }
        // 準備階段專用文案；交接後 overlay 會關閉。
        updatePageState(() {
          _busyMessage = progress.phase == BackupTaskPhase.creatingBackup
              ? l10n.settingsBackupPhasePreparingDriveUpload
              : settingsBackupTaskProgressLabel(l10n, progress);
          _busyProgress = progress.fraction;
        });
        reportProgress(progress);
      },
    );
    if (result.status == BackupPersistStatus.inspectFailed) {
      await _recordBackupPersistResult(
        result,
        action: BackupStatusAction.driveUpload,
        onSuccess: (String path) => l10n.settingsDriveBackupUploadSuccess(path),
        inspectFailedMessage: (String message) =>
            l10n.settingsDriveBackupBackupInspectFailed(message),
      );
      return;
    }
    if (result.status == BackupPersistStatus.cancelled) {
      final String message = result.message.trim().isNotEmpty
          ? result.message.trim()
          : l10n.driveUploadAbandonedFailureBody;
      _showFeedback(
        SettingsFlowFeedback(message, tone: SettingsFlowFeedbackTone.error),
      );
      return;
    }
    if (result.status == BackupPersistStatus.success) {
      final String message = result.message == 'notifications_denied'
          ? '${l10n.driveUploadBackgroundStarted}\n${l10n.driveUploadNotificationsDeniedHint}'
          : l10n.driveUploadBackgroundStarted;
      _showFeedback(
        SettingsFlowFeedback(message, tone: SettingsFlowFeedbackTone.success),
      );
    }
  }

  Future<void> _cancelDriveUpload() async {
    final AppLocalizations l10n = context.l10n;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(l10n.driveUploadCancelConfirmTitle),
          content: Text(l10n.driveUploadCancelConfirmBody),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.commonActionCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.driveUploadCancelButton),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    await ref.read(driveUploadCoordinatorProvider.notifier).cancelUpload();
  }

  Future<void> _abandonCancelCleanup() async {
    final AppLocalizations l10n = context.l10n;
    final DriveUploadJobSnapshot? job = ref
        .read(driveUploadCoordinatorProvider)
        .job;
    if (job == null || !job.isCancelCleanupPending) {
      return;
    }
    final bool confirmed = await showAbandonCancelCleanupDialog(context);
    if (!confirmed || !mounted) {
      return;
    }
    try {
      await ref
          .read(driveUploadCoordinatorProvider.notifier)
          .abandonCancelCleanup(job.jobId);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showFeedback(
        SettingsFlowFeedback(
          userFacingErrorMessage(error, l10n: l10n),
          tone: SettingsFlowFeedbackTone.error,
        ),
      );
      await ref.read(driveUploadCoordinatorProvider.notifier).refresh();
    }
  }

  Future<void> _runRestoreFromAppLocalBackup() async {
    final AppLocalizations l10n = context.l10n;
    try {
      final PreparedRestoreRequest? request = await _settingsFlow
          .prepareAppLocalRestore(pickBackup: _pickLocalBackup);
      if (request == null) {
        return;
      }
      await _restorePreparedRequest(request);
    } catch (error) {
      _showFeedback(
        SettingsFlowFeedback(
          userFacingErrorMessage(error, l10n: l10n),
          tone: SettingsFlowFeedbackTone.error,
        ),
      );
    }
  }

  Future<void> _inspectVault() async {
    final BuildContext context = this.context;
    final AppLocalizations l10n = context.l10n;
    final bool confirmed = await showInspectVaultConfirmDialog(
      context,
      repairSummary: ref.read(vaultRepairSummaryProvider).asData?.value,
    );
    if (!confirmed || !context.mounted) return;
    VaultInspectReport? completed;
    await _runBusy(
      () async {
        completed = await _settingsFlow.inspectVault(
          onProgress: (VaultRepairPhase phase) {
            if (!mounted) return;
            updatePageState(() {
              _busyProgress = vaultInspectProgressFraction(phase);
              _busyMessage = switch (phase) {
                VaultRepairPhase.scanningEntries =>
                  l10n.settingsInspectVaultProgressScanningEntries,
                VaultRepairPhase.checkingAttachments =>
                  l10n.settingsInspectVaultProgressCheckingAttachments,
                VaultRepairPhase.rebuildingIndex =>
                  l10n.settingsInspectVaultProgressRebuildingIndex,
                VaultRepairPhase.rebuildingPeopleAnalytics =>
                  l10n.settingsInspectVaultProgressRebuildingPeople,
                VaultRepairPhase.cleaning =>
                  l10n.settingsInspectVaultProgressRebuildingIndex,
              };
            });
          },
        );
      },
      message: l10n.settingsInspectVaultProgressScanningEntries,
      initialProgress: vaultInspectProgressFraction(
        VaultRepairPhase.scanningEntries,
      ),
    );
    if (completed == null || !context.mounted) return;
    final bool? shouldRepair = await showInspectVaultResultDialog(
      context,
      completed!,
    );
    if (shouldRepair == true && context.mounted) {
      await _repairVaultAfterBackup();
    }
  }

  Future<void> _repairVaultAfterBackup() async {
    final BuildContext context = this.context;
    final AppLocalizations l10n = context.l10n;
    VaultRepairReport? completed;
    try {
      await _runBusy(
        () async {
          completed = await _settingsFlow.repairVaultAfterVerifiedBackup(
            onProgress: (VaultMaintenanceFlowPhase phase) {
              if (!mounted) return;
              updatePageState(() {
                _busyProgress = vaultMaintenanceProgressFraction(phase);
                _busyMessage = switch (phase) {
                  VaultMaintenanceFlowPhase.creatingBackup =>
                    l10n.settingsRepairVaultProgressCreatingBackup,
                  VaultMaintenanceFlowPhase.repairingEntries ||
                  VaultMaintenanceFlowPhase.inspectingEntries =>
                    l10n.settingsRepairVaultProgressRepairingEntries,
                  VaultMaintenanceFlowPhase.repairingAttachments ||
                  VaultMaintenanceFlowPhase.inspectingAttachments =>
                    l10n.settingsRepairVaultProgressRepairingAttachments,
                  VaultMaintenanceFlowPhase.updatingSearch ||
                  VaultMaintenanceFlowPhase.rebuildingIndex ||
                  VaultMaintenanceFlowPhase.rebuildingPeople =>
                    l10n.settingsRepairVaultProgressUpdatingSearch,
                };
              });
            },
          );
        },
        message: l10n.settingsRepairVaultProgressCreatingBackup,
        initialProgress: vaultMaintenanceProgressFraction(
          VaultMaintenanceFlowPhase.creatingBackup,
        ),
      );
    } on VaultRepairBackupException catch (error) {
      if (!context.mounted) return;
      final String message = switch (error.result.status) {
        BackupPersistStatus.cancelled =>
          l10n.settingsRepairVaultBackupCancelled,
        BackupPersistStatus.inspectFailed =>
          l10n.settingsRepairVaultBackupInspectFailed(
            localizedBackupPersistDetail(l10n, error.result.message),
          ),
        BackupPersistStatus.success => l10n.settingsRepairVaultBackupFailed,
      };
      _showFeedback(
        SettingsFlowFeedback(message, tone: SettingsFlowFeedbackTone.error),
      );
      return;
    }
    if (completed != null && context.mounted) {
      await showRepairVaultResultDialog(
        context: context,
        report: completed!,
        canSalvage: _settingsFlow.canSalvageFindings,
        onSalvage: (List<VaultFinding> findings) async =>
            (await _settingsFlow.prepareSalvageDraft(findings))?.token,
        onDelete: (List<VaultFinding> findings) async {
          try {
            await _settingsFlow.permanentlyDeleteAbnormalFindings(findings);
            return true;
          } on Object {
            return false;
          }
        },
      );
    }
  }

  String _formatLocalBackupTime(LocalBackupFile backup) {
    final AppLocalizations l10n = context.l10n;
    return DisplayFormat.formatDateTimeWithoutWeekday(l10n, backup.createdAt);
  }

  String _formatBytes(int bytes) => DisplayFormat.formatBytesForDisplay(bytes);

  Future<void> _runRestoreFromLocalBackup() async {
    final AppLocalizations l10n = context.l10n;
    try {
      final PreparedRestoreRequest? request = await _settingsFlow
          .prepareExternalRestore(l10n);
      if (request == null) {
        return;
      }
      await _restorePreparedRequest(request);
    } catch (error) {
      _showFeedback(
        SettingsFlowFeedback(
          userFacingErrorMessage(error, l10n: l10n),
          tone: SettingsFlowFeedbackTone.error,
        ),
      );
    }
  }

  Future<void> _runRestoreFromGoogleDrive() async {
    final AppLocalizations l10n = context.l10n;
    try {
      final List<DriveBackupFile> backups = await _settingsFlow
          .listDriveBackups();
      final DriveBackupFile? backup = await _pickDriveBackup(backups);
      if (backup == null) {
        return;
      }
      PreparedRestoreRequest? request;
      await _runWithBackupProgress((
        BackupTaskProgressListener reportProgress,
      ) async {
        request = await _settingsFlow.prepareDriveRestore(
          pickBackup: (List<DriveBackupFile> _) async => backup,
          onProgress: reportProgress,
        );
      });
      if (request == null) {
        return;
      }
      await _restorePreparedRequest(request!);
    } catch (error) {
      _showFeedback(
        SettingsFlowFeedback(
          userFacingErrorMessage(error, l10n: l10n),
          tone: SettingsFlowFeedbackTone.error,
        ),
      );
    }
  }

  Future<void> _linkGoogleDrive() async {
    final AppLocalizations l10n = context.l10n;
    _showFeedback(await _settingsFlow.linkGoogleDrive(l10n));
  }

  Future<void> _switchGoogleDrive() async {
    final AppLocalizations l10n = context.l10n;
    final DriveUploadJobSnapshot? job = ref
        .read(driveUploadCoordinatorProvider)
        .job;
    if (job != null &&
        job.blocksConflictingDriveActions &&
        !job.needsCancelCleanupAccountRecovery) {
      _showFeedback(
        SettingsFlowFeedback(
          job.isCancelCleanupPending
              ? l10n.driveUploadCancelCleanupBlocksAccountActions
              : l10n.driveUploadBusyBlocksAccountActions,
          tone: SettingsFlowFeedbackTone.warning,
        ),
      );
      return;
    }
    _showFeedback(await _settingsFlow.switchGoogleDrive(l10n));
  }

  Future<void> _disconnectGoogleDrive() async {
    if (!mounted) {
      return;
    }
    final AppLocalizations l10n = context.l10n;
    final DriveUploadJobSnapshot? job = ref
        .read(driveUploadCoordinatorProvider)
        .job;
    if (job != null &&
        job.blocksConflictingDriveActions &&
        !job.needsCancelCleanupAccountRecovery) {
      _showFeedback(
        SettingsFlowFeedback(
          job.isCancelCleanupPending
              ? l10n.driveUploadCancelCleanupBlocksAccountActions
              : l10n.driveUploadBusyBlocksAccountActions,
          tone: SettingsFlowFeedbackTone.warning,
        ),
      );
      return;
    }
    final bool confirmed = await showDisconnectDriveDialog(context);
    if (!confirmed) {
      return;
    }
    await _runBusy(() async {
      _showFeedback(await _settingsFlow.disconnectGoogleDrive(l10n));
    }, message: l10n.settingsIndexDisconnectDriveProgress);
  }

  Future<void> _restorePreparedRequest(PreparedRestoreRequest request) async {
    final AppLocalizations l10n = context.l10n;
    try {
      if (!mounted) {
        return;
      }
      final bool confirmed = await showRestoreConfirmDialog(
        context,
        request.precheck,
        driveBackupName: request.driveBackupName,
      );
      if (!confirmed || !mounted) {
        return;
      }
      String? backupRecoveryKey;
      if (request.precheck.expectsRecoveryKeyAfterRestore) {
        backupRecoveryKey = await _collectValidatedRestoreRecoveryKey(
          backupFile: request.backupFile,
          precheck: request.precheck,
        );
        if (!mounted || backupRecoveryKey == null) {
          return;
        }
      }
      SettingsRestoreResult? result;
      await _runWithBackupProgress((
        BackupTaskProgressListener reportProgress,
      ) async {
        result = await _settingsFlow.restorePreparedRequest(
          l10n: l10n,
          request: request,
          backupRecoveryKey: backupRecoveryKey,
          recoveryKeyAlreadyVerified: backupRecoveryKey != null,
          onProgress: reportProgress,
        );
      });
      if (result != null) {
        await _presentRestoreResult(result!);
      }
    } on StateError catch (error) {
      _showFeedback(
        SettingsFlowFeedback(
          userFacingErrorMessage(error, l10n: l10n),
          tone: SettingsFlowFeedbackTone.error,
        ),
      );
    }
  }

  Future<String?> _collectValidatedRestoreRecoveryKey({
    required File backupFile,
    required RestorePrecheck precheck,
  }) async {
    final BuildContext context = this.context;
    String? validationError;
    while (true) {
      if (!context.mounted) {
        return null;
      }
      final String? recoveryKey = await showRestoreRecoveryKeyDialog(
        context,
        precheck: precheck,
        validationError: validationError,
      );
      if (!context.mounted) {
        return null;
      }
      if (recoveryKey == null) {
        return null;
      }
      try {
        await _settingsFlow.verifyRestoreRecoveryKey(backupFile, recoveryKey);
        return recoveryKey;
      } on VaultBackupException catch (error) {
        if (!context.mounted) {
          return null;
        }
        validationError = vaultBackupIssueMessage(context.l10n, error.issue);
      }
    }
  }

  Future<void> _presentRestoreResult(SettingsRestoreResult result) async {
    final BuildContext context = this.context;
    if (!context.mounted) {
      return;
    }
    _showFeedback(result.feedback);
    if (result.prompt != null) {
      final bool runPrimary = await showPostRestoreOutcomeDialog(
        context,
        outcome: result.prompt!,
      );
      if (!context.mounted) {
        return;
      }
      if (runPrimary) {
        switch (result.prompt!.primaryAction) {
          case SettingsRestorePrimaryAction.retryVerification:
            await _settingsFlow.retryTrustedUnlock();
          case SettingsRestorePrimaryAction.openSettingsRecovery:
            context.go(AppRoutes.settingsRoute);
        }
      } else {
        context.go(AppRoutes.homeRoute);
      }
      return;
    }
    switch (result.navigationTarget) {
      case SettingsRestoreNavigationTarget.home:
        context.go(AppRoutes.homeRoute);
      case SettingsRestoreNavigationTarget.settings:
        context.go(AppRoutes.settingsRoute);
      case null:
        break;
    }
  }

  Future<void> _retryTrustedUnlock() async {
    await _settingsFlow.retryTrustedUnlock();
  }

  Future<void> _applyUnlockMode(AppUnlockMode mode) async {
    final AppLocalizations l10n = context.l10n;
    _showFeedback(await _settingsFlow.applyUnlockMode(l10n, mode));
  }

  Future<void> _rotateRecoveryKey() async {
    final BuildContext context = this.context;
    if (!context.mounted) {
      return;
    }
    final AppLocalizations l10n = context.l10n;
    final bool confirmed = await showRotateRecoveryKeyDialog(context);
    if (!confirmed) {
      return;
    }
    final SettingsRecoveryKeyResult result = await _settingsFlow
        .rotateRecoveryKey(l10n);
    if (!context.mounted) {
      return;
    }
    _showFeedback(result.feedback);
    await showRecoveryKeySaveDialog(
      context,
      title: l10n.settingsRecoveryKeySaveNewDialogTitle,
      recoveryKey: result.recoveryKey,
    );
  }

  Future<void> _runBusy(
    Future<void> Function() action, {
    String? message,
    double? initialProgress,
  }) async {
    final AppLocalizations l10n = context.l10n;
    updatePageState(() {
      _busy = true;
      _showBusyOverlay = true;
      _busyMessage = message;
      _busyProgress = initialProgress;
    });
    try {
      await action();
    } catch (error) {
      _showFeedback(
        SettingsFlowFeedback(
          userFacingErrorMessage(error, l10n: l10n),
          tone: SettingsFlowFeedbackTone.error,
        ),
      );
    } finally {
      if (mounted) {
        updatePageState(() {
          _busy = false;
          _showBusyOverlay = true;
          _busyMessage = null;
          _busyProgress = null;
        });
      }
    }
  }

  Future<void> _runWithBackupProgress(
    Future<void> Function(BackupTaskProgressListener reportProgress) action,
  ) async {
    final AppLocalizations l10n = context.l10n;
    void reportProgress(BackupTaskProgress progress) {
      if (!mounted) {
        return;
      }
      updatePageState(() {
        _busyMessage = settingsBackupTaskProgressLabel(l10n, progress);
        _busyProgress = progress.fraction;
      });
    }

    updatePageState(() {
      _busy = true;
      _showBusyOverlay = true;
      _busyMessage = null;
      _busyProgress = null;
    });
    try {
      await action(reportProgress);
    } catch (error) {
      _showFeedback(
        SettingsFlowFeedback(
          userFacingErrorMessage(error, l10n: l10n),
          tone: SettingsFlowFeedbackTone.error,
        ),
      );
    } finally {
      if (mounted) {
        updatePageState(() {
          _busy = false;
          _showBusyOverlay = true;
          _busyMessage = null;
          _busyProgress = null;
        });
      }
    }
  }

  Future<void> _recordBackupPersistResult(
    BackupPersistResult result, {
    required BackupStatusAction action,
    required String Function(String savedPath) onSuccess,
    String Function(String message)? inspectFailedMessage,
    String? driveAccountLabel,
  }) async {
    _showFeedback(
      await _settingsFlow.recordBackupPersistResult(
        l10n: context.l10n,
        result: result,
        action: action,
        onSuccess: onSuccess,
        inspectFailedMessage: inspectFailedMessage,
        driveAccountLabel: driveAccountLabel,
      ),
    );
  }

  void _showFeedback(SettingsFlowFeedback? feedback) {
    showSettingsFlowFeedback(context, feedback);
  }
}

class _SettingsTopNavSection extends StatelessWidget {
  const _SettingsTopNavSection();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: _SettingsAppBarNavActions(),
    );
  }
}

class _SettingsAppBarNavActions extends StatelessWidget {
  const _SettingsAppBarNavActions();

  static const double _gap = 8;
  static const double _horizontalPadding = 16;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Align(
        alignment: Alignment.centerLeft,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              _SettingsAppBarNavButton(
                label: context.l10n.personalizationNavButtonLabel,
                icon: Icons.tune_rounded,
                onPressed: () =>
                    unawaited(context.push(AppRoutes.personalizationRoute)),
              ),
              const SizedBox(width: _gap),
              _SettingsAppBarNavButton(
                label: context.l10n.aboutPageTitle,
                icon: Icons.info_outline_rounded,
                onPressed: () => unawaited(context.push(AppRoutes.aboutRoute)),
              ),
              const SizedBox(width: _gap),
              _SettingsAppBarNavButton(
                label: context.l10n.settingsSupportNavButtonLabel,
                icon: Icons.favorite_border_rounded,
                onPressed: () =>
                    unawaited(context.push(AppRoutes.supportRoute)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsAppBarNavButton extends StatelessWidget {
  const _SettingsAppBarNavButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Material(
      color: Color.alphaBlend(
        cs.surfaceContainerHigh.withValues(alpha: 0.9),
        cs.surface,
      ),
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.9)),
        ),
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: 16, color: cs.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsLegalRow extends StatelessWidget {
  const _SettingsLegalRow({
    required this.title,
    required this.onTap,
    required this.colorScheme,
  });

  final String title;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _sessionSummary(AppLocalizations l10n, AppSessionState sessionState) {
  final String? message = sessionState.message;
  return switch (sessionState.status) {
    AppLockStatus.uninitialized =>
      message ?? l10n.settingsSecurityLockStatusPreparing,
    AppLockStatus.unlocking =>
      message ?? l10n.sessionTrustedUnlockInProgressMessage,
    AppLockStatus.unlocked =>
      message ?? l10n.settingsSecurityLockStatusUnlocked,
    AppLockStatus.locked =>
      message ?? l10n.sessionLockedRetryVerificationMessage,
    AppLockStatus.recoveryRequired =>
      message ?? l10n.sessionRecoveryRequiredAfterRestoreMessage,
    AppLockStatus.fatalError =>
      message ?? l10n.settingsSecurityLockStatusFatalError,
  };
}

IconData _sessionIcon(AppLockStatus status) {
  return switch (status) {
    AppLockStatus.uninitialized => Icons.hourglass_top_rounded,
    AppLockStatus.unlocking => Icons.sync_rounded,
    AppLockStatus.unlocked => Icons.lock_open_rounded,
    AppLockStatus.locked => Icons.lock_outline_rounded,
    AppLockStatus.recoveryRequired => Icons.key_outlined,
    AppLockStatus.fatalError => Icons.error_outline_rounded,
  };
}

AppFeedbackTone _sessionTone(AppLockStatus status) {
  return switch (status) {
    AppLockStatus.uninitialized => AppFeedbackTone.info,
    AppLockStatus.unlocking => AppFeedbackTone.info,
    AppLockStatus.recoveryRequired => AppFeedbackTone.warning,
    AppLockStatus.fatalError => AppFeedbackTone.error,
    _ => AppFeedbackTone.info,
  };
}
